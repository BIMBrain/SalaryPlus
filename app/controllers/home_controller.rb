class HomeController < ApplicationController
  def index
    # Dashboard statistics
    @total_employees = Employee.count
    @active_employees = Employee.joins(:terms).where(terms: { end_date: nil }).count
    @current_month_payrolls = Payroll.where(year: Date.current.year, month: Date.current.month).count
    @total_statements = Statement.count
  end
end
