// 樣式模板切換功能的 JavaScript
console.log('Style templates script loaded');

document.addEventListener('DOMContentLoaded', function() {
  console.log('DOMContentLoaded fired');
  initializeStyleTemplates();
  initializeFontScaleToolbar();
});

// 支援 Turbolinks
document.addEventListener('turbolinks:load', function() {
  console.log('turbolinks:load fired');
  initializeStyleTemplates();
  initializeFontScaleToolbar();
});

// 立即執行測試
if (document.readyState === 'loading') {
  console.log('Document is still loading');
} else {
  console.log('Document already loaded, initializing immediately');
  setTimeout(function() {
    initializeStyleTemplates();
    initializeFontScaleToolbar();
  }, 100);
}

function initializeFontScaleToolbar() {
  // 綁定工具列按鈕事件
  const toolbarButtons = document.querySelectorAll('.font-scale-quick-btn');
  toolbarButtons.forEach(button => {
    button.addEventListener('click', function() {
      const scale = this.dataset.scale;
      setFontScale(scale);

      // 更新工具列按鈕狀態
      toolbarButtons.forEach(btn => btn.classList.remove('active'));
      this.classList.add('active');

      // 同步更新設定頁面的控制項（如果存在）
      const fontScaleSlider = document.getElementById('font-scale');
      if (fontScaleSlider) {
        fontScaleSlider.value = scale;
        updateSliderValue(fontScaleSlider);
      }

      const fontScaleButtons = document.querySelectorAll('.font-scale-btn');
      fontScaleButtons.forEach(btn => {
        btn.classList.remove('active');
        if (btn.dataset.scale === scale) {
          btn.classList.add('active');
        }
      });
    });
  });

  // 初始化工具列按鈕狀態
  const savedFontScale = localStorage.getItem('fortuna_font_scale') || '1';
  toolbarButtons.forEach(btn => {
    btn.classList.remove('active');
    if (btn.dataset.scale === savedFontScale) {
      btn.classList.add('active');
    }
  });
}

function initializeStyleTemplates() {
  console.log('Initializing style templates...');

  // 獲取當前樣式模板
  const currentTemplate = localStorage.getItem('fortuna_style_template') || 'macos-classic';
  console.log('Current template:', currentTemplate);

  // 設置當前選中的模板
  setActiveTemplate(currentTemplate);

  // 綁定模板選擇事件
  bindTemplateSelectionEvents();

  // 綁定自定義選項事件
  bindCustomizationEvents();

  // 初始化當前樣式資訊
  updateCurrentStyleInfo(currentTemplate);

  console.log('Style templates initialized successfully');
}

function bindTemplateSelectionEvents() {
  const templateItems = document.querySelectorAll('.style-template-item');
  const selectButtons = document.querySelectorAll('.select-template');

  console.log('Found template items:', templateItems.length);
  console.log('Found select buttons:', selectButtons.length);

  // 模板項目點擊事件
  templateItems.forEach(item => {
    item.addEventListener('click', function() {
      const template = this.dataset.template;
      console.log('Template item clicked:', template);
      selectTemplate(template);
    });
  });

  // 選擇按鈕點擊事件
  selectButtons.forEach(button => {
    button.addEventListener('click', function(e) {
      e.stopPropagation();
      const template = this.dataset.template;
      console.log('Select button clicked:', template);
      selectTemplate(template);
    });
  });
}

function selectTemplate(templateName) {
  console.log('Selecting template:', templateName);

  // 移除所有選中狀態
  document.querySelectorAll('.style-template-item').forEach(item => {
    item.classList.remove('selected');
  });

  // 設置新的選中狀態
  const selectedItem = document.querySelector(`[data-template="${templateName}"]`);
  if (selectedItem) {
    selectedItem.classList.add('selected');
    console.log('Template item selected:', templateName);
  } else {
    console.error('Template item not found:', templateName);
  }

  // 應用樣式模板
  applyStyleTemplate(templateName);

  // 保存到伺服器
  saveTemplateToServer(templateName);

  // 保存到本地存儲
  localStorage.setItem('fortuna_style_template', templateName);

  // 更新當前樣式資訊
  updateCurrentStyleInfo(templateName);

  // 顯示成功消息
  showNotification('樣式模板已更新', 'success');
}

