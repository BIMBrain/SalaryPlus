class CreateInsuranceStatements < ActiveRecord::Migration[6.1]
  def change
    create_table :insurance_statements do |t|
      t.string :statement_type, null: false
      t.integer :year, null: false
      t.integer :month, null: false
      t.decimal :statement_amount, precision: 10, scale: 2, null: false, default: 0
      t.decimal :calculated_amount, precision: 10, scale: 2
      t.string :reconciliation_status, null: false, default: 'pending'
      t.string :statement_file_path
      t.text :resolution_notes
      t.datetime :resolved_at
      t.datetime :uploaded_at

      t.timestamps
    end

    add_index :insurance_statements, [:statement_type, :year, :month], unique: true, name: 'index_insurance_statements_unique'
    add_index :insurance_statements, :reconciliation_status
    add_index :insurance_statements, [:year, :month]
  end
end
