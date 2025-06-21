# frozen_string_literal: true

class SmartPayrollCalculationService
  include Callable
  
  attr_reader :employee, :year, :month, :calculation_options
  
  def initialize(employee, year, month, calculation_options = {})
    @employee = employee
    @year = year.to_i
    @month = month.to_i
    @calculation_options = calculation_options.with_indifferent_access
  end
  
  def call
    # 檢查是否已有薪資記錄
    existing_payroll = employee.payrolls.find_by(year: year, month: month)
    
    if existing_payroll && !calculation_options[:force_recalculate]
      return {
        success: false,
        error: '該月份已有薪資記錄，如需重新計算請使用強制重算選項',
        payroll: existing_payroll
      }
    end
    
    # 計算薪資
    calculation_result = calculate_smart_payroll
    
    if calculation_result[:success]
      # 建立或更新薪資記錄
      payroll = existing_payroll || employee.payrolls.build(year: year, month: month)
      
      # 設定薪資資料
      payroll.assign_attributes(calculation_result[:payroll_data])
      
      if payroll.save
        # 建立薪資明細
        create_payroll_statement(payroll, calculation_result[:statement_data])
        
        {
          success: true,
          payroll: payroll,
          calculation_details: calculation_result[:details]
        }
      else
        {
          success: false,
          error: payroll.errors.full_messages.join(', '),
          payroll: payroll
        }
      end
    else
      calculation_result
    end
  end
  
  private
  
  def calculate_smart_payroll
    # 取得員工最新薪資設定
    salary = employee.salaries.where('effective_date <= ?', Date.new(year, month, 1)).order(:effective_date).last
    
    unless salary
      return {
        success: false,
        error: '找不到該員工的薪資設定'
      }
    end
    
    # 計算出勤相關數據
    attendance_data = calculate_attendance_data
    
    # 計算基本薪資
    basic_pay_data = calculate_basic_pay(salary, attendance_data)
    
    # 計算加班費
    overtime_data = calculate_overtime_pay(salary, attendance_data)
    
    # 計算津貼補助
    allowance_data = calculate_allowances(salary, attendance_data)
    
    # 計算扣款項目
    deduction_data = calculate_deductions(salary, attendance_data)
    
    # 計算總薪資
    gross_pay = basic_pay_data[:amount] + overtime_data[:total] + allowance_data[:total]
    total_deductions = deduction_data[:total]
    net_pay = gross_pay - total_deductions
    
    # 組合薪資資料
    payroll_data = {
      salary: salary,
      year: year,
      month: month
    }
    
    # 組合薪資明細資料
    statement_data = {
      amount: gross_pay,
      net_income: net_pay,
      basic_salary: basic_pay_data[:amount],
      overtime_pay: overtime_data[:total],
      allowances: allowance_data[:total],
      labor_insurance: deduction_data[:labor_insurance],
      health_insurance: deduction_data[:health_insurance],
      income_tax: deduction_data[:income_tax],
      other_deductions: deduction_data[:other],
      work_days: attendance_data[:work_days],
      work_hours: attendance_data[:total_hours],
      overtime_hours: attendance_data[:overtime_hours]
    }
    
    # 計算詳情
    calculation_details = {
      attendance: attendance_data,
      basic_pay: basic_pay_data,
      overtime: overtime_data,
      allowances: allowance_data,
      deductions: deduction_data,
      summary: {
        gross_pay: gross_pay,
        total_deductions: total_deductions,
        net_pay: net_pay
      }
    }
    
    {
      success: true,
      payroll_data: payroll_data,
      statement_data: statement_data,
      details: calculation_details
    }
  end
  
  def calculate_attendance_data
    start_date = Date.new(year, month, 1)
    end_date = start_date.end_of_month
    
    # 取得該月份所有出勤記錄
    attendances = employee.attendances
                         .where(punch_time: start_date.beginning_of_day..end_date.end_of_day)
                         .order(:punch_time)
    
    # 計算工作天數和時數
    work_days = 0
    total_hours = 0.0
    overtime_hours = 0.0
    late_days = 0
    early_leave_days = 0
    
    (start_date..end_date).each do |date|
      next unless date.wday.between?(1, 5) # 只計算工作日
      
      daily_attendances = attendances.select { |a| a.punch_time.to_date == date }
      
      if daily_attendances.any?
        work_days += 1
        
        # 計算當日工作時數
        daily_hours = Attendance.calculate_work_hours(employee.id, date)
        total_hours += daily_hours
        
        # 計算當日加班時數
        daily_overtime = Attendance.calculate_overtime_hours(employee.id, date)
        overtime_hours += daily_overtime
        
        # 檢查遲到早退
        clock_in = daily_attendances.find { |a| a.punch_type == 'clock_in' }
        clock_out = daily_attendances.find { |a| a.punch_type == 'clock_out' }
        
        late_days += 1 if clock_in&.late?
        early_leave_days += 1 if clock_out&.early_leave?
      end
    end
    
    # 計算應工作天數
    expected_work_days = (start_date..end_date).count { |date| date.wday.between?(1, 5) }
    absent_days = expected_work_days - work_days
    
    {
      expected_work_days: expected_work_days,
      work_days: work_days,
      absent_days: absent_days,
      total_hours: total_hours.round(2),
      overtime_hours: overtime_hours.round(2),
      late_days: late_days,
      early_leave_days: early_leave_days,
      attendance_rate: work_days > 0 ? ((work_days.to_f / expected_work_days) * 100).round(2) : 0
    }
  end
  
  def calculate_basic_pay(salary, attendance_data)
    case salary.cycle
    when 'monthly'
      # 月薪制：根據出勤率計算
      base_amount = salary.monthly_wage
      attendance_rate = attendance_data[:attendance_rate] / 100.0
      
      # 如果出勤率低於設定門檻，按比例扣薪
      min_attendance_rate = calculation_options[:min_attendance_rate] || 0.8
      
      if attendance_rate < min_attendance_rate
        actual_amount = base_amount * attendance_rate
      else
        actual_amount = base_amount
      end
      
      {
        type: 'monthly',
        base_amount: base_amount,
        attendance_rate: attendance_data[:attendance_rate],
        amount: actual_amount.round,
        deduction_reason: attendance_rate < min_attendance_rate ? '出勤率不足' : nil
      }
      
    when 'hourly'
      # 時薪制：根據實際工作時數計算
      hourly_rate = salary.hourly_wage
      total_amount = hourly_rate * attendance_data[:total_hours]
      
      {
        type: 'hourly',
        hourly_rate: hourly_rate,
        work_hours: attendance_data[:total_hours],
        amount: total_amount.round
      }
      
    else
      # 其他薪資制度
      {
        type: 'other',
        amount: salary.monthly_wage || 0
      }
    end
  end
  
  def calculate_overtime_pay(salary, attendance_data)
    return { total: 0, details: [] } if attendance_data[:overtime_hours].zero?
    
    # 使用現有的加班費計算服務
    overtime_service = OvertimeCalculationService.new(
      employee, 
      year, 
      month, 
      attendance_data[:overtime_hours]
    )
    
    overtime_result = overtime_service.call
    
    {
      total: overtime_result[:total_amount] || 0,
      details: overtime_result[:breakdown] || [],
      hours: attendance_data[:overtime_hours]
    }
  end
  
  def calculate_allowances(salary, attendance_data)
    total = 0
    details = {}
    
    # 設備津貼
    if salary.equipment_subsidy > 0
      details[:equipment] = salary.equipment_subsidy
      total += salary.equipment_subsidy
    end
    
    # 交通津貼
    if salary.commuting_subsidy > 0
      details[:commuting] = salary.commuting_subsidy
      total += salary.commuting_subsidy
    end
    
    # 主管津貼
    if salary.supervisor_allowance > 0
      details[:supervisor] = salary.supervisor_allowance
      total += salary.supervisor_allowance
    end
    
    # 全勤獎金（如果沒有缺勤和遲到早退）
    if calculation_options[:perfect_attendance_bonus] && 
       attendance_data[:absent_days].zero? && 
       attendance_data[:late_days].zero? && 
       attendance_data[:early_leave_days].zero?
      
      bonus_amount = calculation_options[:perfect_attendance_bonus].to_i
      details[:perfect_attendance] = bonus_amount
      total += bonus_amount
    end
    
    {
      total: total,
      details: details
    }
  end
  
  def calculate_deductions(salary, attendance_data)
    # 勞保費
    labor_insurance = salary.labor_insurance || 0
    
    # 健保費
    health_insurance = salary.health_insurance || 0
    
    # 所得稅
    income_tax = salary.fixed_income_tax || 0
    
    # 其他扣款
    other_deductions = 0
    
    # 遲到早退扣款
    if calculation_options[:late_penalty_per_time]
      late_penalty = attendance_data[:late_days] * calculation_options[:late_penalty_per_time].to_i
      other_deductions += late_penalty
    end
    
    if calculation_options[:early_leave_penalty_per_time]
      early_leave_penalty = attendance_data[:early_leave_days] * calculation_options[:early_leave_penalty_per_time].to_i
      other_deductions += early_leave_penalty
    end
    
    total = labor_insurance + health_insurance + income_tax + other_deductions
    
    {
      labor_insurance: labor_insurance,
      health_insurance: health_insurance,
      income_tax: income_tax,
      other: other_deductions,
      total: total,
      details: {
        late_penalty: attendance_data[:late_days] * (calculation_options[:late_penalty_per_time] || 0),
        early_leave_penalty: attendance_data[:early_leave_days] * (calculation_options[:early_leave_penalty_per_time] || 0)
      }
    }
  end
  
  def create_payroll_statement(payroll, statement_data)
    statement = payroll.statement || payroll.build_statement
    statement.assign_attributes(statement_data)
    statement.save!
    statement
  end
end
