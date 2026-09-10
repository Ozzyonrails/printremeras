class Address < ApplicationRecord
  belongs_to :user

  validates :recipient_name, :phone, :street, :number, :neighborhood, :postal_code, :city, presence: true

  before_save :ensure_single_default

  def one_line
    [ "#{street} #{number}", [ floor.presence && "Piso #{floor}", apartment.presence && "Depto #{apartment}" ].compact.join(" "), neighborhood, city, postal_code ].reject(&:blank?).join(", ")
  end

  def to_snapshot
    slice(:recipient_name, :phone, :street, :number, :apartment, :floor, :neighborhood, :postal_code, :city, :notes).merge("id" => id)
  end

  private

  def ensure_single_default
    return unless is_default? && user
    user.addresses.where.not(id: id).update_all(is_default: false)
  end
end
