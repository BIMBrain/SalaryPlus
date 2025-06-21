# frozen_string_literal: true
class Employee < ApplicationRecord
  include CollectionTranslatable

  has_many :salaries, dependent: :destroy
  accepts_nested_attributes_for :salaries, allow_destroy: true
  has_many :attendances, dependent: :destroy

  has_many :payrolls, dependent: :destroy
  has_many :statements, through: :payrolls, source: :statement
  has_many :terms, dependent: :destroy

  # 允許Ransack搜尋的屬性
  def self.ransackable_attributes(auth_object = nil)
    %w[name chinese_name english_name employee_number department position job_title
       id_number email company_email personal_email phone_number mobile_number
       hire_date resignation_date created_at updated_at]
  end

  def self.ransackable_associations(auth_object = nil)
    %w[salaries terms payrolls attendances]
  end

  BANK_TRANSFER_TYPE = { "薪資轉帳": "salary", "台幣轉帳": "normal", "ATM/臨櫃": "atm" }.freeze

  # 性別選項
  GENDER_OPTIONS = [
    ['男', 'male'],
    ['女', 'female']
  ].freeze

  # 婚姻狀況選項
  MARITAL_STATUS_OPTIONS = [
    ['未婚', 'single'],
    ['已婚', 'married'],
    ['離婚', 'divorced'],
    ['喪偶', 'widowed']
  ].freeze

  # 學歷選項
  EDUCATION_LEVEL_OPTIONS = [
    ['國小', 'elementary'],
    ['國中', 'junior_high'],
    ['高中職', 'senior_high'],
    ['專科', 'college'],
    ['大學', 'university'],
    ['碩士', 'master'],
    ['博士', 'phd']
  ].freeze

  # 聘僱類型選項
  EMPLOYMENT_TYPE_OPTIONS = [
    ['正職', 'full_time'],
    ['兼職', 'part_time'],
    ['約聘', 'contract'],
    ['實習', 'intern']
  ].freeze

  # 兵役狀況選項
  MILITARY_SERVICE_OPTIONS = [
    ['已服完畢', 'completed'],
    ['免役', 'exempt'],
    ['未服', 'not_served'],
    ['替代役', 'alternative']
  ].freeze

  # 驗證
  validates :name, presence: true
  validates :id_number, presence: true, uniqueness: true
  validates :email, presence: true, uniqueness: true, format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :birthday, presence: true

  scope :ordered, -> { order(id: :desc) }
  scope :active, -> { where('resignation_date IS NULL OR resignation_date > ?', Date.current) }
  scope :by_department, ->(dept) { where(department: dept) if dept.present? }
  scope :by_position, ->(pos) { where(position: pos) if pos.present? }

  def term(cycle_start, cycle_end)
    terms.find_by("start_date <= ? AND (end_date >= ? OR end_date IS NULL)", cycle_end, cycle_start)
  end

  def email
    return personal_email if resigned? || company_email.blank?
    company_email
  end

  def recent_term
    terms.ordered.first
  end

  # 新增的方法
  def age
    return nil unless birthday

    today = Date.current
    age = today.year - birthday.year
    age -= 1 if today < birthday + age.years
    age
  end

  def latest_salary
    salaries.order(:created_at).last&.amount || basic_salary || 0
  end

  def full_name
    chinese_name.present? ? chinese_name : name
  end

  def display_name
    if chinese_name.present? && english_name.present?
      "#{chinese_name} (#{english_name})"
    elsif chinese_name.present?
      chinese_name
    else
      name
    end
  end

  def total_salary
    (basic_salary || 0) + (allowances || 0) + (performance_bonus || 0)
  end

  def employment_duration
    return nil unless hire_date

    end_date = resignation_date || Date.current
    ((end_date - hire_date) / 365.25).round(1)
  end

  def is_active?
    resignation_date.nil? || resignation_date > Date.current
  end

  def gender_display
    case gender
    when 'male' then '男'
    when 'female' then '女'
    else gender
    end
  end

  def marital_status_display
    case marital_status
    when 'single' then '未婚'
    when 'married' then '已婚'
    when 'divorced' then '離婚'
    when 'widowed' then '喪偶'
    else marital_status
    end
  end

  def education_level_display
    case education_level
    when 'elementary' then '國小'
    when 'junior_high' then '國中'
    when 'senior_high' then '高中職'
    when 'college' then '專科'
    when 'university' then '大學'
    when 'master' then '碩士'
    when 'phd' then '博士'
    else education_level
    end
  end

  def employment_type_display
    case employment_type
    when 'full_time' then '正職'
    when 'part_time' then '兼職'
    when 'contract' then '約聘'
    when 'intern' then '實習'
    else employment_type
    end
  end

  private

  # 離職當月仍算是在職
  def resigned?
    return true if current_term.blank?
    return false unless current_term.end_date
    current_term.end_date < Date.today.beginning_of_month
  end

  def current_term
    term(Date.today.at_beginning_of_month, Date.today.at_end_of_month)
  end
end
