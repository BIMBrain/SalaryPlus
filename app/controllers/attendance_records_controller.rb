# frozen_string_literal: true

class AttendanceRecordsController < ApplicationController
  before_action :set_attendance_record, only: [:show, :edit, :update, :destroy]
  before_action :set_search_params, only: [:index]

  def index
    @q = AttendanceRecord.includes(:employee).ransack(params[:q])
    @attendance_records = @q.result.order(attendance_date: :desc, employee_id: :asc)
                           .page(params[:page]).per(20)
    
    # 統計資料
    @total_records = @attendance_records.total_count
    @total_employees = @attendance_records.joins(:employee).distinct.count(:employee_id)
    @total_work_hours = @attendance_records.sum(:regular_hours_actual)
    @total_overtime_hours = @attendance_records.sum('weekday_overtime_actual + weekend_overtime_actual')
    
    respond_to do |format|
      format.html
      format.json { render json: @attendance_records }
    end
  end

  def show
    respond_to do |format|
      format.html
      format.json { render json: @attendance_record }
    end
  end

  def new
    @attendance_record = AttendanceRecord.new
    @employees = Employee.active.order(:name)
  end

  def create
    @attendance_record = AttendanceRecord.new(attendance_record_params)
    
    respond_to do |format|
      if @attendance_record.save
        format.html { redirect_to @attendance_record, notice: '考勤記錄已成功創建。' }
        format.json { render json: @attendance_record, status: :created }
      else
        @employees = Employee.active.order(:name)
        format.html { render :new }
        format.json { render json: @attendance_record.errors, status: :unprocessable_entity }
      end
    end
  end

  def edit
    @employees = Employee.active.order(:name)
  end

  def update
    respond_to do |format|
      if @attendance_record.update(attendance_record_params)
        format.html { redirect_to @attendance_record, notice: '考勤記錄已成功更新。' }
        format.json { render json: @attendance_record }
      else
        @employees = Employee.active.order(:name)
        format.html { render :edit }
        format.json { render json: @attendance_record.errors, status: :unprocessable_entity }
      end
    end
  end

  def destroy
    @attendance_record.destroy
    respond_to do |format|
      format.html { redirect_to attendance_records_url, notice: '考勤記錄已成功刪除。' }
      format.json { head :no_content }
    end
  end
  
  # 匯入 Excel 資料
  def import
    if params[:file].present?
      begin
        result = import_excel_file(params[:file])
        redirect_to attendance_records_path, notice: "成功匯入 #{result[:success]} 筆記錄，失敗 #{result[:failed]} 筆。"
      rescue => e
        redirect_to attendance_records_path, alert: "匯入失敗：#{e.message}"
      end
    else
      redirect_to attendance_records_path, alert: '請選擇要匯入的檔案。'
    end
  end
  
  # 匯出 Excel 資料
  def export
    @attendance_records = AttendanceRecord.includes(:employee)
                                         .by_date_range(params[:start_date], params[:end_date])
                                         .order(:attendance_date, :employee_id)
    
    respond_to do |format|
      format.xlsx do
        response.headers['Content-Disposition'] = 'attachment; filename="attendance_records.xlsx"'
      end
    end
  end
  
  # 月度統計
  def monthly_summary
    @year = params[:year]&.to_i || Date.current.year
    @month = params[:month]&.to_i || Date.current.month
    
    start_date = Date.new(@year, @month, 1)
    end_date = start_date.end_of_month
    
    @records = AttendanceRecord.includes(:employee)
                              .by_date_range(start_date, end_date)
                              .order(:employee_id, :attendance_date)
    
    @summary_by_employee = @records.group_by(&:employee).transform_values do |records|
      {
        total_work_hours: records.sum(&:total_work_hours),
        total_overtime_hours: records.sum(&:total_overtime_hours),
        total_leave_days: records.sum(&:total_leave_days),
        total_exceptions: records.sum(&:total_exception_count),
        attendance_rate: records.map(&:attendance_rate).sum / records.size
      }
    end
  end

  private

  def set_attendance_record
    @attendance_record = AttendanceRecord.find(params[:id])
  end

  def set_search_params
    @employees = Employee.active.order(:name)
    @start_date = params.dig(:q, :attendance_date_gteq) || Date.current.beginning_of_month
    @end_date = params.dig(:q, :attendance_date_lteq) || Date.current.end_of_month
  end

  def attendance_record_params
    params.require(:attendance_record).permit(
      :employee_id, :attendance_date, :day_of_week, :is_holiday,
      :regular_hours_required, :regular_hours_actual, :regular_hours_extra,
      :weekday_overtime_required, :weekday_overtime_actual, :weekday_overtime_extra,
      :weekend_overtime_required, :weekend_overtime_actual, :weekend_overtime_extra,
      :personal_leave_days, :menstrual_leave_days, :annual_leave_days, :sick_leave_days,
      :compensatory_leave_days, :business_trip_days,
      :shift1_clock_in, :shift1_clock_out, :shift1_late, :shift1_early_leave, :shift1_absent,
      :overtime1_required, :overtime1_actual, :overtime1_extra,
      :overtime1_clock_in, :overtime1_clock_out, :overtime1_late, :overtime1_early_leave, :overtime1_absent,
      :overtime2_clock_in, :overtime2_clock_out, :overtime2_late, :overtime2_early_leave, :overtime2_absent,
      :late_count, :early_leave_count, :absent_count, :missing_punch_count,
      :filter_status, :exception_status, :notes
    )
  end
  
  def import_excel_file(file)
    require 'roo'
    
    spreadsheet = Roo::Spreadsheet.open(file.path)
    success_count = 0
    failed_count = 0
    
    # 處理考勤詳細工作表
    if spreadsheet.sheets.include?('考勤詳細')
      sheet = spreadsheet.sheet('考勤詳細')
      
      # 跳過表頭（前3行）
      (4..sheet.last_row).each do |row_num|
        begin
          row = sheet.row(row_num)
          next if row[0].blank? || row[2].blank? # 跳過空行
          
          # 查找員工
          employee = Employee.find_by(name: row[2]) || Employee.find_by(employee_number: row[3])
          next unless employee
          
          # 解析日期
          date_str = row[0].to_s
          attendance_date = parse_excel_date(date_str)
          next unless attendance_date
          
          # 創建或更新記錄
          record = AttendanceRecord.find_or_initialize_by(
            employee: employee,
            attendance_date: attendance_date
          )
          
          record.assign_attributes(
            day_of_week: row[1],
            is_holiday: row[1].to_s.include?('#假'),
            regular_hours_actual: parse_hours(row[7]),
            weekday_overtime_actual: parse_hours(row[21]),
            # 可以根據需要添加更多欄位解析
          )
          
          if record.save
            success_count += 1
          else
            failed_count += 1
          end
          
        rescue => e
          failed_count += 1
          Rails.logger.error "匯入第 #{row_num} 行失敗: #{e.message}"
        end
      end
    end
    
    { success: success_count, failed: failed_count }
  end
  
  def parse_excel_date(date_str)
    return nil unless date_str.present?
    
    if date_str.match(/(\d{2})月(\d{2})日/)
      month = $1.to_i
      day = $2.to_i
      year = Date.current.year
      
      begin
        Date.new(year, month, day)
      rescue ArgumentError
        nil
      end
    end
  end
  
  def parse_hours(hours_str)
    return 0.0 unless hours_str.present?
    
    if hours_str.match(/(\d+):(\d+)/)
      hours = $1.to_i
      minutes = $2.to_i
      hours + (minutes / 60.0)
    else
      hours_str.to_f
    end
  end
end

