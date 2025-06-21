# frozen_string_literal: true

class FormTemplate < ApplicationRecord
  has_many :form_submissions, dependent: :destroy
  has_many :form_fields, dependent: :destroy
  has_many :approval_workflows, dependent: :destroy
  
  # 表單類型
  FORM_TYPES = {
    'leave_request' => '請假申請',
    'overtime_request' => '加班申請',
    'expense_claim' => '費用報銷',
    'equipment_request' => '設備申請',
    'training_request' => '教育訓練申請',
    'resignation' => '離職申請',
    'salary_adjustment' => '薪資調整申請',
    'general' => '一般申請'
  }.freeze
  
  # 表單狀態
  STATUS_OPTIONS = {
    'active' => '啟用',
    'inactive' => '停用',
    'draft' => '草稿'
  }.freeze
  
  validates :name, presence: true
  validates :form_type, presence: true, inclusion: { in: FORM_TYPES.keys }
  validates :status, presence: true, inclusion: { in: STATUS_OPTIONS.keys }
  
  scope :active, -> { where(status: 'active') }
  scope :by_type, ->(type) { where(form_type: type) if type.present? }
  
  # 允許Ransack搜尋的屬性
  def self.ransackable_attributes(auth_object = nil)
    %w[name form_type status description created_at updated_at]
  end
  
  def self.ransackable_associations(auth_object = nil)
    %w[form_submissions form_fields approval_workflows]
  end
  
  # 取得表單類型中文名稱
  def form_type_name
    FORM_TYPES[form_type]
  end
  
  # 取得狀態中文名稱
  def status_name
    STATUS_OPTIONS[status]
  end
  
  # 檢查是否啟用
  def active?
    status == 'active'
  end
  
  # 取得表單欄位（按順序）
  def ordered_fields
    form_fields.order(:sort_order)
  end
  
  # 取得預設審核流程
  def default_workflow
    approval_workflows.where(is_default: true).first
  end
  
  # 建立表單提交
  def create_submission(employee, form_data)
    submission = form_submissions.build(
      employee: employee,
      status: 'pending',
      submitted_at: Time.current,
      form_data: form_data
    )
    
    if submission.save
      # 啟動審核流程
      workflow = default_workflow
      if workflow
        submission.start_approval_process(workflow)
      end
    end
    
    submission
  end
  
  # 複製表單範本
  def duplicate
    new_template = self.dup
    new_template.name = "#{name} (複本)"
    new_template.status = 'draft'
    
    if new_template.save
      # 複製表單欄位
      form_fields.each do |field|
        new_field = field.dup
        new_field.form_template = new_template
        new_field.save
      end
      
      # 複製審核流程
      approval_workflows.each do |workflow|
        new_workflow = workflow.dup
        new_workflow.form_template = new_template
        new_workflow.is_default = false
        new_workflow.save
        
        # 複製審核步驟
        workflow.approval_steps.each do |step|
          new_step = step.dup
          new_step.approval_workflow = new_workflow
          new_step.save
        end
      end
    end
    
    new_template
  end
  
  # 統計資料
  def submission_stats
    {
      total: form_submissions.count,
      pending: form_submissions.where(status: 'pending').count,
      approved: form_submissions.where(status: 'approved').count,
      rejected: form_submissions.where(status: 'rejected').count,
      this_month: form_submissions.where(submitted_at: Date.current.beginning_of_month..Date.current.end_of_month).count
    }
  end
end
