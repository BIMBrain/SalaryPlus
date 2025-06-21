# frozen_string_literal: true

class SecurityAuditLog < ApplicationRecord
  # 操作類型
  ACTION_TYPES = {
    'login' => '登入',
    'logout' => '登出',
    'view_employee_data' => '查看員工資料',
    'edit_employee_data' => '編輯員工資料',
    'view_salary_data' => '查看薪資資料',
    'edit_salary_data' => '編輯薪資資料',
    'generate_payroll' => '產生薪資單',
    'export_data' => '匯出資料',
    'import_data' => '匯入資料',
    'delete_data' => '刪除資料',
    'password_change' => '變更密碼',
    'failed_login' => '登入失敗',
    'unauthorized_access' => '未授權存取'
  }.freeze
  
  # 風險等級
  RISK_LEVELS = {
    'low' => '低風險',
    'medium' => '中風險',
    'high' => '高風險',
    'critical' => '嚴重風險'
  }.freeze
  
  validates :action_type, presence: true, inclusion: { in: ACTION_TYPES.keys }
  validates :risk_level, presence: true, inclusion: { in: RISK_LEVELS.keys }
  validates :ip_address, presence: true
  validates :user_agent, presence: true
  validates :performed_at, presence: true
  
  scope :by_action, ->(action) { where(action_type: action) if action.present? }
  scope :by_risk_level, ->(level) { where(risk_level: level) if level.present? }
  scope :high_risk, -> { where(risk_level: ['high', 'critical']) }
  scope :recent, -> { order(performed_at: :desc) }
  scope :by_date_range, ->(start_date, end_date) { where(performed_at: start_date..end_date) }
  
  # 允許Ransack搜尋的屬性
  def self.ransackable_attributes(auth_object = nil)
    %w[action_type risk_level ip_address user_agent performed_at user_id target_id]
  end
  
  def self.ransackable_associations(auth_object = nil)
    []
  end
  
  # 取得操作類型中文名稱
  def action_type_name
    ACTION_TYPES[action_type]
  end
  
  # 取得風險等級中文名稱
  def risk_level_name
    RISK_LEVELS[risk_level]
  end
  
  # 記錄安全事件
  def self.log_security_event(action_type, options = {})
    create!(
      action_type: action_type,
      risk_level: determine_risk_level(action_type),
      user_id: options[:user_id],
      target_id: options[:target_id],
      target_type: options[:target_type],
      ip_address: options[:ip_address],
      user_agent: options[:user_agent],
      details: options[:details],
      performed_at: Time.current
    )
  end
  
  # 檢測異常活動
  def self.detect_suspicious_activities
    suspicious_activities = []
    
    # 檢測短時間內多次登入失敗
    failed_logins = where(action_type: 'failed_login')
                   .where(performed_at: 1.hour.ago..Time.current)
                   .group(:ip_address)
                   .having('COUNT(*) >= ?', 5)
                   .count
    
    failed_logins.each do |ip, count|
      suspicious_activities << {
        type: 'multiple_failed_logins',
        severity: 'high',
        description: "IP #{ip} 在1小時內登入失敗 #{count} 次",
        ip_address: ip,
        count: count
      }
    end
    
    # 檢測異常時間存取
    unusual_hours = where(performed_at: 1.day.ago..Time.current)
                   .where('EXTRACT(hour FROM performed_at) < ? OR EXTRACT(hour FROM performed_at) > ?', 6, 22)
                   .where(action_type: ['view_employee_data', 'view_salary_data', 'export_data'])
    
    if unusual_hours.any?
      suspicious_activities << {
        type: 'unusual_hours_access',
        severity: 'medium',
        description: "檢測到 #{unusual_hours.count} 次非正常時間的敏感資料存取",
        count: unusual_hours.count
      }
    end
    
    # 檢測大量資料匯出
    bulk_exports = where(action_type: 'export_data')
                  .where(performed_at: 1.day.ago..Time.current)
                  .group(:user_id)
                  .having('COUNT(*) >= ?', 10)
                  .count
    
    bulk_exports.each do |user_id, count|
      suspicious_activities << {
        type: 'bulk_data_export',
        severity: 'critical',
        description: "用戶 #{user_id} 在24小時內匯出資料 #{count} 次",
        user_id: user_id,
        count: count
      }
    end
    
    suspicious_activities
  end
  
  # 產生安全報告
  def self.generate_security_report(start_date, end_date)
    logs = where(performed_at: start_date..end_date)
    
    {
      period: "#{start_date.strftime('%Y-%m-%d')} ~ #{end_date.strftime('%Y-%m-%d')}",
      total_activities: logs.count,
      by_action_type: logs.group(:action_type).count,
      by_risk_level: logs.group(:risk_level).count,
      high_risk_activities: logs.high_risk.count,
      unique_users: logs.distinct.count(:user_id),
      unique_ips: logs.distinct.count(:ip_address),
      suspicious_activities: detect_suspicious_activities,
      top_activities: logs.group(:action_type).order('count_all DESC').limit(10).count,
      hourly_distribution: logs.group('EXTRACT(hour FROM performed_at)').count
    }
  end
  
  # 清理舊記錄
  def self.cleanup_old_logs(days_to_keep = 365)
    cutoff_date = days_to_keep.days.ago
    deleted_count = where('performed_at < ?', cutoff_date).delete_all
    
    {
      deleted_count: deleted_count,
      cutoff_date: cutoff_date
    }
  end
  
  private
  
  def self.determine_risk_level(action_type)
    case action_type
    when 'login', 'logout', 'view_employee_data'
      'low'
    when 'edit_employee_data', 'view_salary_data', 'generate_payroll'
      'medium'
    when 'edit_salary_data', 'export_data', 'import_data'
      'high'
    when 'delete_data', 'failed_login', 'unauthorized_access'
      'critical'
    else
      'medium'
    end
  end
end
