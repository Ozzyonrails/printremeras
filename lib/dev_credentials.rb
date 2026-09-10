# Demo accounts created by db/seeds.rb in development, and the one place their passwords
# are written down. The login screens offer them as click-to-fill shortcuts.
#
# `enabled?` gates both the admin view and the JSON the storefront receives.
#
# On by default in development only. A container running RAILS_ENV=production (the docker
# compose stack) can opt in with SHOW_DEV_CREDENTIALS=true, which is how you demo the
# shortcuts outside development; the login screens then carry a visible "demo" warning and
# the app logs one at boot, so an accidentally public deployment announces itself.
# HIDE_DEV_CREDENTIALS=true always wins and switches the shortcuts off.
module DevCredentials
  CUSTOMER = {
    email: "cliente@printremeras.local",
    password: "password123",
    first_name: "Camila",
    last_name: "Gómez"
  }.freeze

  OPERATOR = {
    email: "operator@printremeras.local",
    password: "changeme-operator-1",
    name: "Operador",
    role: "operator"
  }.freeze

  module_function

  def enabled?
    return false if ENV["HIDE_DEV_CREDENTIALS"] == "true"
    Rails.env.development? || forced?
  end

  # True when the shortcuts are on somewhere other than development, i.e. deliberately.
  def forced?
    !Rails.env.development? && ENV["SHOW_DEV_CREDENTIALS"] == "true"
  end

  # The admin follows ADMIN_EMAIL / ADMIN_PASSWORD so the shortcut always matches what
  # the seeds actually created.
  def admin
    { email: ENV.fetch("ADMIN_EMAIL", "admin@printremeras.local"),
      password: ENV.fetch("ADMIN_PASSWORD", "changeme-admin-1"),
      name: "Admin", role: "admin" }.freeze
  end

  def staff_accounts = [ admin, OPERATOR ]
  def customer_accounts = [ CUSTOMER ]

  # Shapes used by the admin login view and the storefront settings payload.
  def staff_list
    return [] unless enabled?
    staff_accounts.map { |a| { email: a[:email], password: a[:password], label: a[:role] } }
  end

  def customer_list
    return [] unless enabled?
    customer_accounts.map { |a| { email: a[:email], password: a[:password], label: "#{a[:first_name]} #{a[:last_name]}" } }
  end
end
