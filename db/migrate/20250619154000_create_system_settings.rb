class CreateSystemSettings < ActiveRecord::Migration[6.1]
  def change
    create_table :system_settings do |t|
      t.string :setting_key, null: false
      t.string :setting_name, null: false
      t.string :setting_type, null: false
      t.string :data_type, null: false
      t.text :setting_value
      t.text :description
      t.text :formula
      t.boolean :is_active, default: true
      t.timestamps
    end
    
    add_index :system_settings, :setting_key, unique: true
    add_index :system_settings, :setting_type
    add_index :system_settings, :is_active
  end
end
