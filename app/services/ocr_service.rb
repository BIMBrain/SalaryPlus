# frozen_string_literal: true

require 'open3'
require 'json'

class OcrService
  class << self
    # 處理人事資料卡 OCR 辨識
    def process_hr_card(file_path)
      begin
        # 確保檔案存在
        unless File.exist?(file_path)
          return { success: false, error: "檔案不存在: #{file_path}" }
        end

        # 檢查檔案類型
        file_type = detect_file_type(file_path)
        
        case file_type
        when :image
          result = process_image_ocr(file_path)
        when :pdf
          result = process_pdf_ocr(file_path)
        when :word
          result = process_word_document(file_path)
        else
          return { success: false, error: "不支援的檔案格式" }
        end

        if result[:success]
          # 解析辨識結果
          parsed_data = parse_hr_card_data(result[:text])
          return { success: true, data: parsed_data, raw_text: result[:text] }
        else
          return result
        end

      rescue => e
        Rails.logger.error "OCR 處理錯誤: #{e.message}"
        return { success: false, error: "OCR 處理失敗: #{e.message}" }
      end
    end

    private

    # 檢測檔案類型
    def detect_file_type(file_path)
      extension = File.extname(file_path).downcase
      
      case extension
      when '.jpg', '.jpeg', '.png', '.bmp', '.tiff', '.gif'
        :image
      when '.pdf'
        :pdf
      when '.doc', '.docx'
        :word
      else
        :unknown
      end
    end

    # 處理圖片 OCR
    def process_image_ocr(file_path)
      begin
        # 安裝 tesseract 如果尚未安裝
        install_tesseract_if_needed

        # 使用 tesseract 進行 OCR
        command = "tesseract '#{file_path}' stdout -l chi_tra+eng"
        stdout, stderr, status = Open3.capture3(command)

        if status.success?
          return { success: true, text: stdout }
        else
          Rails.logger.error "Tesseract 錯誤: #{stderr}"
          return { success: false, error: "OCR 辨識失敗: #{stderr}" }
        end

      rescue => e
        Rails.logger.error "圖片 OCR 錯誤: #{e.message}"
        return { success: false, error: "圖片 OCR 處理失敗: #{e.message}" }
      end
    end

    # 處理 PDF OCR
    def process_pdf_ocr(file_path)
      begin
        # 先將 PDF 轉換為圖片，然後進行 OCR
        temp_dir = Rails.root.join('tmp', 'ocr')
        FileUtils.mkdir_p(temp_dir)
        
        # 使用 pdftoppm 將 PDF 轉換為圖片
        image_path = File.join(temp_dir, "#{SecureRandom.hex(8)}.png")
        command = "pdftoppm -png -singlefile '#{file_path}' '#{image_path.gsub('.png', '')}'"
        
        stdout, stderr, status = Open3.capture3(command)
        
        if status.success? && File.exist?(image_path)
          result = process_image_ocr(image_path)
          File.delete(image_path) if File.exist?(image_path)
          return result
        else
          return { success: false, error: "PDF 轉換失敗: #{stderr}" }
        end

      rescue => e
        Rails.logger.error "PDF OCR 錯誤: #{e.message}"
        return { success: false, error: "PDF OCR 處理失敗: #{e.message}" }
      end
    end

    # 處理 Word 文檔
    def process_word_document(file_path)
      begin
        # 使用 antiword 提取文字
        command = "antiword '#{file_path}'"
        stdout, stderr, status = Open3.capture3(command)

        if status.success?
          return { success: true, text: stdout }
        else
          Rails.logger.error "Antiword 錯誤: #{stderr}"
          return { success: false, error: "Word 文檔處理失敗: #{stderr}" }
        end

      rescue => e
        Rails.logger.error "Word 文檔錯誤: #{e.message}"
        return { success: false, error: "Word 文檔處理失敗: #{e.message}" }
      end
    end

    # 安裝 tesseract 如果需要
    def install_tesseract_if_needed
      unless system('which tesseract > /dev/null 2>&1')
        Rails.logger.info "安裝 Tesseract OCR..."
        system('sudo apt-get update && sudo apt-get install -y tesseract-ocr tesseract-ocr-chi-tra tesseract-ocr-eng poppler-utils antiword')
      end
    end

    # 解析人事資料卡數據
    def parse_hr_card_data(text)
      data = {}
      
      # 基本資料解析
      data[:name] = extract_field(text, ['姓名', '姓　名'], /([^\s\|]+)/)
      data[:gender] = extract_field(text, ['性別'], /(男|女)/)
      data[:birth_date] = extract_birth_date(text)
      data[:id_number] = extract_field(text, ['身分證字號', '身份證字號'], /([A-Z]\d{9})/)
      data[:phone] = extract_field(text, ['聯絡電話', '電話', '手機'], /(09\d{8}|\d{2,4}-\d{6,8})/)
      data[:email] = extract_field(text, ['電子信箱', 'E-mail', 'email'], /([a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,})/)
      
      # 地址解析
      data[:address] = extract_address(text)
      
      # 學歷解析
      data[:education] = extract_education(text)
      
      # 工作經歷解析
      data[:work_experience] = extract_work_experience(text)
      
      # 緊急聯絡人解析
      emergency_contact = extract_emergency_contact(text)
      data[:emergency_contact_name] = emergency_contact[:name]
      data[:emergency_contact_phone] = emergency_contact[:phone]
      data[:emergency_contact_relationship] = emergency_contact[:relationship]
      
      # 其他資料
      data[:blood_type] = extract_field(text, ['血型'], /([ABO]型?)/)
      data[:height] = extract_field(text, ['身高'], /(\d+)公分/)
      data[:weight] = extract_field(text, ['體重'], /(\d+)公斤/)
      data[:marital_status] = extract_field(text, ['婚姻狀況'], /(已婚|未婚|離婚|喪偶)/)
      data[:military_status] = extract_field(text, ['兵役狀況'], /(已服畢|免役|未服|服役中)/)
      
      # 專長與興趣
      data[:skills] = extract_field(text, ['專長', '專　長'], /([^\|]+)/)
      data[:interests] = extract_field(text, ['興趣', '興　趣'], /([^\|]+)/)
      data[:certifications] = extract_field(text, ['證照', '證　照'], /([^\|]+)/)

      # 清理數據
      data.each do |key, value|
        data[key] = value.to_s.strip if value
      end

      data
    end

    # 提取欄位值
    def extract_field(text, field_names, pattern)
      field_names.each do |field_name|
        # 尋找欄位名稱後的內容
        regex = /#{Regexp.escape(field_name)}[：:\s]*#{pattern.source}/
        match = text.match(regex)
        return match[1].strip if match && match[1]
        
        # 嘗試表格格式
        lines = text.split("\n")
        lines.each_with_index do |line, index|
          if line.include?(field_name)
            # 檢查同一行
            match = line.match(pattern)
            return match[1].strip if match && match[1]
            
            # 檢查下一行
            if index + 1 < lines.length
              match = lines[index + 1].match(pattern)
              return match[1].strip if match && match[1]
            end
          end
        end
      end
      nil
    end

    # 提取出生日期
    def extract_birth_date(text)
      # 民國年格式
      match = text.match(/出生日期[：:\s]*民國(\d+)年(\d+)月(\d+)日/)
      if match
        year = match[1].to_i + 1911
        month = match[2].to_i
        day = match[3].to_i
        return "#{year}-#{month.to_s.padded(2, '0')}-#{day.to_s.padded(2, '0')}"
      end
      
      # 西元年格式
      match = text.match(/出生日期[：:\s]*(\d{4})年(\d+)月(\d+)日/)
      if match
        year = match[1]
        month = match[2].to_i.to_s.rjust(2, '0')
        day = match[3].to_i.to_s.rjust(2, '0')
        return "#{year}-#{month}-#{day}"
      end
      
      # 數字格式 (83/05/06)
      match = text.match(/(\d{2,3})\/(\d{1,2})\/(\d{1,2})/)
      if match
        year = match[1].to_i
        year += 1911 if year < 200  # 假設是民國年
        month = match[2].to_i.to_s.rjust(2, '0')
        day = match[3].to_i.to_s.rjust(2, '0')
        return "#{year}-#{month}-#{day}"
      end
      
      nil
    end

    # 提取地址
    def extract_address(text)
      # 尋找戶籍地址或通訊地址
      address_patterns = [
        /戶籍地址[：:\s]*([^|\n]+)/,
        /通訊地址[：:\s]*([^|\n]+)/,
        /地址[：:\s]*([^|\n]+)/,
        /(台中市|台北市|新北市|桃園市|台南市|高雄市|基隆市|新竹市|嘉義市|台中縣|彰化縣|南投縣|雲林縣|嘉義縣|屏東縣|宜蘭縣|花蓮縣|台東縣|澎湖縣|金門縣|連江縣)[^|\n]+/
      ]
      
      address_patterns.each do |pattern|
        match = text.match(pattern)
        return match[1].strip if match && match[1]
      end
      
      nil
    end

    # 提取學歷
    def extract_education(text)
      education_info = {}
      
      # 學校名稱
      school_match = text.match(/學校[：:\s]*([^|\n]+)/)
      education_info[:school] = school_match[1].strip if school_match
      
      # 科系
      department_match = text.match(/科系[：:\s]*([^|\n]+)/)
      education_info[:department] = department_match[1].strip if department_match
      
      # 學歷
      degree_match = text.match(/學歷[：:\s]*(大學|碩士|博士|高中|國中|國小)/)
      education_info[:degree] = degree_match[1].strip if degree_match
      
      education_info.empty? ? nil : education_info
    end

    # 提取工作經歷
    def extract_work_experience(text)
      experience_info = {}
      
      # 公司名稱
      company_match = text.match(/公司[：:\s]*([^|\n]+)/)
      experience_info[:company] = company_match[1].strip if company_match
      
      # 職位
      position_match = text.match(/職位[：:\s]*([^|\n]+)/)
      experience_info[:position] = position_match[1].strip if position_match
      
      experience_info.empty? ? nil : experience_info
    end

    # 提取緊急聯絡人
    def extract_emergency_contact(text)
      contact_info = {}
      
      # 在緊急聯絡人區域尋找
      emergency_section = text[/緊.*?急.*?連絡人.*?$/m]
      if emergency_section
        # 姓名
        name_match = emergency_section.match(/([^\s\|]+)\s*\|[^|]*\|/)
        contact_info[:name] = name_match[1].strip if name_match
        
        # 電話
        phone_match = emergency_section.match(/(09\d{8}|\d{2,4}-\d{6,8})/)
        contact_info[:phone] = phone_match[1].strip if phone_match
        
        # 關係
        relationship_match = emergency_section.match(/\|(父|母|配偶|兄弟|姊妹|朋友|女朋|男朋)\w*\|/)
        contact_info[:relationship] = relationship_match[1].strip if relationship_match
      end
      
      contact_info
    end
  end
end

