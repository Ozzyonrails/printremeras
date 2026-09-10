# Puma configuration.
#
# Single mode in development (forking a preloaded app with live database
# connections is fragile, and reloading works better without workers).
# Clustered mode in production when WEB_CONCURRENCY > 0.

rails_env = ENV.fetch("RAILS_ENV", "development")

threads_count = ENV.fetch("RAILS_MAX_THREADS", 3).to_i
threads threads_count, threads_count

port ENV.fetch("PORT", 3000)
environment rails_env
pidfile ENV["PIDFILE"] if ENV["PIDFILE"]

plugin :tmp_restart

# Run Solid Queue inside Puma for single-container deployments. The default
# docker-compose runs a dedicated worker container instead.
plugin :solid_queue if ENV["SOLID_QUEUE_IN_PUMA"]

# Puma reads WEB_CONCURRENCY on its own, so `workers` is always set explicitly here:
# development must stay in single mode even when the shared .env sets WEB_CONCURRENCY.
workers_count = rails_env == "development" ? 0 : ENV.fetch("WEB_CONCURRENCY", 0).to_i
workers workers_count

if workers_count > 0
  preload_app!

  # Close inherited database connections before forking; each worker opens its own.
  before_fork do
    ActiveRecord::Base.connection_handler.clear_all_connections!(:all) if defined?(ActiveRecord::Base)
  end

  on_worker_boot do
    ActiveRecord::Base.connection_handler.clear_all_connections!(:all) if defined?(ActiveRecord::Base)
  end
end
