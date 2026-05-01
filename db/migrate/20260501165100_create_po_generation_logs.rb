class CreatePoGenerationLogs < ActiveRecord::Migration[7.2]
  def change
    create_table :po_generation_logs do |t|
      t.references :po_generation_job, null: false, foreign_key: true
      t.string :level, null: false  # info, success, warning, error
      t.text :message, null: false
      t.json :metadata  # Additional context

      t.timestamps
    end

    add_index :po_generation_logs, [:po_generation_job_id, :created_at]
  end
end
