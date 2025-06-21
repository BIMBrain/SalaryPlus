# frozen_string_literal: true

class SystemSettingsController < ApplicationController
  before_action :set_system_setting, only: [:show, :edit, :update, :destroy]
  
  def index
    @setting_types = SystemSetting::SETTING_TYPES
    @selected_type = params[:type] || 'overtime_calculation'
    
    @settings = SystemSetting.by_type(@selected_type)
                             .active
                             .order(:setting_key)
    
    @formulas = SystemSetting.get_calculation_formulas[@selected_type.to_sym]
    
    # 統計資料
    @total_settings = SystemSetting.active.count
    @settings_by_type = SystemSetting.active.group(:setting_type).count
  end
  
  def show
  end
  
  def new
    @setting = SystemSetting.new
    @setting.setting_type = params[:type] || 'general_settings'
  end
  
  def create
    @setting = SystemSetting.new(system_setting_params)
    
    if @setting.save
      redirect_to system_settings_path(type: @setting.setting_type), 
                  notice: '設定已成功建立'
    else
      render :new
    end
  end
  
  def edit
  end
  
  def update
    if @setting.update(system_setting_params)
      redirect_to system_settings_path(type: @setting.setting_type), 
                  notice: '設定已成功更新'
    else
      render :edit
    end
  end
  
  def destroy
    setting_type = @setting.setting_type
    @setting.destroy
    redirect_to system_settings_path(type: setting_type), 
                notice: '設定已刪除'
  end
  
  # 批量更新設定
  def batch_update
    setting_type = params[:setting_type]
    settings_params = params[:settings] || {}
    
    updated_count = 0
    errors = []
    
    settings_params.each do |setting_key, value|
      setting = SystemSetting.find_by(setting_key: setting_key)
      
      if setting
        setting.set_value(value)
        if setting.save
          updated_count += 1
        else
          errors << "#{setting.setting_name}: #{setting.errors.full_messages.join(', ')}"
        end
      end
    end
    
    if errors.empty?
      redirect_to system_settings_path(type: setting_type), 
                  notice: "成功更新 #{updated_count} 項設定"
    else
      redirect_to system_settings_path(type: setting_type), 
                  alert: "更新時發生錯誤：#{errors.join('; ')}"
    end
  end
  
  # 重置為預設值
  def reset_defaults
    setting_type = params[:type]
    
    case setting_type
    when 'overtime_calculation'
      reset_overtime_defaults
    when 'insurance_calculation'
      reset_insurance_defaults
    when 'income_tax_calculation'
      reset_income_tax_defaults
    when 'supplement_health_insurance'
      reset_supplement_health_insurance_defaults
    end
    
    redirect_to system_settings_path(type: setting_type), 
                notice: '已重置為預設值'
  end
  
  # 匯出設定
  def export
    @settings = SystemSetting.active.order(:setting_type, :setting_key)
    
    respond_to do |format|
      format.csv do
        send_data generate_settings_csv, 
                  filename: "system_settings_#{Date.current.strftime('%Y%m%d')}.csv"
      end
      format.json do
        send_data generate_settings_json,
                  filename: "system_settings_#{Date.current.strftime('%Y%m%d')}.json"
      end
    end
  end
  
  # 匯入設定
  def import
    if params[:file].present?
      result = import_settings_from_file(params[:file])
      
      if result[:success]
        redirect_to system_settings_path, 
                    notice: "成功匯入 #{result[:imported_count]} 項設定"
      else
        redirect_to system_settings_path, 
                    alert: "匯入失敗：#{result[:error]}"
      end
    else
      redirect_to system_settings_path, alert: '請選擇要匯入的檔案'
    end
  end
  
  # 計算預覽
  def calculation_preview
    setting_type = params[:type]
    test_values = params[:test_values] || {}
    
    case setting_type
    when 'overtime_calculation'
      @preview_result = preview_overtime_calculation(test_values)
    when 'insurance_calculation'
      @preview_result = preview_insurance_calculation(test_values)
    when 'income_tax_calculation'
      @preview_result = preview_income_tax_calculation(test_values)
    when 'supplement_health_insurance'
      @preview_result = preview_supplement_health_insurance_calculation(test_values)
    end
    
    render json: @preview_result
  end
  
  # 初始化預設設定
  def initialize_defaults
    SystemSetting.initialize_default_settings
    redirect_to system_settings_path, notice: '預設設定已初始化完成'
  end

  # 更新UI偏好設定
  def update_ui_preference
    setting_key = params[:setting_key]
    setting_value = params[:setting_value]

    setting = SystemSetting.find_or_initialize_by(setting_key: setting_key)
    setting.assign_attributes(
      setting_name: setting_key.humanize,
      setting_type: 'ui_preferences',
      data_type: setting_value.is_a?(TrueClass) || setting_value.is_a?(FalseClass) ? 'boolean' : 'string',
      is_active: true
    )
    setting.set_value(setting_value)

    if setting.save
      render json: { success: true, message: '設定已更新' }
    else
      render json: { success: false, error: setting.errors.full_messages.join(', ') }
    end
  end

  # 更新樣式模板
  def update_style_template
    template_name = params[:template_name]

    # 更新當前樣式模板設定
    setting = SystemSetting.find_or_initialize_by(setting_key: 'style_template_current')
    setting.assign_attributes(
      setting_name: '當前樣式模板',
      setting_type: 'style_templates',
      data_type: 'string',
      is_active: true
    )
    setting.set_value(template_name)

    if setting.save
      render json: { success: true, message: '樣式模板已更新', template: template_name }
    else
      render json: { success: false, error: setting.errors.full_messages.join(', ') }
    end
  end

  # 更新自定義樣式設定
  def update_custom_style
    custom_settings = params[:custom_settings] || {}
    updated_count = 0
    errors = []

    custom_settings.each do |key, value|
      setting_key = "style_template_custom_#{key}"
      setting = SystemSetting.find_or_initialize_by(setting_key: setting_key)

      setting.assign_attributes(
        setting_name: "自定義#{key.humanize}",
        setting_type: 'style_templates',
        data_type: key.in?(['border_radius', 'shadow_intensity']) ? 'integer' : 'string',
        is_active: true
      )
      setting.set_value(value)

      if setting.save
        updated_count += 1
      else
        errors << "#{setting.setting_name}: #{setting.errors.full_messages.join(', ')}"
      end
    end

    if errors.empty?
      render json: { success: true, message: "成功更新 #{updated_count} 項自定義設定" }
    else
      render json: { success: false, error: "更新時發生錯誤：#{errors.join('; ')}" }
    end
  end
  
  private
  
  def set_system_setting
    @setting = SystemSetting.find(params[:id])
  end
  
  def system_setting_params
    params.require(:system_setting).permit(
      :setting_key, :setting_name, :setting_type, :data_type,
      :setting_value, :description, :formula, :is_active
    )
  end
  
  def reset_overtime_defaults
    overtime_settings = {
      'overtime_weekday_rate' => '1.34',
      'overtime_holiday_rate_first_2h' => '1.34',
      'overtime_holiday_rate_after_2h' => '1.67',
      'overtime_national_holiday_rate' => '2.0'
    }
    
    overtime_settings.each do |key, value|
      setting = SystemSetting.find_by(setting_key: key)
      setting&.update!(setting_value: value)
    end
  end
  
  def reset_insurance_defaults
    insurance_settings = {
      'labor_insurance_employee_rate' => '0.11',
      'labor_insurance_employer_rate' => '0.22',
      'health_insurance_employee_rate' => '0.0517',
      'health_insurance_employer_rate' => '0.0517',
      'labor_pension_rate' => '0.06'
    }
    
    insurance_settings.each do |key, value|
      setting = SystemSetting.find_by(setting_key: key)
      setting&.update!(setting_value: value)
    end
  end
  
  def reset_income_tax_defaults
    tax_settings = {
      'income_tax_exemption_single' => '92000',
      'income_tax_exemption_married' => '184000',
      'income_tax_standard_deduction_single' => '124000',
      'income_tax_standard_deduction_married' => '248000',
      'income_tax_salary_deduction' => '207000'
    }
    
    tax_settings.each do |key, value|
      setting = SystemSetting.find_by(setting_key: key)
      setting&.update!(setting_value: value)
    end
  end
  
  def reset_supplement_health_insurance_defaults
    supplement_settings = {
      'supplement_health_insurance_rate' => '0.0211',
      'supplement_health_insurance_threshold' => '20000',
      'supplement_health_insurance_max_base' => '1000000'
    }
    
    supplement_settings.each do |key, value|
      setting = SystemSetting.find_by(setting_key: key)
      setting&.update!(setting_value: value)
    end
  end
  
  def preview_overtime_calculation(test_values)
    base_hourly_wage = test_values[:base_hourly_wage].to_f
    overtime_hours = test_values[:overtime_hours].to_f
    overtime_type = test_values[:overtime_type] || 'weekday'
    
    case overtime_type
    when 'weekday'
      rate = SystemSetting.get('overtime_weekday_rate', 1.34)
      overtime_pay = base_hourly_wage * overtime_hours * rate
    when 'holiday_first_2h'
      rate = SystemSetting.get('overtime_holiday_rate_first_2h', 1.34)
      overtime_pay = base_hourly_wage * [overtime_hours, 2].min * rate
    when 'holiday_after_2h'
      rate = SystemSetting.get('overtime_holiday_rate_after_2h', 1.67)
      overtime_pay = base_hourly_wage * [overtime_hours - 2, 0].max * rate
    when 'national_holiday'
      rate = SystemSetting.get('overtime_national_holiday_rate', 2.0)
      overtime_pay = base_hourly_wage * overtime_hours * rate
    end
    
    {
      base_hourly_wage: base_hourly_wage,
      overtime_hours: overtime_hours,
      overtime_type: overtime_type,
      rate: rate,
      overtime_pay: overtime_pay.round(2),
      calculation: "#{base_hourly_wage} × #{overtime_hours} × #{rate} = #{overtime_pay.round(2)}"
    }
  end
  
  def preview_insurance_calculation(test_values)
    insured_salary = test_values[:insured_salary].to_f
    
    labor_employee_rate = SystemSetting.get('labor_insurance_employee_rate', 0.11)
    labor_employer_rate = SystemSetting.get('labor_insurance_employer_rate', 0.22)
    health_employee_rate = SystemSetting.get('health_insurance_employee_rate', 0.0517)
    health_employer_rate = SystemSetting.get('health_insurance_employer_rate', 0.0517)
    pension_rate = SystemSetting.get('labor_pension_rate', 0.06)
    
    {
      insured_salary: insured_salary,
      labor_insurance_employee: (insured_salary * labor_employee_rate).round,
      labor_insurance_employer: (insured_salary * labor_employer_rate).round,
      health_insurance_employee: (insured_salary * health_employee_rate).round,
      health_insurance_employer: (insured_salary * health_employer_rate).round,
      labor_pension: (insured_salary * pension_rate).round
    }
  end
  
  def preview_income_tax_calculation(test_values)
    annual_income = test_values[:annual_income].to_f
    marital_status = test_values[:marital_status] || 'single'
    
    exemption = SystemSetting.get("income_tax_exemption_#{marital_status}", 92000)
    standard_deduction = SystemSetting.get("income_tax_standard_deduction_#{marital_status}", 124000)
    salary_deduction = SystemSetting.get('income_tax_salary_deduction', 207000)
    
    taxable_income = [annual_income - exemption - standard_deduction - salary_deduction, 0].max
    
    # 簡化稅率計算（實際應該使用累進稅率）
    tax_rate = case taxable_income
               when 0...560000
                 0.05
               when 560000...1260000
                 0.12
               when 1260000...2520000
                 0.20
               when 2520000...4720000
                 0.30
               else
                 0.40
               end
    
    annual_tax = (taxable_income * tax_rate).round
    monthly_tax = (annual_tax / 12.0).round
    
    {
      annual_income: annual_income,
      exemption: exemption,
      standard_deduction: standard_deduction,
      salary_deduction: salary_deduction,
      taxable_income: taxable_income,
      tax_rate: (tax_rate * 100).round(1),
      annual_tax: annual_tax,
      monthly_tax: monthly_tax
    }
  end
  
  def preview_supplement_health_insurance_calculation(test_values)
    salary_income = test_values[:salary_income].to_f
    insured_amount = test_values[:insured_amount].to_f
    
    rate = SystemSetting.get('supplement_health_insurance_rate', 0.0211)
    threshold = SystemSetting.get('supplement_health_insurance_threshold', 20000)
    
    if salary_income > threshold && salary_income > insured_amount
      supplement_base = salary_income - insured_amount
      supplement_fee = (supplement_base * rate).round
    else
      supplement_base = 0
      supplement_fee = 0
    end
    
    {
      salary_income: salary_income,
      insured_amount: insured_amount,
      threshold: threshold,
      supplement_base: supplement_base,
      rate: (rate * 100).round(2),
      supplement_fee: supplement_fee,
      calculation: supplement_fee > 0 ? "#{supplement_base} × #{(rate * 100).round(2)}% = #{supplement_fee}" : "未達起扣門檻"
    }
  end
  
  def generate_settings_csv
    require 'csv'
    
    CSV.generate(headers: true) do |csv|
      csv << ['設定鍵值', '設定名稱', '設定類型', '資料類型', '設定值', '說明', '公式']
      
      @settings.each do |setting|
        csv << [
          setting.setting_key,
          setting.setting_name,
          setting.setting_type_name,
          setting.data_type_name,
          setting.setting_value,
          setting.description,
          setting.formula
        ]
      end
    end
  end
  
  def generate_settings_json
    settings_data = @settings.map do |setting|
      {
        setting_key: setting.setting_key,
        setting_name: setting.setting_name,
        setting_type: setting.setting_type,
        data_type: setting.data_type,
        setting_value: setting.setting_value,
        description: setting.description,
        formula: setting.formula
      }
    end
    
    {
      exported_at: Time.current,
      total_settings: settings_data.count,
      settings: settings_data
    }.to_json
  end
  
  def import_settings_from_file(file)
    # 實作檔案匯入邏輯
    { success: true, imported_count: 0 }
  end
end
