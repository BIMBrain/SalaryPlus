class CreateAttendances < ActiveRecord::Migration[6.1]
  def change
    create_table :attendances do |t|
      t.references :employee, null: false, foreign_key: true
      t.datetime :punch_time, null: false
      t.string :punch_type, null: false
      t.string :punch_method, null: false
      t.string :location
      t.string :ip_address
      t.text :notes
      t.decimal :latitude, precision: 10, scale: 6
      t.decimal :longitude, precision: 10, scale: 6
      t.string :device_info
      t.boolean :is_manual, default: false
      t.references :approved_by, foreign_key: { to_table: :employees }, null: true
      t.datetime :approved_at
      
      t.timestamps
    end
    
    add_index :attendances, [:employee_id, :punch_time]
    add_index :attendances, :punch_time
    add_index :attendances, :punch_type
  end
end
