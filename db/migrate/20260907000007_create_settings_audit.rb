class CreateSettingsAudit < ActiveRecord::Migration[8.1]
  def change
    create_table :settings do |t|
      t.string :key, null: false
      t.jsonb :value
      t.timestamps
    end
    add_index :settings, :key, unique: true

    create_table :audit_logs do |t|
      t.references :admin_user, foreign_key: true
      t.string :action, null: false
      t.string :subject_type
      t.bigint :subject_id
      t.jsonb :change_set, null: false, default: {}
      t.datetime :created_at, null: false
    end
    add_index :audit_logs, [ :subject_type, :subject_id ]
    add_index :audit_logs, :created_at
  end
end
