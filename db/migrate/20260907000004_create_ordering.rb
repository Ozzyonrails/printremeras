class CreateOrdering < ActiveRecord::Migration[8.1]
  def change
    create_table :carts do |t|
      t.string :owner_type, null: false
      t.bigint :owner_id, null: false
      t.timestamps
    end
    add_index :carts, [ :owner_type, :owner_id ], unique: true

    create_table :cart_items do |t|
      t.references :cart, null: false, foreign_key: true
      t.references :template, null: false, foreign_key: true
      t.references :template_size, null: false, foreign_key: true
      t.references :catalog_item, foreign_key: true
      t.integer :quantity, null: false, default: 1
      t.timestamps
    end

    create_table :coupons do |t|
      t.string :code, null: false
      t.string :discount_type, null: false # percentage | fixed_amount
      t.integer :discount_value, null: false
      t.references :owner, foreign_key: { to_table: :users }
      t.string :source, null: false, default: "manual" # review_reward | manual | campaign
      t.integer :max_uses
      t.integer :used_count, null: false, default: 0
      t.integer :min_order_cents
      t.datetime :valid_from
      t.datetime :valid_until
      t.boolean :active, null: false, default: true
      t.text :note
      t.timestamps
    end
    add_index :coupons, :code, unique: true

    create_table :orders do |t|
      t.references :user, null: false, foreign_key: true
      t.string :number, null: false
      t.string :status, null: false, default: "draft"
      t.string :locale, null: false, default: "es"
      t.string :currency, null: false, default: "ARS"
      t.integer :subtotal_cents, null: false, default: 0
      t.integer :discount_cents, null: false, default: 0
      t.boolean :rush, null: false, default: false
      t.integer :rush_fee_cents, null: false, default: 0
      t.integer :shipping_fee_cents, null: false, default: 0
      t.integer :total_cents, null: false, default: 0
      t.string :shipping_method, null: false # pickup | courier
      t.jsonb :shipping_address, null: false, default: {}
      t.references :coupon, foreign_key: true
      t.string :coupon_code
      t.boolean :requires_moderation, null: false, default: false
      t.text :customer_notes
      t.text :rejection_reason
      t.text :problem_note
      t.datetime :placed_at
      t.datetime :paid_at
      t.datetime :delivered_at
      t.datetime :cancelled_at
      t.timestamps
    end
    add_index :orders, :number, unique: true
    add_index :orders, :status
    add_index :orders, [ :user_id, :created_at ]

    create_table :order_items do |t|
      t.references :order, null: false, foreign_key: true
      t.references :template, null: false, foreign_key: true
      t.references :template_size, null: false, foreign_key: true
      t.references :catalog_item, foreign_key: true
      t.integer :quantity, null: false, default: 1
      t.integer :unit_price_cents, null: false
      t.integer :line_total_cents, null: false
      t.integer :sides_count, null: false, default: 0
      t.jsonb :snapshot, null: false, default: {} # template name, colour, size label, price breakdown
      t.timestamps
    end

    create_table :order_status_transitions do |t|
      t.references :order, null: false, foreign_key: true
      t.string :from_status
      t.string :to_status, null: false
      t.string :actor_type
      t.bigint :actor_id
      t.text :reason
      t.datetime :created_at, null: false
    end

    create_table :coupon_redemptions do |t|
      t.references :coupon, null: false, foreign_key: true
      t.references :order, null: false, foreign_key: true
      t.references :user, foreign_key: true
      t.integer :discount_cents, null: false
      t.datetime :restored_at
      t.timestamps
    end
    add_index :coupon_redemptions, [ :coupon_id, :order_id ], unique: true
  end
end
