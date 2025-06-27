# frozen_string_literal: true
class EmployeesController < ApplicationController
  before_action :prepare, only: [:show, :edit, :update, :destroy]
  before_action :store_location, only: [:show]

  def index
    list = SalaryTracker.on_payroll.by_role(role: %w[boss regular contractor])
    @result = Kaminari.paginate_array(list).page(params[:page])
  end

  def parttimers
    list = SalaryTracker.on_payroll.by_role(role: %w[vendor advisor parttime])
    @result = Kaminari.paginate_array(list).page(params[:page])
    render :index
  end

  def inactive
    @result = SalaryTracker.inactive.page(params[:page])
    render :index
  end

  def show
    @payrolls = @employee.payrolls.personal_history
  end

  def new
    @employee = Employee.new
  end

  def edit
  end

  def create
    @employee = Employee.new(employee_params)
    if @employee.save
      redirect_to @employee
    else
      render :new
    end
  end

  def update
    if @employee.update(employee_params)
      redirect_to @employee
    else
      render :edit
    end
  end

  def destroy
    @employee.destroy
    redirect_to employees_path
  end

  # 匯入功能
  def import
    # 顯示匯入頁面
  end

  def process_import
    if params[:file].blank?
      flash[:error] = '請選擇要匯入的檔案'
      redirect_to import_employees_path and return
    end

    begin
      result = EmployeeImportService.new(params[:file]).call

      if result[:success]
        flash[:success] = "成功匯入 #{result[:imported_count]} 筆員工資料"
        if result[:errors].any?
          flash[:warning] = "有 #{result[:errors].count} 筆資料匯入失敗，請檢查格式"
          session[:import_errors] = result[:errors]
        end
        redirect_to employees_path
      else
        flash[:error] = result[:message]
        redirect_to import_employees_path
      end
    rescue => e
      flash[:error] = "匯入失敗：#{e.message}"
      redirect_to import_employees_path
    end
  end

  def download_template
    send_data EmployeeImportService.generate_template,
              filename: "員工資料匯入範本_#{Date.current.strftime('%Y%m%d')}.csv",
              type: 'text/csv; charset=utf-8'
  end

  def import_errors
    @errors = session[:import_errors] || []
    session.delete(:import_errors)
  end

  # OCR 辨識人事資料卡
  def ocr_upload
    # 顯示 OCR 上傳頁面
    @employee = Employee.new
  end

  def process_ocr
    if params[:hr_card_file].blank?
      flash[:error] = '請選擇要辨識的人事資料卡檔案'
      redirect_to ocr_upload_employees_path and return
    end

    begin
      # 儲存上傳的檔案
      uploaded_file = params[:hr_card_file]
      temp_file_path = Rails.root.join('tmp', 'ocr', "#{SecureRandom.hex(8)}_#{uploaded_file.original_filename}")
      FileUtils.mkdir_p(File.dirname(temp_file_path))
      
      File.open(temp_file_path, 'wb') do |file|
        file.write(uploaded_file.read)
      end

      # 進行 OCR 辨識
      ocr_result = OcrService.process_hr_card(temp_file_path)

      # 清理臨時檔案
      File.delete(temp_file_path) if File.exist?(temp_file_path)

      if ocr_result[:success]
        # 將辨識結果存入 session，用於預填表單
        session[:ocr_data] = ocr_result[:data]
        session[:ocr_raw_text] = ocr_result[:raw_text]
        
        flash[:success] = 'OCR 辨識成功！請檢查並確認以下資料'
        redirect_to new_employee_path(ocr: true)
      else
        flash[:error] = "OCR 辨識失敗：#{ocr_result[:error]}"
        redirect_to ocr_upload_employees_path
      end

    rescue => e
      Rails.logger.error "OCR 處理錯誤: #{e.message}"
      flash[:error] = "OCR 處理失敗：#{e.message}"
      redirect_to ocr_upload_employees_path
    end
  end

  # 獲取 OCR 辨識結果的 JSON API
  def ocr_result
    ocr_data = session[:ocr_data] || {}
    render json: { success: true, data: ocr_data }
  end

  # 清除 OCR 資料
  def clear_ocr_data
    session.delete(:ocr_data)
    session.delete(:ocr_raw_text)
    render json: { success: true }
  end

  private

  def employee_params
    params.require(:employee).permit(
      # 基本資料
      :name, :role, :id_number, :birthday, :b2b,
      :employee_number, :chinese_name, :english_name, :gender, :marital_status, :nationality,

      # 聯絡資訊
      :company_email, :personal_email, :residence_address, :phone_number, :mobile_number,
      :current_address, :mailing_address,
      :emergency_contact_name, :emergency_contact_relationship, :emergency_contact_phone,

      # 學歷資訊
      :education_level, :school_name, :major, :graduation_year,

      # 工作經歷
      :previous_company, :previous_position, :previous_work_period, :work_experience_years,

      # 職位資訊
      :department, :position, :job_title, :employment_type, :probation_period, :work_location,
      :hire_date, :resignation_date, :resignation_reason,

      # 薪資資訊
      :basic_salary, :allowances, :performance_bonus, :bank_account, :bank_transfer_type,

      # 保險資訊
      :labor_insurance_number, :health_insurance_number, :pension_account,

      # 家庭狀況
      :spouse_name, :spouse_id_number, :spouse_birthday, :children_count,

      # 其他資訊
      :blood_type, :height, :weight, :military_service_status, :driver_license,
      :special_skills, :languages, :hobbies, :health_condition, :notes, :photo_url,

      # 關聯資料
      salaries_attributes: salaries_attributes,
      terms_attributes: [:start_date, :end_date, :_destory, :id]
    )
  end

  def salaries_attributes
    [
      :tax_code, :effective_date, :monthly_wage, :hourly_wage,
      :equipment_subsidy, :commuting_subsidy, :supervisor_allowance,
      :labor_insurance, :health_insurance, :_destroy, :id,
    ]
  end

  def prepare
    (@employee = Employee.find_by(id: params[:id])) || not_found
  end
end
