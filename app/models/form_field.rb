# frozen_string_literal: true

class FormField < ApplicationRecord
  belongs_to :form_template
  
  # 欄位類型
  FIELD_TYPES = {
    'text' => '文字輸入',
    'textarea' => '多行文字',
    'number' => '數字',
    'date' => '日期',
    'datetime' => '日期時間',
    'select' => '下拉選單',
    'radio' => '單選按鈕',
    'checkbox' => '多選框',
    'file' => '檔案上傳',
    'email' => '電子郵件',
    'phone' => '電話號碼',
    'currency' => '金額'
  }.freeze
  
  validates :field_name, presence: true
  validates :field_type, presence: true, inclusion: { in: FIELD_TYPES.keys }
  validates :sort_order, presence: true, numericality: { greater_than: 0 }
  
  scope :ordered, -> { order(:sort_order) }
  scope :required, -> { where(required: true) }
  
  # 取得欄位類型中文名稱
  def field_type_name
    FIELD_TYPES[field_type]
  end
  
  # 檢查是否為選項類型
  def has_options?
    %w[select radio checkbox].include?(field_type)
  end
  
  # 取得選項列表
  def option_list
    return [] unless has_options?
    return [] if field_options.blank?
    
    field_options.split("\n").map(&:strip).reject(&:blank?)
  end
  
  # 驗證欄位值
  def validate_value(value)
    errors = []
    
    # 必填驗證
    if required && value.blank?
      errors << "#{field_label}為必填欄位"
      return errors
    end
    
    return errors if value.blank?
    
    # 類型驗證
    case field_type
    when 'number'
      unless value.to_s.match?(/\A-?\d+(\.\d+)?\z/)
        errors << "#{field_label}必須為數字"
      end
    when 'email'
      unless value.to_s.match?(URI::MailTo::EMAIL_REGEXP)
        errors << "#{field_label}格式不正確"
      end
    when 'date'
      begin
        Date.parse(value.to_s)
      rescue ArgumentError
        errors << "#{field_label}日期格式不正確"
      end
    when 'datetime'
      begin
        DateTime.parse(value.to_s)
      rescue ArgumentError
        errors << "#{field_label}日期時間格式不正確"
      end
    when 'select', 'radio'
      unless option_list.include?(value.to_s)
        errors << "#{field_label}選項無效"
      end
    when 'checkbox'
      if value.is_a?(Array)
        invalid_options = value - option_list
        if invalid_options.any?
          errors << "#{field_label}包含無效選項：#{invalid_options.join(', ')}"
        end
      end
    end
    
    # 長度驗證
    if max_length.present? && value.to_s.length > max_length
      errors << "#{field_label}長度不能超過#{max_length}個字元"
    end
    
    if min_length.present? && value.to_s.length < min_length
      errors << "#{field_label}長度不能少於#{min_length}個字元"
    end
    
    # 數值範圍驗證
    if field_type == 'number' && value.present?
      numeric_value = value.to_f
      
      if max_value.present? && numeric_value > max_value
        errors << "#{field_label}不能大於#{max_value}"
      end
      
      if min_value.present? && numeric_value < min_value
        errors << "#{field_label}不能小於#{min_value}"
      end
    end
    
    errors
  end
  
  # 格式化顯示值
  def format_value(value)
    return '' if value.blank?
    
    case field_type
    when 'currency'
      ActionController::Base.helpers.number_to_currency(value, unit: 'NT$ ', precision: 0)
    when 'date'
      Date.parse(value.to_s).strftime('%Y-%m-%d') rescue value
    when 'datetime'
      DateTime.parse(value.to_s).strftime('%Y-%m-%d %H:%M') rescue value
    when 'checkbox'
      value.is_a?(Array) ? value.join(', ') : value
    else
      value.to_s
    end
  end
  
  # 產生HTML輸入欄位
  def render_input(form_builder, value = nil)
    options = {
      class: 'macos-form-control',
      placeholder: placeholder,
      required: required
    }
    
    case field_type
    when 'text'
      form_builder.text_field field_name, options.merge(value: value)
    when 'textarea'
      form_builder.text_area field_name, options.merge(value: value, rows: 4)
    when 'number'
      form_builder.number_field field_name, options.merge(value: value)
    when 'date'
      form_builder.date_field field_name, options.merge(value: value)
    when 'datetime'
      form_builder.datetime_local_field field_name, options.merge(value: value)
    when 'email'
      form_builder.email_field field_name, options.merge(value: value)
    when 'phone'
      form_builder.telephone_field field_name, options.merge(value: value)
    when 'currency'
      form_builder.number_field field_name, options.merge(value: value, step: 0.01)
    when 'select'
      form_builder.select field_name, option_list.map { |opt| [opt, opt] }, 
                         { prompt: '請選擇...', selected: value }, 
                         options
    when 'radio'
      option_list.map do |opt|
        form_builder.radio_button(field_name, opt, checked: value == opt) +
        form_builder.label("#{field_name}_#{opt}", opt, class: 'macos-form-label-inline')
      end.join.html_safe
    when 'checkbox'
      option_list.map do |opt|
        checked = value.is_a?(Array) ? value.include?(opt) : false
        form_builder.check_box("#{field_name}[]", { checked: checked }, opt, '') +
        form_builder.label("#{field_name}_#{opt}", opt, class: 'macos-form-label-inline')
      end.join.html_safe
    when 'file'
      form_builder.file_field field_name, options.merge(class: 'macos-form-control-file')
    else
      form_builder.text_field field_name, options.merge(value: value)
    end
  end
end
