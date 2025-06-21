# frozen_string_literal: true

class BankTransfersController < ApplicationController
  before_action :set_bank_transfer, only: [:show, :edit, :update, :destroy, :cancel, :process, :complete]
  
  def index
    @query = BankTransfer.ransack(params[:q])
    @bank_transfers = @query.result
                           .includes(:employee, :payroll)
                           .recent
                           .page(params[:page])
                           .per(20)
    
    # 統計數據
    @total_transfers = BankTransfer.count
    @pending_transfers = BankTransfer.pending.count
    @completed_transfers = BankTransfer.completed.count
    @total_amount = BankTransfer.pending.sum(:transfer_amount)
  end
  
  def show
  end
  
  def new
    @bank_transfer = BankTransfer.new
    @employees = Employee.active.order(:employee_number)
  end
  
  def create
    @bank_transfer = BankTransfer.new(bank_transfer_params)
    
    if @bank_transfer.save
      redirect_to bank_transfers_path, notice: '轉帳記錄已成功建立'
    else
      @employees = Employee.active.order(:employee_number)
      render :new
    end
  end
  
  def edit
    @employees = Employee.active.order(:employee_number)
  end
  
  def update
    if @bank_transfer.update(bank_transfer_params)
      redirect_to @bank_transfer, notice: '轉帳記錄已成功更新'
    else
      @employees = Employee.active.order(:employee_number)
      render :edit
    end
  end
  
  def destroy
    @bank_transfer.destroy
    redirect_to bank_transfers_path, notice: '轉帳記錄已刪除'
  end
  
  # 批量建立薪資轉帳
  def batch_create_salary_transfers
    year = params[:year]&.to_i || Date.current.year
    month = params[:month]&.to_i || Date.current.month
    transfer_date = params[:transfer_date]&.to_date || Date.current
    force_recreate = params[:force_recreate] == '1'
    
    result = BankTransfer.create_salary_transfers(
      year, 
      month, 
      transfer_date: transfer_date,
      force_recreate: force_recreate
    )
    
    if result[:success]
      redirect_to bank_transfers_path, notice: "成功建立 #{result[:created_count]} 筆薪資轉帳記錄"
    else
      redirect_to bank_transfers_path, alert: "建立轉帳記錄時發生錯誤：#{result[:errors].join(', ')}"
    end
  end
  
  # 產生轉帳檔案
  def generate_transfer_file
    transfer_ids = params[:transfer_ids]
    bank_format = params[:bank_format] || 'standard'
    
    if transfer_ids.blank?
      redirect_to bank_transfers_path, alert: '請選擇要產生轉帳檔案的記錄'
      return
    end
    
    transfers = BankTransfer.where(id: transfer_ids).pending
    
    if transfers.empty?
      redirect_to bank_transfers_path, alert: '沒有可產生轉帳檔案的記錄'
      return
    end
    
    # 產生檔案內容
    file_content = BankTransfer.generate_transfer_file(transfers, bank_format)
    
    # 標記為處理中
    transfers.each(&:mark_as_processing!)
    
    # 產生檔案名稱
    filename = "transfer_#{Date.current.strftime('%Y%m%d_%H%M%S')}.txt"
    
    respond_to do |format|
      format.txt do
        send_data file_content, 
                  filename: filename,
                  type: 'text/plain',
                  disposition: 'attachment'
      end
    end
  end
  
  # 匯入轉帳結果
  def import_transfer_results
    if params[:file].present?
      result = ImportTransferResultsService.call(params[:file])
      
      if result[:success]
        redirect_to bank_transfers_path, notice: "成功匯入 #{result[:updated_count]} 筆轉帳結果"
      else
        redirect_to bank_transfers_path, alert: "匯入失敗：#{result[:error]}"
      end
    else
      redirect_to bank_transfers_path, alert: '請選擇要匯入的檔案'
    end
  end
  
  # 轉帳狀態管理
  def process
    @bank_transfer.mark_as_processing!
    redirect_to @bank_transfer, notice: '轉帳狀態已更新為處理中'
  end
  
  def complete
    @bank_transfer.mark_as_completed!
    redirect_to @bank_transfer, notice: '轉帳已標記為完成'
  end
  
  def cancel
    reason = params[:reason]
    
    if @bank_transfer.cancel!(reason)
      redirect_to @bank_transfer, notice: '轉帳已取消'
    else
      redirect_to @bank_transfer, alert: '無法取消此轉帳'
    end
  end
  
  # 批量操作
  def batch_process
    transfer_ids = params[:transfer_ids]
    action = params[:batch_action]
    
    if transfer_ids.blank?
      redirect_to bank_transfers_path, alert: '請選擇要操作的轉帳記錄'
      return
    end
    
    transfers = BankTransfer.where(id: transfer_ids)
    processed_count = 0
    
    case action
    when 'process'
      transfers.pending.each do |transfer|
        transfer.mark_as_processing!
        processed_count += 1
      end
      redirect_to bank_transfers_path, notice: "已將 #{processed_count} 筆轉帳標記為處理中"
      
    when 'complete'
      transfers.where(status: 'processing').each do |transfer|
        transfer.mark_as_completed!
        processed_count += 1
      end
      redirect_to bank_transfers_path, notice: "已將 #{processed_count} 筆轉帳標記為完成"
      
    when 'cancel'
      reason = params[:cancel_reason]
      transfers.where(status: ['pending', 'processing']).each do |transfer|
        if transfer.cancel!(reason)
          processed_count += 1
        end
      end
      redirect_to bank_transfers_path, notice: "已取消 #{processed_count} 筆轉帳"
      
    else
      redirect_to bank_transfers_path, alert: '無效的批量操作'
    end
  end
  
  # 轉帳統計
  def statistics
    @year = params[:year]&.to_i || Date.current.year
    @month = params[:month]&.to_i || Date.current.month
    
    @monthly_stats = calculate_monthly_statistics(@year, @month)
    @bank_stats = calculate_bank_statistics(@year, @month)
    @status_stats = calculate_status_statistics(@year, @month)
    @annual_trend = calculate_annual_trend(@year)
  end
  
  # 轉帳明細報表
  def transfer_report
    @year = params[:year]&.to_i || Date.current.year
    @month = params[:month]&.to_i || Date.current.month
    @status = params[:status]
    
    @transfers = BankTransfer.includes(:employee, :payroll)
                            .joins(:payroll)
                            .where(payrolls: { year: @year, month: @month })
    
    @transfers = @transfers.where(status: @status) if @status.present?
    @transfers = @transfers.order(:created_at)
    
    @summary = {
      total_count: @transfers.count,
      total_amount: @transfers.sum(:transfer_amount),
      by_status: @transfers.group(:status).count,
      by_bank: @transfers.joins(:employee).group('employees.bank_code').count
    }
    
    respond_to do |format|
      format.html
      format.csv do
        send_data generate_transfer_report_csv(@transfers),
                  filename: "transfer_report_#{@year}_#{@month}.csv"
      end
      format.xlsx do
        send_data generate_transfer_report_xlsx(@transfers),
                  filename: "transfer_report_#{@year}_#{@month}.xlsx"
      end
    end
  end
  
  private
  
  def set_bank_transfer
    @bank_transfer = BankTransfer.find(params[:id])
  end
  
  def bank_transfer_params
    params.require(:bank_transfer).permit(
      :employee_id, :payroll_id, :transfer_type, :transfer_amount,
      :account_number, :account_name, :bank_code, :transfer_date,
      :memo, :status
    )
  end
  
  def calculate_monthly_statistics(year, month)
    transfers = BankTransfer.joins(:payroll)
                           .where(payrolls: { year: year, month: month })
    
    {
      total_count: transfers.count,
      total_amount: transfers.sum(:transfer_amount),
      pending_count: transfers.pending.count,
      pending_amount: transfers.pending.sum(:transfer_amount),
      completed_count: transfers.completed.count,
      completed_amount: transfers.completed.sum(:transfer_amount)
    }
  end
  
  def calculate_bank_statistics(year, month)
    BankTransfer.joins(:payroll, :employee)
               .where(payrolls: { year: year, month: month })
               .group('employees.bank_code')
               .group(:status)
               .count
  end
  
  def calculate_status_statistics(year, month)
    BankTransfer.joins(:payroll)
               .where(payrolls: { year: year, month: month })
               .group(:status)
               .sum(:transfer_amount)
  end
  
  def calculate_annual_trend(year)
    (1..12).map do |month|
      monthly_data = calculate_monthly_statistics(year, month)
      {
        month: month,
        total_amount: monthly_data[:total_amount],
        total_count: monthly_data[:total_count]
      }
    end
  end
  
  def generate_transfer_report_csv(transfers)
    require 'csv'
    
    CSV.generate(headers: true) do |csv|
      csv << ['員工姓名', '員工編號', '銀行代碼', '銀行名稱', '帳號', '戶名', '轉帳金額', '轉帳日期', '狀態', '備註']
      
      transfers.each do |transfer|
        csv << [
          transfer.employee.display_name,
          transfer.employee.employee_number,
          transfer.bank_code,
          transfer.bank_name,
          transfer.account_number,
          transfer.account_name,
          transfer.transfer_amount,
          transfer.transfer_date,
          transfer.status_name,
          transfer.memo
        ]
      end
    end
  end
end
