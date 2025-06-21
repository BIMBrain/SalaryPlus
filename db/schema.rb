# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema.define(version: 2025_06_19_154000) do

  # These are extensions that must be enabled in order to support this database
  enable_extension "plpgsql"

  create_table "attendances", force: :cascade do |t|
    t.bigint "employee_id", null: false
    t.datetime "punch_time", null: false
    t.string "punch_type", null: false
    t.string "punch_method", null: false
    t.string "location"
    t.string "ip_address"
    t.text "notes"
    t.decimal "latitude", precision: 10, scale: 6
    t.decimal "longitude", precision: 10, scale: 6
    t.string "device_info"
    t.boolean "is_manual", default: false
    t.bigint "approved_by_id"
    t.datetime "approved_at"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.index ["approved_by_id"], name: "index_attendances_on_approved_by_id"
    t.index ["employee_id", "punch_time"], name: "index_attendances_on_employee_id_and_punch_time"
    t.index ["employee_id"], name: "index_attendances_on_employee_id"
    t.index ["punch_time"], name: "index_attendances_on_punch_time"
    t.index ["punch_type"], name: "index_attendances_on_punch_type"
  end

  create_table "corrections", force: :cascade do |t|
    t.integer "statement_id"
    t.integer "amount", default: 0
    t.string "description"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["statement_id"], name: "index_corrections_on_statement_id"
  end

  create_table "employees", force: :cascade do |t|
    t.string "name"
    t.string "company_email"
    t.string "personal_email"
    t.string "id_number"
    t.string "residence_address"
    t.date "birthday"
    t.string "bank_account"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "bank_transfer_type", default: "salary"
    t.boolean "b2b", default: false
    t.boolean "owner", default: false
    t.string "employee_number"
    t.string "chinese_name"
    t.string "english_name"
    t.string "gender"
    t.string "marital_status"
    t.string "nationality"
    t.string "phone_number"
    t.string "mobile_number"
    t.string "emergency_contact_name"
    t.string "emergency_contact_relationship"
    t.string "emergency_contact_phone"
    t.text "current_address"
    t.text "mailing_address"
    t.string "education_level"
    t.string "school_name"
    t.string "major"
    t.integer "graduation_year"
    t.string "previous_company"
    t.string "previous_position"
    t.string "previous_work_period"
    t.decimal "work_experience_years", precision: 3, scale: 1
    t.string "spouse_name"
    t.string "spouse_id_number"
    t.date "spouse_birthday"
    t.integer "children_count", default: 0
    t.string "labor_insurance_number"
    t.string "health_insurance_number"
    t.string "pension_account"
    t.string "blood_type"
    t.decimal "height", precision: 5, scale: 2
    t.decimal "weight", precision: 5, scale: 2
    t.string "military_service_status"
    t.string "driver_license"
    t.text "special_skills"
    t.text "languages"
    t.text "hobbies"
    t.text "health_condition"
    t.text "notes"
    t.string "department"
    t.string "position"
    t.string "job_title"
    t.string "employment_type"
    t.integer "probation_period"
    t.string "work_location"
    t.decimal "basic_salary", precision: 10, scale: 2
    t.decimal "allowances", precision: 10, scale: 2
    t.decimal "performance_bonus", precision: 10, scale: 2
    t.date "hire_date"
    t.date "resignation_date"
    t.text "resignation_reason"
    t.string "photo_url"
    t.index ["department"], name: "index_employees_on_department"
    t.index ["employee_number"], name: "index_employees_on_employee_number", unique: true
    t.index ["hire_date"], name: "index_employees_on_hire_date"
    t.index ["position"], name: "index_employees_on_position"
  end

  create_table "extra_entries", force: :cascade do |t|
    t.string "title"
    t.integer "amount", default: 0
    t.string "note"
    t.integer "payroll_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "income_type", default: "salary"
    t.index ["payroll_id"], name: "index_extra_entries_on_payroll_id"
  end

  create_table "insurance_statements", force: :cascade do |t|
    t.string "statement_type", null: false
    t.integer "year", null: false
    t.integer "month", null: false
    t.decimal "statement_amount", precision: 10, scale: 2, default: "0.0", null: false
    t.decimal "calculated_amount", precision: 10, scale: 2
    t.string "reconciliation_status", default: "pending", null: false
    t.string "statement_file_path"
    t.text "resolution_notes"
    t.datetime "resolved_at"
    t.datetime "uploaded_at"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.index ["reconciliation_status"], name: "index_insurance_statements_on_reconciliation_status"
    t.index ["statement_type", "year", "month"], name: "index_insurance_statements_unique", unique: true
    t.index ["year", "month"], name: "index_insurance_statements_on_year_and_month"
  end

  create_table "overtimes", force: :cascade do |t|
    t.date "date"
    t.string "rate"
    t.decimal "hours", default: "0.0"
    t.integer "payroll_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["payroll_id"], name: "index_overtimes_on_payroll_id"
  end

  create_table "payrolls", force: :cascade do |t|
    t.integer "year"
    t.integer "month"
    t.decimal "parttime_hours", default: "0.0"
    t.decimal "leavetime_hours", default: "0.0"
    t.decimal "sicktime_hours", default: "0.0"
    t.decimal "vacation_refund_hours", default: "0.0"
    t.integer "employee_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "salary_id"
    t.integer "festival_bonus", default: 0
    t.string "festival_type"
    t.index ["employee_id"], name: "index_payrolls_on_employee_id"
    t.index ["month"], name: "index_payrolls_on_month"
    t.index ["salary_id"], name: "index_payrolls_on_salary_id"
    t.index ["year"], name: "index_payrolls_on_year"
  end

  create_table "salaries", force: :cascade do |t|
    t.string "role"
    t.string "tax_code", default: "50"
    t.integer "monthly_wage", default: 0
    t.integer "hourly_wage", default: 0
    t.date "effective_date"
    t.integer "equipment_subsidy", default: 0
    t.integer "commuting_subsidy", default: 0
    t.integer "supervisor_allowance", default: 0
    t.integer "labor_insurance", default: 0
    t.integer "health_insurance", default: 0
    t.integer "employee_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "insured_for_health", default: 0
    t.integer "insured_for_labor", default: 0
    t.string "cycle", default: "normal"
    t.decimal "monthly_wage_adjustment", default: "1.0"
    t.integer "fixed_income_tax", default: 0
    t.boolean "split", default: false
    t.integer "term_id"
    t.index ["effective_date"], name: "index_salaries_on_effective_date"
    t.index ["employee_id"], name: "index_salaries_on_employee_id"
  end

  create_table "statements", force: :cascade do |t|
    t.integer "amount", default: 0
    t.integer "year"
    t.integer "month"
    t.integer "splits", array: true
    t.integer "payroll_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "subsidy_income", default: 0
    t.integer "excess_income", default: 0
    t.jsonb "gain"
    t.jsonb "loss"
    t.integer "correction", default: 0
    t.index ["payroll_id"], name: "index_statements_on_payroll_id"
  end

  create_table "system_settings", force: :cascade do |t|
    t.string "setting_key", null: false
    t.string "setting_name", null: false
    t.string "setting_type", null: false
    t.string "data_type", null: false
    t.text "setting_value"
    t.text "description"
    t.text "formula"
    t.boolean "is_active", default: true
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.index ["is_active"], name: "index_system_settings_on_is_active"
    t.index ["setting_key"], name: "index_system_settings_on_setting_key", unique: true
    t.index ["setting_type"], name: "index_system_settings_on_setting_type"
  end

  create_table "terms", force: :cascade do |t|
    t.date "start_date"
    t.date "end_date"
    t.integer "employee_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["employee_id"], name: "index_terms_on_employee_id"
    t.index ["end_date"], name: "index_terms_on_end_date"
    t.index ["start_date"], name: "index_terms_on_start_date"
  end

  add_foreign_key "attendances", "employees"
  add_foreign_key "attendances", "employees", column: "approved_by_id"

  create_view "payroll_details", sql_definition: <<-SQL
      SELECT DISTINCT employees.id AS employee_id,
      payrolls.id AS payroll_id,
      payrolls.year,
      payrolls.month,
      salaries.tax_code,
      salaries.monthly_wage,
      salaries.insured_for_health,
      statements.splits,
      statements.amount,
      statements.subsidy_income,
      statements.excess_income,
      employees.owner
     FROM (((employees
       JOIN payrolls ON ((employees.id = payrolls.employee_id)))
       JOIN salaries ON ((salaries.id = payrolls.salary_id)))
       JOIN statements ON ((payrolls.id = statements.payroll_id)))
    WHERE (employees.b2b = false);
  SQL
  create_view "salary_trackers", sql_definition: <<-SQL
      SELECT employees.id AS employee_id,
      terms.id AS term_id,
      salaries.id AS salary_id,
      employees.name,
      terms.start_date AS term_start,
      terms.end_date AS term_end,
      salaries.role,
      salaries.effective_date AS salary_start
     FROM ((employees
       JOIN terms ON ((employees.id = terms.employee_id)))
       JOIN salaries ON ((employees.id = salaries.employee_id)))
    WHERE (salaries.term_id = terms.id);
  SQL
  create_view "reports", sql_definition: <<-SQL
      SELECT DISTINCT employees.id AS employee_id,
      payrolls.id AS payroll_id,
      employees.name,
      employees.id_number,
      employees.residence_address,
      payrolls.year,
      payrolls.month,
      salaries.tax_code,
      statements.amount,
      statements.subsidy_income,
      statements.gain,
      statements.loss,
      statements.correction,
      payrolls.festival_bonus,
      payrolls.festival_type
     FROM ((((employees
       JOIN payrolls ON ((employees.id = payrolls.employee_id)))
       JOIN salaries ON ((salaries.id = payrolls.salary_id)))
       JOIN statements ON ((payrolls.id = statements.payroll_id)))
       LEFT JOIN corrections ON ((statements.id = corrections.statement_id)))
    WHERE (employees.b2b = false)
    GROUP BY employees.id, payrolls.id, statements.id, salaries.tax_code;
  SQL
end
