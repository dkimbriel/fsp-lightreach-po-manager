# frozen_string_literal: true

class DeviseCreateUsers < ActiveRecord::Migration[7.2]
  def change
    create_table :users do |t|
      ## Email (required for Google OAuth)
      t.string :email, null: false, default: ""

      ## Google OAuth fields
      t.string :full_name
      t.string :uid  # Google OAuth UID

      t.timestamps null: false
    end

    add_index :users, :email, unique: true
  end
end
