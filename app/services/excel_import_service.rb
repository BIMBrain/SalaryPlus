# frozen_string_literal: true

class ExcelImportService
  include Callable
  
  # 支援的匯入類型
  IMPORT_TYPES = {
    'employees' => '員工資料',
    'salaries' => '薪資設定',
    'attendances' => '出勤記錄',
    'payrolls' => '薪資發放',
    'overtime' => '加班記錄',
    'leaves' => '請假記錄',
    'insurance_statements' => '保險對帳單',
    'bank_transfers' => '銀行轉帳'
  }.freeze
  
  # 檔案格式
  SUPPORTED_FORMATS = %w[.xlsx .xls .csv].freeze
  
  attr_reader :file, :import_type, :options
  
  def initialize(file, import_type, options = {})
    @file = file
    @import_type = import_type
    @options = options.with_indifferent_access
  end
  
  def call
    # 驗證檔案格式
    unless valid_file_format?
      return {
        success: false,
        error: '不支援的檔案格式，請使用 Excel (.xlsx, .xls) 或 CSV 檔案'
      }
    end
    
    # 驗證匯入類型
    unless IMPORT_TYPES.key?(import_type)
      return {
        success: false,
        error: '不支援的匯入類型'
      }
    end
    
    begin
      # 讀取檔案資料
      data = read_file_data
      
      # 驗證資料格式
      validation_result = validate_data_format(data)
      unless validation_result[:valid]
        return {
          success: false,
          error: validation_result[:error],
          details: validation_result[:details]
        }
      end
      
      # 執行匯入
      import_result = perform_import(data)
      
      {
        success: true,
        imported_count: import_result[:imported_count],
        skipped_count: import_result[:skipped_count],
        error_count: import_result[:error_count],
        errors: import_result[:errors],
        warnings: import_result[:warnings]
      }
      
    rescue => e
      {
        success: false,
        error: "匯入失敗：#{e.message}",
        details: e.backtrace.first(5)
      }
    end
  end
  
  # 取得匯入範本
  def self.generate_template(import_type)
    case import_type
    when 'employees'
      generate_employee_template
    when 'salaries'
      generate_salary_template
    when 'attendances'
      generate_attendance_template
    when 'payrolls'
      generate_payroll_template
    when 'overtime'
      generate_overtime_template
    when 'leaves'
      generate_leave_template
    when 'insurance_statements'
      generate_insurance_statement_template
    when 'bank_transfers'
      generate_bank_transfer_template
    else
      nil
    end
  end
  
  private
  
  def valid_file_format?
    return false unless file.present?
    
    file_extension = File.extname(file.original_filename).downcase
    SUPPORTED_FORMATS.include?(file_extension)
  end
  
  def read_file_data
    file_extension = File.extname(file.original_filename).downcase
    
    case file_extension
    when '.csv'
      read_csv_data
    when '.xlsx', '.xls'
      read_excel_data
    else
      raise "不支援的檔案格式：#{file_extension}"
    end
  end
  
  def read_csv_data
    require 'csv'
    
    data = []
    CSV.foreach(file.path, headers: true, encoding: 'UTF-8') do |row|
      data << row.to_h
    end
    
    data
  end
  
  def read_excel_data
    require 'roo'
    
    spreadsheet = Roo::Spreadsheet.open(file.path)
    
    # 取得第一個工作表
    sheet = spreadsheet.sheet(0)
    
    # 取得標題行
    headers = sheet.row(1)
    
    # 讀取資料
    data = []
    (2..sheet.last_row).each do |row_num|
      row_data = sheet.row(row_num)
      row_hash = Hash[headers.zip(row_data)]
      data << row_hash
    end
    
    data
  end
  
  def validate_data_format(data)
    return { valid: false, error: '檔案沒有資料' } if data.empty?
    
    case import_type
    when 'employees'
      validate_employee_data(data)
    when 'salaries'
      validate_salary_data(data)
    when 'attendances'
      validate_attendance_data(data)
    when 'payrolls'
      validate_payroll_data(data)
    when 'overtime'
      validate_overtime_data(data)
    when 'leaves'
      validate_leave_data(data)
    when 'insurance_statements'
      validate_insurance_statement_data(data)
    when 'bank_transfers'
      validate_bank_transfer_data(data)
    else
      { valid: false, error: '未知的匯入類型' }
    end
  end
  
  def perform_import(data)
    case import_type
    when 'employees'
      import_employees(data)
    when 'salaries'
      import_salaries(data)
    when 'attendances'
      import_attendances(data)
    when 'payrolls'
      import_payrolls(data)
    when 'overtime'
      import_overtime(data)
    when 'leaves'
      import_leaves(data)
    when 'insurance_statements'
      import_insurance_statements(data)
    when 'bank_transfers'
      import_bank_transfers(data)
    else
      { imported_count: 0, skipped_count: 0, error_count: 0, errors: [], warnings: [] }
    end
  end
  
  def validate_employee_data(data)
    required_fields = ['員工編號', '姓名', '身分證字號']
    missing_fields = required_fields - data.first.keys
    
    if missing_fields.any?
      return {
        valid: false,
        error: "缺少必要欄位：#{missing_fields.join(', ')}",
        details: "員工資料必須包含：#{required_fields.join(', ')}"
      }
    end
    
    { valid: true }
  end
  
  def import_employees(data)
    imported_count = 0
    skipped_count = 0
    error_count = 0
    errors = []
    warnings = []
    
    data.each_with_index do |row, index|
      begin
        employee_number = row['員工編號']&.to_s&.strip
        name = row['姓名']&.strip
        id_number = row['身分證字號']&.strip
        
        # 檢查必要欄位
        if employee_number.blank? || name.blank? || id_number.blank?
          error_count += 1
          errors << "第#{index + 2}行：員工編號、姓名、身分證字號不能為空"
          next
        end
        
        # 檢查是否已存在
        existing_employee = Employee.find_by(employee_number: employee_number)
        if existing_employee && !options[:update_existing]
          skipped_count += 1
          warnings << "第#{index + 2}行：員工編號 #{employee_number} 已存在，已跳過"
          next
        end
        
        # 建立或更新員工資料
        employee_data = {
          employee_number: employee_number,
          name: name,
          id_number: id_number,
          email: row['電子郵件']&.strip,
          phone: row['電話']&.strip,
          address: row['地址']&.strip,
          department: row['部門']&.strip,
          position: row['職位']&.strip,
          hire_date: parse_date(row['到職日期']),
          bank_account_number: row['銀行帳號']&.strip,
          bank_account_name: row['銀行戶名']&.strip,
          bank_code: row['銀行代碼']&.strip
        }
        
        if existing_employee
          existing_employee.update!(employee_data)
        else
          Employee.create!(employee_data)
        end
        
        imported_count += 1
        
      rescue => e
        error_count += 1
        errors << "第#{index + 2}行：#{e.message}"
      end
    end
    
    {
      imported_count: imported_count,
      skipped_count: skipped_count,
      error_count: error_count,
      errors: errors,
      warnings: warnings
    }
  end
  
  def validate_salary_data(data)
    required_fields = ['員工編號', '月薪', '生效日期']
    missing_fields = required_fields - data.first.keys
    
    if missing_fields.any?
      return {
        valid: false,
        error: "缺少必要欄位：#{missing_fields.join(', ')}",
        details: "薪資資料必須包含：#{required_fields.join(', ')}"
      }
    end
    
    { valid: true }
  end
  
  def import_salaries(data)
    imported_count = 0
    skipped_count = 0
    error_count = 0
    errors = []
    warnings = []
    
    data.each_with_index do |row, index|
      begin
        employee_number = row['員工編號']&.to_s&.strip
        monthly_wage = row['月薪']&.to_f
        effective_date = parse_date(row['生效日期'])
        
        # 檢查員工是否存在
        employee = Employee.find_by(employee_number: employee_number)
        unless employee
          error_count += 1
          errors << "第#{index + 2}行：找不到員工編號 #{employee_number}"
          next
        end
        
        # 建立薪資設定
        salary_data = {
          employee: employee,
          monthly_wage: monthly_wage,
          effective_date: effective_date,
          equipment_subsidy: row['設備津貼']&.to_f || 0,
          commuting_subsidy: row['交通津貼']&.to_f || 0,
          supervisor_allowance: row['主管津貼']&.to_f || 0,
          labor_insurance: row['勞保費']&.to_f || 0,
          health_insurance: row['健保費']&.to_f || 0,
          insured_for_labor: row['勞保投保薪資']&.to_f || monthly_wage,
          insured_for_health: row['健保投保薪資']&.to_f || monthly_wage
        }
        
        Salary.create!(salary_data)
        imported_count += 1
        
      rescue => e
        error_count += 1
        errors << "第#{index + 2}行：#{e.message}"
      end
    end
    
    {
      imported_count: imported_count,
      skipped_count: skipped_count,
      error_count: error_count,
      errors: errors,
      warnings: warnings
    }
  end
  
  def validate_attendance_data(data)
    required_fields = ['員工編號', '打卡時間', '打卡類型']
    missing_fields = required_fields - data.first.keys
    
    if missing_fields.any?
      return {
        valid: false,
        error: "缺少必要欄位：#{missing_fields.join(', ')}",
        details: "出勤資料必須包含：#{required_fields.join(', ')}"
      }
    end
    
    { valid: true }
  end
  
  def import_attendances(data)
    imported_count = 0
    skipped_count = 0
    error_count = 0
    errors = []
    warnings = []
    
    data.each_with_index do |row, index|
      begin
        employee_number = row['員工編號']&.to_s&.strip
        punch_time = parse_datetime(row['打卡時間'])
        punch_type = map_punch_type(row['打卡類型'])
        
        # 檢查員工是否存在
        employee = Employee.find_by(employee_number: employee_number)
        unless employee
          error_count += 1
          errors << "第#{index + 2}行：找不到員工編號 #{employee_number}"
          next
        end
        
        # 建立出勤記錄
        attendance_data = {
          employee: employee,
          punch_time: punch_time,
          punch_type: punch_type,
          punch_method: 'manual_import',
          location: row['地點']&.strip,
          notes: row['備註']&.strip
        }
        
        Attendance.create!(attendance_data)
        imported_count += 1
        
      rescue => e
        error_count += 1
        errors << "第#{index + 2}行：#{e.message}"
      end
    end
    
    {
      imported_count: imported_count,
      skipped_count: skipped_count,
      error_count: error_count,
      errors: errors,
      warnings: warnings
    }
  end
  
  def parse_date(date_string)
    return nil if date_string.blank?
    
    # 嘗試多種日期格式
    formats = ['%Y-%m-%d', '%Y/%m/%d', '%m/%d/%Y', '%d/%m/%Y']
    
    formats.each do |format|
      begin
        return Date.strptime(date_string.to_s, format)
      rescue ArgumentError
        next
      end
    end
    
    # 如果都失敗，嘗試自動解析
    Date.parse(date_string.to_s) rescue nil
  end
  
  def parse_datetime(datetime_string)
    return nil if datetime_string.blank?
    
    # 嘗試多種日期時間格式
    formats = ['%Y-%m-%d %H:%M:%S', '%Y/%m/%d %H:%M:%S', '%Y-%m-%d %H:%M', '%Y/%m/%d %H:%M']
    
    formats.each do |format|
      begin
        return DateTime.strptime(datetime_string.to_s, format)
      rescue ArgumentError
        next
      end
    end
    
    # 如果都失敗，嘗試自動解析
    DateTime.parse(datetime_string.to_s) rescue nil
  end
  
  def map_punch_type(type_string)
    case type_string.to_s.strip
    when '上班', '打卡上班', 'clock_in'
      'clock_in'
    when '下班', '打卡下班', 'clock_out'
      'clock_out'
    when '外出', 'break_out'
      'break_out'
    when '回來', 'break_in'
      'break_in'
    else
      'clock_in'
    end
  end
  
  # 其他匯入方法的實作...
  def validate_payroll_data(data)
    { valid: true }
  end
  
  def import_payrolls(data)
    { imported_count: 0, skipped_count: 0, error_count: 0, errors: [], warnings: [] }
  end
  
  def validate_overtime_data(data)
    { valid: true }
  end
  
  def import_overtime(data)
    { imported_count: 0, skipped_count: 0, error_count: 0, errors: [], warnings: [] }
  end
  
  def validate_leave_data(data)
    { valid: true }
  end
  
  def import_leaves(data)
    { imported_count: 0, skipped_count: 0, error_count: 0, errors: [], warnings: [] }
  end
  
  def validate_insurance_statement_data(data)
    { valid: true }
  end
  
  def import_insurance_statements(data)
    { imported_count: 0, skipped_count: 0, error_count: 0, errors: [], warnings: [] }
  end
  
  def validate_bank_transfer_data(data)
    { valid: true }
  end
  
  def import_bank_transfers(data)
    { imported_count: 0, skipped_count: 0, error_count: 0, errors: [], warnings: [] }
  end
  
  # 範本產生方法
  def self.generate_employee_template
    require 'csv'
    
    CSV.generate(headers: true) do |csv|
      csv << ['員工編號', '姓名', '身分證字號', '電子郵件', '電話', '地址', '部門', '職位', '到職日期', '銀行帳號', '銀行戶名', '銀行代碼']
      csv << ['E001', '王小明', 'A123456789', 'wang@example.com', '0912345678', '台北市信義區', '資訊部', '工程師', '2024-01-01', '1234567890123', '王小明', '004']
    end
  end
  
  def self.generate_salary_template
    require 'csv'
    
    CSV.generate(headers: true) do |csv|
      csv << ['員工編號', '月薪', '生效日期', '設備津貼', '交通津貼', '主管津貼', '勞保費', '健保費', '勞保投保薪資', '健保投保薪資']
      csv << ['E001', '50000', '2024-01-01', '1000', '2000', '0', '956', '749', '50000', '50000']
    end
  end
  
  def self.generate_attendance_template
    require 'csv'
    
    CSV.generate(headers: true) do |csv|
      csv << ['員工編號', '打卡時間', '打卡類型', '地點', '備註']
      csv << ['E001', '2024-01-01 09:00:00', '上班', '辦公室', '']
      csv << ['E001', '2024-01-01 18:00:00', '下班', '辦公室', '']
    end
  end
  
  def self.generate_payroll_template
    require 'csv'
    
    CSV.generate(headers: true) do |csv|
      csv << ['員工編號', '年度', '月份', '基本薪資', '加班費', '津貼', '總收入', '勞保費', '健保費', '所得稅', '實領金額']
    end
  end
  
  def self.generate_overtime_template
    require 'csv'
    
    CSV.generate(headers: true) do |csv|
      csv << ['員工編號', '加班日期', '開始時間', '結束時間', '加班時數', '加班類型', '核准狀態']
    end
  end
  
  def self.generate_leave_template
    require 'csv'
    
    CSV.generate(headers: true) do |csv|
      csv << ['員工編號', '請假類型', '開始日期', '結束日期', '請假時數', '請假原因', '核准狀態']
    end
  end
  
  def self.generate_insurance_statement_template
    require 'csv'
    
    CSV.generate(headers: true) do |csv|
      csv << ['保險類型', '年度', '月份', '對帳單金額', '備註']
    end
  end
  
  def self.generate_bank_transfer_template
    require 'csv'
    
    CSV.generate(headers: true) do |csv|
      csv << ['員工編號', '轉帳金額', '銀行代碼', '帳號', '戶名', '轉帳日期', '備註']
    end
  end
end
