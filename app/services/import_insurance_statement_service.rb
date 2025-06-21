# frozen_string_literal: true

class ImportInsuranceStatementService
  include Callable
  
  attr_reader :file
  
  def initialize(file)
    @file = file
  end
  
  def call
    return { success: false, error: '檔案格式不支援' } unless valid_file_format?
    
    begin
      case file.content_type
      when 'text/csv', 'application/csv'
        import_from_csv
      when 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet'
        import_from_xlsx
      else
        { success: false, error: '不支援的檔案格式' }
      end
    rescue => e
      { success: false, error: "匯入失敗：#{e.message}" }
    end
  end
  
  private
  
  def valid_file_format?
    return false unless file.present?
    
    allowed_types = [
      'text/csv',
      'application/csv', 
      'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet'
    ]
    
    allowed_types.include?(file.content_type)
  end
  
  def import_from_csv
    require 'csv'
    
    imported_count = 0
    errors = []
    
    CSV.foreach(file.path, headers: true, encoding: 'UTF-8') do |row|
      result = create_insurance_statement_from_row(row.to_h)
      if result[:success]
        imported_count += 1
      else
        errors << "第#{$.}行：#{result[:error]}"
      end
    end
    
    if errors.empty?
      { success: true, count: imported_count }
    else
      { success: false, error: errors.join('; '), count: imported_count }
    end
  end
  
  def import_from_xlsx
    require 'roo'
    
    imported_count = 0
    errors = []
    
    xlsx = Roo::Spreadsheet.open(file.path)
    headers = xlsx.row(1)
    
    (2..xlsx.last_row).each do |row_num|
      row_data = Hash[headers.zip(xlsx.row(row_num))]
      result = create_insurance_statement_from_row(row_data)
      
      if result[:success]
        imported_count += 1
      else
        errors << "第#{row_num}行：#{result[:error]}"
      end
    end
    
    if errors.empty?
      { success: true, count: imported_count }
    else
      { success: false, error: errors.join('; '), count: imported_count }
    end
  end
  
  def create_insurance_statement_from_row(row_data)
    # 標準化欄位名稱
    normalized_data = normalize_column_names(row_data)
    
    # 驗證必要欄位
    required_fields = ['statement_type', 'year', 'month', 'statement_amount']
    missing_fields = required_fields.select { |field| normalized_data[field].blank? }
    
    if missing_fields.any?
      return { success: false, error: "缺少必要欄位：#{missing_fields.join(', ')}" }
    end
    
    # 轉換資料類型
    statement_data = {
      statement_type: map_statement_type(normalized_data['statement_type']),
      year: normalized_data['year'].to_i,
      month: normalized_data['month'].to_i,
      statement_amount: normalized_data['statement_amount'].to_f,
      uploaded_at: Time.current
    }
    
    # 驗證資料有效性
    unless valid_statement_type?(statement_data[:statement_type])
      return { success: false, error: "無效的保險類型：#{normalized_data['statement_type']}" }
    end
    
    unless valid_year_month?(statement_data[:year], statement_data[:month])
      return { success: false, error: "無效的年月：#{statement_data[:year]}/#{statement_data[:month]}" }
    end
    
    # 建立或更新記錄
    insurance_statement = InsuranceStatement.find_or_initialize_by(
      statement_type: statement_data[:statement_type],
      year: statement_data[:year],
      month: statement_data[:month]
    )
    
    insurance_statement.assign_attributes(statement_data)
    
    if insurance_statement.save
      insurance_statement.auto_reconcile!
      { success: true }
    else
      { success: false, error: insurance_statement.errors.full_messages.join(', ') }
    end
  end
  
  def normalize_column_names(row_data)
    normalized = {}
    
    row_data.each do |key, value|
      normalized_key = case key.to_s.strip
                      when /保險類型|類型|type/i
                        'statement_type'
                      when /年度|年|year/i
                        'year'
                      when /月份|月|month/i
                        'month'
                      when /對帳單金額|金額|amount/i
                        'statement_amount'
                      when /備註|notes/i
                        'notes'
                      else
                        key.to_s.downcase
                      end
      
      normalized[normalized_key] = value
    end
    
    normalized
  end
  
  def map_statement_type(type_string)
    case type_string.to_s.strip
    when /勞保|labor.*insurance/i
      'labor_insurance'
    when /健保|health.*insurance/i
      'health_insurance'
    when /勞退|labor.*pension/i
      'labor_pension'
    else
      type_string
    end
  end
  
  def valid_statement_type?(type)
    InsuranceStatement::STATEMENT_TYPES.keys.include?(type)
  end
  
  def valid_year_month?(year, month)
    return false unless year.is_a?(Integer) && month.is_a?(Integer)
    return false unless year >= 2000 && year <= Date.current.year + 1
    return false unless month >= 1 && month <= 12
    
    true
  end
end
