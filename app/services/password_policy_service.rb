# frozen_string_literal: true

class PasswordPolicyService
  include Callable
  
  # 密碼政策設定
  POLICY_CONFIG = {
    min_length: 8,
    max_length: 128,
    require_uppercase: true,
    require_lowercase: true,
    require_numbers: true,
    require_special_chars: true,
    min_special_chars: 1,
    max_consecutive_chars: 2,
    password_history_count: 5,
    password_expiry_days: 90,
    account_lockout_attempts: 5,
    account_lockout_duration: 30 # minutes
  }.freeze
  
  # 特殊字符
  SPECIAL_CHARS = '!@#$%^&*()_+-=[]{}|;:,.<>?'.freeze
  
  # 常見弱密碼
  WEAK_PASSWORDS = %w[
    password 123456 123456789 qwerty abc123 password123
    admin root user guest test demo welcome
    12345678 1234567890 qwertyuiop asdfghjkl
  ].freeze
  
  attr_reader :password, :user_context
  
  def initialize(password, user_context = {})
    @password = password
    @user_context = user_context
  end
  
  def call
    validation_result = validate_password
    
    {
      valid: validation_result[:valid],
      errors: validation_result[:errors],
      warnings: validation_result[:warnings],
      strength_score: calculate_strength_score,
      strength_level: determine_strength_level,
      suggestions: generate_suggestions
    }
  end
  
  # 驗證密碼是否符合政策
  def self.validate_password_policy(password, user_context = {})
    new(password, user_context).call
  end
  
  # 產生安全密碼
  def self.generate_secure_password(length = 12)
    uppercase = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ'
    lowercase = 'abcdefghijklmnopqrstuvwxyz'
    numbers = '0123456789'
    special = SPECIAL_CHARS
    
    # 確保包含各種字符類型
    password = ''
    password += uppercase.sample
    password += lowercase.sample
    password += numbers.sample
    password += special.sample
    
    # 填充剩餘長度
    all_chars = uppercase + lowercase + numbers + special
    (length - 4).times do
      password += all_chars.sample
    end
    
    # 打亂順序
    password.chars.shuffle.join
  end
  
  # 檢查密碼是否過期
  def self.password_expired?(last_changed_at)
    return true if last_changed_at.blank?
    
    expiry_date = last_changed_at + POLICY_CONFIG[:password_expiry_days].days
    expiry_date < Time.current
  end
  
  # 檢查帳號是否被鎖定
  def self.account_locked?(failed_attempts, last_failed_at)
    return false if failed_attempts < POLICY_CONFIG[:account_lockout_attempts]
    return false if last_failed_at.blank?
    
    lockout_until = last_failed_at + POLICY_CONFIG[:account_lockout_duration].minutes
    lockout_until > Time.current
  end
  
  # 計算密碼強度分數
  def self.calculate_password_strength(password)
    new(password).calculate_strength_score
  end
  
  # 雜湊密碼
  def self.hash_password(password, salt = nil)
    salt ||= BCrypt::Engine.generate_salt
    BCrypt::Engine.hash_secret(password, salt)
  end
  
  # 驗證密碼
  def self.verify_password(password, hashed_password)
    BCrypt::Password.new(hashed_password) == password
  rescue BCrypt::Errors::InvalidHash
    false
  end
  
  private
  
  def validate_password
    errors = []
    warnings = []
    
    # 檢查長度
    if password.length < POLICY_CONFIG[:min_length]
      errors << "密碼長度至少需要 #{POLICY_CONFIG[:min_length]} 個字符"
    elsif password.length > POLICY_CONFIG[:max_length]
      errors << "密碼長度不能超過 #{POLICY_CONFIG[:max_length]} 個字符"
    end
    
    # 檢查字符類型
    if POLICY_CONFIG[:require_uppercase] && !password.match?(/[A-Z]/)
      errors << '密碼必須包含至少一個大寫字母'
    end
    
    if POLICY_CONFIG[:require_lowercase] && !password.match?(/[a-z]/)
      errors << '密碼必須包含至少一個小寫字母'
    end
    
    if POLICY_CONFIG[:require_numbers] && !password.match?(/\d/)
      errors << '密碼必須包含至少一個數字'
    end
    
    if POLICY_CONFIG[:require_special_chars]
      special_char_count = password.count(SPECIAL_CHARS)
      if special_char_count < POLICY_CONFIG[:min_special_chars]
        errors << "密碼必須包含至少 #{POLICY_CONFIG[:min_special_chars]} 個特殊字符"
      end
    end
    
    # 檢查連續字符
    if has_consecutive_chars?
      errors << "密碼不能包含超過 #{POLICY_CONFIG[:max_consecutive_chars]} 個連續相同字符"
    end
    
    # 檢查常見弱密碼
    if WEAK_PASSWORDS.include?(password.downcase)
      errors << '密碼過於簡單，請使用更複雜的密碼'
    end
    
    # 檢查是否包含用戶資訊
    if contains_user_info?
      warnings << '密碼不應包含個人資訊'
    end
    
    # 檢查鍵盤模式
    if has_keyboard_pattern?
      warnings << '避免使用鍵盤上的連續字符'
    end
    
    {
      valid: errors.empty?,
      errors: errors,
      warnings: warnings
    }
  end
  
  def calculate_strength_score
    score = 0
    
    # 長度分數 (0-25分)
    length_score = [password.length * 2, 25].min
    score += length_score
    
    # 字符多樣性分數 (0-25分)
    diversity_score = 0
    diversity_score += 5 if password.match?(/[a-z]/)
    diversity_score += 5 if password.match?(/[A-Z]/)
    diversity_score += 5 if password.match?(/\d/)
    diversity_score += 5 if password.match?(/[#{Regexp.escape(SPECIAL_CHARS)}]/)
    diversity_score += 5 if password.length > 12
    score += diversity_score
    
    # 複雜度分數 (0-25分)
    complexity_score = 0
    complexity_score += 5 if password.match?(/[a-z].*[A-Z]|[A-Z].*[a-z]/) # 大小寫混合
    complexity_score += 5 if password.match?(/\d.*[a-zA-Z]|[a-zA-Z].*\d/) # 字母數字混合
    complexity_score += 5 if password.count(SPECIAL_CHARS) >= 2 # 多個特殊字符
    complexity_score += 5 if !has_keyboard_pattern? # 無鍵盤模式
    complexity_score += 5 if !has_consecutive_chars? # 無連續字符
    score += complexity_score
    
    # 獨特性分數 (0-25分)
    uniqueness_score = 25
    uniqueness_score -= 10 if WEAK_PASSWORDS.include?(password.downcase)
    uniqueness_score -= 5 if contains_user_info?
    uniqueness_score -= 5 if has_common_substitutions?
    score += [uniqueness_score, 0].max
    
    [score, 100].min
  end
  
  def determine_strength_level
    score = calculate_strength_score
    
    case score
    when 0...30
      'very_weak'
    when 30...50
      'weak'
    when 50...70
      'fair'
    when 70...85
      'good'
    when 85..100
      'strong'
    else
      'unknown'
    end
  end
  
  def generate_suggestions
    suggestions = []
    
    if password.length < 12
      suggestions << '使用更長的密碼（建議12個字符以上）'
    end
    
    unless password.match?(/[A-Z]/)
      suggestions << '加入大寫字母'
    end
    
    unless password.match?(/[a-z]/)
      suggestions << '加入小寫字母'
    end
    
    unless password.match?(/\d/)
      suggestions << '加入數字'
    end
    
    if password.count(SPECIAL_CHARS) < 2
      suggestions << '加入更多特殊字符'
    end
    
    if has_keyboard_pattern?
      suggestions << '避免使用鍵盤上的連續字符'
    end
    
    if has_consecutive_chars?
      suggestions << '避免重複相同字符'
    end
    
    if contains_user_info?
      suggestions << '不要在密碼中包含個人資訊'
    end
    
    suggestions
  end
  
  def has_consecutive_chars?
    max_consecutive = POLICY_CONFIG[:max_consecutive_chars]
    
    (0..password.length - max_consecutive - 1).each do |i|
      substring = password[i, max_consecutive + 1]
      return true if substring.chars.uniq.length == 1
    end
    
    false
  end
  
  def contains_user_info?
    return false if user_context.blank?
    
    user_info = [
      user_context[:name],
      user_context[:email],
      user_context[:employee_number],
      user_context[:phone]
    ].compact.map(&:to_s).map(&:downcase)
    
    password_lower = password.downcase
    
    user_info.any? do |info|
      next if info.length < 3
      password_lower.include?(info) || info.include?(password_lower)
    end
  end
  
  def has_keyboard_pattern?
    keyboard_patterns = [
      'qwerty', 'asdf', 'zxcv', '1234', '4567', '7890',
      'qwertyuiop', 'asdfghjkl', 'zxcvbnm',
      '1234567890', '0987654321'
    ]
    
    password_lower = password.downcase
    
    keyboard_patterns.any? do |pattern|
      password_lower.include?(pattern) || password_lower.include?(pattern.reverse)
    end
  end
  
  def has_common_substitutions?
    # 檢查常見的字符替換（如 @ 代替 a，3 代替 e）
    substitutions = {
      '@' => 'a', '3' => 'e', '1' => 'i', '0' => 'o',
      '5' => 's', '7' => 't', '4' => 'a', '8' => 'b'
    }
    
    normalized_password = password.downcase
    substitutions.each do |sub, original|
      normalized_password = normalized_password.gsub(sub, original)
    end
    
    WEAK_PASSWORDS.include?(normalized_password)
  end
end
