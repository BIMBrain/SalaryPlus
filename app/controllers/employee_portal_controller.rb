# frozen_string_literal: true

class EmployeePortalController < ApplicationController
  before_action :authenticate_employee
  before_action :set_current_employee
  
  def index
    @recent_payrolls = @current_employee.payrolls.includes(:salary).order(year: :desc, month: :desc).limit(6)
    @current_year = Date.current.year
    @current_month = Date.current.month
    
    # 統計數據
    @total_payrolls = @current_employee.payrolls.count
    @ytd_gross_pay = calculate_ytd_gross_pay
    @ytd_tax_withheld = calculate_ytd_tax_withheld
    @ytd_insurance = calculate_ytd_insurance
    
    # 最近出勤記錄
    @recent_attendances = @current_employee.attendances.order(punch_time: :desc).limit(10)
    @this_month_work_hours = calculate_this_month_work_hours
  end
  
  def payrolls
    @year = params[:year]&.to_i || Date.current.year
    @payrolls = @current_employee.payrolls
                                .includes(:salary, :statement)
                                .where(year: @year)
                                .order(month: :desc)
    
    @years = @current_employee.payrolls.distinct.pluck(:year).sort.reverse
    @annual_summary = calculate_annual_summary(@year)
  end
  
  def payroll
    @payroll = @current_employee.payrolls.find(params[:id])
    @statement = @payroll.statement
    @salary = @payroll.salary
  end
  
  def insurance
    @year = params[:year]&.to_i || Date.current.year
    @payrolls = @current_employee.payrolls
                                .includes(:salary)
                                .where(year: @year)
                                .order(month: :desc)
    
    @years = @current_employee.payrolls.distinct.pluck(:year).sort.reverse
    @insurance_summary = calculate_insurance_summary(@year)
  end
  
  def tax_documents
    @year = params[:year]&.to_i || Date.current.year
    @payrolls = @current_employee.payrolls
                                .includes(:salary, :statement)
                                .where(year: @year)
                                .order(month: :desc)
    
    @years = @current_employee.payrolls.distinct.pluck(:year).sort.reverse
    @tax_summary = calculate_tax_summary(@year)
  end
  
  def attendance
    @year = params[:year]&.to_i || Date.current.year
    @month = params[:month]&.to_i || Date.current.month
    
    start_date = Date.new(@year, @month, 1)
    end_date = start_date.end_of_month
    
    @attendances = @current_employee.attendances
                                   .where(punch_time: start_date.beginning_of_day..end_date.end_of_day)
                                   .order(:punch_time)
    
    @attendance_summary = calculate_attendance_summary(@year, @month)
    @calendar_data = generate_attendance_calendar(@year, @month)
  end
  
  def profile
    # 顯示員工基本資料（唯讀）
  end
  
  def download_payslip
    @payroll = @current_employee.payrolls.find(params[:id])
    
    respond_to do |format|
      format.pdf do
        pdf = PayslipPdfService.new(@payroll).generate
        send_data pdf, filename: "payslip_#{@payroll.year}_#{@payroll.month}.pdf", type: 'application/pdf'
      end
    end
  end
  
  def download_tax_statement
    @year = params[:year]&.to_i || Date.current.year
    @payrolls = @current_employee.payrolls.where(year: @year)
    
    respond_to do |format|
      format.pdf do
        pdf = TaxStatementPdfService.new(@current_employee, @year).generate
        send_data pdf, filename: "tax_statement_#{@year}.pdf", type: 'application/pdf'
      end
    end
  end
  
  private
  
  def authenticate_employee
    # 簡單的員工認證機制 - 在實際應用中應該使用更安全的認證方式
    if session[:employee_id].blank?
      redirect_to employee_login_path, alert: '請先登入'
    end
  end
  
  def set_current_employee
    @current_employee = Employee.find(session[:employee_id])
  rescue ActiveRecord::RecordNotFound
    session[:employee_id] = nil
    redirect_to employee_login_path, alert: '員工不存在'
  end
  
  def calculate_ytd_gross_pay
    @current_employee.payrolls
                     .where(year: Date.current.year)
                     .joins(:statement)
                     .sum('statements.amount')
  end
  
  def calculate_ytd_tax_withheld
    @current_employee.payrolls
                     .where(year: Date.current.year)
                     .joins(:statement)
                     .sum('statements.income_tax')
  end
  
  def calculate_ytd_insurance
    labor_insurance = @current_employee.payrolls
                                      .where(year: Date.current.year)
                                      .joins(:salary)
                                      .sum('salaries.labor_insurance')
    
    health_insurance = @current_employee.payrolls
                                       .where(year: Date.current.year)
                                       .joins(:salary)
                                       .sum('salaries.health_insurance')
    
    labor_insurance + health_insurance
  end
  
  def calculate_this_month_work_hours
    current_month_start = Date.current.beginning_of_month
    current_month_end = Date.current.end_of_month
    
    total_hours = 0
    (current_month_start..current_month_end).each do |date|
      total_hours += Attendance.calculate_work_hours(@current_employee.id, date)
    end
    
    total_hours
  end
  
  def calculate_annual_summary(year)
    payrolls = @current_employee.payrolls.includes(:statement).where(year: year)
    
    {
      total_gross_pay: payrolls.joins(:statement).sum('statements.amount'),
      total_net_pay: payrolls.joins(:statement).sum('statements.net_income'),
      total_tax: payrolls.joins(:statement).sum('statements.income_tax'),
      total_labor_insurance: payrolls.joins(:salary).sum('salaries.labor_insurance'),
      total_health_insurance: payrolls.joins(:salary).sum('salaries.health_insurance'),
      months_worked: payrolls.count
    }
  end
  
  def calculate_insurance_summary(year)
    payrolls = @current_employee.payrolls.includes(:salary).where(year: year)
    
    {
      total_labor_insurance: payrolls.joins(:salary).sum('salaries.labor_insurance'),
      total_health_insurance: payrolls.joins(:salary).sum('salaries.health_insurance'),
      average_insured_salary: payrolls.joins(:salary).average('salaries.insured_for_health')&.round || 0,
      months_insured: payrolls.count
    }
  end
  
  def calculate_tax_summary(year)
    payrolls = @current_employee.payrolls.includes(:statement).where(year: year)
    
    {
      total_gross_income: payrolls.joins(:statement).sum('statements.amount'),
      total_tax_withheld: payrolls.joins(:statement).sum('statements.income_tax'),
      total_deductions: payrolls.joins(:statement).sum('statements.subsidy_income'),
      taxable_income: payrolls.joins(:statement).sum('statements.amount - statements.subsidy_income'),
      average_tax_rate: calculate_average_tax_rate(payrolls)
    }
  end
  
  def calculate_average_tax_rate(payrolls)
    total_income = payrolls.joins(:statement).sum('statements.amount')
    total_tax = payrolls.joins(:statement).sum('statements.income_tax')
    
    return 0 if total_income.zero?
    ((total_tax / total_income) * 100).round(2)
  end
  
  def calculate_attendance_summary(year, month)
    start_date = Date.new(year, month, 1)
    end_date = start_date.end_of_month
    
    attendances = @current_employee.attendances
                                  .where(punch_time: start_date.beginning_of_day..end_date.end_of_day)
    
    work_days = (start_date..end_date).count { |date| date.wday.between?(1, 5) }
    present_days = attendances.where(punch_type: 'clock_in').distinct.count('DATE(punch_time)')
    late_days = attendances.select(&:late?).count
    
    total_work_hours = (start_date..end_date).sum do |date|
      Attendance.calculate_work_hours(@current_employee.id, date)
    end
    
    {
      work_days: work_days,
      present_days: present_days,
      absent_days: work_days - present_days,
      late_days: late_days,
      total_work_hours: total_work_hours,
      average_daily_hours: present_days > 0 ? (total_work_hours / present_days).round(2) : 0
    }
  end
  
  def generate_attendance_calendar(year, month)
    start_date = Date.new(year, month, 1)
    end_date = start_date.end_of_month
    
    calendar_data = {}
    
    (start_date..end_date).each do |date|
      attendances = @current_employee.attendances
                                    .where(punch_time: date.beginning_of_day..date.end_of_day)
                                    .order(:punch_time)
      
      clock_in = attendances.find { |a| a.punch_type == 'clock_in' }
      clock_out = attendances.find { |a| a.punch_type == 'clock_out' }
      
      calendar_data[date] = {
        clock_in: clock_in,
        clock_out: clock_out,
        work_hours: Attendance.calculate_work_hours(@current_employee.id, date),
        status: determine_daily_status(clock_in, clock_out, date)
      }
    end
    
    calendar_data
  end
  
  def determine_daily_status(clock_in, clock_out, date)
    return 'weekend' unless date.wday.between?(1, 5)
    return 'absent' unless clock_in
    return 'late' if clock_in.late?
    return 'early_leave' if clock_out&.early_leave?
    'normal'
  end
end
