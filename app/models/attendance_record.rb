# frozen_string_literal: true

class AttendanceRecord < ApplicationRecord
  belongs_to :employee

  # 允許Ransack搜尋
  def self.ransackable_attributes(auth_object = nil)
    %w[employee_id attendance_date day_of_week is_holiday 
       regular_hours_required regular_hours_actual regular_hours_extra
       weekday_overtime_required weekday_overtime_actual weekday_overtime_extra
       weekend_overtime_required weekend_overtime_actual weekend_overtime_extra
       personal_leave_days menstrual_leave_days annual_leave_days sick_leave_days
       compensatory_leave_days business_trip_days
       late_count early_leave_count absent_count missing_punch_count
       filter_status exception_status created_at updated_at]
  end

  def self.ransackable_associations(auth_object = nil)
    %w[employee]
  end
  
  # 假期類型
  LEAVE_TYPES = {
    'personal_leave' => '事假',
    'menstrual_leave' => '生理假',
    'annual_leave' => '年假',
    'sick_leave' => '病假',
    'compensatory_leave' => '調休',
    'business_trip' => '出差'
  }.freeze
  
  # 異常狀態
  EXCEPTION_STATUS = {
    'normal' => '正常',
    'late' => '遲到',
    'early_leave' => '早退',
    'absent' => '曠職',
    'missing_punch' => '未簽'
  }.freeze
  
  validates :employee_id, presence: true
  validates :attendance_date, presence: true, uniqueness: { scope: :employee_id }
  
  scope :today, -> { where(attendance_date: Date.current) }
  scope :this_month, -> { where(attendance_date: Date.current.beginning_of_month..Date.current.end_of_month) }
  scope :by_employee, ->(employee_id) { where(employee_id: employee_id) }
  scope :by_date_range, ->(start_date, end_date) { where(attendance_date: start_date..end_date) }
  scope :holidays, -> { where(is_holiday: true) }
  scope :workdays, -> { where(is_holiday: false) }
  scope :with_exceptions, -> { where.not(exception_status: ['normal', nil]) }
  
  # 計算總工作時數
  def total_work_hours
    regular_hours_actual + weekday_overtime_actual + weekend_overtime_actual
  end
  
  # 計算總加班時數
  def total_overtime_hours
    weekday_overtime_actual + weekend_overtime_actual
  end
  
  # 計算總請假天數
  def total_leave_days
    personal_leave_days + menstrual_leave_days + annual_leave_days + 
    sick_leave_days + compensatory_leave_days + business_trip_days
  end
  
  # 計算總異常次數
  def total_exception_count
    late_count + early_leave_count + absent_count + missing_punch_count
  end
  
  # 檢查是否有異常
  def has_exceptions?
    total_exception_count > 0
  end
  
  # 檢查是否有請假
  def has_leave?
    total_leave_days > 0
  end
  
  # 檢查是否有加班
  def has_overtime?
    total_overtime_hours > 0
  end
  
  # 取得星期幾的中文名稱
  def day_of_week_chinese
    case day_of_week
    when 'Monday' then '周一'
    when 'Tuesday' then '周二'
    when 'Wednesday' then '周三'
    when 'Thursday' then '周四'
    when 'Friday' then '周五'
    when 'Saturday' then '周六'
    when 'Sunday' then '周日'
    else day_of_week
    end
  end
  
  # 取得異常狀態中文名稱
  def exception_status_name
    EXCEPTION_STATUS[exception_status] || exception_status
  end
  
  # 計算出勤率
  def attendance_rate
    return 100.0 if is_holiday?
    return 0.0 if absent_count > 0
    
    expected_hours = regular_hours_required
    return 100.0 if expected_hours == 0
    
    actual_rate = (regular_hours_actual / expected_hours) * 100
    [actual_rate, 100.0].min
  end
  
  # 檢查是否達到標準工時
  def meets_standard_hours?
    regular_hours_actual >= regular_hours_required
  end
  
  # 取得當日狀態摘要
  def daily_summary
    status = []
    status << "工時: #{regular_hours_actual}h" if regular_hours_actual > 0
    status << "加班: #{total_overtime_hours}h" if total_overtime_hours > 0
    status << "請假: #{total_leave_days}天" if total_leave_days > 0
    status << "異常: #{total_exception_count}次" if total_exception_count > 0
    status << "假日" if is_holiday?
    
    status.empty? ? "無記錄" : status.join(", ")
  end
  
  # 匯入 Excel 資料的類方法
  def self.import_from_excel_data(employee, date_str, row_data)
    # 解析日期
    attendance_date = parse_date_from_string(date_str)
    return nil unless attendance_date
    
    # 查找或創建記錄
    record = find_or_initialize_by(
      employee: employee,
      attendance_date: attendance_date
    )
    
    # 更新記錄資料
    record.assign_attributes(
      day_of_week: row_data[:day_of_week],
      is_holiday: row_data[:is_holiday] || false,
      regular_hours_actual: parse_hours(row_data[:regular_hours]),
      weekday_overtime_actual: parse_hours(row_data[:weekday_overtime]),
      weekend_overtime_actual: parse_hours(row_data[:weekend_overtime]),
      # 可以根據需要添加更多欄位
    )
    
    record.save
    record
  end
  
  private
  
  def self.parse_date_from_string(date_str)
    # 解析 "05月01日" 格式的日期
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
  
  def self.parse_hours(hours_str)
    return 0.0 unless hours_str.present?
    
    # 解析 "9:00" 格式的時間為小時數
    if hours_str.match(/(\d+):(\d+)/)
      hours = $1.to_i
      minutes = $2.to_i
      hours + (minutes / 60.0)
    else
      hours_str.to_f
    end
  end
end

