require "sidekiq/web"

# Protect the Sidekiq dashboard (it exposes recipient emails and lets anyone
# retry/kill jobs) with HTTP Basic auth when credentials are configured. Left
# open when they aren't, so local dev and the test suite are unaffected.
if ENV["SIDEKIQ_WEB_USER"].present? && ENV["SIDEKIQ_WEB_PASSWORD"].present?
  Sidekiq::Web.use(Rack::Auth::Basic) do |user, password|
    ActiveSupport::SecurityUtils.secure_compare(user, ENV["SIDEKIQ_WEB_USER"]) &
      ActiveSupport::SecurityUtils.secure_compare(password, ENV["SIDEKIQ_WEB_PASSWORD"])
  end
end
