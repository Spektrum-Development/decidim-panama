# frozen_string_literal: true

redis_url = ENV["SIDEKIQ_REDIS_URL"].presence || ENV["REDIS_URL"].presence

if defined?(Sidekiq) && redis_url.present?
  Sidekiq.configure_server do |config|
    config.redis = { url: redis_url }
  end

  Sidekiq.configure_client do |config|
    config.redis = { url: redis_url }
  end
end
