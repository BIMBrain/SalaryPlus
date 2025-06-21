# frozen_string_literal: true

class LegalRegulation < ApplicationRecord
  # 法規類型
  REGULATION_TYPES = {
    'labor_standards' => '勞動基準法',
    'labor_insurance' => '勞工保險條例',
    'health_insurance' => '全民健康保險法',
    'labor_pension' => '勞工退休金條例',
    'income_tax' => '所得稅法',
    'employment_insurance' => '就業保險法',
    'occupational_safety' => '職業安全衛生法',
    'gender_equality' => '性別工作平等法',
    'minimum_wage' => '基本工資',
    'working_hours' => '工時規定',
    'overtime_pay' => '加班費規定',
    'leave_regulations' => '請假規定'
  }.freeze
  
  # 法規狀態
  STATUS_OPTIONS = {
    'active' => '生效中',
    'pending' => '待生效',
    'superseded' => '已廢止',
    'draft' => '草案'
  }.freeze
  
  # 影響等級
  IMPACT_LEVELS = {
    'high' => '高度影響',
    'medium' => '中度影響',
    'low' => '輕微影響'
  }.freeze
  
  validates :title, presence: true
  validates :regulation_type, presence: true, inclusion: { in: REGULATION_TYPES.keys }
  validates :status, presence: true, inclusion: { in: STATUS_OPTIONS.keys }
  validates :effective_date, presence: true
  validates :impact_level, presence: true, inclusion: { in: IMPACT_LEVELS.keys }
  
  scope :active, -> { where(status: 'active') }
  scope :by_type, ->(type) { where(regulation_type: type) if type.present? }
  scope :high_impact, -> { where(impact_level: 'high') }
  scope :recent, -> { order(effective_date: :desc) }
  scope :effective_on, ->(date) { where('effective_date <= ?', date) }
  
  # 允許Ransack搜尋的屬性
  def self.ransackable_attributes(auth_object = nil)
    %w[title regulation_type status effective_date impact_level created_at updated_at]
  end
  
  def self.ransackable_associations(auth_object = nil)
    []
  end
  
  # 取得法規類型中文名稱
  def regulation_type_name
    REGULATION_TYPES[regulation_type]
  end
  
  # 取得狀態中文名稱
  def status_name
    STATUS_OPTIONS[status]
  end
  
  # 取得影響等級中文名稱
  def impact_level_name
    IMPACT_LEVELS[impact_level]
  end
  
  # 檢查是否已生效
  def effective?
    status == 'active' && effective_date <= Date.current
  end
  
  # 檢查是否即將生效
  def pending_effective?
    status == 'pending' && effective_date > Date.current
  end
  
  # 取得相關的系統設定更新
  def system_updates
    case regulation_type
    when 'minimum_wage'
      update_minimum_wage_settings
    when 'labor_insurance'
      update_labor_insurance_rates
    when 'health_insurance'
      update_health_insurance_rates
    when 'income_tax'
      update_income_tax_brackets
    when 'overtime_pay'
      update_overtime_calculation_rules
    else
      []
    end
  end
  
  # 應用法規更新到系統
  def apply_to_system!
    return false unless effective?
    
    updates = system_updates
    applied_updates = []
    
    updates.each do |update|
      begin
        case update[:type]
        when 'system_setting'
          apply_system_setting_update(update)
        when 'calculation_rule'
          apply_calculation_rule_update(update)
        when 'rate_table'
          apply_rate_table_update(update)
        end
        
        applied_updates << update
      rescue => e
        Rails.logger.error "Failed to apply update #{update[:name]}: #{e.message}"
      end
    end
    
    update!(
      applied_at: Time.current,
      applied_updates: applied_updates
    )
    
    true
  end
  
  # 檢查系統合規性
  def self.check_compliance
    compliance_issues = []
    
    # 檢查基本工資合規性
    current_minimum_wage = get_current_minimum_wage
    if current_minimum_wage
      low_salary_employees = Employee.joins(:salaries)
                                   .where('salaries.monthly_wage < ?', current_minimum_wage)
                                   .distinct
      
      if low_salary_employees.any?
        compliance_issues << {
          type: 'minimum_wage_violation',
          severity: 'high',
          description: "有 #{low_salary_employees.count} 位員工薪資低於基本工資",
          employees: low_salary_employees,
          regulation: find_by(regulation_type: 'minimum_wage', status: 'active')
        }
      end
    end
    
    # 檢查工時合規性
    overtime_violations = check_overtime_compliance
    compliance_issues.concat(overtime_violations) if overtime_violations.any?
    
    # 檢查保險費率合規性
    insurance_issues = check_insurance_compliance
    compliance_issues.concat(insurance_issues) if insurance_issues.any?
    
    compliance_issues
  end
  
  # 產生合規報告
  def self.generate_compliance_report(year = Date.current.year, month = Date.current.month)
    report = {
      period: "#{year}/#{month}",
      generated_at: Time.current,
      compliance_status: 'compliant',
      issues: [],
      recommendations: []
    }
    
    # 檢查各項合規性
    compliance_issues = check_compliance
    
    if compliance_issues.any?
      report[:compliance_status] = 'non_compliant'
      report[:issues] = compliance_issues
      
      # 產生建議
      compliance_issues.each do |issue|
        case issue[:type]
        when 'minimum_wage_violation'
          report[:recommendations] << {
            priority: 'high',
            action: '調整薪資至基本工資以上',
            affected_employees: issue[:employees].count,
            deadline: Date.current + 30.days
          }
        when 'overtime_violation'
          report[:recommendations] << {
            priority: 'medium',
            action: '檢討加班時數管理',
            affected_employees: issue[:employees].count,
            deadline: Date.current + 14.days
          }
        end
      end
    end
    
    report
  end
  
  # 自動更新法規資料
  def self.auto_update_regulations
    # 這裡可以整合政府開放資料API或其他法規資料來源
    # 目前先提供手動更新的框架
    
    updated_count = 0
    
    # 檢查待生效的法規
    pending_regulations = where(status: 'pending')
                         .where('effective_date <= ?', Date.current)
    
    pending_regulations.each do |regulation|
      regulation.update!(status: 'active')
      regulation.apply_to_system!
      updated_count += 1
    end
    
    {
      success: true,
      updated_count: updated_count,
      message: "已更新 #{updated_count} 項法規"
    }
  end
  
  private
  
  def update_minimum_wage_settings
    return [] unless regulation_type == 'minimum_wage'
    
    # 從法規內容中解析新的基本工資
    new_wage = extract_minimum_wage_from_content
    
    [{
      type: 'system_setting',
      name: 'minimum_wage',
      old_value: get_current_minimum_wage,
      new_value: new_wage,
      description: "更新基本工資為 #{new_wage} 元"
    }]
  end
  
  def update_labor_insurance_rates
    return [] unless regulation_type == 'labor_insurance'
    
    # 解析新的勞保費率
    new_rates = extract_labor_insurance_rates_from_content
    
    new_rates.map do |rate_info|
      {
        type: 'rate_table',
        name: 'labor_insurance_rate',
        category: rate_info[:category],
        old_rate: rate_info[:old_rate],
        new_rate: rate_info[:new_rate],
        description: "更新勞保費率"
      }
    end
  end
  
  def apply_system_setting_update(update)
    # 更新系統設定
    case update[:name]
    when 'minimum_wage'
      # 更新基本工資設定
      Rails.cache.write('current_minimum_wage', update[:new_value])
    end
  end
  
  def apply_calculation_rule_update(update)
    # 更新計算規則
    # 這裡可以更新加班費計算、稅額計算等規則
  end
  
  def apply_rate_table_update(update)
    # 更新費率表
    # 這裡可以更新保險費率、稅率等
  end
  
  def extract_minimum_wage_from_content
    # 從法規內容中提取基本工資數值
    # 這裡需要根據實際的法規內容格式來實作
    content.to_s.scan(/(\d+)元/).flatten.first&.to_i || 0
  end
  
  def extract_labor_insurance_rates_from_content
    # 從法規內容中提取勞保費率
    # 這裡需要根據實際的法規內容格式來實作
    []
  end
  
  def self.get_current_minimum_wage
    Rails.cache.fetch('current_minimum_wage') do
      # 預設基本工資，實際應從系統設定中取得
      26400
    end
  end
  
  def self.check_overtime_compliance
    # 檢查加班時數合規性
    violations = []
    
    # 檢查月加班時數是否超過46小時
    current_month_start = Date.current.beginning_of_month
    current_month_end = Date.current.end_of_month
    
    Employee.active.each do |employee|
      monthly_overtime = employee.attendances
                                .where(punch_time: current_month_start..current_month_end)
                                .sum(&:overtime_hours)
      
      if monthly_overtime > 46
        violations << {
          type: 'overtime_violation',
          severity: 'high',
          description: "員工 #{employee.display_name} 月加班時數超過46小時",
          employee: employee,
          overtime_hours: monthly_overtime
        }
      end
    end
    
    violations
  end
  
  def self.check_insurance_compliance
    # 檢查保險費率合規性
    issues = []
    
    # 檢查是否有員工未投保
    uninsured_employees = Employee.active.joins(:salaries)
                                 .where(salaries: { labor_insurance: 0 })
    
    if uninsured_employees.any?
      issues << {
        type: 'insurance_violation',
        severity: 'high',
        description: "有 #{uninsured_employees.count} 位員工未投保勞保",
        employees: uninsured_employees
      }
    end
    
    issues
  end
end
