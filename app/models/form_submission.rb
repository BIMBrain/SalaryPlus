# frozen_string_literal: true

class FormSubmission < ApplicationRecord
  belongs_to :form_template
  belongs_to :employee
  has_many :approval_records, dependent: :destroy
  has_many :form_comments, dependent: :destroy
  
  # 提交狀態
  STATUS_OPTIONS = {
    'draft' => '草稿',
    'pending' => '待審核',
    'in_review' => '審核中',
    'approved' => '已核准',
    'rejected' => '已駁回',
    'cancelled' => '已取消'
  }.freeze
  
  validates :status, presence: true, inclusion: { in: STATUS_OPTIONS.keys }
  validates :submitted_at, presence: true
  
  scope :by_status, ->(status) { where(status: status) if status.present? }
  scope :by_employee, ->(employee_id) { where(employee_id: employee_id) if employee_id.present? }
  scope :recent, -> { order(submitted_at: :desc) }
  scope :pending_approval, -> { where(status: ['pending', 'in_review']) }
  
  # 允許Ransack搜尋的屬性
  def self.ransackable_attributes(auth_object = nil)
    %w[status submitted_at approved_at rejected_at created_at updated_at]
  end
  
  def self.ransackable_associations(auth_object = nil)
    %w[form_template employee approval_records form_comments]
  end
  
  # 取得狀態中文名稱
  def status_name
    STATUS_OPTIONS[status]
  end
  
  # 檢查是否可以編輯
  def editable?
    %w[draft].include?(status)
  end
  
  # 檢查是否可以取消
  def cancellable?
    %w[pending in_review].include?(status)
  end
  
  # 檢查是否已完成
  def completed?
    %w[approved rejected cancelled].include?(status)
  end
  
  # 取得表單資料值
  def get_field_value(field_name)
    form_data&.dig(field_name.to_s)
  end
  
  # 設定表單資料值
  def set_field_value(field_name, value)
    self.form_data ||= {}
    self.form_data[field_name.to_s] = value
  end
  
  # 驗證表單資料
  def validate_form_data
    errors = []
    
    form_template.ordered_fields.each do |field|
      value = get_field_value(field.field_name)
      field_errors = field.validate_value(value)
      errors.concat(field_errors)
    end
    
    errors
  end
  
  # 提交表單
  def submit!
    validation_errors = validate_form_data
    
    if validation_errors.any?
      self.errors.add(:base, validation_errors.join(', '))
      return false
    end
    
    update!(
      status: 'pending',
      submitted_at: Time.current
    )
    
    # 啟動審核流程
    workflow = form_template.default_workflow
    start_approval_process(workflow) if workflow
    
    true
  end
  
  # 啟動審核流程
  def start_approval_process(workflow)
    return unless workflow
    
    update!(status: 'in_review')
    
    # 建立第一個審核步驟的記錄
    first_step = workflow.approval_steps.order(:step_order).first
    if first_step
      approval_records.create!(
        approval_step: first_step,
        approver_id: first_step.approver_id,
        status: 'pending',
        assigned_at: Time.current
      )
    end
  end
  
  # 核准
  def approve!(approver, comments = nil)
    current_record = current_approval_record
    return false unless current_record
    
    current_record.update!(
      status: 'approved',
      approved_at: Time.current,
      comments: comments
    )
    
    # 檢查是否還有下一個審核步驟
    next_step = next_approval_step
    if next_step
      # 建立下一個審核記錄
      approval_records.create!(
        approval_step: next_step,
        approver_id: next_step.approver_id,
        status: 'pending',
        assigned_at: Time.current
      )
    else
      # 所有步驟都完成，最終核准
      update!(
        status: 'approved',
        approved_at: Time.current
      )
    end
    
    true
  end
  
  # 駁回
  def reject!(approver, comments)
    current_record = current_approval_record
    return false unless current_record
    
    current_record.update!(
      status: 'rejected',
      rejected_at: Time.current,
      comments: comments
    )
    
    update!(
      status: 'rejected',
      rejected_at: Time.current
    )
    
    true
  end
  
  # 取消
  def cancel!(reason = nil)
    return false unless cancellable?
    
    update!(
      status: 'cancelled',
      cancelled_at: Time.current,
      cancellation_reason: reason
    )
    
    # 取消所有待審核記錄
    approval_records.where(status: 'pending').update_all(
      status: 'cancelled',
      cancelled_at: Time.current
    )
    
    true
  end
  
  # 取得目前審核記錄
  def current_approval_record
    approval_records.where(status: 'pending').first
  end
  
  # 取得下一個審核步驟
  def next_approval_step
    current_step = current_approval_record&.approval_step
    return nil unless current_step
    
    workflow = current_step.approval_workflow
    workflow.approval_steps
            .where('step_order > ?', current_step.step_order)
            .order(:step_order)
            .first
  end
  
  # 取得審核歷程
  def approval_history
    approval_records.includes(:approval_step, :approver).order(:created_at)
  end
  
  # 新增評論
  def add_comment(user, content)
    form_comments.create!(
      user: user,
      content: content,
      created_at: Time.current
    )
  end
  
  # 產生表單摘要
  def summary
    summary_fields = form_template.form_fields.where(show_in_summary: true).order(:sort_order)
    
    summary_data = {}
    summary_fields.each do |field|
      value = get_field_value(field.field_name)
      summary_data[field.field_label] = field.format_value(value)
    end
    
    summary_data
  end
end
