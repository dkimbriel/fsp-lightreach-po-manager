class CreatePoGenerationJobs < ActiveRecord::Migration[7.2]
  def change
    create_table :po_generation_jobs do |t|
      t.references :user, null: false, foreign_key: true
      t.string :job_type, null: false  # 'region', 'batch', 'single'
      t.string :status, default: 'pending'  # pending, running, completed, failed

      # Job parameters
      t.string :region
      t.json :project_ids  # Array of project IDs

      # Results
      t.integer :total_projects, default: 0
      t.integer :successful_pos, default: 0
      t.integer :failed_pos, default: 0
      t.json :po_results

      # Locking mechanism
      t.datetime :locked_at
      t.string :locked_by  # Worker ID

      # Completion
      t.datetime :started_at
      t.datetime :completed_at
      t.text :error_message

      t.timestamps
    end

    add_index :po_generation_jobs, [:status, :region]
    add_index :po_generation_jobs, :locked_at
  end
end
