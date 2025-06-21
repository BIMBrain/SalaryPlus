# frozen_string_literal: true

class InsuranceStatementsController < ApplicationController
  before_action :set_insurance_statement, only: [:show, :edit, :update, :destroy, :reconcile, :resolve]
  
  def index
    @query = InsuranceStatement.ransack(params[:q])
    @insurance_statements = @query.result
                                  .order(year: :desc, month: :desc, statement_type: :asc)
                                  .page(params[:page])
                                  .per(20)
    
    # 統計數據
    @total_statements = InsuranceStatement.count
    @pending_statements = InsuranceStatement.pending.count
    @discrepancy_statements = InsuranceStatement.with_discrepancy.count
    @current_year = Date.current.year
    @current_month = Date.current.month
  end
  
  def show
    @calculated_details = calculate_statement_details
  end
  
  def new
    @insurance_statement = InsuranceStatement.new
    @insurance_statement.year = params[:year] || Date.current.year
    @insurance_statement.month = params[:month] || Date.current.month
  end
  
  def create
    @insurance_statement = InsuranceStatement.new(insurance_statement_params)
    @insurance_statement.uploaded_at = Time.current
    @insurance_statement.calculated_amount = @insurance_statement.calculated_amount
    
    if @insurance_statement.save
      @insurance_statement.auto_reconcile!
      redirect_to insurance_statements_path, notice: '保險對帳單已成功建立'
    else
      render :new
    end
  end
  
  def edit
  end
  
  def update
    if @insurance_statement.update(insurance_statement_params)
      @insurance_statement.auto_reconcile!
      redirect_to @insurance_statement, notice: '保險對帳單已成功更新'
    else
      render :edit
    end
  end
  
  def destroy
    @insurance_statement.destroy
    redirect_to insurance_statements_path, notice: '保險對帳單已刪除'
  end
  
  # 執行對帳
  def reconcile
    @insurance_statement.auto_reconcile!
    redirect_to @insurance_statement, notice: '對帳完成'
  end
  
  # 標記為已解決
  def resolve
    @insurance_statement.mark_as_resolved!(params[:resolution_notes])
    redirect_to @insurance_statement, notice: '已標記為解決'
  end
  
  # 批量對帳
  def batch_reconcile
    year = params[:year]&.to_i || Date.current.year
    month = params[:month]&.to_i || Date.current.month
    
    statements = InsuranceStatement.where(year: year, month: month)
    reconciled_count = 0
    
    statements.each do |statement|
      statement.auto_reconcile!
      reconciled_count += 1
    end
    
    redirect_to insurance_statements_path, notice: "已完成 #{reconciled_count} 筆對帳"
  end
  
  # 匯入對帳單
  def import
    if params[:file].present?
      result = ImportInsuranceStatementService.call(params[:file])
      if result[:success]
        redirect_to insurance_statements_path, notice: "成功匯入 #{result[:count]} 筆對帳單"
      else
        redirect_to insurance_statements_path, alert: "匯入失敗：#{result[:error]}"
      end
    else
      redirect_to insurance_statements_path, alert: '請選擇要匯入的檔案'
    end
  end
  
  # 匯出對帳報表
  def export
    @statements = InsuranceStatement.where(
      year: params[:year] || Date.current.year,
      month: params[:month] || Date.current.month
    ).order(:statement_type)
    
    respond_to do |format|
      format.csv do
        send_data generate_csv(@statements), 
                  filename: "insurance_reconciliation_#{params[:year]}_#{params[:month]}.csv"
      end
      format.xlsx do
        send_data generate_xlsx(@statements),
                  filename: "insurance_reconciliation_#{params[:year]}_#{params[:month]}.xlsx"
      end
    end
  end
  
  # 對帳總覽
  def dashboard
    @year = params[:year]&.to_i || Date.current.year
    @month = params[:month]&.to_i || Date.current.month
    
    @summary = InsuranceStatement::STATEMENT_TYPES.keys.map do |type|
      statement = InsuranceStatement.find_by(statement_type: type, year: @year, month: @month)
      calculated = calculate_amount_by_type(type, @year, @month)
      
      {
        type: type,
        type_name: InsuranceStatement::STATEMENT_TYPES[type],
        statement: statement,
        calculated_amount: calculated,
        statement_amount: statement&.statement_amount || 0,
        difference: (statement&.statement_amount || 0) - calculated,
        has_statement: statement.present?,
        status: statement&.reconciliation_status || 'no_statement'
      }
    end
  end
  
  private
  
  def set_insurance_statement
    @insurance_statement = InsuranceStatement.find(params[:id])
  end
  
  def insurance_statement_params
    params.require(:insurance_statement).permit(
      :statement_type, :year, :month, :statement_amount,
      :reconciliation_status, :statement_file_path, :resolution_notes
    )
  end
  
  def calculate_statement_details
    case @insurance_statement.statement_type
    when 'labor_insurance'
      calculate_labor_insurance_details
    when 'health_insurance'
      calculate_health_insurance_details
    when 'labor_pension'
      calculate_labor_pension_details
    else
      {}
    end
  end
  
  def calculate_labor_insurance_details
    payrolls = Payroll.includes(:employee, :salary)
                     .where(year: @insurance_statement.year, month: @insurance_statement.month)
    
    {
      payrolls: payrolls,
      total_amount: payrolls.joins(:salary).sum(:labor_insurance),
      employee_count: payrolls.count
    }
  end
  
  def calculate_health_insurance_details
    payrolls = Payroll.includes(:employee, :salary)
                     .where(year: @insurance_statement.year, month: @insurance_statement.month)
    
    regular_amount = payrolls.joins(:salary).sum(:health_insurance)
    supplement_amount = payrolls.sum { |p| HealthInsuranceService::Dispatcher.call(p) }
    company_amount = HealthInsuranceService::CompanyCoverage.call(@insurance_statement.year, @insurance_statement.month)
    
    {
      payrolls: payrolls,
      regular_amount: regular_amount,
      supplement_amount: supplement_amount,
      company_amount: company_amount,
      total_amount: regular_amount + supplement_amount + company_amount,
      employee_count: payrolls.count
    }
  end
  
  def calculate_labor_pension_details
    payrolls = Payroll.includes(:employee, :salary)
                     .where(year: @insurance_statement.year, month: @insurance_statement.month)
    
    total_amount = payrolls.sum do |payroll|
      (payroll.salary.insured_for_labor * 0.06).round
    end
    
    {
      payrolls: payrolls,
      total_amount: total_amount,
      employee_count: payrolls.count,
      contribution_rate: 0.06
    }
  end
  
  def calculate_amount_by_type(type, year, month)
    case type
    when 'labor_insurance'
      Payroll.where(year: year, month: month).joins(:salary).sum(:labor_insurance)
    when 'health_insurance'
      payrolls = Payroll.where(year: year, month: month)
      regular = payrolls.joins(:salary).sum(:health_insurance)
      supplement = payrolls.sum { |p| HealthInsuranceService::Dispatcher.call(p) }
      company = HealthInsuranceService::CompanyCoverage.call(year, month)
      regular + supplement + company
    when 'labor_pension'
      Payroll.where(year: year, month: month).sum do |payroll|
        (payroll.salary.insured_for_labor * 0.06).round
      end
    else
      0
    end
  end
  
  def generate_csv(statements)
    CSV.generate(headers: true) do |csv|
      csv << ['保險類型', '年度', '月份', '對帳單金額', '系統計算金額', '差異金額', '對帳狀態', '上傳時間']
      
      statements.each do |statement|
        csv << [
          statement.statement_type_name,
          statement.year,
          statement.month,
          statement.statement_amount,
          statement.calculated_amount,
          statement.difference_amount,
          statement.reconciliation_status_name,
          statement.uploaded_at&.strftime('%Y-%m-%d %H:%M:%S')
        ]
      end
    end
  end
end
