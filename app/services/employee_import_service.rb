# frozen_string_literal: true
require 'csv'

class EmployeeImportService
  attr_reader :file, :errors, :imported_count

  def initialize(file)
    @file = file
    @errors = []
    @imported_count = 0
  end

  def call
    return { success: false, message: '檔案格式不正確' } unless valid_file?

    begin
      CSV.foreach(file.path, headers: true, encoding: 'UTF-8') do |row|
        process_row(row)
      end

      {
        success: true,
        imported_count: @imported_count,
        errors: @errors
      }
    rescue CSV::MalformedCSVError => e
      { success: false, message: "CSV 格式錯誤：#{e.message}" }
    rescue => e
      { success: false, message: "匯入過程發生錯誤：#{e.message}" }
    end
  end

  def self.generate_template
    headers = [
      '姓名*', '中文姓名', '英文姓名', '員工編號', '身分證字號*', '生日*',
      '性別', '婚姻狀況', '國籍', '部門', '職位', '職稱', '聘僱類型',
      '到職日期', '基本薪資', '津貼', '績效獎金', '公司信箱*', '個人信箱',
      '手機號碼', '電話號碼', '現居地址', '戶籍地址', '通訊地址',
      '緊急聯絡人姓名', '緊急聯絡人關係', '緊急聯絡人電話',
      '學歷', '學校名稱', '科系', '畢業年份', '工作經驗年數',
      '銀行帳號', '勞保號碼', '健保號碼', '退休金帳戶', '兵役狀況', '備註'
    ]

    sample_data = [
      '王小明', '王小明', 'Wang Xiao Ming', 'EMP001', 'A123456789', '1990-01-01',
      '男', '未婚', '中華民國', '資訊部', '工程師', '軟體工程師', '正職',
      '2024-01-01', '50000', '5000', '10000', 'wang@company.com', 'wang@gmail.com',
      '0912345678', '02-12345678', '台北市信義區信義路一段1號', '台北市信義區信義路一段1號', '台北市信義區信義路一段1號',
      '王大明', '父親', '0987654321',
      '大學', '台灣大學', '資訊工程學系', '2012', '5',
      '123-456-789012', 'L123456789', 'H987654321', 'P555666777', '已服完畢', '無'
    ]

    CSV.generate(encoding: 'UTF-8') do |csv|
      csv << headers
      csv << sample_data
    end
  end

  private

  def valid_file?
    return false unless file.respond_to?(:path)
    return false unless File.extname(file.original_filename).downcase == '.csv'
    true
  end

  def process_row(row)
    return if row.to_h.values.all?(&:blank?)

    employee_data = map_row_to_employee(row)
    
    if valid_employee_data?(employee_data, row.line_number)
      employee = Employee.new(employee_data)
      
      if employee.save
        @imported_count += 1
      else
        @errors << {
          line: row.line_number,
          name: employee_data[:name],
          errors: employee.errors.full_messages
        }
      end
    end
  end

  def map_row_to_employee(row)
    {
      # 基本資料
      name: row['姓名*']&.strip,
      chinese_name: row['中文姓名']&.strip,
      english_name: row['英文姓名']&.strip,
      employee_number: row['員工編號']&.strip,
      id_number: row['身分證字號*']&.strip,
      birthday: parse_date(row['生日*']),
      gender: map_gender(row['性別']),
      marital_status: map_marital_status(row['婚姻狀況']),
      nationality: row['國籍']&.strip || '中華民國',

      # 職位資訊
      department: row['部門']&.strip,
      position: row['職位']&.strip,
      job_title: row['職稱']&.strip,
      employment_type: map_employment_type(row['聘僱類型']),
      hire_date: parse_date(row['到職日期']),

      # 薪資資訊
      basic_salary: parse_number(row['基本薪資']),
      allowances: parse_number(row['津貼']),
      performance_bonus: parse_number(row['績效獎金']),

      # 聯絡資訊
      company_email: row['公司信箱*']&.strip,
      personal_email: row['個人信箱']&.strip,
      mobile_number: row['手機號碼']&.strip,
      phone_number: row['電話號碼']&.strip,
      current_address: row['現居地址']&.strip,
      residence_address: row['戶籍地址']&.strip,
      mailing_address: row['通訊地址']&.strip,

      # 緊急聯絡人
      emergency_contact_name: row['緊急聯絡人姓名']&.strip,
      emergency_contact_relationship: row['緊急聯絡人關係']&.strip,
      emergency_contact_phone: row['緊急聯絡人電話']&.strip,

      # 學歷資訊
      education_level: map_education_level(row['學歷']),
      school_name: row['學校名稱']&.strip,
      major: row['科系']&.strip,
      graduation_year: parse_number(row['畢業年份']),
      work_experience_years: parse_number(row['工作經驗年數']),

      # 保險資訊
      bank_account: row['銀行帳號']&.strip,
      labor_insurance_number: row['勞保號碼']&.strip,
      health_insurance_number: row['健保號碼']&.strip,
      pension_account: row['退休金帳戶']&.strip,
      military_service_status: map_military_service(row['兵役狀況']),

      # 其他
      notes: row['備註']&.strip
    }
  end

  def valid_employee_data?(data, line_number)
    required_fields = [:name, :id_number, :birthday, :company_email]
    missing_fields = required_fields.select { |field| data[field].blank? }

    if missing_fields.any?
      @errors << {
        line: line_number,
        name: data[:name] || '未知',
        errors: ["必填欄位不能為空：#{missing_fields.map { |f| field_name(f) }.join(', ')}"]
      }
      return false
    end

    # 檢查身分證字號格式
    unless valid_id_number?(data[:id_number])
      @errors << {
        line: line_number,
        name: data[:name],
        errors: ['身分證字號格式不正確']
      }
      return false
    end

    # 檢查信箱格式
    unless valid_email?(data[:company_email])
      @errors << {
        line: line_number,
        name: data[:name],
        errors: ['公司信箱格式不正確']
      }
      return false
    end

    true
  end

  def parse_date(date_string)
    return nil if date_string.blank?
    
    begin
      Date.parse(date_string.strip)
    rescue ArgumentError
      nil
    end
  end

  def parse_number(number_string)
    return nil if number_string.blank?
    
    number_string.strip.gsub(/[,\s]/, '').to_i
  end

  def map_gender(gender_string)
    return nil if gender_string.blank?
    
    case gender_string.strip
    when '男', 'M', 'Male', 'male'
      'male'
    when '女', 'F', 'Female', 'female'
      'female'
    else
      nil
    end
  end

  def map_marital_status(status_string)
    return nil if status_string.blank?
    
    case status_string.strip
    when '未婚', 'Single', 'single'
      'single'
    when '已婚', 'Married', 'married'
      'married'
    when '離婚', 'Divorced', 'divorced'
      'divorced'
    when '喪偶', 'Widowed', 'widowed'
      'widowed'
    else
      nil
    end
  end

  def map_employment_type(type_string)
    return nil if type_string.blank?
    
    case type_string.strip
    when '正職', '全職', 'Full Time', 'full_time'
      'full_time'
    when '兼職', 'Part Time', 'part_time'
      'part_time'
    when '約聘', '契約', 'Contract', 'contract'
      'contract'
    when '實習', 'Intern', 'intern'
      'intern'
    else
      'full_time' # 預設為正職
    end
  end

  def map_education_level(level_string)
    return nil if level_string.blank?
    
    case level_string.strip
    when '國小', '小學', 'Elementary'
      'elementary'
    when '國中', '初中', 'Junior High'
      'junior_high'
    when '高中', '高職', '高中職', 'Senior High'
      'senior_high'
    when '專科', 'College'
      'college'
    when '大學', 'University'
      'university'
    when '碩士', 'Master'
      'master'
    when '博士', 'PhD', 'Ph.D'
      'phd'
    else
      nil
    end
  end

  def map_military_service(service_string)
    return nil if service_string.blank?
    
    case service_string.strip
    when '已服完畢', '已服完', 'Completed'
      'completed'
    when '免役', 'Exempt'
      'exempt'
    when '未服', 'Not Served'
      'not_served'
    when '替代役', 'Alternative'
      'alternative'
    else
      nil
    end
  end

  def valid_id_number?(id_number)
    return false if id_number.blank?
    
    # 台灣身分證字號格式檢查
    id_number.match?(/^[A-Z][12]\d{8}$/)
  end

  def valid_email?(email)
    return false if email.blank?
    
    email.match?(URI::MailTo::EMAIL_REGEXP)
  end

  def field_name(field)
    case field
    when :name then '姓名'
    when :id_number then '身分證字號'
    when :birthday then '生日'
    when :company_email then '公司信箱'
    else field.to_s
    end
  end
end
