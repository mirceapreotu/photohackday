base_sidekiq_coinfig = {
    url:       Rails.application.config_for(:app_config)['redis_host'],
    namespace: Rails.application.config_for(:app_config)['redis_namespace']
}

Sidekiq.configure_server do |config|
  Rails.logger              = Sidekiq::Logging.logger
  ActiveRecord::Base.logger = Sidekiq::Logging.logger

  config.redis         = base_sidekiq_coinfig
  config.poll_interval = Rails.application.config_for(:app_config)['redis_poll_interval']
end

Sidekiq.configure_client do |config|
  config.redis = base_sidekiq_coinfig.merge(size: 1)
end