# frozen_string_literal: true

class Attendance < ApplicationRecord
  belongs_to :employee

  # 允許Ransack搜尋關聯的員工資料
  def self.ransackable_attributes(auth_object = nil)
    %w[employee_id punch_time punch_type punch_method location ip_address notes created_at updated_at]
  end

  def self.ransackable_associations(auth_object = nil)
    %w[employee]
  end
  
  # 打卡類型
  PUNCH_TYPES = {
    'clock_in' => '上班打卡',
    'clock_out' => '下班打卡',
    'break_out' => '休息開始',
    'break_in' => '休息結束',
    'overtime_in' => '加班開始',
    'overtime_out' => '加班結束'
  }.freeze
  
  # 打卡方式
  PUNCH_METHODS = {
    'web' => '網頁打卡',
    'mobile' => '手機打卡',
    'card' => '卡片打卡',
    'biometric' => '生物識別',
    'manual' => '手動補卡'
  }.freeze
  
  # 出勤狀態
  ATTENDANCE_STATUS = {
    'normal' => '正常',
    'late' => '遲到',
    'early_leave' => '早退',
    'absent' => '缺勤',
    'sick_leave' => '病假',
    'personal_leave' => '事假',
    'annual_leave' => '特休',
    'overtime' => '加班'
  }.freeze
  
  validates :employee_id, presence: true
  validates :punch_time, presence: true
  validates :punch_type, presence: true, inclusion: { in: PUNCH_TYPES.keys }
  validates :punch_method, presence: true, inclusion: { in: PUNCH_METHODS.keys }
  
  scope :today, -> { where(punch_time: Date.current.beginning_of_day..Date.current.end_of_day) }
  scope :this_month, -> { where(punch_time: Date.current.beginning_of_month..Date.current.end_of_month) }
  scope :by_employee, ->(employee_id) { where(employee_id: employee_id) }
  scope :by_date_range, ->(start_date, end_date) { where(punch_time: start_date..end_date) }
  scope :clock_in, -> { where(punch_type: 'clock_in') }
  scope :clock_out, -> { where(punch_type: 'clock_out') }
  
  # 計算工作時數
  def self.calculate_work_hours(employee_id, date)
    attendances = where(employee_id: employee_id)
                    .where(punch_time: date.beginning_of_day..date.end_of_day)
                    .order(:punch_time)
    
    return 0 if attendances.empty?
    
    clock_in = attendances.find { |a| a.punch_type == 'clock_in' }
    clock_out = attendances.find { |a| a.punch_type == 'clock_out' }
    
    return 0 unless clock_in && clock_out
    
    work_seconds = clock_out.punch_time - clock_in.punch_time
    (work_seconds / 1.hour).round(2)
  end
  
  # 計算加班時數
  def self.calculate_overtime_hours(employee_id, date)
    attendances = where(employee_id: employee_id)
                    .where(punch_time: date.beginning_of_day..date.end_of_day)
                    .order(:punch_time)
    
    overtime_in = attendances.find { |a| a.punch_type == 'overtime_in' }
    overtime_out = attendances.find { |a| a.punch_type == 'overtime_out' }
    
    return 0 unless overtime_in && overtime_out
    
    overtime_seconds = overtime_out.punch_time - overtime_in.punch_time
    (overtime_seconds / 1.hour).round(2)
  end
  
  # 檢查是否遲到
  def late?
    return false unless punch_type == 'clock_in'
    
    # 假設標準上班時間是 9:00 AM
    standard_time = punch_time.beginning_of_day + 9.hours
    punch_time > standard_time
  end
  
  # 檢查是否早退
  def early_leave?
    return false unless punch_type == 'clock_out'
    
    # 假設標準下班時間是 6:00 PM
    standard_time = punch_time.beginning_of_day + 18.hours
    punch_time < standard_time
  end
  
  # 取得打卡類型中文名稱
  def punch_type_name
    PUNCH_TYPES[punch_type]
  end
  
  # 取得打卡方式中文名稱
  def punch_method_name
    PUNCH_METHODS[punch_method]
  end
  
  # 取得出勤狀態
  def attendance_status
    return 'late' if late?
    return 'early_leave' if early_leave?
    'normal'
  end
  
  # 取得出勤狀態中文名稱
  def attendance_status_name
    ATTENDANCE_STATUS[attendance_status]
  end
end
