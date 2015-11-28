class BaseWorker
  include Sidekiq::Worker

  Sidekiq::Worker::ClassMethods.module_eval do
    def client_push(item, retry_count = 0)
      Sidekiq::Client.push(item.stringify_keys)
    rescue
      (retry_count += 1) < 3 ? client_push(item, retry_count) : raise
    end
  end

  def config
    Rails.application.config_for(:app_config)
  end

  def redis_namespace
    "#{ config['redis_namespace'] }"
  end
end
