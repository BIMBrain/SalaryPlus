# frozen_string_literal: true

class BankTransfer < ApplicationRecord
  belongs_to :payroll
  belongs_to :employee
  
  # 轉帳狀態
  STATUS_OPTIONS = {
    'pending' => '待轉帳',
    'processing' => '處理中',
    'completed' => '已完成',
    'failed' => '轉帳失敗',
    'cancelled' => '已取消'
  }.freeze
  
  # 轉帳類型
  TRANSFER_TYPES = {
    'salary' => '薪資轉帳',
    'bonus' => '獎金轉帳',
    'reimbursement' => '費用報銷',
    'other' => '其他轉帳'
  }.freeze
  
  validates :transfer_amount, presence: true, numericality: { greater_than: 0 }
  validates :account_number, presence: true
  validates :account_name, presence: true
  validates :bank_code, presence: true
  validates :status, presence: true, inclusion: { in: STATUS_OPTIONS.keys }
  validates :transfer_type, presence: true, inclusion: { in: TRANSFER_TYPES.keys }
  
  scope :pending, -> { where(status: 'pending') }
  scope :completed, -> { where(status: 'completed') }
  scope :by_status, ->(status) { where(status: status) if status.present? }
  scope :by_transfer_date, ->(date) { where(transfer_date: date) if date.present? }
  scope :recent, -> { order(created_at: :desc) }
  
  # 允許Ransack搜尋的屬性
  def self.ransackable_attributes(auth_object = nil)
    %w[transfer_amount account_number account_name bank_code status transfer_type 
       transfer_date processed_at created_at updated_at]
  end
  
  def self.ransackable_associations(auth_object = nil)
    %w[payroll employee]
  end
  
  # 取得狀態中文名稱
  def status_name
    STATUS_OPTIONS[status]
  end
  
  # 取得轉帳類型中文名稱
  def transfer_type_name
    TRANSFER_TYPES[transfer_type]
  end
  
  # 檢查是否可以取消
  def cancellable?
    %w[pending processing].include?(status)
  end
  
  # 檢查是否已完成
  def completed?
    status == 'completed'
  end
  
  # 取得銀行名稱
  def bank_name
    BANK_CODES[bank_code] || bank_code
  end
  
  # 標記為處理中
  def mark_as_processing!
    update!(
      status: 'processing',
      processed_at: Time.current
    )
  end
  
  # 標記為完成
  def mark_as_completed!
    update!(
      status: 'completed',
      completed_at: Time.current
    )
  end
  
  # 標記為失敗
  def mark_as_failed!(error_message = nil)
    update!(
      status: 'failed',
      error_message: error_message,
      failed_at: Time.current
    )
  end
  
  # 取消轉帳
  def cancel!(reason = nil)
    return false unless cancellable?
    
    update!(
      status: 'cancelled',
      cancellation_reason: reason,
      cancelled_at: Time.current
    )
  end
  
  # 產生轉帳檔案記錄
  def generate_transfer_record
    {
      sequence_number: id.to_s.rjust(6, '0'),
      bank_code: bank_code,
      account_number: account_number,
      account_name: account_name,
      transfer_amount: transfer_amount.to_i,
      transfer_date: transfer_date&.strftime('%Y%m%d') || Date.current.strftime('%Y%m%d'),
      memo: memo || "#{payroll.year}/#{payroll.month} 薪資"
    }
  end
  
  # 批量建立薪資轉帳記錄
  def self.create_salary_transfers(year, month, options = {})
    payrolls = Payroll.where(year: year, month: month)
                     .includes(:employee, :statement)
    
    created_transfers = []
    errors = []
    
    payrolls.each do |payroll|
      next unless payroll.statement&.net_income&.positive?
      next unless payroll.employee.bank_account_number.present?
      
      # 檢查是否已有轉帳記錄
      existing_transfer = find_by(payroll: payroll)
      if existing_transfer && !options[:force_recreate]
        errors << "#{payroll.employee.display_name} 已有轉帳記錄"
        next
      end
      
      transfer_data = {
        payroll: payroll,
        employee: payroll.employee,
        transfer_type: 'salary',
        transfer_amount: payroll.statement.net_income,
        account_number: payroll.employee.bank_account_number,
        account_name: payroll.employee.bank_account_name || payroll.employee.display_name,
        bank_code: payroll.employee.bank_code || '004',
        transfer_date: options[:transfer_date] || Date.current,
        memo: "#{year}/#{month} 薪資轉帳",
        status: 'pending'
      }
      
      if existing_transfer
        existing_transfer.update!(transfer_data)
        created_transfers << existing_transfer
      else
        transfer = create!(transfer_data)
        created_transfers << transfer
      end
    end
    
    {
      success: errors.empty?,
      created_count: created_transfers.count,
      transfers: created_transfers,
      errors: errors
    }
  end
  
  # 產生銀行轉帳檔案
  def self.generate_transfer_file(transfers, bank_format = 'standard')
    case bank_format
    when 'cathay'
      generate_cathay_format(transfers)
    when 'fubon'
      generate_fubon_format(transfers)
    when 'ctbc'
      generate_ctbc_format(transfers)
    else
      generate_standard_format(transfers)
    end
  end
  
  # 標準格式轉帳檔案
  def self.generate_standard_format(transfers)
    content = []
    
    # 檔頭
    total_amount = transfers.sum(:transfer_amount)
    total_count = transfers.count
    
    header = [
      'H',                                    # 記錄類別
      Date.current.strftime('%Y%m%d'),       # 檔案日期
      total_count.to_s.rjust(6, '0'),       # 總筆數
      total_amount.to_i.to_s.rjust(12, '0'), # 總金額
      ''.ljust(50)                           # 保留欄位
    ].join('')
    
    content << header
    
    # 明細記錄
    transfers.each_with_index do |transfer, index|
      detail = [
        'D',                                           # 記錄類別
        (index + 1).to_s.rjust(6, '0'),               # 序號
        transfer.bank_code.ljust(3),                   # 銀行代碼
        transfer.account_number.ljust(16),             # 帳號
        transfer.account_name.force_encoding('UTF-8').ljust(20), # 戶名
        transfer.transfer_amount.to_i.to_s.rjust(10, '0'), # 金額
        transfer.memo.to_s.ljust(20),                  # 備註
        ''.ljust(15)                                   # 保留欄位
      ].join('')
      
      content << detail
    end
    
    # 檔尾
    footer = [
      'T',                                    # 記錄類別
      total_count.to_s.rjust(6, '0'),        # 總筆數
      total_amount.to_i.to_s.rjust(12, '0'), # 總金額
      ''.ljust(62)                           # 保留欄位
    ].join('')
    
    content << footer
    
    content.join("\r\n")
  end
  
  # 國泰銀行格式
  def self.generate_cathay_format(transfers)
    content = []
    
    transfers.each do |transfer|
      record = [
        transfer.bank_code.ljust(7),                    # 銀行代碼
        transfer.account_number.ljust(16),              # 帳號
        transfer.transfer_amount.to_i.to_s.rjust(10, '0'), # 金額
        '1',                                            # 交易代碼
        transfer.account_name.force_encoding('UTF-8').ljust(60), # 戶名
        transfer.memo.to_s.ljust(20)                    # 備註
      ].join('')
      
      content << record
    end
    
    content.join("\r\n")
  end
  
  # 富邦銀行格式
  def self.generate_fubon_format(transfers)
    content = []
    
    transfers.each_with_index do |transfer, index|
      record = [
        (index + 1).to_s.rjust(6, '0'),                # 序號
        transfer.bank_code,                             # 銀行代碼
        transfer.account_number.ljust(14),              # 帳號
        transfer.account_name.force_encoding('UTF-8').ljust(10), # 戶名
        transfer.transfer_amount.to_i.to_s.rjust(8, '0'), # 金額
        '50',                                           # 交易代碼
        transfer.transfer_date.strftime('%m%d'),        # 轉帳日期
        transfer.memo.to_s.ljust(12)                    # 備註
      ].join('')
      
      content << record
    end
    
    content.join("\r\n")
  end
  
  # 中信銀行格式
  def self.generate_ctbc_format(transfers)
    content = []
    
    # 檔頭
    header = [
      'HDR',
      Date.current.strftime('%Y%m%d%H%M%S'),
      transfers.count.to_s.rjust(8, '0'),
      transfers.sum(:transfer_amount).to_i.to_s.rjust(15, '0')
    ].join('|')
    
    content << header
    
    # 明細
    transfers.each_with_index do |transfer, index|
      detail = [
        'DTL',
        (index + 1).to_s.rjust(8, '0'),
        transfer.bank_code,
        transfer.account_number,
        transfer.account_name.force_encoding('UTF-8'),
        transfer.transfer_amount.to_i.to_s,
        transfer.memo.to_s
      ].join('|')
      
      content << detail
    end
    
    content.join("\r\n")
  end
  
  # 銀行代碼對照表
  BANK_CODES = {
    '004' => '台灣銀行',
    '005' => '土地銀行',
    '006' => '合作金庫',
    '007' => '第一銀行',
    '008' => '華南銀行',
    '009' => '彰化銀行',
    '011' => '上海銀行',
    '012' => '台北富邦',
    '013' => '國泰世華',
    '017' => '兆豐銀行',
    '021' => '花旗銀行',
    '050' => '台灣企銀',
    '052' => '渣打銀行',
    '053' => '台中銀行',
    '054' => '京城銀行',
    '081' => '匯豐銀行',
    '103' => '台新銀行',
    '108' => '陽信銀行',
    '114' => '中華開發',
    '115' => '聯邦銀行',
    '118' => '板信銀行',
    '119' => '淡水第一',
    '124' => '玉山銀行',
    '127' => '萬泰銀行',
    '147' => '三信銀行',
    '158' => '日盛銀行',
    '161' => '中華郵政',
    '700' => '中華郵政',
    '803' => '聯合信用卡',
    '806' => '元大銀行',
    '807' => '永豐銀行',
    '808' => '玉山銀行',
    '809' => '凱基銀行',
    '810' => '星展銀行',
    '812' => '台新銀行'
  }.freeze
end
