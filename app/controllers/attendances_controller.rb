# frozen_string_literal: true

class AttendancesController < ApplicationController
  before_action :set_attendance, only: [:show, :edit, :update, :destroy]
  before_action :set_employees, only: [:index, :new, :edit, :create, :update]
  
  def index
    @query = Attendance.ransack(params[:q])
    @attendances = @query.result
                         .includes(:employee)
                         .order(punch_time: :desc)
                         .page(params[:page])
                         .per(20)
    
    # 統計數據
    @today_attendances = Attendance.today.count
    @total_employees = Employee.count
    @present_today = Attendance.today.clock_in.distinct.count(:employee_id)
    @late_today = Attendance.today.select(&:late?).count
  end
  
  def show
  end
  
  def new
    @attendance = Attendance.new
    @employees = Employee.all
  end
  
  def create
    @attendance = Attendance.new(attendance_params)
    @attendance.punch_time ||= Time.current
    
    if @attendance.save
      redirect_to attendances_path, notice: '打卡記錄已成功建立'
    else
      render :new
    end
  end
  
  def edit
  end
  
  def update
    if @attendance.update(attendance_params)
      redirect_to attendances_path, notice: '打卡記錄已成功更新'
    else
      render :edit
    end
  end
  
  def destroy
    @attendance.destroy
    redirect_to attendances_path, notice: '打卡記錄已刪除'
  end
  
  # 快速打卡 API
  def quick_punch
    employee = Employee.find(params[:employee_id])
    punch_type = determine_punch_type(employee)
    
    attendance = Attendance.new(
      employee: employee,
      punch_time: Time.current,
      punch_type: punch_type,
      punch_method: params[:punch_method] || 'web',
      location: params[:location],
      ip_address: request.remote_ip,
      notes: params[:notes]
    )
    
    if attendance.save
      render json: { 
        success: true, 
        message: "#{attendance.punch_type_name}成功",
        attendance: attendance.as_json(include: :employee)
      }
    else
      render json: { 
        success: false, 
        errors: attendance.errors.full_messages 
      }
    end
  end
  
  # 今日出勤統計
  def daily_summary
    @date = params[:date]&.to_date || Date.current
    @employees = Employee.includes(:attendances)
    
    @summary = @employees.map do |employee|
      attendances = employee.attendances.where(
        punch_time: @date.beginning_of_day..@date.end_of_day
      ).order(:punch_time)
      
      {
        employee: employee,
        attendances: attendances,
        work_hours: Attendance.calculate_work_hours(employee.id, @date),
        overtime_hours: Attendance.calculate_overtime_hours(employee.id, @date),
        status: determine_daily_status(attendances)
      }
    end
  end
  
  # 月度出勤報表
  def monthly_report
    @year = params[:year]&.to_i || Date.current.year
    @month = params[:month]&.to_i || Date.current.month
    @start_date = Date.new(@year, @month, 1)
    @end_date = @start_date.end_of_month
    
    @employees = Employee.includes(:attendances)
    @report_data = generate_monthly_report(@employees, @start_date, @end_date)
  end
  
  # 匯出出勤記錄
  def export
    @attendances = Attendance.includes(:employee)
                            .where(punch_time: params[:start_date]..params[:end_date])
                            .order(:punch_time)
    
    respond_to do |format|
      format.csv do
        send_data generate_csv(@attendances), 
                  filename: "attendance_report_#{Date.current}.csv"
      end
      format.xlsx do
        send_data generate_xlsx(@attendances),
                  filename: "attendance_report_#{Date.current}.xlsx"
      end
    end
  end
  
  private
  
  def set_attendance
    @attendance = Attendance.find(params[:id])
  end
  
  def set_employees
    @employees = Employee.all
  end
  
  def attendance_params
    params.require(:attendance).permit(
      :employee_id, :punch_time, :punch_type, :punch_method,
      :location, :ip_address, :notes
    )
  end
  
  # 判斷打卡類型
  def determine_punch_type(employee)
    today_attendances = employee.attendances.today.order(:punch_time)
    
    return 'clock_in' if today_attendances.empty?
    
    last_punch = today_attendances.last
    case last_punch.punch_type
    when 'clock_in'
      'clock_out'
    when 'clock_out'
      'overtime_in'
    when 'overtime_in'
      'overtime_out'
    else
      'clock_in'
    end
  end
  
  # 判斷每日出勤狀態
  def determine_daily_status(attendances)
    return 'absent' if attendances.empty?
    
    clock_in = attendances.find { |a| a.punch_type == 'clock_in' }
    clock_out = attendances.find { |a| a.punch_type == 'clock_out' }
    
    return 'late' if clock_in&.late?
    return 'early_leave' if clock_out&.early_leave?
    'normal'
  end
  
  # 生成月度報表數據
  def generate_monthly_report(employees, start_date, end_date)
    employees.map do |employee|
      days_data = (start_date..end_date).map do |date|
        attendances = employee.attendances.where(
          punch_time: date.beginning_of_day..date.end_of_day
        ).order(:punch_time)
        
        {
          date: date,
          attendances: attendances,
          work_hours: Attendance.calculate_work_hours(employee.id, date),
          overtime_hours: Attendance.calculate_overtime_hours(employee.id, date),
          status: determine_daily_status(attendances)
        }
      end
      
      {
        employee: employee,
        days: days_data,
        total_work_hours: days_data.sum { |d| d[:work_hours] },
        total_overtime_hours: days_data.sum { |d| d[:overtime_hours] },
        present_days: days_data.count { |d| d[:status] != 'absent' },
        late_days: days_data.count { |d| d[:status] == 'late' }
      }
    end
  end
  
  # 生成CSV格式數據
  def generate_csv(attendances)
    CSV.generate(headers: true) do |csv|
      csv << ['員工姓名', '打卡時間', '打卡類型', '打卡方式', '位置', 'IP地址', '備註']
      
      attendances.each do |attendance|
        csv << [
          attendance.employee.name,
          attendance.punch_time.strftime('%Y-%m-%d %H:%M:%S'),
          attendance.punch_type_name,
          attendance.punch_method_name,
          attendance.location,
          attendance.ip_address,
          attendance.notes
        ]
      end
    end
  end
end
