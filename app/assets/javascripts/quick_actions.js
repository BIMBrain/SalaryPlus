// Quick Actions Customization
document.addEventListener('DOMContentLoaded', function() {
  const customizeBtn = document.getElementById('customize-btn');
  const addShortcutBtn = document.getElementById('add-shortcut-btn');
  const resetShortcutsBtn = document.getElementById('reset-shortcuts-btn');
  const functionSelector = document.querySelector('.function-selector');
  const quickActionsGrid = document.getElementById('quick-actions-grid');
  const addShortcutPlaceholder = document.querySelector('.add-shortcut-placeholder');
  
  let isCustomizing = false;
  
  // Function definitions with their properties
  const functionDefinitions = {
    employees: {
      icon: 'fas fa-users',
      color: '#4A90E2',
      title: '員工管理',
      description: '管理員工資料',
      status: '管理',
      path: '/employees'
    },
    attendances: {
      icon: 'fas fa-clock',
      color: '#27AE60',
      title: '出勤管理',
      description: '員工打卡記錄',
      status: '出勤',
      path: '/attendances'
    },
    overtime: {
      icon: 'fas fa-calculator',
      color: '#E67E22',
      title: '加班費計算',
      description: '一例一休計算',
      status: '計算',
      path: '/overtime'
    },
    payrolls: {
      icon: 'fas fa-file-invoice-dollar',
      color: '#9B59B6',
      title: '薪資計算',
      description: '計算員工薪資',
      status: '計算',
      path: '/payrolls'
    },
    insurance_statements: {
      icon: 'fas fa-shield-alt',
      color: '#E74C3C',
      title: '勞健保比對工具',
      description: '保險費用比對',
      status: '比對',
      path: '/insurance_statements'
    },
    statements: {
      icon: 'fas fa-history',
      color: '#34495E',
      title: '發薪紀錄',
      description: '歷史薪資記錄',
      status: '記錄',
      path: '/statements'
    },
    employee_login: {
      icon: 'fas fa-user-circle',
      color: '#16A085',
      title: '員工自助平台',
      description: '員工入口網站',
      status: '平台',
      path: '/employee/login'
    },
    reports: {
      icon: 'fas fa-chart-line',
      color: '#8E44AD',
      title: '報表分析',
      description: '薪資統計報表',
      status: '報表',
      path: '/reports'
    },
    system_settings: {
      icon: 'fas fa-cogs',
      color: '#95A5A6',
      title: '系統設定',
      description: '系統參數設定',
      status: '設定',
      path: '/system_settings'
    }
  };
  
  // Load saved quick actions from localStorage
  function loadQuickActions() {
    const saved = localStorage.getItem('fortuna_quick_actions');
    if (saved) {
      try {
        const quickActions = JSON.parse(saved);
        renderQuickActions(quickActions);
      } catch (e) {
        console.error('Error loading quick actions:', e);
        // Load default actions if saved data is corrupted
        const defaultActions = ['employees', 'payrolls', 'attendances', 'reports'];
        renderQuickActions(defaultActions);
      }
    } else {
      // Load default actions if no saved data
      const defaultActions = ['employees', 'payrolls', 'attendances', 'reports'];
      renderQuickActions(defaultActions);
    }
  }
  
  // Save quick actions to localStorage
  function saveQuickActions() {
    const currentActions = [];
    const actionCards = quickActionsGrid.querySelectorAll('.quick-action-item');
    
    actionCards.forEach(card => {
      const functionName = card.getAttribute('data-function');
      if (functionName) {
        currentActions.push(functionName);
      }
    });
    
    localStorage.setItem('fortuna_quick_actions', JSON.stringify(currentActions));
  }
  
  // Render quick actions based on saved preferences
  function renderQuickActions(actions) {
    if (!quickActionsGrid) return;

    quickActionsGrid.innerHTML = '';

    actions.forEach(functionName => {
      const func = functionDefinitions[functionName];
      if (func) {
        const card = createQuickActionCard(functionName, func);
        quickActionsGrid.appendChild(card);
      }
    });

    updateCustomizeMode();
  }
  
  // Create a quick action card
  function createQuickActionCard(functionName, func) {
    const card = document.createElement('a');
    card.href = func.path;
    card.className = 'meeting-card quick-action-item';
    card.setAttribute('data-function', functionName);
    
    card.innerHTML = `
      <div class="meeting-avatar">
        <i class="${func.icon}" style="font-size: 20px; color: ${func.color};"></i>
      </div>
      <div class="meeting-info">
        <h4>${func.title}</h4>
        <p>${func.description}</p>
      </div>
      <div class="meeting-meta">
        <span class="meeting-status">${func.status}</span>
        <span class="meeting-time">快速訪問</span>
        <span class="meeting-score">★</span>
      </div>
      <button class="meeting-action">
        <i class="fas fa-arrow-right"></i>
      </button>
      <button class="remove-shortcut" style="display: none;">
        <i class="fas fa-times"></i>
      </button>
    `;
    
    // Add remove functionality
    const removeBtn = card.querySelector('.remove-shortcut');
    if (removeBtn) {
      removeBtn.addEventListener('click', function(e) {
        e.preventDefault();
        e.stopPropagation();
        card.remove();
        updateFunctionSelector();
        saveQuickActions();
      });
    }
    
    return card;
  }
  
  // Toggle customize mode
  function toggleCustomizeMode() {
    isCustomizing = !isCustomizing;
    updateCustomizeMode();
    saveQuickActions();
  }

  // Update customize mode UI
  function updateCustomizeMode() {
    if (!functionSelector || !addShortcutPlaceholder || !customizeBtn) return;

    if (isCustomizing) {
      functionSelector.style.display = 'block';
      addShortcutPlaceholder.style.display = 'block';

      // Show remove buttons
      const actionCards = quickActionsGrid.querySelectorAll('.quick-action-item');
      actionCards.forEach(card => {
        card.classList.add('customizing');
      });

      customizeBtn.innerHTML = '<i class="fas fa-check"></i>';
      customizeBtn.title = '完成自定義';
      customizeBtn.style.background = 'rgba(255, 255, 255, 0.3)';
    } else {
      functionSelector.style.display = 'none';
      addShortcutPlaceholder.style.display = 'none';

      // Hide remove buttons
      const actionCards = quickActionsGrid.querySelectorAll('.quick-action-item');
      actionCards.forEach(card => {
        card.classList.remove('customizing');
      });

      customizeBtn.innerHTML = '<i class="fas fa-cog"></i>';
      customizeBtn.title = '自定義快速操作';
      customizeBtn.style.background = '';
    }

    updateFunctionSelector();
  }
  
  // Update function selector to show available functions
  function updateFunctionSelector() {
    if (!functionSelector || !quickActionsGrid) return;

    const currentActions = Array.from(quickActionsGrid.querySelectorAll('.quick-action-item'))
      .map(card => card.getAttribute('data-function'));

    const functionOptions = functionSelector.querySelectorAll('.function-option');
    functionOptions.forEach(option => {
      const functionName = option.getAttribute('data-function');
      if (currentActions.includes(functionName)) {
        option.classList.add('selected');
        option.style.opacity = '0.5';
        option.style.pointerEvents = 'none';
        option.style.background = '#e9ecef';
      } else {
        option.classList.remove('selected');
        option.style.opacity = '1';
        option.style.pointerEvents = 'auto';
        option.style.background = 'white';
      }
    });
  }
  
  // Add function to quick actions
  function addFunctionToQuickActions(functionName) {
    if (!quickActionsGrid) return;

    const func = functionDefinitions[functionName];
    if (func) {
      const card = createQuickActionCard(functionName, func);
      quickActionsGrid.appendChild(card);

      if (isCustomizing) {
        card.classList.add('customizing');
      }

      updateFunctionSelector();
      saveQuickActions();
    }
  }
  
  // Reset to default quick actions
  function resetToDefaults() {
    const defaultActions = ['employees', 'payrolls', 'attendances', 'reports'];
    renderQuickActions(defaultActions);
    saveQuickActions();
    updateFunctionSelector();
  }
  
  // Event listeners
  if (customizeBtn) {
    customizeBtn.addEventListener('click', toggleCustomizeMode);
  }
  
  if (resetShortcutsBtn) {
    resetShortcutsBtn.addEventListener('click', function() {
      if (confirm('確定要重置為預設的快速操作嗎？')) {
        resetToDefaults();
      }
    });
  }
  
  // Function selector event listeners
  document.addEventListener('click', function(e) {
    const option = e.target.closest('.function-option');
    if (option && !option.classList.contains('selected') && isCustomizing) {
      const functionName = option.getAttribute('data-function');
      addFunctionToQuickActions(functionName);
    }
  });
  
  // Add new shortcut button
  document.addEventListener('click', function(e) {
    if (e.target.closest('.add-new-shortcut')) {
      if (functionSelector) {
        functionSelector.scrollIntoView({ behavior: 'smooth' });
      }
    }
  });
  
  // Initialize
  loadQuickActions();
  updateFunctionSelector();
});
