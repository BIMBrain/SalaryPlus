class CreateAttendanceRecords < ActiveRecord::Migration[6.1]
  def change
    create_table :attendance_records do |t|
      t.references :employee, null: false, foreign_key: true
      t.date :attendance_date, null: false
      t.string :day_of_week
      t.boolean :is_holiday, default: false
      
      # 普通工時
      t.decimal :regular_hours_required, precision: 4, scale: 2, default: 0
      t.decimal :regular_hours_actual, precision: 4, scale: 2, default: 0
      t.decimal :regular_hours_extra, precision: 4, scale: 2, default: 0
      
      # 平時加班
      t.decimal :weekday_overtime_required, precision: 4, scale: 2, default: 0
      t.decimal :weekday_overtime_actual, precision: 4, scale: 2, default: 0
      t.decimal :weekday_overtime_extra, precision: 4, scale: 2, default: 0
      
      # 週末加班
      t.decimal :weekend_overtime_required, precision: 4, scale: 2, default: 0
      t.decimal :weekend_overtime_actual, precision: 4, scale: 2, default: 0
      t.decimal :weekend_overtime_extra, precision: 4, scale: 2, default: 0
      
      # 申請假期（天數）
      t.decimal :personal_leave_days, precision: 3, scale: 1, default: 0      # 事假
      t.decimal :menstrual_leave_days, precision: 3, scale: 1, default: 0     # 生理假
      t.decimal :annual_leave_days, precision: 3, scale: 1, default: 0        # 年假
      t.decimal :sick_leave_days, precision: 3, scale: 1, default: 0          # 病假
      t.decimal :compensatory_leave_days, precision: 3, scale: 1, default: 0  # 調休
      t.decimal :business_trip_days, precision: 3, scale: 1, default: 0       # 出差
      
      # 時段記錄
      t.time :shift1_clock_in
      t.time :shift1_clock_out
      t.boolean :shift1_late, default: false
      t.boolean :shift1_early_leave, default: false
      t.boolean :shift1_absent, default: false
      
      # 加班時段1
      t.decimal :overtime1_required, precision: 4, scale: 2, default: 0
      t.decimal :overtime1_actual, precision: 4, scale: 2, default: 0
      t.decimal :overtime1_extra, precision: 4, scale: 2, default: 0
      t.time :overtime1_clock_in
      t.time :overtime1_clock_out
      t.boolean :overtime1_late, default: false
      t.boolean :overtime1_early_leave, default: false
      t.boolean :overtime1_absent, default: false
      
      # 加班時段2
      t.time :overtime2_clock_in
      t.time :overtime2_clock_out
      t.boolean :overtime2_late, default: false
      t.boolean :overtime2_early_leave, default: false
      t.boolean :overtime2_absent, default: false
      
      # 異常記錄（次數）
      t.integer :late_count, default: 0
      t.integer :early_leave_count, default: 0
      t.integer :absent_count, default: 0
      t.integer :missing_punch_count, default: 0
      
      # 篩選和狀態
      t.string :filter_status
      t.string :exception_status
      t.text :notes
      
      t.timestamps
    end
    
    add_index :attendance_records, [:employee_id, :attendance_date], unique: true
    add_index :attendance_records, :attendance_date
    add_index :attendance_records, :is_holiday
    add_index :attendance_records, [:attendance_date, :is_holiday]
  end
end

