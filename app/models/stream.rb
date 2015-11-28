class Stream
  include ActiveModel::Validations
  include Rails.application.routes.url_helpers

  def default_url_options
    {
        host: 'localhost', port: '3000', protocol: 'http'
    }
  end

  attr_accessor :id
  attr_accessor :meta
  attr_accessor :alerts

  def initialize(options = {})
    options.each { |acc, value| send("#{ acc }=", value) }
  end

  def self.find(id)
    meta_json = Sidekiq.redis do |redis| ; redis.get("stream:#{ id }"); end || raise(NotFoundError, "cannot find stream `#{ id }`")
    meta      = JSON.parse(meta_json)

    self.new({ id: id, meta: meta })
  end

  def self.delete(id)
    # Sidekiq.redis do |redis| ; redis.del("stream:#{ id }:*") ; end
  end

  def alerts
    return meta['alerts'] if meta && meta['updated_at']
    []
  end

  def created_at
    meta['created_at'] if meta && meta['created_at']
    current_time_in_timezone
  end

  def updated_at
    meta['updated_at'] if meta && meta['updated_at']
    current_time_in_timezone
  end

  def last
    # returns last image
    binding.pry
  end

  def push(image)
    # save to filesystem
    image_directory = "#{ Rails.application.config_for(:app_config)['upload_directory'] }/#{ id }"
    image_name      = current_time_in_timezone.to_i.to_s

    FileUtils.mkdir_p(image_directory) unless File.directory?(image_directory)
    File.open("#{ image_directory }/#{ image_name }.png", "wb") { |f| f.write(image.read) }

    # save to redis
    Sidekiq.redis do |redis|
      json_data = JSON.generate({ image_name: "#{ image_name }.png", image_url: '', eyeem: {tags: [], resource_url: ""}, created_at: current_time_in_timezone })
      redis.set "stream:#{ self.id }:#{ image_name }", json_data
    end

    # call eyeem api

    # schedule worker in *retry seconds
    # ExpireWorker.perform_in 5, { stream_id: id, image_name: image_name }
  end

  def save!
    @id ||= SecureRandom.base64(24)

    Sidekiq.redis do |redis|
      raise StandardError, 'duplicate stream found' if !!(Sidekiq.redis do |redis| ; redis.get("stream:#{ id }"); end)

      json_data = JSON.generate({ alerts: alerts, created_at: created_at, updated_at: updated_at })

      redis.set "stream:#{ self.id }", json_data
    end

    self
  end

  private

  def current_time_in_timezone
    Time.now.in_time_zone Rails.application.config_for(:app_config)['timezone']
  end
end