function saveTemplateToServer(templateName) {
  const csrfToken = document.querySelector('meta[name="csrf-token"]');
  if (!csrfToken) {
    console.error('CSRF token not found');
    return;
  }

  fetch('/system_settings/update_style_template', {
    method: 'PATCH',
    headers: {
      'Content-Type': 'application/json',
      'X-CSRF-Token': csrfToken.getAttribute('content')
    },
    body: JSON.stringify({
      template_name: templateName
    })
  })
  .then(response => response.json())
  .then(data => {
    if (data.success) {
      console.log('Template saved successfully:', data.message);
    } else {
      console.error('Failed to save template to server:', data.error);
    }
  })
  .catch(error => {
    console.error('Error saving template to server:', error);
  });
}

function applyStyleTemplate(templateName) {
  const root = document.documentElement;
  
  // 移除現有的模板類
  root.classList.remove('template-macos-classic', 'template-ai-modern', 'template-minimal',
                       'template-dark-pro', 'template-colorful', 'template-business', 'template-hubspot-crm');
  
  // 添加新的模板類
  root.classList.add(`template-${templateName}`);
  
  // 根據模板設置 CSS 變量
  switch(templateName) {
    case 'macos-classic':
      setMacOSClassicTheme();
      break;
    case 'ai-modern':
      setAIModernTheme();
      break;
    case 'minimal':
      setMinimalTheme();
      break;
    case 'dark-pro':
      setDarkProTheme();
      break;
    case 'colorful':
      setColorfulTheme();
      break;
    case 'business':
      setBusinessTheme();
      break;
    case 'hubspot-crm':
      setHubSpotCRMTheme();
      break;
  }
}

function setMacOSClassicTheme() {
  const root = document.documentElement;
  root.style.setProperty('--macos-primary', '#007AFF');
  root.style.setProperty('--macos-secondary', '#5AC8FA');
  root.style.setProperty('--macos-success', '#34C759');
  root.style.setProperty('--macos-warning', '#FF9500');
  root.style.setProperty('--macos-danger', '#FF3B30');
  root.style.setProperty('--macos-bg-primary', '#FFFFFF');
  root.style.setProperty('--macos-bg-secondary', '#F2F2F7');
  root.style.setProperty('--macos-text-primary', '#000000');
  root.style.setProperty('--macos-text-secondary', '#6D6D80');
  root.style.setProperty('--macos-border-color', '#C6C6C8');
  root.style.setProperty('--macos-radius', '10px');
  root.style.setProperty('--macos-radius-large', '16px');
}

function setAIModernTheme() {
  const root = document.documentElement;
  root.style.setProperty('--macos-primary', '#667EEA');
  root.style.setProperty('--macos-secondary', '#764BA2');
  root.style.setProperty('--macos-success', '#00D4FF');
  root.style.setProperty('--macos-warning', '#FFB800');
  root.style.setProperty('--macos-danger', '#FF6B6B');
  root.style.setProperty('--macos-bg-primary', '#0E1419');
  root.style.setProperty('--macos-bg-secondary', '#1A1A2E');
  root.style.setProperty('--macos-text-primary', '#FFFFFF');
  root.style.setProperty('--macos-text-secondary', '#64B5F6');
  root.style.setProperty('--macos-border-color', '#0F3460');
  root.style.setProperty('--macos-radius', '12px');
  root.style.setProperty('--macos-radius-large', '20px');
}

function setMinimalTheme() {
  const root = document.documentElement;
  root.style.setProperty('--macos-primary', '#333333');
  root.style.setProperty('--macos-secondary', '#666666');
  root.style.setProperty('--macos-success', '#28A745');
  root.style.setProperty('--macos-warning', '#FFC107');
  root.style.setProperty('--macos-danger', '#DC3545');
  root.style.setProperty('--macos-bg-primary', '#FFFFFF');
  root.style.setProperty('--macos-bg-secondary', '#FAFAFA');
  root.style.setProperty('--macos-text-primary', '#333333');
  root.style.setProperty('--macos-text-secondary', '#666666');
  root.style.setProperty('--macos-border-color', '#F0F0F0');
  root.style.setProperty('--macos-radius', '4px');
  root.style.setProperty('--macos-radius-large', '8px');
}

function setDarkProTheme() {
  const root = document.documentElement;
  root.style.setProperty('--macos-primary', '#0A84FF');
  root.style.setProperty('--macos-secondary', '#30D158');
  root.style.setProperty('--macos-success', '#30D158');
  root.style.setProperty('--macos-warning', '#FF9F0A');
  root.style.setProperty('--macos-danger', '#FF453A');
  root.style.setProperty('--macos-bg-primary', '#1C1C1E');
  root.style.setProperty('--macos-bg-secondary', '#2C2C2E');
  root.style.setProperty('--macos-text-primary', '#FFFFFF');
  root.style.setProperty('--macos-text-secondary', '#AEAEB2');
  root.style.setProperty('--macos-border-color', '#38383A');
  root.style.setProperty('--macos-radius', '10px');
  root.style.setProperty('--macos-radius-large', '16px');
}

