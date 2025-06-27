# SalaryPlus 薪資計算系統 - 開發指導

## 項目概述

SalaryPlus 是一個基於 Ruby on Rails 6.1.7.4 的薪資計算系統，提供完整的員工薪資管理功能。

## 系統環境

- **作業系統**: Ubuntu 22.04
- **Ruby 版本**: 2.7.6
- **Rails 版本**: 6.1.7.4
- **資料庫**: PostgreSQL 14.3
- **Web 服務器**: Puma

## 項目結構

```
SalaryPlus/
├── app/                    # 應用程序核心代碼
│   ├── assets/            # 前端資源 (CSS, JS, 圖片)
│   ├── controllers/       # 控制器
│   ├── models/           # 模型
│   └── views/            # 視圖模板
├── config/               # 配置文件
│   ├── database.yml      # 資料庫配置
│   ├── application.yml   # 應用程序配置
│   └── routes.rb         # 路由配置
├── db/                   # 資料庫相關
│   ├── migrate/          # 資料庫遷移文件
│   └── seeds.rb          # 種子資料
└── public/               # 靜態文件
```

## 主要功能模組

1. **員工管理** (`/employees`)
   - 員工基本資料管理
   - 薪資設定
   - 到職/離職管理

2. **薪資計算** (`/payrolls`)
   - 月薪制員工薪資計算
   - 兼職外包薪資計算
   - 加班費計算

3. **出勤管理** (`/attendances`)
   - 員工打卡記錄
   - 請假管理

4. **報表系統**
   - 年度報表
   - 薪資統計
   - 勞健保比對

## 開發環境設置

### 1. 環境準備

```bash
# 安裝 Ruby 依賴
sudo apt update
sudo apt install -y git curl libssl-dev libreadline-dev zlib1g-dev autoconf bison build-essential libyaml-dev libncurses5-dev libffi-dev libgdbm-dev postgresql postgresql-contrib libpq-dev

# 安裝 rbenv
curl -fsSL https://github.com/rbenv/rbenv-installer/raw/HEAD/bin/rbenv-installer | bash

# 設置環境變數
echo 'export PATH="$HOME/.rbenv/bin:$PATH"' >> ~/.bashrc
echo 'eval "$(rbenv init -)"' >> ~/.bashrc
source ~/.bashrc

# 安裝 Ruby 2.7.6
rbenv install 2.7.6
rbenv global 2.7.6
```

### 2. 項目設置

```bash
# 克隆項目
git clone https://github.com/BIMBrain/SalaryPlus.git
cd SalaryPlus

# 安裝 gems
gem install bundler -v 2.4.22
bundle install

# 配置資料庫
cp config/database.yml.sample config/database.yml
cp config/application.yml.sample config/application.yml

# 設置 PostgreSQL
sudo service postgresql start
sudo -u postgres createuser -s ubuntu

# 創建資料庫並執行遷移
bundle exec rails db:create
RAILS_ENV=development bundle exec rails db:migrate
```

### 3. 啟動開發服務器

```bash
# 啟動 Rails 服務器
bundle exec rails server -b 0.0.0.0 -p 3000
```

## 公共訪問

系統已部署到公共環境，可通過以下 URL 訪問：
**https://3000-i7kium0317xrnh64r7q30-6634148f.manusvm.computer**

## 二次開發指導

### 1. 添加新功能

#### 創建新的控制器
```bash
bundle exec rails generate controller NewFeature index show
```

#### 創建新的模型
```bash
bundle exec rails generate model NewModel name:string description:text
bundle exec rails db:migrate
```

### 2. 修改現有功能

#### 員工管理擴展
- 位置：`app/controllers/employees_controller.rb`
- 模型：`app/models/employee.rb`
- 視圖：`app/views/employees/`

#### 薪資計算邏輯
- 位置：`app/controllers/payrolls_controller.rb`
- 模型：`app/models/payroll.rb`
- 計算邏輯：`app/models/salary_calculator.rb`

### 3. 前端自定義

#### 樣式修改
- CSS 文件：`app/assets/stylesheets/`
- 使用 Bootstrap 和 SASS

#### JavaScript 功能
- JS 文件：`app/assets/javascripts/`
- 主要功能：`application.js`, `employees.js`

### 4. 資料庫操作

#### 創建新的遷移
```bash
bundle exec rails generate migration AddFieldToTable field:type
bundle exec rails db:migrate
```

#### 回滾遷移
```bash
bundle exec rails db:rollback
```

### 5. 測試

#### 運行測試
```bash
bundle exec rails test
```

#### 創建測試
```bash
bundle exec rails generate test_unit:model ModelName
```

## 重要配置文件

### database.yml
```yaml
development:
  adapter: postgresql
  encoding: unicode
  database: salaryplus_development
  username: ubuntu
  pool: 5
```

### application.yml
包含應用程序的環境變數和配置選項。

## 常用指令

```bash
# 重新啟動服務器
bundle exec rails server -b 0.0.0.0 -p 3000

# 進入 Rails 控制台
bundle exec rails console

# 查看路由
bundle exec rails routes

# 資料庫重置
bundle exec rails db:reset

# 安裝新的 gem
bundle install

# 更新 gems
bundle update
```

## 故障排除

### 1. 資料庫連接問題
- 確認 PostgreSQL 服務運行：`sudo service postgresql status`
- 檢查資料庫配置：`config/database.yml`

### 2. 端口佔用
```bash
# 查找佔用端口的進程
sudo netstat -tlnp | grep :3000
# 終止進程
sudo kill -9 <PID>
```

### 3. Gem 安裝問題
```bash
# 清理 bundle 快取
bundle clean --force
# 重新安裝
bundle install
```

## 聯絡資訊

- **原作者**: BIMBrain (ppson0@gmail.com)
- **GitHub**: https://github.com/BIMBrain/SalaryPlus
- **授權**: MIT License

## 注意事項

1. 這是開發環境配置，生產環境需要額外的安全性配置
2. 定期備份資料庫
3. 敏感資料請妥善保管
4. 建議使用版本控制追蹤變更

---

*此文檔由 Manus AI 自動生成，基於實際部署過程整理*

