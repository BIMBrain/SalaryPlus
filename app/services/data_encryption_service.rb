# frozen_string_literal: true

class DataEncryptionService
  include Callable
  
  # 敏感資料欄位
  SENSITIVE_FIELDS = %w[
    id_number
    phone
    address
    bank_account_number
    bank_account_name
    salary_amount
    net_income
    tax_amount
  ].freeze
  
  attr_reader :data, :operation
  
  def initialize(data, operation = 'encrypt')
    @data = data
    @operation = operation
  end
  
  def call
    case operation
    when 'encrypt'
      encrypt_data
    when 'decrypt'
      decrypt_data
    when 'mask'
      mask_data
    else
      { success: false, error: '不支援的操作類型' }
    end
  end
  
  # 加密敏感資料
  def self.encrypt_sensitive_data(model_instance)
    return model_instance unless model_instance.respond_to?(:attributes)
    
    SENSITIVE_FIELDS.each do |field|
      if model_instance.respond_to?(field) && model_instance.send(field).present?
        original_value = model_instance.send(field)
        encrypted_value = encrypt_string(original_value.to_s)
        model_instance.send("#{field}=", encrypted_value)
      end
    end
    
    model_instance
  end
  
  # 解密敏感資料
  def self.decrypt_sensitive_data(model_instance)
    return model_instance unless model_instance.respond_to?(:attributes)
    
    SENSITIVE_FIELDS.each do |field|
      if model_instance.respond_to?(field) && model_instance.send(field).present?
        encrypted_value = model_instance.send(field)
        
        begin
          decrypted_value = decrypt_string(encrypted_value.to_s)
          model_instance.send("#{field}=", decrypted_value)
        rescue => e
          Rails.logger.error "Failed to decrypt #{field}: #{e.message}"
          # 如果解密失敗，保持原值
        end
      end
    end
    
    model_instance
  end
  
  # 遮罩敏感資料（用於顯示）
  def self.mask_sensitive_data(value, field_type = 'default')
    return '' if value.blank?
    
    case field_type
    when 'id_number'
      mask_id_number(value)
    when 'phone'
      mask_phone_number(value)
    when 'bank_account'
      mask_bank_account(value)
    when 'salary'
      mask_salary(value)
    else
      mask_default(value)
    end
  end
  
  # 檢查資料是否已加密
  def self.encrypted?(value)
    return false if value.blank?
    
    # 檢查是否符合加密格式
    value.to_s.match?(/\A[A-Za-z0-9+\/]+=*\z/) && value.length > 20
  end
  
  # 產生安全雜湊
  def self.generate_secure_hash(data)
    Digest::SHA256.hexdigest("#{data}#{Rails.application.secret_key_base}")
  end
  
  # 驗證資料完整性
  def self.verify_data_integrity(data, expected_hash)
    actual_hash = generate_secure_hash(data)
    actual_hash == expected_hash
  end
  
  # 安全刪除敏感資料
  def self.secure_delete_sensitive_data(model_instance)
    return false unless model_instance.respond_to?(:attributes)
    
    SENSITIVE_FIELDS.each do |field|
      if model_instance.respond_to?("#{field}=")
        # 用隨機資料覆寫多次
        3.times do
          random_data = SecureRandom.hex(50)
          model_instance.send("#{field}=", random_data)
        end
        
        # 最後設為nil
        model_instance.send("#{field}=", nil)
      end
    end
    
    model_instance.save! if model_instance.respond_to?(:save!)
    true
  end
  
  # 記錄資料存取
  def self.log_data_access(user_id, action, target_type, target_id, request_info = {})
    SecurityAuditLog.log_security_event(
      action,
      user_id: user_id,
      target_type: target_type,
      target_id: target_id,
      ip_address: request_info[:ip_address],
      user_agent: request_info[:user_agent],
      details: {
        timestamp: Time.current,
        encrypted: true
      }
    )
  end
  
  private
  
  def encrypt_data
    begin
      if data.is_a?(Hash)
        encrypted_hash = {}
        data.each do |key, value|
          encrypted_hash[key] = encrypt_string(value.to_s)
        end
        { success: true, data: encrypted_hash }
      else
        encrypted_value = encrypt_string(data.to_s)
        { success: true, data: encrypted_value }
      end
    rescue => e
      { success: false, error: "加密失敗：#{e.message}" }
    end
  end
  
  def decrypt_data
    begin
      if data.is_a?(Hash)
        decrypted_hash = {}
        data.each do |key, value|
          decrypted_hash[key] = decrypt_string(value.to_s)
        end
        { success: true, data: decrypted_hash }
      else
        decrypted_value = decrypt_string(data.to_s)
        { success: true, data: decrypted_value }
      end
    rescue => e
      { success: false, error: "解密失敗：#{e.message}" }
    end
  end
  
  def mask_data
    begin
      if data.is_a?(Hash)
        masked_hash = {}
        data.each do |key, value|
          field_type = SENSITIVE_FIELDS.include?(key.to_s) ? key.to_s : 'default'
          masked_hash[key] = self.class.mask_sensitive_data(value, field_type)
        end
        { success: true, data: masked_hash }
      else
        masked_value = self.class.mask_sensitive_data(data, 'default')
        { success: true, data: masked_value }
      end
    rescue => e
      { success: false, error: "遮罩失敗：#{e.message}" }
    end
  end
  
  def self.encrypt_string(plaintext)
    return '' if plaintext.blank?
    
    cipher = OpenSSL::Cipher.new('AES-256-CBC')
    cipher.encrypt
    cipher.key = encryption_key
    cipher.iv = iv = cipher.random_iv
    
    encrypted = cipher.update(plaintext) + cipher.final
    Base64.strict_encode64(iv + encrypted)
  end
  
  def self.decrypt_string(ciphertext)
    return '' if ciphertext.blank?
    
    data = Base64.strict_decode64(ciphertext)
    iv = data[0..15]
    encrypted = data[16..-1]
    
    cipher = OpenSSL::Cipher.new('AES-256-CBC')
    cipher.decrypt
    cipher.key = encryption_key
    cipher.iv = iv
    
    cipher.update(encrypted) + cipher.final
  end
  
  def self.encryption_key
    # 使用Rails的secret_key_base產生固定的加密金鑰
    Digest::SHA256.digest(Rails.application.secret_key_base)[0..31]
  end
  
  def self.mask_id_number(id_number)
    return '' if id_number.blank?
    
    id_str = id_number.to_s
    return id_str if id_str.length < 4
    
    "#{id_str[0]}#{'*' * (id_str.length - 2)}#{id_str[-1]}"
  end
  
  def self.mask_phone_number(phone)
    return '' if phone.blank?
    
    phone_str = phone.to_s.gsub(/\D/, '') # 移除非數字字符
    return phone_str if phone_str.length < 4
    
    "#{phone_str[0..2]}****#{phone_str[-2..-1]}"
  end
  
  def self.mask_bank_account(account)
    return '' if account.blank?
    
    account_str = account.to_s
    return account_str if account_str.length < 6
    
    "#{account_str[0..2]}#{'*' * (account_str.length - 6)}#{account_str[-3..-1]}"
  end
  
  def self.mask_salary(salary)
    return '' if salary.blank?
    
    # 薪資只顯示範圍
    amount = salary.to_f
    case amount
    when 0...30000
      '30,000以下'
    when 30000...50000
      '30,000-50,000'
    when 50000...80000
      '50,000-80,000'
    when 80000...120000
      '80,000-120,000'
    else
      '120,000以上'
    end
  end
  
  def self.mask_default(value)
    return '' if value.blank?
    
    value_str = value.to_s
    return value_str if value_str.length < 3
    
    "#{value_str[0]}#{'*' * (value_str.length - 2)}#{value_str[-1]}"
  end
end
