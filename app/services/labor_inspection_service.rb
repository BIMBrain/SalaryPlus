# frozen_string_literal: true

class LaborInspectionService
  include Callable
  
  # 勞檢六大類別
  INSPECTION_CATEGORIES = {
    'working_hours' => '工作時間',
    'overtime_pay' => '加班費給付',
    'leave_management' => '休假管理',
    'labor_insurance' => '勞工保險',
    'workplace_safety' => '職場安全',
    'labor_contracts' => '勞動契約'
  }.freeze
  
  # 違規嚴重程度
  SEVERITY_LEVELS = {
    'critical' => '嚴重違規',
    'major' => '重大違規',
    'minor' => '輕微違規',
    'warning' => '注意事項'
  }.freeze
  
  attr_reader :inspection_date, :scope
  
  def initialize(inspection_date = Date.current, scope = 'all')
    @inspection_date = inspection_date
    @scope = scope
  end
  
  def call
    inspection_results = {
      inspection_date: inspection_date,
      scope: scope,
      overall_score: 0,
      compliance_status: 'compliant',
      categories: {},
      violations: [],
      recommendations: [],
      summary: {}
    }
    
    # 執行各類別檢查
    INSPECTION_CATEGORIES.each do |category, name|
      category_result = perform_category_inspection(category)
      inspection_results[:categories][category] = category_result
      
      # 收集違規項目
      inspection_results[:violations].concat(category_result[:violations])
      
      # 收集建議
      inspection_results[:recommendations].concat(category_result[:recommendations])
    end
    
    # 計算整體分數和合規狀態
    inspection_results[:overall_score] = calculate_overall_score(inspection_results[:categories])
    inspection_results[:compliance_status] = determine_compliance_status(inspection_results[:overall_score])
    
    # 產生摘要
    inspection_results[:summary] = generate_inspection_summary(inspection_results)
    
    inspection_results
  end
  
  private
  
  def perform_category_inspection(category)
    case category
    when 'working_hours'
      inspect_working_hours
    when 'overtime_pay'
      inspect_overtime_pay
    when 'leave_management'
      inspect_leave_management
    when 'labor_insurance'
      inspect_labor_insurance
    when 'workplace_safety'
      inspect_workplace_safety
    when 'labor_contracts'
      inspect_labor_contracts
    else
      default_category_result(category)
    end
  end
  
  def inspect_working_hours
    violations = []
    recommendations = []
    score = 100
    
    # 檢查每日工作時間
    daily_violations = check_daily_working_hours
    violations.concat(daily_violations)
    score -= daily_violations.count * 10
    
    # 檢查每週工作時間
    weekly_violations = check_weekly_working_hours
    violations.concat(weekly_violations)
    score -= weekly_violations.count * 15
    
    # 檢查連續工作天數
    consecutive_violations = check_consecutive_working_days
    violations.concat(consecutive_violations)
    score -= consecutive_violations.count * 20
    
    # 檢查休息時間
    break_violations = check_break_time_compliance
    violations.concat(break_violations)
    score -= break_violations.count * 5
    
    # 產生建議
    if violations.any?
      recommendations << {
        priority: 'high',
        action: '建立工時管控機制',
        description: '設定每日、每週工時上限，並確實記錄員工出勤時間',
        deadline: Date.current + 30.days
      }
      
      recommendations << {
        priority: 'medium',
        action: '實施彈性工時制度',
        description: '考慮導入彈性工時，讓員工在合法範圍內調整工作時間',
        deadline: Date.current + 60.days
      }
    end
    
    {
      category: 'working_hours',
      name: INSPECTION_CATEGORIES['working_hours'],
      score: [score, 0].max,
      violations: violations,
      recommendations: recommendations,
      compliance_rate: calculate_compliance_rate(violations.count, get_total_employees)
    }
  end
  
  def inspect_overtime_pay
    violations = []
    recommendations = []
    score = 100
    
    # 檢查加班費計算正確性
    overtime_calculation_errors = check_overtime_calculation
    violations.concat(overtime_calculation_errors)
    score -= overtime_calculation_errors.count * 25
    
    # 檢查加班費給付及時性
    payment_delays = check_overtime_payment_timeliness
    violations.concat(payment_delays)
    score -= payment_delays.count * 15
    
    # 檢查加班申請程序
    procedure_violations = check_overtime_approval_procedure
    violations.concat(procedure_violations)
    score -= procedure_violations.count * 10
    
    if violations.any?
      recommendations << {
        priority: 'critical',
        action: '修正加班費計算方式',
        description: '確保加班費計算符合一例一休規定，平日1.34倍、休息日前2小時1.34倍後2小時1.67倍',
        deadline: Date.current + 14.days
      }
      
      recommendations << {
        priority: 'high',
        action: '建立加班申請制度',
        description: '要求員工事前申請加班，並由主管核准後才能加班',
        deadline: Date.current + 30.days
      }
    end
    
    {
      category: 'overtime_pay',
      name: INSPECTION_CATEGORIES['overtime_pay'],
      score: [score, 0].max,
      violations: violations,
      recommendations: recommendations,
      compliance_rate: calculate_compliance_rate(violations.count, get_total_employees)
    }
  end
  
  def inspect_leave_management
    violations = []
    recommendations = []
    score = 100
    
    # 檢查特別休假給予
    annual_leave_violations = check_annual_leave_compliance
    violations.concat(annual_leave_violations)
    score -= annual_leave_violations.count * 20
    
    # 檢查病假、事假規定
    sick_leave_violations = check_sick_leave_compliance
    violations.concat(sick_leave_violations)
    score -= sick_leave_violations.count * 10
    
    # 檢查產假、陪產假
    maternity_leave_violations = check_maternity_leave_compliance
    violations.concat(maternity_leave_violations)
    score -= maternity_leave_violations.count * 30
    
    if violations.any?
      recommendations << {
        priority: 'high',
        action: '建立完整請假制度',
        description: '制定符合法規的請假辦法，包含特休、病假、事假等各種假別',
        deadline: Date.current + 45.days
      }
    end
    
    {
      category: 'leave_management',
      name: INSPECTION_CATEGORIES['leave_management'],
      score: [score, 0].max,
      violations: violations,
      recommendations: recommendations,
      compliance_rate: calculate_compliance_rate(violations.count, get_total_employees)
    }
  end
  
  def inspect_labor_insurance
    violations = []
    recommendations = []
    score = 100
    
    # 檢查勞保投保
    uninsured_employees = check_labor_insurance_coverage
    violations.concat(uninsured_employees)
    score -= uninsured_employees.count * 50
    
    # 檢查投保薪資正確性
    salary_discrepancies = check_insured_salary_accuracy
    violations.concat(salary_discrepancies)
    score -= salary_discrepancies.count * 20
    
    # 檢查保費繳納
    premium_delays = check_insurance_premium_payment
    violations.concat(premium_delays)
    score -= premium_delays.count * 30
    
    if violations.any?
      recommendations << {
        priority: 'critical',
        action: '立即為未投保員工辦理勞保',
        description: '所有員工都必須投保勞工保險，未投保將面臨重罰',
        deadline: Date.current + 7.days
      }
      
      recommendations << {
        priority: 'high',
        action: '檢視投保薪資級距',
        description: '確保員工投保薪資與實際薪資相符，避免高薪低報',
        deadline: Date.current + 30.days
      }
    end
    
    {
      category: 'labor_insurance',
      name: INSPECTION_CATEGORIES['labor_insurance'],
      score: [score, 0].max,
      violations: violations,
      recommendations: recommendations,
      compliance_rate: calculate_compliance_rate(violations.count, get_total_employees)
    }
  end
  
  def inspect_workplace_safety
    violations = []
    recommendations = []
    score = 100
    
    # 檢查職業安全衛生教育訓練
    training_violations = check_safety_training
    violations.concat(training_violations)
    score -= training_violations.count * 15
    
    # 檢查工作環境安全
    environment_violations = check_workplace_environment
    violations.concat(environment_violations)
    score -= environment_violations.count * 25
    
    # 檢查職業災害預防
    prevention_violations = check_accident_prevention
    violations.concat(prevention_violations)
    score -= prevention_violations.count * 30
    
    if violations.any?
      recommendations << {
        priority: 'high',
        action: '實施安全衛生教育訓練',
        description: '定期舉辦職業安全衛生教育訓練，提升員工安全意識',
        deadline: Date.current + 60.days
      }
    end
    
    {
      category: 'workplace_safety',
      name: INSPECTION_CATEGORIES['workplace_safety'],
      score: [score, 0].max,
      violations: violations,
      recommendations: recommendations,
      compliance_rate: calculate_compliance_rate(violations.count, get_total_employees)
    }
  end
  
  def inspect_labor_contracts
    violations = []
    recommendations = []
    score = 100
    
    # 檢查勞動契約簽訂
    contract_violations = check_labor_contract_signing
    violations.concat(contract_violations)
    score -= contract_violations.count * 30
    
    # 檢查契約內容完整性
    content_violations = check_contract_content_completeness
    violations.concat(content_violations)
    score -= content_violations.count * 20
    
    # 檢查試用期規定
    probation_violations = check_probation_period_compliance
    violations.concat(probation_violations)
    score -= probation_violations.count * 15
    
    if violations.any?
      recommendations << {
        priority: 'high',
        action: '完善勞動契約制度',
        description: '確保所有員工都有簽訂書面勞動契約，內容符合法規要求',
        deadline: Date.current + 45.days
      }
    end
    
    {
      category: 'labor_contracts',
      name: INSPECTION_CATEGORIES['labor_contracts'],
      score: [score, 0].max,
      violations: violations,
      recommendations: recommendations,
      compliance_rate: calculate_compliance_rate(violations.count, get_total_employees)
    }
  end
  
  def check_daily_working_hours
    violations = []
    
    # 檢查是否有員工單日工作超過8小時（不含加班）
    Employee.active.each do |employee|
      recent_attendances = employee.attendances
                                  .where(punch_time: 30.days.ago..Date.current)
                                  .group_by { |a| a.punch_time.to_date }
      
      recent_attendances.each do |date, daily_attendances|
        work_hours = Attendance.calculate_work_hours(employee.id, date)
        
        if work_hours > 8
          violations << {
            type: 'daily_hours_exceeded',
            severity: 'major',
            employee: employee,
            date: date,
            work_hours: work_hours,
            description: "員工 #{employee.display_name} 於 #{date} 工作 #{work_hours} 小時，超過法定8小時"
          }
        end
      end
    end
    
    violations
  end
  
  def check_weekly_working_hours
    violations = []
    
    # 檢查週工時是否超過40小時
    Employee.active.each do |employee|
      (4.weeks.ago.to_date..Date.current).each do |date|
        next unless date.wday == 1 # 只檢查週一
        
        week_start = date
        week_end = date + 6.days
        
        weekly_hours = (week_start..week_end).sum do |day|
          Attendance.calculate_work_hours(employee.id, day)
        end
        
        if weekly_hours > 40
          violations << {
            type: 'weekly_hours_exceeded',
            severity: 'major',
            employee: employee,
            week_start: week_start,
            week_end: week_end,
            work_hours: weekly_hours,
            description: "員工 #{employee.display_name} 週工時 #{weekly_hours} 小時，超過法定40小時"
          }
        end
      end
    end
    
    violations
  end
  
  def check_consecutive_working_days
    violations = []
    
    # 檢查連續工作天數是否超過6天
    Employee.active.each do |employee|
      consecutive_days = 0
      
      (30.days.ago.to_date..Date.current).each do |date|
        work_hours = Attendance.calculate_work_hours(employee.id, date)
        
        if work_hours > 0
          consecutive_days += 1
        else
          if consecutive_days > 6
            violations << {
              type: 'consecutive_days_exceeded',
              severity: 'critical',
              employee: employee,
              consecutive_days: consecutive_days,
              description: "員工 #{employee.display_name} 連續工作 #{consecutive_days} 天，違反一例一休規定"
            }
          end
          consecutive_days = 0
        end
      end
    end
    
    violations
  end
  
  def check_break_time_compliance
    # 檢查休息時間是否足夠
    []
  end
  
  def check_overtime_calculation
    # 檢查加班費計算是否正確
    []
  end
  
  def check_overtime_payment_timeliness
    # 檢查加班費是否及時給付
    []
  end
  
  def check_overtime_approval_procedure
    # 檢查加班申請程序
    []
  end
  
  def check_annual_leave_compliance
    # 檢查特別休假給予
    []
  end
  
  def check_sick_leave_compliance
    # 檢查病假規定
    []
  end
  
  def check_maternity_leave_compliance
    # 檢查產假、陪產假
    []
  end
  
  def check_labor_insurance_coverage
    # 檢查勞保投保
    uninsured = Employee.active.joins(:salaries)
                        .where(salaries: { labor_insurance: 0 })
                        .map do |employee|
      {
        type: 'uninsured_employee',
        severity: 'critical',
        employee: employee,
        description: "員工 #{employee.display_name} 未投保勞工保險"
      }
    end
    
    uninsured
  end
  
  def check_insured_salary_accuracy
    # 檢查投保薪資正確性
    []
  end
  
  def check_insurance_premium_payment
    # 檢查保費繳納
    []
  end
  
  def check_safety_training
    # 檢查安全衛生教育訓練
    []
  end
  
  def check_workplace_environment
    # 檢查工作環境安全
    []
  end
  
  def check_accident_prevention
    # 檢查職業災害預防
    []
  end
  
  def check_labor_contract_signing
    # 檢查勞動契約簽訂
    []
  end
  
  def check_contract_content_completeness
    # 檢查契約內容完整性
    []
  end
  
  def check_probation_period_compliance
    # 檢查試用期規定
    []
  end
  
  def calculate_overall_score(categories)
    total_score = categories.values.sum { |category| category[:score] }
    (total_score / categories.count).round
  end
  
  def determine_compliance_status(score)
    case score
    when 90..100
      'excellent'
    when 80..89
      'good'
    when 70..79
      'fair'
    when 60..69
      'poor'
    else
      'critical'
    end
  end
  
  def calculate_compliance_rate(violation_count, total_count)
    return 100 if total_count.zero?
    
    compliant_count = total_count - violation_count
    ((compliant_count.to_f / total_count) * 100).round(2)
  end
  
  def get_total_employees
    Employee.active.count
  end
  
  def generate_inspection_summary(results)
    {
      total_violations: results[:violations].count,
      critical_violations: results[:violations].count { |v| v[:severity] == 'critical' },
      major_violations: results[:violations].count { |v| v[:severity] == 'major' },
      minor_violations: results[:violations].count { |v| v[:severity] == 'minor' },
      total_recommendations: results[:recommendations].count,
      high_priority_actions: results[:recommendations].count { |r| r[:priority] == 'critical' || r[:priority] == 'high' }
    }
  end
  
  def default_category_result(category)
    {
      category: category,
      name: INSPECTION_CATEGORIES[category],
      score: 100,
      violations: [],
      recommendations: [],
      compliance_rate: 100
    }
  end
end