function setColorfulTheme() {
  const root = document.documentElement;
  root.style.setProperty('--macos-primary', '#45B7D1');
  root.style.setProperty('--macos-secondary', '#96CEB4');
  root.style.setProperty('--macos-success', '#96CEB4');
  root.style.setProperty('--macos-warning', '#FECA57');
  root.style.setProperty('--macos-danger', '#FF6B6B');
  root.style.setProperty('--macos-bg-primary', '#FFFFFF');
  root.style.setProperty('--macos-bg-secondary', '#F8F9FA');
  root.style.setProperty('--macos-text-primary', '#2C3E50');
  root.style.setProperty('--macos-text-secondary', '#7F8C8D');
  root.style.setProperty('--macos-border-color', '#E9ECEF');
  root.style.setProperty('--macos-radius', '12px');
  root.style.setProperty('--macos-radius-large', '20px');
}

function setBusinessTheme() {
  const root = document.documentElement;
  root.style.setProperty('--macos-primary', '#3498DB');
  root.style.setProperty('--macos-secondary', '#2C3E50');
  root.style.setProperty('--macos-success', '#27AE60');
  root.style.setProperty('--macos-warning', '#F39C12');
  root.style.setProperty('--macos-danger', '#E74C3C');
  root.style.setProperty('--macos-bg-primary', '#FFFFFF');
  root.style.setProperty('--macos-bg-secondary', '#ECF0F1');
  root.style.setProperty('--macos-text-primary', '#2C3E50');
  root.style.setProperty('--macos-text-secondary', '#7F8C8D');
  root.style.setProperty('--macos-border-color', '#BDC3C7');
  root.style.setProperty('--macos-radius', '8px');
  root.style.setProperty('--macos-radius-large', '12px');
}

function setHubSpotCRMTheme() {
  const root = document.documentElement;
  root.style.setProperty('--macos-primary', '#FF7A59');
  root.style.setProperty('--macos-secondary', '#FF5722');
  root.style.setProperty('--macos-success', '#4ADE80');
  root.style.setProperty('--macos-warning', '#F59E0B');
  root.style.setProperty('--macos-danger', '#EF4444');
  root.style.setProperty('--macos-bg-primary', '#FFFFFF');
  root.style.setProperty('--macos-bg-secondary', '#F8FAFC');
  root.style.setProperty('--macos-text-primary', '#1E293B');
  root.style.setProperty('--macos-text-secondary', '#64748B');
  root.style.setProperty('--macos-border-color', '#E2E8F0');
  root.style.setProperty('--macos-radius', '8px');
  root.style.setProperty('--macos-radius-large', '12px');

  // HubSpot 特有的顏色變量
  root.style.setProperty('--hubspot-orange', '#FF7A59');
  root.style.setProperty('--hubspot-orange-dark', '#FF5722');
  root.style.setProperty('--hubspot-gray-50', '#F8FAFC');
  root.style.setProperty('--hubspot-gray-100', '#F1F5F9');
  root.style.setProperty('--hubspot-gray-200', '#E2E8F0');
  root.style.setProperty('--hubspot-gray-500', '#64748B');
  root.style.setProperty('--hubspot-gray-900', '#1E293B');
}

function setActiveTemplate(templateName) {
  // 移除所有選中狀態
  document.querySelectorAll('.style-template-item').forEach(item => {
    item.classList.remove('selected');
  });
  
  // 設置當前模板為選中狀態
  const activeItem = document.querySelector(`[data-template="${templateName}"]`);
  if (activeItem) {
    activeItem.classList.add('selected');
  }
  
  // 應用樣式模板
  applyStyleTemplate(templateName);
}

