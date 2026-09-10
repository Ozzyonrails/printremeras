class CreateIdentity < ActiveRecord::Migration[8.1]
  def change
    create_table :users do |t|
      t.citext :email, null: false
      t.string :password_digest
      t.string :first_name, null: false, default: ""
      t.string :last_name, null: false, default: ""
      t.string :phone
      t.string :locale, null: false, default: "es"
      t.datetime :confirmed_at
      t.string :google_uid
      t.datetime :last_sign_in_at
      t.timestamps
    end
    add_index :users, :email, unique: true
    add_index :users, :google_uid, unique: true, where: "google_uid IS NOT NULL"

    create_table :admin_users do |t|
      t.citext :email, null: false
      t.string :password_digest, null: false
      t.string :name, null: false
      t.string :role, null: false, default: "operator" # operator | admin
      t.string :locale, null: false, default: "es"
      t.boolean :active, null: false, default: true
      t.timestamps
    end
    add_index :admin_users, :email, unique: true

    create_table :guest_sessions do |t|
      t.string :token, null: false
      t.datetime :last_seen_at
      t.datetime :expires_at, null: false
      t.datetime :merged_at
      t.bigint :merged_into_user_id
      t.timestamps
    end
    add_index :guest_sessions, :token, unique: true
    add_index :guest_sessions, :expires_at

    create_table :addresses do |t|
      t.references :user, null: false, foreign_key: true
      t.string :recipient_name, null: false
      t.string :phone, null: false
      t.string :street, null: false
      t.string :number, null: false
      t.string :apartment
      t.string :floor
      t.string :neighborhood, null: false
      t.string :postal_code, null: false
      t.string :city, null: false, default: "CABA"
      t.text :notes
      t.boolean :is_default, null: false, default: false
      t.timestamps
    end
  end
end
