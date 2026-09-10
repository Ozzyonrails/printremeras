module Identity
  # Reassigns everything a guest session owns to a user. Runs on EVERY authentication
  # (register, login, Google) so work done before signing in is never lost.
  class MergeGuest < ApplicationService
    def initialize(user:, guest_session:)
      @user = user
      @guest = guest_session
    end

    def call
      return success(merged: false) if @guest.nil? || @guest.merged_at.present?

      ActiveRecord::Base.transaction do
        @guest.designs.update_all(owner_type: "User", owner_id: @user.id, updated_at: Time.current)
        merge_carts
        @guest.update!(merged_at: Time.current, merged_into_user_id: @user.id)
      end
      success(merged: true)
    end

    private

    def merge_carts
      guest_cart = @guest.cart
      return if guest_cart.nil?

      user_cart = Cart.find_or_create_by!(owner: @user)
      existing = user_cart.items.includes(:placements).index_by(&:merge_key)
      guest_cart.items.includes(:placements).each do |item|
        if (twin = existing[item.merge_key])
          twin.update!(quantity: twin.quantity + item.quantity)
          item.destroy!
        else
          item.update!(cart: user_cart)
        end
      end
      guest_cart.reload.destroy!
    end
  end
end
