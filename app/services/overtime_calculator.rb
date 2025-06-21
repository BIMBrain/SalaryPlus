# frozen_string_literal: true

class OvertimeCalculator
  # 一例一休加班費計算服務
  
  # 加班費率
  OVERTIME_RATES = {
    weekday_overtime: 1.34,      # 平日加班費率 (前2小時)
    weekday_overtime_extra: 1.67, # 平日加班費率 (超過2小時)
    weekend_overtime: 1.34,      # 週六加班費率
    holiday_overtime: 2.0,       # 國定假日加班費率
    rest_day_overtime_2h: 1.34,  # 休息日前2小時
    rest_day_overtime_2to8h: 1.67, # 休息日2-8小時
    rest_day_overtime_8h: 2.0    # 休息日超過8小時
  }.freeze
  
  # 標準工時設定
  STANDARD_WORK_HOURS = 8
  STANDARD_WORK_DAYS = 5
  WEEKLY_WORK_HOURS = 40
  
  def initialize(employee, start_date, end_date)
    @employee = employee
    @start_date = start_date
    @end_date = end_date
    @attendances = load_attendances
    @holidays = load_holidays
  end
  
  # 計算加班費
  def calculate_overtime_pay
    total_overtime_pay = 0
    overtime_details = []
    
    (@start_date..@end_date).each do |date|
      daily_overtime = calculate_daily_overtime(date)
      if daily_overtime[:total_pay] > 0
        overtime_details << daily_overtime
        total_overtime_pay += daily_overtime[:total_pay]
      end
    end
    
    {
      total_pay: total_overtime_pay,
      details: overtime_details,
      summary: generate_summary(overtime_details)
    }
  end
  
  # 計算單日加班費
  def calculate_daily_overtime(date)
    daily_attendances = @attendances.select { |a| a.punch_time.to_date == date }
    return zero_overtime_result(date) if daily_attendances.empty?
    
    work_hours = calculate_work_hours(daily_attendances)
    overtime_hours = work_hours - STANDARD_WORK_HOURS
    
    return zero_overtime_result(date) if overtime_hours <= 0
    
    day_type = determine_day_type(date)
    hourly_wage = calculate_hourly_wage
    
    case day_type
    when :weekday
      calculate_weekday_overtime(date, overtime_hours, hourly_wage)
    when :weekend
      calculate_weekend_overtime(date, work_hours, hourly_wage)
    when :rest_day
      calculate_rest_day_overtime(date, work_hours, hourly_wage)
    when :holiday
      calculate_holiday_overtime(date, work_hours, hourly_wage)
    end
  end
  
  # 檢查是否符合一例一休規定
  def check_labor_law_compliance
    violations = []
    
    # 檢查每週工時
    weeks = group_by_weeks(@start_date, @end_date)
    weeks.each do |week_start, week_end|
      weekly_hours = calculate_weekly_hours(week_start, week_end)
      if weekly_hours > WEEKLY_WORK_HOURS
        violations << {
          type: 'weekly_overtime',
          week: "#{week_start.strftime('%Y-%m-%d')} ~ #{week_end.strftime('%Y-%m-%d')}",
          hours: weekly_hours,
          excess: weekly_hours - WEEKLY_WORK_HOURS
        }
      end
    end
    
    # 檢查連續工作天數
    consecutive_days = check_consecutive_work_days
    if consecutive_days > 6
      violations << {
        type: 'consecutive_work_days',
        days: consecutive_days,
        message: '連續工作超過6天，違反一例一休規定'
      }
    end
    
    violations
  end
  
  private
  
  def load_attendances
    Attendance.where(employee: @employee)
              .where(punch_time: @start_date.beginning_of_day..@end_date.end_of_day)
              .order(:punch_time)
  end
  
  def load_holidays
    # 這裡應該從假日表載入，暫時使用固定假日
    [
      Date.new(2024, 1, 1),   # 元旦
      Date.new(2024, 2, 10),  # 春節
      Date.new(2024, 2, 11),  # 春節
      Date.new(2024, 2, 12),  # 春節
      Date.new(2024, 4, 4),   # 兒童節
      Date.new(2024, 4, 5),   # 清明節
      Date.new(2024, 5, 1),   # 勞動節
      Date.new(2024, 6, 10),  # 端午節
      Date.new(2024, 9, 17),  # 中秋節
      Date.new(2024, 10, 10), # 國慶日
    ]
  end
  
  def calculate_work_hours(attendances)
    clock_in = attendances.find { |a| a.punch_type == 'clock_in' }
    clock_out = attendances.find { |a| a.punch_type == 'clock_out' }
    
    return 0 unless clock_in && clock_out
    
    work_seconds = clock_out.punch_time - clock_in.punch_time
    
    # 扣除休息時間（假設1小時）
    lunch_break = 1.hour
    total_seconds = work_seconds - lunch_break
    
    (total_seconds / 1.hour).round(2)
  end
  
  def determine_day_type(date)
    return :holiday if @holidays.include?(date)
    
    case date.wday
    when 0 # 星期日
      :rest_day
    when 6 # 星期六
      :weekend
    else
      :weekday
    end
  end
  
  def calculate_hourly_wage
    # 從員工薪資資料計算時薪
    latest_salary = @employee.salaries.order(:created_at).last
    return 0 unless latest_salary
    
    monthly_salary = latest_salary.amount || 0
    # 假設每月工作22天，每天8小時
    monthly_salary / (22 * 8)
  end
  
  def calculate_weekday_overtime(date, overtime_hours, hourly_wage)
    first_2h = [overtime_hours, 2].min
    extra_hours = [overtime_hours - 2, 0].max
    
    first_2h_pay = first_2h * hourly_wage * OVERTIME_RATES[:weekday_overtime]
    extra_pay = extra_hours * hourly_wage * OVERTIME_RATES[:weekday_overtime_extra]
    
    {
      date: date,
      day_type: '平日',
      overtime_hours: overtime_hours,
      breakdown: [
        { hours: first_2h, rate: OVERTIME_RATES[:weekday_overtime], pay: first_2h_pay },
        { hours: extra_hours, rate: OVERTIME_RATES[:weekday_overtime_extra], pay: extra_pay }
      ].reject { |b| b[:hours] == 0 },
      total_pay: first_2h_pay + extra_pay
    }
  end
  
  def calculate_weekend_overtime(date, work_hours, hourly_wage)
    overtime_pay = work_hours * hourly_wage * OVERTIME_RATES[:weekend_overtime]
    
    {
      date: date,
      day_type: '週六',
      overtime_hours: work_hours,
      breakdown: [
        { hours: work_hours, rate: OVERTIME_RATES[:weekend_overtime], pay: overtime_pay }
      ],
      total_pay: overtime_pay
    }
  end
  
  def calculate_rest_day_overtime(date, work_hours, hourly_wage)
    first_2h = [work_hours, 2].min
    hours_2to8 = [work_hours - 2, 0].min
    hours_2to8 = [hours_2to8, 6].min
    hours_over8 = [work_hours - 8, 0].max
    
    first_2h_pay = first_2h * hourly_wage * OVERTIME_RATES[:rest_day_overtime_2h]
    hours_2to8_pay = hours_2to8 * hourly_wage * OVERTIME_RATES[:rest_day_overtime_2to8h]
    hours_over8_pay = hours_over8 * hourly_wage * OVERTIME_RATES[:rest_day_overtime_8h]
    
    {
      date: date,
      day_type: '休息日',
      overtime_hours: work_hours,
      breakdown: [
        { hours: first_2h, rate: OVERTIME_RATES[:rest_day_overtime_2h], pay: first_2h_pay },
        { hours: hours_2to8, rate: OVERTIME_RATES[:rest_day_overtime_2to8h], pay: hours_2to8_pay },
        { hours: hours_over8, rate: OVERTIME_RATES[:rest_day_overtime_8h], pay: hours_over8_pay }
      ].reject { |b| b[:hours] == 0 },
      total_pay: first_2h_pay + hours_2to8_pay + hours_over8_pay
    }
  end
  
  def calculate_holiday_overtime(date, work_hours, hourly_wage)
    overtime_pay = work_hours * hourly_wage * OVERTIME_RATES[:holiday_overtime]
    
    {
      date: date,
      day_type: '國定假日',
      overtime_hours: work_hours,
      breakdown: [
        { hours: work_hours, rate: OVERTIME_RATES[:holiday_overtime], pay: overtime_pay }
      ],
      total_pay: overtime_pay
    }
  end
  
  def zero_overtime_result(date)
    {
      date: date,
      day_type: determine_day_type(date).to_s,
      overtime_hours: 0,
      breakdown: [],
      total_pay: 0
    }
  end
  
  def group_by_weeks(start_date, end_date)
    weeks = []
    current_date = start_date.beginning_of_week
    
    while current_date <= end_date
      week_end = [current_date.end_of_week, end_date].min
      weeks << [current_date, week_end]
      current_date = week_end + 1.day
    end
    
    weeks
  end
  
  def calculate_weekly_hours(week_start, week_end)
    total_hours = 0
    (week_start..week_end).each do |date|
      daily_attendances = @attendances.select { |a| a.punch_time.to_date == date }
      total_hours += calculate_work_hours(daily_attendances)
    end
    total_hours
  end
  
  def check_consecutive_work_days
    max_consecutive = 0
    current_consecutive = 0
    
    (@start_date..@end_date).each do |date|
      daily_attendances = @attendances.select { |a| a.punch_time.to_date == date }
      
      if daily_attendances.any?
        current_consecutive += 1
        max_consecutive = [max_consecutive, current_consecutive].max
      else
        current_consecutive = 0
      end
    end
    
    max_consecutive
  end
  
  def generate_summary(overtime_details)
    {
      total_days: overtime_details.count,
      total_hours: overtime_details.sum { |d| d[:overtime_hours] },
      weekday_hours: overtime_details.select { |d| d[:day_type] == '平日' }.sum { |d| d[:overtime_hours] },
      weekend_hours: overtime_details.select { |d| d[:day_type] == '週六' }.sum { |d| d[:overtime_hours] },
      rest_day_hours: overtime_details.select { |d| d[:day_type] == '休息日' }.sum { |d| d[:overtime_hours] },
      holiday_hours: overtime_details.select { |d| d[:day_type] == '國定假日' }.sum { |d| d[:overtime_hours] }
    }
  end
end
