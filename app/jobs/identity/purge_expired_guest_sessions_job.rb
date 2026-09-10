module Identity
  class PurgeExpiredGuestSessionsJob < ApplicationJob
    queue_as :default

    def perform
      cutoff = Setting.guest_retention_days.days.ago
      GuestSession.where("expires_at < ? OR (merged_at IS NOT NULL AND merged_at < ?)", Time.current, cutoff).find_each do |guest|
        guest.designs.where(source: "user").find_each { |d| d.destroy if d.placements.none? }
        guest.destroy
      end
    end
  end
end
