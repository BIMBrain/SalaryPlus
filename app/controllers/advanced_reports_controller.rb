# frozen_string_literal: true

class AdvancedReportsController < ApplicationController
  before_action :set_date_range, only: [:department_salary, :company_burden, :employee_cost_analysis, :insurance_summary]
  
  def index
    # 報表總覽頁面
  end
  
  # 部門薪資總表
  def department_salary
    @departments = Employee.distinct.pluck(:department).compact.sort
    @selected_department = params[:department]
    
    if @selected_department.present?
      @employees = Employee.where(department: @selected_department)
                          .includes(:payrolls, :salaries)
      
      @payrolls = Payroll.joins(:employee)
                         .where(employees: { department: @selected_department })
                         .where(year: @year, month: @month)
                         .includes(:employee, :salary, :statement)
      
      @department_summary = calculate_department_summary(@payrolls)
    end
    
    respond_to do |format|
      format.html
      format.csv { send_data generate_department_salary_csv, filename: "department_salary_#{@year}_#{@month}.csv" }
      format.xlsx { send_data generate_department_salary_xlsx, filename: "department_salary_#{@year}_#{@month}.xlsx" }
    end
  end
  
  # 公司負擔管理表
  def company_burden
    @payrolls = Payroll.where(year: @year, month: @month)
                       .includes(:employee, :salary, :statement)
    
    @burden_summary = calculate_company_burden(@payrolls)
    @monthly_trend = calculate_burden_trend(@year)
    
    respond_to do |format|
      format.html
      format.csv { send_data generate_company_burden_csv, filename: "company_burden_#{@year}_#{@month}.csv" }
      format.xlsx { send_data generate_company_burden_xlsx, filename: "company_burden_#{@year}_#{@month}.xlsx" }
    end
  end
  
  # 員工成本分析
  def employee_cost_analysis
    @employees = Employee.includes(:payrolls, :salaries)
    @cost_analysis = calculate_employee_cost_analysis(@year, @month)
    @cost_ranking = @cost_analysis.sort_by { |data| -data[:total_cost] }
    
    respond_to do |format|
      format.html
      format.csv { send_data generate_cost_analysis_csv, filename: "employee_cost_analysis_#{@year}_#{@month}.csv" }
    end
  end
  
  # 保險費用統計
  def insurance_summary
    @insurance_data = calculate_insurance_summary(@year, @month)
    @annual_insurance_trend = calculate_annual_insurance_trend(@year)
    
    respond_to do |format|
      format.html
      format.csv { send_data generate_insurance_summary_csv, filename: "insurance_summary_#{@year}_#{@month}.csv" }
    end
  end
  
  # 薪資結構分析
  def salary_structure_analysis
    @year = params[:year]&.to_i || Date.current.year
    @salary_ranges = calculate_salary_ranges(@year)
    @department_comparison = calculate_department_salary_comparison(@year)
    @position_analysis = calculate_position_salary_analysis(@year)
    
    respond_to do |format|
      format.html
      format.csv { send_data generate_salary_structure_csv, filename: "salary_structure_#{@year}.csv" }
    end
  end
  
  # 出勤統計報表
  def attendance_statistics
    @year = params[:year]&.to_i || Date.current.year
    @month = params[:month]&.to_i || Date.current.month
    
    @attendance_summary = calculate_attendance_summary(@year, @month)
    @department_attendance = calculate_department_attendance(@year, @month)
    @overtime_statistics = calculate_overtime_statistics(@year, @month)
    
    respond_to do |format|
      format.html
      format.csv { send_data generate_attendance_statistics_csv, filename: "attendance_statistics_#{@year}_#{@month}.csv" }
    end
  end
  
  # 年度薪資總表
  def annual_salary_summary
    @year = params[:year]&.to_i || Date.current.year
    @annual_data = calculate_annual_salary_summary(@year)
    @monthly_breakdown = calculate_monthly_breakdown(@year)
    @employee_annual_summary = calculate_employee_annual_summary(@year)
    
    respond_to do |format|
      format.html
      format.csv { send_data generate_annual_summary_csv, filename: "annual_salary_summary_#{@year}.csv" }
      format.xlsx { send_data generate_annual_summary_xlsx, filename: "annual_salary_summary_#{@year}.xlsx" }
    end
  end
  
  # 勞動成本分析
  def labor_cost_analysis
    @year = params[:year]&.to_i || Date.current.year
    @labor_cost_data = calculate_labor_cost_analysis(@year)
    @productivity_metrics = calculate_productivity_metrics(@year)
    @cost_per_employee = calculate_cost_per_employee(@year)
    
    respond_to do |format|
      format.html
      format.csv { send_data generate_labor_cost_csv, filename: "labor_cost_analysis_#{@year}.csv" }
    end
  end
  
  private
  
  def set_date_range
    @year = params[:year]&.to_i || Date.current.year
    @month = params[:month]&.to_i || Date.current.month
  end
  
  def calculate_department_summary(payrolls)
    {
      employee_count: payrolls.count,
      total_gross_pay: payrolls.joins(:statement).sum('statements.amount'),
      total_net_pay: payrolls.joins(:statement).sum('statements.net_income'),
      total_labor_insurance: payrolls.joins(:salary).sum('salaries.labor_insurance'),
      total_health_insurance: payrolls.joins(:salary).sum('salaries.health_insurance'),
      total_income_tax: payrolls.joins(:statement).sum('statements.income_tax'),
      average_salary: payrolls.joins(:statement).average('statements.amount')&.round || 0
    }
  end
  
  def calculate_company_burden(payrolls)
    # 公司負擔的勞保費（通常是員工負擔的2倍）
    employee_labor_insurance = payrolls.joins(:salary).sum('salaries.labor_insurance')
    company_labor_insurance = employee_labor_insurance * 2
    
    # 公司負擔的健保費（通常是員工負擔的1.5倍）
    employee_health_insurance = payrolls.joins(:salary).sum('salaries.health_insurance')
    company_health_insurance = employee_health_insurance * 1.5
    
    # 勞退提繳（通常是投保薪資的6%）
    labor_pension = payrolls.joins(:salary).sum do |payroll|
      (payroll.salary.insured_for_labor * 0.06).round
    end
    
    # 二代健保補充保費
    supplement_health_insurance = payrolls.sum do |payroll|
      HealthInsuranceService::CompanyCoverage.call(payroll.year, payroll.month)
    end
    
    total_burden = company_labor_insurance + company_health_insurance + labor_pension + supplement_health_insurance
    
    {
      company_labor_insurance: company_labor_insurance,
      company_health_insurance: company_health_insurance,
      labor_pension: labor_pension,
      supplement_health_insurance: supplement_health_insurance,
      total_burden: total_burden,
      employee_count: payrolls.count
    }
  end
  
  def calculate_burden_trend(year)
    (1..12).map do |month|
      monthly_payrolls = Payroll.where(year: year, month: month)
      burden_data = calculate_company_burden(monthly_payrolls)
      
      {
        month: month,
        total_burden: burden_data[:total_burden],
        employee_count: burden_data[:employee_count]
      }
    end
  end
  
  def calculate_employee_cost_analysis(year, month)
    Employee.includes(:payrolls, :salaries).map do |employee|
      payroll = employee.payrolls.find_by(year: year, month: month)
      
      if payroll
        gross_pay = payroll.statement&.amount || 0
        labor_insurance = payroll.salary&.labor_insurance || 0
        health_insurance = payroll.salary&.health_insurance || 0
        
        # 計算公司負擔
        company_labor_insurance = labor_insurance * 2
        company_health_insurance = health_insurance * 1.5
        labor_pension = (payroll.salary&.insured_for_labor || 0) * 0.06
        
        total_cost = gross_pay + company_labor_insurance + company_health_insurance + labor_pension
        
        {
          employee: employee,
          gross_pay: gross_pay,
          company_burden: company_labor_insurance + company_health_insurance + labor_pension,
          total_cost: total_cost.round,
          cost_per_hour: payroll.statement&.work_hours&.positive? ? (total_cost / payroll.statement.work_hours).round : 0
        }
      else
        {
          employee: employee,
          gross_pay: 0,
          company_burden: 0,
          total_cost: 0,
          cost_per_hour: 0
        }
      end
    end
  end
  
  def calculate_insurance_summary(year, month)
    payrolls = Payroll.where(year: year, month: month).includes(:salary)
    
    {
      total_labor_insurance: payrolls.joins(:salary).sum('salaries.labor_insurance'),
      total_health_insurance: payrolls.joins(:salary).sum('salaries.health_insurance'),
      average_insured_salary: payrolls.joins(:salary).average('salaries.insured_for_health')&.round || 0,
      insured_employee_count: payrolls.count,
      total_premium: payrolls.joins(:salary).sum('salaries.labor_insurance + salaries.health_insurance')
    }
  end
  
  def calculate_annual_insurance_trend(year)
    (1..12).map do |month|
      insurance_data = calculate_insurance_summary(year, month)
      {
        month: month,
        total_premium: insurance_data[:total_premium],
        employee_count: insurance_data[:insured_employee_count]
      }
    end
  end
  
  def calculate_salary_ranges(year)
    payrolls = Payroll.where(year: year).includes(:statement)
    salaries = payrolls.joins(:statement).pluck('statements.amount').compact
    
    return {} if salaries.empty?
    
    ranges = {
      '30,000以下' => salaries.count { |s| s < 30000 },
      '30,000-40,000' => salaries.count { |s| s >= 30000 && s < 40000 },
      '40,000-50,000' => salaries.count { |s| s >= 40000 && s < 50000 },
      '50,000-60,000' => salaries.count { |s| s >= 50000 && s < 60000 },
      '60,000-80,000' => salaries.count { |s| s >= 60000 && s < 80000 },
      '80,000以上' => salaries.count { |s| s >= 80000 }
    }
    
    {
      ranges: ranges,
      total_employees: salaries.count,
      average_salary: (salaries.sum / salaries.count).round,
      median_salary: salaries.sort[salaries.count / 2]
    }
  end
  
  def calculate_department_salary_comparison(year)
    departments = Employee.distinct.pluck(:department).compact
    
    departments.map do |dept|
      dept_payrolls = Payroll.joins(:employee)
                             .where(employees: { department: dept })
                             .where(year: year)
                             .includes(:statement)
      
      salaries = dept_payrolls.joins(:statement).pluck('statements.amount').compact
      
      {
        department: dept,
        employee_count: dept_payrolls.joins(:employee).distinct.count('employees.id'),
        average_salary: salaries.any? ? (salaries.sum / salaries.count).round : 0,
        total_cost: salaries.sum
      }
    end.sort_by { |data| -data[:average_salary] }
  end
  
  def generate_department_salary_csv
    require 'csv'
    
    CSV.generate(headers: true) do |csv|
      csv << ['員工姓名', '部門', '職位', '基本薪資', '津貼', '加班費', '總收入', '勞保費', '健保費', '所得稅', '實領金額']
      
      @payrolls.each do |payroll|
        csv << [
          payroll.employee.display_name,
          payroll.employee.department,
          payroll.employee.position,
          payroll.salary.monthly_wage,
          payroll.salary.equipment_subsidy + payroll.salary.commuting_subsidy + payroll.salary.supervisor_allowance,
          payroll.statement&.overtime_pay || 0,
          payroll.statement&.amount || 0,
          payroll.salary.labor_insurance,
          payroll.salary.health_insurance,
          payroll.statement&.income_tax || 0,
          payroll.statement&.net_income || 0
        ]
      end
    end
  end
  
  def generate_company_burden_csv
    require 'csv'
    
    CSV.generate(headers: true) do |csv|
      csv << ['項目', '金額', '說明']
      csv << ['公司負擔勞保費', @burden_summary[:company_labor_insurance], '員工勞保費 × 2']
      csv << ['公司負擔健保費', @burden_summary[:company_health_insurance], '員工健保費 × 1.5']
      csv << ['勞退提繳', @burden_summary[:labor_pension], '投保薪資 × 6%']
      csv << ['二代健保補充保費', @burden_summary[:supplement_health_insurance], '公司負擔部分']
      csv << ['總計', @burden_summary[:total_burden], '']
    end
  end
end
