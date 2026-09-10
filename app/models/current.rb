class Current < ActiveSupport::CurrentAttributes
  attribute :user, :guest_session, :admin_user, :locale, :request_id
end
