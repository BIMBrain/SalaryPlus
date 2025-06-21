// 簡化的主題控制器
(function() {
  'use strict';

  var currentTheme = 'light';

  // 基本主題功能
  function initTheme() {
    currentTheme = localStorage.getItem('fortuna_theme') || 'light';
    document.documentElement.setAttribute('data-theme', currentTheme);

    // 創建主題切換器
    createThemeSwitcher();
    bindEvents();
  }

  function createThemeSwitcher() {
    var switcher = document.createElement('div');
    switcher.className = 'theme-switcher';
    switcher.innerHTML =
      '<div class="theme-option theme-light" data-theme="light" title="淺色模式">' +
        '<i class="fas fa-sun"></i>' +
      '</div>' +
      '<div class="theme-option theme-dark" data-theme="dark" title="深色模式">' +
        '<i class="fas fa-moon"></i>' +
      '</div>' +
      '<div class="theme-option theme-auto" data-theme="auto" title="跟隨系統">' +
        '<i class="fas fa-adjust"></i>' +
      '</div>';

    document.body.appendChild(switcher);
    updateSwitcherState();
  }

  function bindEvents() {
    // 主題切換事件
    document.addEventListener('click', function(e) {
      var themeOption = e.target.closest('.theme-option');
      if (themeOption) {
        var theme = themeOption.getAttribute('data-theme');
        setTheme(theme);
      }
    });

    // 鍵盤快捷鍵
    document.addEventListener('keydown', function(e) {
      // Ctrl/Cmd + Shift + D 切換暗黑模式
      if ((e.ctrlKey || e.metaKey) && e.shiftKey && e.key === 'D') {
        e.preventDefault();
        toggleDarkMode();
      }
    });
  }

  function setTheme(theme) {
    currentTheme = theme;
    document.documentElement.setAttribute('data-theme', theme);
    localStorage.setItem('fortuna_theme', theme);
    updateSwitcherState();
    updateMetaThemeColor(theme);
  }

  function toggleDarkMode() {
    var newTheme = currentTheme === 'dark' ? 'light' : 'dark';
    setTheme(newTheme);
  }

  function updateSwitcherState() {
    var options = document.querySelectorAll('.theme-option');
    for (var i = 0; i < options.length; i++) {
      var option = options[i];
      var isActive = option.getAttribute('data-theme') === currentTheme;
      if (isActive) {
        option.classList.add('active');
      } else {
        option.classList.remove('active');
      }
    }
  }

  function updateMetaThemeColor(theme) {
    var metaThemeColor = document.querySelector('meta[name="theme-color"]');
    if (!metaThemeColor) {
      metaThemeColor = document.createElement('meta');
      metaThemeColor.name = 'theme-color';
      document.head.appendChild(metaThemeColor);
    }
    var color = theme === 'dark' ? '#1c1c1e' : '#ffffff';
    metaThemeColor.content = color;
  }

  // 全域函數
  window.toggleDarkMode = toggleDarkMode;
  window.setTheme = setTheme;

  // 初始化
  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', initTheme);
  } else {
    initTheme();
  }

})();


