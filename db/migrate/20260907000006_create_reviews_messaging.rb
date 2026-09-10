class CreateReviewsMessaging < ActiveRecord::Migration[8.1]
  def change
    create_table :reviews do |t|
      t.references :order, null: false, foreign_key: true, index: { unique: true }
      t.references :user, null: false, foreign_key: true
      t.integer :rating, null: false
      t.text :body
      t.string :status, null: false, default: "pending"
      t.text :rejection_reason
      t.references :reviewed_by, foreign_key: { to_table: :admin_users }
      t.datetime :reviewed_at
      t.boolean :published, null: false, default: true
      t.references :coupon, foreign_key: true
      t.integer :submission_count, null: false, default: 1
      t.timestamps
    end
    add_index :reviews, [ :status, :published ]

    create_table :conversations do |t|
      t.references :user, null: false, foreign_key: true, index: { unique: true }
      t.datetime :last_message_at
      t.integer :unread_for_admin, null: false, default: 0
      t.integer :unread_for_user, null: false, default: 0
      t.timestamps
    end

    create_table :messages do |t|
      t.references :conversation, null: false, foreign_key: true
      t.string :sender_type, null: false
      t.bigint :sender_id, null: false
      t.text :body, null: false, default: ""
      t.references :order, foreign_key: true
      t.datetime :read_at
      t.timestamps
    end
    add_index :messages, [ :conversation_id, :created_at ]
  end
end
