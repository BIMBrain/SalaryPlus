# frozen_string_literal: true

class OvertimeController < ApplicationController
  before_action :set_employee, only: [:show, :calculate]
  
  def index
    @employees = Employee.includes(:attendances)
    @current_month = Date.current.beginning_of_month
    @overtime_summary = calculate_monthly_overtime_summary
  end
  
  def show
    @start_date = params[:start_date]&.to_date || Date.current.beginning_of_month
    @end_date = params[:end_date]&.to_date || Date.current.end_of_month
    
    calculator = OvertimeCalculator.new(@employee, @start_date, @end_date)
    @overtime_result = calculator.calculate_overtime_pay
    @compliance_check = calculator.check_labor_law_compliance
  end
  
  def calculate
    @start_date = params[:start_date]&.to_date || Date.current.beginning_of_month
    @end_date = params[:end_date]&.to_date || Date.current.end_of_month
    
    calculator = OvertimeCalculator.new(@employee, @start_date, @end_date)
    @overtime_result = calculator.calculate_overtime_pay
    @compliance_check = calculator.check_labor_law_compliance
    
    respond_to do |format|
      format.json do
        render json: {
          overtime_result: @overtime_result,
          compliance_check: @compliance_check
        }
      end
      format.html { render :show }
    end
  end
  
  def batch_calculate
    @start_date = params[:start_date]&.to_date || Date.current.beginning_of_month
    @end_date = params[:end_date]&.to_date || Date.current.end_of_month
    @employee_ids = params[:employee_ids] || Employee.pluck(:id)
    
    @batch_results = []
    
    Employee.where(id: @employee_ids).each do |employee|
      calculator = OvertimeCalculator.new(employee, @start_date, @end_date)
      overtime_result = calculator.calculate_overtime_pay
      compliance_check = calculator.check_labor_law_compliance
      
      @batch_results << {
        employee: employee,
        overtime_result: overtime_result,
        compliance_check: compliance_check
      }
    end
    
    respond_to do |format|
      format.html
      format.csv do
        send_data generate_overtime_csv(@batch_results),
                  filename: "overtime_report_#{@start_date}_#{@end_date}.csv"
      end
    end
  end
  
  def compliance_report
    @start_date = params[:start_date]&.to_date || Date.current.beginning_of_month
    @end_date = params[:end_date]&.to_date || Date.current.end_of_month
    
    @violations = []
    
    Employee.includes(:attendances).each do |employee|
      calculator = OvertimeCalculator.new(employee, @start_date, @end_date)
      violations = calculator.check_labor_law_compliance
      
      if violations.any?
        @violations << {
          employee: employee,
          violations: violations
        }
      end
    end
  end
  
  def rates
    # 顯示加班費率設定
    @overtime_rates = OvertimeCalculator::OVERTIME_RATES
  end
  
  private
  
  def set_employee
    @employee = Employee.find(params[:id] || params[:employee_id])
  end
  
  def calculate_monthly_overtime_summary
    start_date = Date.current.beginning_of_month
    end_date = Date.current.end_of_month
    
    summary = {
      total_employees: 0,
      employees_with_overtime: 0,
      total_overtime_hours: 0,
      total_overtime_pay: 0,
      violations_count: 0
    }
    
    Employee.includes(:attendances).each do |employee|
      calculator = OvertimeCalculator.new(employee, start_date, end_date)
      overtime_result = calculator.calculate_overtime_pay
      compliance_check = calculator.check_labor_law_compliance
      
      summary[:total_employees] += 1
      
      if overtime_result[:total_pay] > 0
        summary[:employees_with_overtime] += 1
        summary[:total_overtime_hours] += overtime_result[:summary][:total_hours]
        summary[:total_overtime_pay] += overtime_result[:total_pay]
      end
      
      summary[:violations_count] += compliance_check.count
    end
    
    summary
  end
  
  def generate_overtime_csv(batch_results)
    CSV.generate(headers: true) do |csv|
      csv << [
        '員工姓名', '員工編號', '期間', '加班總時數', '加班總金額',
        '平日加班時數', '週六加班時數', '休息日加班時數', '國定假日加班時數',
        '法規違規項目'
      ]
      
      batch_results.each do |result|
        employee = result[:employee]
        overtime = result[:overtime_result]
        violations = result[:compliance_check]
        
        csv << [
          employee.name,
          employee.id,
          "#{@start_date} ~ #{@end_date}",
          overtime[:summary][:total_hours],
          overtime[:total_pay],
          overtime[:summary][:weekday_hours],
          overtime[:summary][:weekend_hours],
          overtime[:summary][:rest_day_hours],
          overtime[:summary][:holiday_hours],
          violations.map { |v| v[:type] }.join(', ')
        ]
      end
    end
  end
end
