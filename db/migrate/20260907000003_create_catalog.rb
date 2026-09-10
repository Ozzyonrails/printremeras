class CreateCatalog < ActiveRecord::Migration[8.1]
  def change
    create_table :templates do |t|
      t.string :kind, null: false, default: "t-shirt"
      t.jsonb :name, null: false, default: {}
      t.jsonb :description, null: false, default: {}
      t.string :slug, null: false
      t.string :color_name, null: false
      t.string :color_hex, null: false, default: "#ffffff"
      t.integer :base_price_cents, null: false, default: 0
      t.integer :print_price_one_side_cents, null: false, default: 0
      t.integer :print_price_two_sides_cents, null: false, default: 0
      t.boolean :active, null: false, default: false
      t.integer :position, null: false, default: 0
      t.timestamps
    end
    add_index :templates, :slug, unique: true
    add_index :templates, [ :active, :position ]

    create_table :print_areas do |t|
      t.references :template, null: false, foreign_key: true
      t.string :side, null: false # front | back
      t.decimal :x, precision: 8, scale: 6, null: false, default: 0.25
      t.decimal :y, precision: 8, scale: 6, null: false, default: 0.2
      t.decimal :w, precision: 8, scale: 6, null: false, default: 0.5
      t.decimal :h, precision: 8, scale: 6, null: false, default: 0.5
      t.decimal :width_mm, precision: 8, scale: 2, null: false, default: 280
      t.decimal :height_mm, precision: 8, scale: 2, null: false, default: 380
      t.integer :min_dpi, null: false, default: 150
      t.integer :mockup_width_px
      t.integer :mockup_height_px
      t.timestamps
    end
    add_index :print_areas, [ :template_id, :side ], unique: true

    create_table :template_sizes do |t|
      t.references :template, null: false, foreign_key: true
      t.string :label, null: false
      t.integer :stock, null: false, default: 0
      t.date :restock_at
      t.integer :position, null: false, default: 0
      t.timestamps
    end
    add_index :template_sizes, [ :template_id, :label ], unique: true

    create_table :designs do |t|
      t.string :owner_type
      t.bigint :owner_id
      t.string :source, null: false, default: "user" # user | catalog
      t.integer :width_px
      t.integer :height_px
      t.string :content_type
      t.bigint :byte_size
      t.string :moderation_status, null: false, default: "pending"
      t.text :license_note
      t.string :original_filename
      t.timestamps
    end
    add_index :designs, [ :owner_type, :owner_id ]

    create_table :catalog_items do |t|
      t.references :template, null: false, foreign_key: true
      t.jsonb :title, null: false, default: {}
      t.jsonb :description, null: false, default: {}
      t.string :slug, null: false
      t.integer :price_cents, null: false, default: 0
      t.string :tags, array: true, null: false, default: []
      t.boolean :published, null: false, default: false
      t.integer :position, null: false, default: 0
      t.timestamps
    end
    add_index :catalog_items, :slug, unique: true
    add_index :catalog_items, :tags, using: :gin
    add_index :catalog_items, [ :published, :position ]

    create_table :placements do |t|
      t.references :design, null: false, foreign_key: true
      t.references :print_area, null: false, foreign_key: true
      t.string :placeable_type, null: false
      t.bigint :placeable_id, null: false
      t.decimal :x, precision: 8, scale: 6, null: false, default: 0.5
      t.decimal :y, precision: 8, scale: 6, null: false, default: 0.5
      t.decimal :scale, precision: 8, scale: 6, null: false, default: 1.0
      t.decimal :rotation, precision: 8, scale: 3, null: false, default: 0
      t.timestamps
    end
    add_index :placements, [ :placeable_type, :placeable_id ]
  end
end