function bindCustomizationEvents() {
  // 顏色選擇器事件
  const colorPickers = document.querySelectorAll('.color-picker');
  colorPickers.forEach(picker => {
    picker.addEventListener('change', function() {
      updateCustomColors();
    });
  });
  
  // 滑塊事件
  const sliders = document.querySelectorAll('.range-slider');
  sliders.forEach(slider => {
    slider.addEventListener('input', function() {
      updateSliderValue(this);
    });
    
    slider.addEventListener('change', function() {
      updateCustomStyles();
    });
  });
  
  // 預覽自定義按鈕
  const previewButton = document.getElementById('preview-custom');
  if (previewButton) {
    previewButton.addEventListener('click', previewCustomization);
  }
  
  // 套用自定義按鈕
  const applyButton = document.getElementById('apply-custom');
  if (applyButton) {
    applyButton.addEventListener('click', applyCustomization);
  }

  // 字體縮放按鈕
  const fontScaleButtons = document.querySelectorAll('.font-scale-btn');
  fontScaleButtons.forEach(button => {
    button.addEventListener('click', function() {
      const scale = this.dataset.scale;
      setFontScale(scale);

      // 更新滑塊值
      const fontScaleSlider = document.getElementById('font-scale');
      if (fontScaleSlider) {
        fontScaleSlider.value = scale;
        updateSliderValue(fontScaleSlider);
      }

      // 更新按鈕狀態
      fontScaleButtons.forEach(btn => btn.classList.remove('active'));
      this.classList.add('active');
    });
  });

  // 字體縮放滑塊
  const fontScaleSlider = document.getElementById('font-scale');
  if (fontScaleSlider) {
    fontScaleSlider.addEventListener('input', function() {
      updateSliderValue(this);
      setFontScale(this.value);

      // 更新按鈕狀態
      fontScaleButtons.forEach(btn => {
        btn.classList.remove('active');
        if (btn.dataset.scale === this.value) {
          btn.classList.add('active');
        }
      });
    });
  }
}

function updateSliderValue(slider) {
  const valueSpan = slider.parentNode.querySelector('.slider-value');
  if (valueSpan) {
    let value = slider.value;
    if (slider.id === 'border-radius') {
      value += 'px';
    } else if (slider.id === 'shadow-intensity') {
      value += '%';
    } else if (slider.id === 'font-scale') {
      value += 'x';
    }
    valueSpan.textContent = value;
  }
}

function setFontScale(scale) {
  const root = document.documentElement;

  // 移除現有的字體縮放
  root.removeAttribute('data-font-scale');

  // 設定新的字體縮放
  if (scale !== '1') {
    root.setAttribute('data-font-scale', scale);
  }

  // 保存到本地存儲
  localStorage.setItem('fortuna_font_scale', scale);

  // 保存到伺服器
  saveFontScaleToServer(scale);

  showNotification(`字體已縮放至 ${scale} 倍`, 'success');
}

function saveFontScaleToServer(scale) {
  const csrfToken = document.querySelector('meta[name="csrf-token"]');
  if (!csrfToken) {
    console.error('CSRF token not found');
    return;
  }

  fetch('/system_settings/update_ui_preference', {
    method: 'PATCH',
    headers: {
      'Content-Type': 'application/json',
      'X-CSRF-Token': csrfToken.getAttribute('content')
    },
    body: JSON.stringify({
      setting_key: 'ui_font_scale',
      setting_value: scale
    })
  })
  .then(response => response.json())
  .then(data => {
    if (data.success) {
      console.log('Font scale saved successfully:', data.message);
    } else {
      console.error('Failed to save font scale to server:', data.error);
    }
  })
  .catch(error => {
    console.error('Error saving font scale to server:', error);
  });
}

function updateCustomColors() {
  const primaryColor = document.getElementById('primary-color').value;
  const secondaryColor = document.getElementById('secondary-color').value;
  
  const root = document.documentElement;
  root.style.setProperty('--macos-primary', primaryColor);
  root.style.setProperty('--macos-secondary', secondaryColor);
}

function updateCustomStyles() {
  const borderRadius = document.getElementById('border-radius').value + 'px';
  const shadowIntensity = document.getElementById('shadow-intensity').value;
  
  const root = document.documentElement;
  root.style.setProperty('--macos-radius', borderRadius);
  root.style.setProperty('--macos-radius-large', (parseInt(borderRadius) * 1.6) + 'px');
  
  // 更新陰影強度
  const shadowOpacity = shadowIntensity / 100 * 0.3;
  root.style.setProperty('--macos-shadow', `0 4px 20px rgba(0, 0, 0, ${shadowOpacity})`);
}

function previewCustomization() {
  updateCustomColors();
  updateCustomStyles();
  showNotification('自定義預覽已套用', 'info');
}

function applyCustomization() {
  updateCustomColors();
  updateCustomStyles();

  // 保存自定義設定
  const customSettings = {
    primary_color: document.getElementById('primary-color').value,
    secondary_color: document.getElementById('secondary-color').value,
    border_radius: document.getElementById('border-radius').value,
    shadow_intensity: document.getElementById('shadow-intensity').value
  };

  // 保存到伺服器
  saveCustomSettingsToServer(customSettings);

  localStorage.setItem('fortuna_custom_settings', JSON.stringify(customSettings));
  localStorage.setItem('fortuna_style_template', 'custom');

  // 更新當前樣式資訊
  updateCurrentStyleInfo('custom');

  showNotification('自定義樣式已套用', 'success');
}

