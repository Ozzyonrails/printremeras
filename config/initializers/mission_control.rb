# Job dashboard is mounted at /admin/jobs behind the admin session (see routes.rb).
# These are assigned directly rather than through config.mission_control.jobs.*, because
# the engine copies that configuration before app initializers run.
Rails.application.config.after_initialize do
  MissionControl::Jobs.base_controller_class = "Admin::BaseController"
  MissionControl::Jobs.http_basic_auth_enabled = false
  MissionControl::Jobs.back_to_main_app_path = "/admin"
end
