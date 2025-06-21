class AddDetailedFieldsToEmployees < ActiveRecord::Migration[6.1]
  def change
    add_column :employees, :employee_number, :string # 員工編號
    add_column :employees, :chinese_name, :string # 中文姓名
    add_column :employees, :english_name, :string # 英文姓名
    add_column :employees, :gender, :string # 性別
    add_column :employees, :marital_status, :string # 婚姻狀況
    add_column :employees, :nationality, :string # 國籍
    add_column :employees, :phone_number, :string # 電話號碼
    add_column :employees, :mobile_number, :string # 手機號碼
    add_column :employees, :emergency_contact_name, :string # 緊急聯絡人姓名
    add_column :employees, :emergency_contact_relationship, :string # 緊急聯絡人關係
    add_column :employees, :emergency_contact_phone, :string # 緊急聯絡人電話
    add_column :employees, :current_address, :text # 現住地址
    add_column :employees, :mailing_address, :text # 通訊地址
    
    # 學歷資訊
    add_column :employees, :education_level, :string # 學歷
    add_column :employees, :school_name, :string # 學校名稱
    add_column :employees, :major, :string # 科系
    add_column :employees, :graduation_year, :integer # 畢業年份
    
    # 工作經歷
    add_column :employees, :previous_company, :string # 前公司
    add_column :employees, :previous_position, :string # 前職位
    add_column :employees, :previous_work_period, :string # 前工作期間
    add_column :employees, :work_experience_years, :decimal, precision: 3, scale: 1 # 工作年資
    
    # 家庭狀況
    add_column :employees, :spouse_name, :string # 配偶姓名
    add_column :employees, :spouse_id_number, :string # 配偶身分證字號
    add_column :employees, :spouse_birthday, :date # 配偶生日
    add_column :employees, :children_count, :integer, default: 0 # 子女人數
    
    # 保險資訊
    add_column :employees, :labor_insurance_number, :string # 勞保證號
    add_column :employees, :health_insurance_number, :string # 健保證號
    add_column :employees, :pension_account, :string # 退休金帳戶
    
    # 其他資訊
    add_column :employees, :blood_type, :string # 血型
    add_column :employees, :height, :decimal, precision: 5, scale: 2 # 身高
    add_column :employees, :weight, :decimal, precision: 5, scale: 2 # 體重
    add_column :employees, :military_service_status, :string # 兵役狀況
    add_column :employees, :driver_license, :string # 駕照
    add_column :employees, :special_skills, :text # 專長技能
    add_column :employees, :languages, :text # 語言能力
    add_column :employees, :hobbies, :text # 興趣嗜好
    add_column :employees, :health_condition, :text # 健康狀況
    add_column :employees, :notes, :text # 備註
    
    # 職位資訊
    add_column :employees, :department, :string # 部門
    add_column :employees, :position, :string # 職位
    add_column :employees, :job_title, :string # 職稱
    add_column :employees, :employment_type, :string # 聘僱類型
    add_column :employees, :probation_period, :integer # 試用期(月)
    add_column :employees, :work_location, :string # 工作地點
    
    # 薪資相關
    add_column :employees, :basic_salary, :decimal, precision: 10, scale: 2 # 基本薪資
    add_column :employees, :allowances, :decimal, precision: 10, scale: 2 # 津貼
    add_column :employees, :performance_bonus, :decimal, precision: 10, scale: 2 # 績效獎金
    
    # 到職離職資訊
    add_column :employees, :hire_date, :date # 到職日期
    add_column :employees, :resignation_date, :date # 離職日期
    add_column :employees, :resignation_reason, :text # 離職原因
    
    # 照片
    add_column :employees, :photo_url, :string # 照片URL
    
    # 索引
    add_index :employees, :employee_number, unique: true
    add_index :employees, :department
    add_index :employees, :position
    add_index :employees, :hire_date
  end
end
