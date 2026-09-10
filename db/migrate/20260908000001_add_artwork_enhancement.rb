class AddArtworkEnhancement < ActiveRecord::Migration[8.1]
  def change
    # Low-resolution artwork is accepted and marked instead of being rejected, so it can
    # be sent to an upscaling provider later (see ImageEnhancement::Provider).
    change_table :designs, bulk: true do |t|
      t.string :enhancement_status, null: false, default: "none" # none|needed|requested|processing|done|failed
      t.string :enhancement_provider
      t.text :enhancement_note
      t.datetime :enhancement_requested_at
      t.datetime :enhanced_at
      t.integer :enhanced_width_px
      t.integer :enhanced_height_px
    end
    add_index :designs, :enhancement_status

    add_column :orders, :low_quality_artwork, :boolean, null: false, default: false
    add_index :orders, :low_quality_artwork, where: "low_quality_artwork"
  end
end
