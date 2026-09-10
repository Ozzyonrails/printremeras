class CreatePayments < ActiveRecord::Migration[8.1]
  def change
    create_table :payments do |t|
      t.references :order, null: false, foreign_key: true
      t.string :provider, null: false
      t.string :provider_payment_id
      t.string :provider_preference_id
      t.string :flow, null: false, default: "redirect" # redirect | qr
      t.integer :amount_cents, null: false
      t.string :currency, null: false, default: "ARS"
      t.string :status, null: false, default: "pending" # pending | approved | rejected | refunded
      t.string :external_reference, null: false
      t.string :checkout_url
      t.text :qr_data
      t.jsonb :raw_payload, null: false, default: {}
      t.datetime :approved_at
      t.timestamps
    end
    add_index :payments, [ :provider, :provider_payment_id ], unique: true, where: "provider_payment_id IS NOT NULL"
    add_index :payments, :external_reference

    create_table :payment_events do |t|
      t.string :provider, null: false
      t.string :provider_event_id, null: false
      t.string :event_type
      t.jsonb :payload, null: false, default: {}
      t.references :order, foreign_key: true
      t.datetime :processed_at
      t.string :result
      t.timestamps
    end
    add_index :payment_events, [ :provider, :provider_event_id ], unique: true
  end
end
