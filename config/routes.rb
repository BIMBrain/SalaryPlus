Rails.application.routes.draw do
  resources :employees do
    get "inactive", on: :collection
    get "parttimers", on: :collection

    resources :salaries
    get "salaries/recent/:employee_id", to: "salaries#recent", as: :salaries_recent

    resources :terms
  end

  resources :payrolls, except: [:new, :create, :show]
  get "payrolls/init_regulars/:year/:month", to: "payrolls#init_regulars", as: :init_regulars, constraints: { year: /\d{4}/, month: /\d{1,2}/ }
  get "payrolls/parttimers/:year/:month", to: "payrolls#parttimers", as: :parttimers, constraints: { year: /\d{4}/, month: /\d{1,2}/ }
  post "payrolls/parttimers/:year/:month", to: "payrolls#init_parttimers", constraints: { year: /\d{4}/, month: /\d{1,2}/ }

  resources :statements, only: [:index, :show, :edit, :update]

  resources :reports, only: [:index] do
    collection do
      get "salary/:year", to: "reports#salary", as: :salary, constraints: { year: /\d{4}/ }
      get "service/:year", to: "reports#service", as: :service, constraints: { year: /\d{4}/ }
      get "irregular/:year", to: "reports#irregular", as: :irregular, constraints: { year: /\d{4}/ }
      get "monthly/:year/:month", to: "reports#monthly", as: :monthly, constraints: { year: /\d{4}/, month: /\d{1,2}/ }
    end
  end

  resources :attendances do
    collection do
      post :quick_punch
      get :daily_summary
      get :monthly_report
      get :export
    end
  end

  resources :overtime, only: [:index, :show] do
    collection do
      get :batch_calculate
      get :compliance_report
      get :rates
    end
    member do
      get :calculate
    end
  end

  resources :insurance_statements do
    collection do
      get :dashboard
      post :batch_reconcile
      post :import
      get :export
    end
    member do
      patch :reconcile
      patch :resolve
    end
  end

  # Employee Portal Routes
  get 'employee/login', to: 'employee_auth#login', as: :employee_login
  post 'employee/authenticate', to: 'employee_auth#authenticate', as: :employee_authenticate
  delete 'employee/logout', to: 'employee_auth#logout', as: :employee_logout

  scope 'employee', as: 'employee_portal' do
    get '/', to: 'employee_portal#index', as: :index
    get '/payrolls', to: 'employee_portal#payrolls', as: :payrolls
    get '/payroll/:id', to: 'employee_portal#payroll', as: :payroll
    get '/insurance', to: 'employee_portal#insurance', as: :insurance
    get '/tax_documents', to: 'employee_portal#tax_documents', as: :tax_documents
    get '/attendance', to: 'employee_portal#attendance', as: :attendance
    get '/profile', to: 'employee_portal#profile', as: :profile
    get '/download_payslip/:id', to: 'employee_portal#download_payslip', as: :download_payslip
    get '/download_tax_statement', to: 'employee_portal#download_tax_statement', as: :download_tax_statement
  end

  resources :bank_transfers do
    collection do
      post :batch_create_salary_transfers
      post :generate_transfer_file
      post :import_transfer_results
      post :batch_process
      get :statistics
      get :transfer_report
    end
    member do
      patch :process
      patch :complete
      patch :cancel
    end
  end

  resources :system_settings do
    collection do
      patch :batch_update
      patch :reset_defaults
      get :export
      post :import
      post :calculation_preview
      post :initialize_defaults
      patch :update_ui_preference
      patch :update_style_template
      patch :update_custom_style
    end
  end

  root to: "home#index"
end
