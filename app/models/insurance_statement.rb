# frozen_string_literal: true

class InsuranceStatement < ApplicationRecord
  # 保險對帳單類型
  STATEMENT_TYPES = {
    'labor_insurance' => '勞保',
    'health_insurance' => '健保',
    'labor_pension' => '勞退'
  }.freeze
  
  # 對帳狀態
  RECONCILIATION_STATUS = {
    'pending' => '待對帳',
    'matched' => '已對帳',
    'discrepancy' => '有差異',
    'resolved' => '已解決'
  }.freeze
  
  validates :statement_type, presence: true, inclusion: { in: STATEMENT_TYPES.keys }
  validates :year, presence: true
  validates :month, presence: true
  validates :statement_amount, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :reconciliation_status, presence: true, inclusion: { in: RECONCILIATION_STATUS.keys }

  # 允許Ransack搜尋的屬性
  def self.ransackable_attributes(auth_object = nil)
    %w[statement_type year month statement_amount calculated_amount reconciliation_status
       uploaded_at resolved_at created_at updated_at]
  end

  def self.ransackable_associations(auth_object = nil)
    []
  end

  scope :by_type, ->(type) { where(statement_type: type) if type.present? }
  scope :by_year, ->(year) { where(year: year) if year.present? }
  scope :by_month, ->(month) { where(month: month) if month.present? }
  scope :by_status, ->(status) { where(reconciliation_status: status) if status.present? }
  scope :pending, -> { where(reconciliation_status: 'pending') }
  scope :with_discrepancy, -> { where(reconciliation_status: 'discrepancy') }
  
  # 計算系統金額（根據薪資計算）
  def calculated_amount
    case statement_type
    when 'labor_insurance'
      calculate_labor_insurance_amount
    when 'health_insurance'
      calculate_health_insurance_amount
    when 'labor_pension'
      calculate_labor_pension_amount
    else
      0
    end
  end
  
  # 計算差異金額
  def difference_amount
    statement_amount - calculated_amount
  end
  
  # 是否有差異
  def has_discrepancy?
    difference_amount.abs > 0.01 # 允許1分錢的誤差
  end
  
  # 取得對帳狀態中文名稱
  def reconciliation_status_name
    RECONCILIATION_STATUS[reconciliation_status]
  end
  
  # 取得保險類型中文名稱
  def statement_type_name
    STATEMENT_TYPES[statement_type]
  end
  
  # 自動對帳
  def auto_reconcile!
    if has_discrepancy?
      update!(reconciliation_status: 'discrepancy')
    else
      update!(reconciliation_status: 'matched')
    end
  end
  
  # 標記為已解決
  def mark_as_resolved!(notes = nil)
    update!(
      reconciliation_status: 'resolved',
      resolution_notes: notes,
      resolved_at: Time.current
    )
  end
  
  private
  
  # 計算勞保金額
  def calculate_labor_insurance_amount
    payrolls = Payroll.where(year: year, month: month)
    payrolls.joins(:salary).sum(:labor_insurance)
  end
  
  # 計算健保金額
  def calculate_health_insurance_amount
    payrolls = Payroll.where(year: year, month: month)
    regular_health_insurance = payrolls.joins(:salary).sum(:health_insurance)
    
    # 加上二代健保
    supplement_health_insurance = payrolls.sum do |payroll|
      HealthInsuranceService::Dispatcher.call(payroll)
    end
    
    # 加上公司負擔的二代健保
    company_coverage = HealthInsuranceService::CompanyCoverage.call(year, month)
    
    regular_health_insurance + supplement_health_insurance + company_coverage
  end
  
  # 計算勞退金額
  def calculate_labor_pension_amount
    payrolls = Payroll.where(year: year, month: month)
    payrolls.joins(:salary).sum do |payroll|
      # 勞退提繳率通常是6%
      (payroll.salary.insured_for_labor * 0.06).round
    end
  end
end
