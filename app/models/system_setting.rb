# frozen_string_literal: true

class SystemSetting < ApplicationRecord
  # 設定類型
  SETTING_TYPES = {
    'overtime_calculation' => '一例一休加班費計算',
    'insurance_calculation' => '勞健保自動計算',
    'income_tax_calculation' => '所得稅預扣計算',
    'supplement_health_insurance' => '二代健保補充保費',
    'ui_preferences' => '介面偏好設定',
    'style_templates' => '樣式模板設定',
    'general_settings' => '一般設定'
  }.freeze

  # 資料類型
  DATA_TYPES = {
    'decimal' => '小數',
    'integer' => '整數',
    'percentage' => '百分比',
    'boolean' => '是/否',
    'string' => '文字',
    'json' => 'JSON資料'
  }.freeze

  validates :setting_key, presence: true, uniqueness: true
  validates :setting_type, presence: true, inclusion: { in: SETTING_TYPES.keys }
  validates :data_type, presence: true, inclusion: { in: DATA_TYPES.keys }
  validates :setting_name, presence: true

  scope :by_type, ->(type) { where(setting_type: type) if type.present? }
  scope :active, -> { where(is_active: true) }

  # 允許Ransack搜尋的屬性
  def self.ransackable_attributes(auth_object = nil)
    %w[setting_key setting_name setting_type data_type is_active created_at updated_at]
  end

  def self.ransackable_associations(auth_object = nil)
    []
  end

  # 取得設定類型中文名稱
  def setting_type_name
    SETTING_TYPES[setting_type]
  end

  # 取得資料類型中文名稱
  def data_type_name
    DATA_TYPES[data_type]
  end

  # 取得格式化的值
  def formatted_value
    case data_type
    when 'decimal'
      setting_value.to_f
    when 'integer'
      setting_value.to_i
    when 'percentage'
      "#{(setting_value.to_f * 100).round(2)}%"
    when 'boolean'
      setting_value == 'true' ? '是' : '否'
    when 'json'
      JSON.parse(setting_value) rescue {}
    else
      setting_value.to_s
    end
  end

  # 設定值
  def set_value(value)
    case data_type
    when 'decimal'
      self.setting_value = value.to_f.to_s
    when 'integer'
      self.setting_value = value.to_i.to_s
    when 'percentage'
      # 如果輸入的是百分比格式，轉換為小數
      if value.to_s.include?('%')
        self.setting_value = (value.to_f / 100).to_s
      else
        self.setting_value = value.to_f.to_s
      end
    when 'boolean'
      self.setting_value = value.to_s == 'true' ? 'true' : 'false'
    when 'json'
      self.setting_value = value.is_a?(String) ? value : value.to_json
    else
      self.setting_value = value.to_s
    end
  end

  # 取得設定值
  def get_value
    case data_type
    when 'decimal'
      setting_value.to_f
    when 'integer'
      setting_value.to_i
    when 'percentage'
      setting_value.to_f
    when 'boolean'
      setting_value == 'true'
    when 'json'
      JSON.parse(setting_value) rescue {}
    else
      setting_value
    end
  end

  # 快速取得設定值
  def self.get(key, default_value = nil)
    setting = find_by(setting_key: key, is_active: true)
    setting ? setting.get_value : default_value
  end

  # 快速設定值
  def self.set(key, value)
    setting = find_or_initialize_by(setting_key: key)
    setting.set_value(value)
    setting.save!
    setting
  end

  # 初始化預設設定
  def self.initialize_default_settings
    default_settings = [
      # 一例一休加班費計算
      {
        setting_key: 'overtime_weekday_rate',
        setting_name: '平日加班費率',
        setting_type: 'overtime_calculation',
        data_type: 'decimal',
        setting_value: '1.34',
        description: '平日加班費率（基本時薪的倍數）',
        formula: '平日加班費 = 基本時薪 × 加班時數 × 1.34'
      },
      {
        setting_key: 'overtime_holiday_rate_first_2h',
        setting_name: '休息日前2小時加班費率',
        setting_type: 'overtime_calculation',
        data_type: 'decimal',
        setting_value: '1.34',
        description: '休息日前2小時加班費率',
        formula: '休息日前2小時加班費 = 基本時薪 × 2 × 1.34'
      },
      {
        setting_key: 'overtime_holiday_rate_after_2h',
        setting_name: '休息日第3小時起加班費率',
        setting_type: 'overtime_calculation',
        data_type: 'decimal',
        setting_value: '1.67',
        description: '休息日第3小時起加班費率',
        formula: '休息日第3小時起加班費 = 基本時薪 × (加班時數-2) × 1.67'
      },
      {
        setting_key: 'overtime_national_holiday_rate',
        setting_name: '國定假日加班費率',
        setting_type: 'overtime_calculation',
        data_type: 'decimal',
        setting_value: '2.0',
        description: '國定假日加班費率',
        formula: '國定假日加班費 = 基本時薪 × 加班時數 × 2.0'
      },

      # 勞健保自動計算
      {
        setting_key: 'labor_insurance_employee_rate',
        setting_name: '勞保費率（員工負擔）',
        setting_type: 'insurance_calculation',
        data_type: 'percentage',
        setting_value: '0.11',
        description: '勞工保險費率（員工負擔部分）',
        formula: '員工勞保費 = 投保薪資 × 11%'
      },
      {
        setting_key: 'labor_insurance_employer_rate',
        setting_name: '勞保費率（雇主負擔）',
        setting_type: 'insurance_calculation',
        data_type: 'percentage',
        setting_value: '0.22',
        description: '勞工保險費率（雇主負擔部分）',
        formula: '雇主勞保費 = 投保薪資 × 22%'
      },
      {
        setting_key: 'health_insurance_employee_rate',
        setting_name: '健保費率（員工負擔）',
        setting_type: 'insurance_calculation',
        data_type: 'percentage',
        setting_value: '0.0517',
        description: '全民健康保險費率（員工負擔部分）',
        formula: '員工健保費 = 投保薪資 × 5.17%'
      },
      {
        setting_key: 'health_insurance_employer_rate',
        setting_name: '健保費率（雇主負擔）',
        setting_type: 'insurance_calculation',
        data_type: 'percentage',
        setting_value: '0.0517',
        description: '全民健康保險費率（雇主負擔部分）',
        formula: '雇主健保費 = 投保薪資 × 5.17%'
      },
      {
        setting_key: 'labor_pension_rate',
        setting_name: '勞退提繳率',
        setting_type: 'insurance_calculation',
        data_type: 'percentage',
        setting_value: '0.06',
        description: '勞工退休金提繳率',
        formula: '勞退提繳金 = 投保薪資 × 6%'
      },

      # 所得稅預扣計算
      {
        setting_key: 'income_tax_exemption_single',
        setting_name: '個人免稅額（單身）',
        setting_type: 'income_tax_calculation',
        data_type: 'integer',
        setting_value: '92000',
        description: '個人免稅額（單身者）',
        formula: '年度免稅額 = 92,000元'
      },
      {
        setting_key: 'income_tax_exemption_married',
        setting_name: '個人免稅額（已婚）',
        setting_type: 'income_tax_calculation',
        data_type: 'integer',
        setting_value: '184000',
        description: '個人免稅額（已婚者）',
        formula: '年度免稅額 = 184,000元'
      },
      {
        setting_key: 'income_tax_standard_deduction_single',
        setting_name: '標準扣除額（單身）',
        setting_type: 'income_tax_calculation',
        data_type: 'integer',
        setting_value: '124000',
        description: '標準扣除額（單身者）',
        formula: '年度標準扣除額 = 124,000元'
      },
      {
        setting_key: 'income_tax_standard_deduction_married',
        setting_name: '標準扣除額（已婚）',
        setting_type: 'income_tax_calculation',
        data_type: 'integer',
        setting_value: '248000',
        description: '標準扣除額（已婚者）',
        formula: '年度標準扣除額 = 248,000元'
      },
      {
        setting_key: 'income_tax_salary_deduction',
        setting_name: '薪資所得特別扣除額',
        setting_type: 'income_tax_calculation',
        data_type: 'integer',
        setting_value: '207000',
        description: '薪資所得特別扣除額',
        formula: '年度薪資特別扣除額 = 207,000元'
      },

      # 二代健保補充保費
      {
        setting_key: 'supplement_health_insurance_rate',
        setting_name: '二代健保補充保費費率',
        setting_type: 'supplement_health_insurance',
        data_type: 'percentage',
        setting_value: '0.0211',
        description: '二代健保補充保費費率',
        formula: '補充保費 = (薪資所得 - 投保金額) × 2.11%'
      },
      {
        setting_key: 'supplement_health_insurance_threshold',
        setting_name: '二代健保起扣門檻',
        setting_type: 'supplement_health_insurance',
        data_type: 'integer',
        setting_value: '20000',
        description: '二代健保補充保費起扣門檻',
        formula: '當單次給付超過20,000元時需扣繳補充保費'
      },
      {
        setting_key: 'supplement_health_insurance_max_base',
        setting_name: '二代健保計費上限',
        setting_type: 'supplement_health_insurance',
        data_type: 'integer',
        setting_value: '1000000',
        description: '二代健保補充保費計費上限',
        formula: '年度計費上限為1,000,000元'
      },

      # 介面偏好設定
      {
        setting_key: 'ui_theme_mode',
        setting_name: '介面主題模式',
        setting_type: 'ui_preferences',
        data_type: 'string',
        setting_value: 'light',
        description: '選擇介面主題：light（淺色）、dark（深色）、auto（跟隨系統）'
      },
      {
        setting_key: 'ui_enable_animations',
        setting_name: '啟用動畫效果',
        setting_type: 'ui_preferences',
        data_type: 'boolean',
        setting_value: 'true',
        description: '是否啟用介面動畫和過渡效果'
      },
      {
        setting_key: 'ui_compact_mode',
        setting_name: '緊湊模式',
        setting_type: 'ui_preferences',
        data_type: 'boolean',
        setting_value: 'false',
        description: '啟用緊湊模式以顯示更多內容'
      },
      {
        setting_key: 'ui_sidebar_collapsed',
        setting_name: '側邊欄預設收合',
        setting_type: 'ui_preferences',
        data_type: 'boolean',
        setting_value: 'false',
        description: '頁面載入時側邊欄是否預設收合'
      },
      {
        setting_key: 'ui_font_size',
        setting_name: '字體大小',
        setting_type: 'ui_preferences',
        data_type: 'string',
        setting_value: 'medium',
        description: '介面字體大小：small（小）、medium（中）、large（大）'
      },

      # 樣式模板設定
      {
        setting_key: 'style_template_current',
        setting_name: '當前樣式模板',
        setting_type: 'style_templates',
        data_type: 'string',
        setting_value: 'macos-classic',
        description: '當前使用的樣式模板'
      },
      {
        setting_key: 'style_template_custom_primary_color',
        setting_name: '自定義主色調',
        setting_type: 'style_templates',
        data_type: 'string',
        setting_value: '#007AFF',
        description: '自定義樣式的主要顏色'
      },
      {
        setting_key: 'style_template_custom_secondary_color',
        setting_name: '自定義輔助色調',
        setting_type: 'style_templates',
        data_type: 'string',
        setting_value: '#5AC8FA',
        description: '自定義樣式的輔助顏色'
      },
      {
        setting_key: 'style_template_custom_border_radius',
        setting_name: '自定義圓角程度',
        setting_type: 'style_templates',
        data_type: 'integer',
        setting_value: '10',
        description: '自定義樣式的圓角大小（像素）'
      },
      {
        setting_key: 'style_template_custom_shadow_intensity',
        setting_name: '自定義陰影強度',
        setting_type: 'style_templates',
        data_type: 'integer',
        setting_value: '20',
        description: '自定義樣式的陰影強度（百分比）'
      }
    ]

    default_settings.each do |setting_data|
      setting = find_or_initialize_by(setting_key: setting_data[:setting_key])
      setting.assign_attributes(setting_data.merge(is_active: true))
      setting.save! if setting.new_record? || setting.changed?
    end
  end

  # 取得計算公式說明
  def self.get_calculation_formulas
    {
      overtime_calculation: {
        name: '一例一休加班費計算',
        formulas: [
          '平日加班費 = 基本時薪 × 加班時數 × 1.34',
          '休息日前2小時 = 基本時薪 × 2 × 1.34',
          '休息日第3小時起 = 基本時薪 × (加班時數-2) × 1.67',
          '國定假日加班費 = 基本時薪 × 加班時數 × 2.0'
        ]
      },
      insurance_calculation: {
        name: '勞健保自動計算',
        formulas: [
          '員工勞保費 = 投保薪資 × 11%',
          '雇主勞保費 = 投保薪資 × 22%',
          '員工健保費 = 投保薪資 × 5.17%',
          '雇主健保費 = 投保薪資 × 5.17%',
          '勞退提繳金 = 投保薪資 × 6%'
        ]
      },
      income_tax_calculation: {
        name: '所得稅預扣計算',
        formulas: [
          '應納稅額 = (年收入 - 免稅額 - 扣除額) × 稅率',
          '月扣繳稅額 = 應納稅額 ÷ 12',
          '免稅額：單身92,000元，已婚184,000元',
          '標準扣除額：單身124,000元，已婚248,000元',
          '薪資特別扣除額：207,000元'
        ]
      },
      supplement_health_insurance: {
        name: '二代健保補充保費',
        formulas: [
          '補充保費 = (薪資所得 - 投保金額) × 2.11%',
          '起扣門檻：單次給付超過20,000元',
          '計費上限：年度1,000,000元',
          '適用項目：薪資所得、執行業務所得、股利所得等'
        ]
      }
    }
  end
end