function saveCustomSettingsToServer(customSettings) {
  const csrfToken = document.querySelector('meta[name="csrf-token"]');
  if (!csrfToken) {
    console.error('CSRF token not found');
    return;
  }

  fetch('/system_settings/update_custom_style', {
    method: 'PATCH',
    headers: {
      'Content-Type': 'application/json',
      'X-CSRF-Token': csrfToken.getAttribute('content')
    },
    body: JSON.stringify({
      custom_settings: customSettings
    })
  })
  .then(response => response.json())
  .then(data => {
    if (data.success) {
      console.log('Custom settings saved successfully:', data.message);
    } else {
      console.error('Failed to save custom settings to server:', data.error);
    }
  })
  .catch(error => {
    console.error('Error saving custom settings to server:', error);
  });
}

function updateCurrentStyleInfo(templateName) {
  const templateNames = {
    'macos-classic': 'macOS 經典風格',
    'ai-modern': 'AI 現代風格',
    'minimal': '極簡風格',
    'dark-pro': '深色專業風格',
    'colorful': '彩色活潑風格',
    'business': '商務正式風格',
    'hubspot-crm': 'HubSpot CRM 風格',
    'custom': '自定義風格'
  };
  
  const nameElement = document.getElementById('current-template-name');
  const timeElement = document.getElementById('current-apply-time');
  const customStatusElement = document.getElementById('custom-settings-status');
  
  if (nameElement) {
    nameElement.textContent = templateNames[templateName] || templateName;
  }
  
  if (timeElement) {
    timeElement.textContent = new Date().toLocaleString('zh-TW');
  }
  
  if (customStatusElement) {
    const hasCustomSettings = localStorage.getItem('fortuna_custom_settings');
    customStatusElement.textContent = hasCustomSettings ? '已啟用' : '未啟用';
  }
}

function showNotification(message, type = 'info') {
  // 創建通知元素
  const notification = document.createElement('div');
  notification.className = `macos-notification macos-notification-${type}`;
  notification.innerHTML = `
    <div class="macos-notification-content">
      <i class="fas fa-${getNotificationIcon(type)}"></i>
      <span>${message}</span>
    </div>
  `;
  
  // 添加到頁面
  document.body.appendChild(notification);
  
  // 顯示動畫
  setTimeout(() => {
    notification.classList.add('show');
  }, 100);
  
  // 自動隱藏
  setTimeout(() => {
    notification.classList.remove('show');
    setTimeout(() => {
      document.body.removeChild(notification);
    }, 300);
  }, 3000);
}

function getNotificationIcon(type) {
  switch(type) {
    case 'success': return 'check-circle';
    case 'warning': return 'exclamation-triangle';
    case 'error': return 'times-circle';
    default: return 'info-circle';
  }
}

// 頁面載入時恢復保存的設定
window.addEventListener('load', function() {
  const savedTemplate = localStorage.getItem('fortuna_style_template');
  const savedCustomSettings = localStorage.getItem('fortuna_custom_settings');
  const savedFontScale = localStorage.getItem('fortuna_font_scale') || '1';

  if (savedTemplate) {
    applyStyleTemplate(savedTemplate);
  }

  // 恢復字體縮放
  if (savedFontScale !== '1') {
    setFontScale(savedFontScale);

    // 更新UI控制項
    const fontScaleSlider = document.getElementById('font-scale');
    if (fontScaleSlider) {
      fontScaleSlider.value = savedFontScale;
      updateSliderValue(fontScaleSlider);
    }

    // 更新按鈕狀態
    const fontScaleButtons = document.querySelectorAll('.font-scale-btn');
    fontScaleButtons.forEach(btn => {
      btn.classList.remove('active');
      if (btn.dataset.scale === savedFontScale) {
        btn.classList.add('active');
      }
    });
  }

  if (savedCustomSettings && savedTemplate === 'custom') {
    const settings = JSON.parse(savedCustomSettings);

    // 恢復自定義設定
    if (document.getElementById('primary-color')) {
      document.getElementById('primary-color').value = settings.primaryColor;
    }
    if (document.getElementById('secondary-color')) {
      document.getElementById('secondary-color').value = settings.secondaryColor;
    }
    if (document.getElementById('border-radius')) {
      document.getElementById('border-radius').value = settings.borderRadius;
      updateSliderValue(document.getElementById('border-radius'));
    }
    if (document.getElementById('shadow-intensity')) {
      document.getElementById('shadow-intensity').value = settings.shadowIntensity;
      updateSliderValue(document.getElementById('shadow-intensity'));
    }

    // 套用自定義樣式
    updateCustomColors();
    updateCustomStyles();
  }
});


