class Stream
  include ActiveModel::Validations
  include Rails.application.routes.url_helpers

  def default_url_options
    {
        host: Rails.application.config_for(:app_config)['hostname'],
        port: Rails.application.config_for(:app_config)['port'],
        protocol: 'http'
    }
  end

  attr_accessor :id
  attr_accessor :meta

  attr_accessor :subscriptions
  attr_accessor :notifications

  def initialize(options = {})
    options.each { |acc, value| send("#{ acc }=", value) }
  end

  def self.active
    streams = []
    Sidekiq.redis do |redis|
      redis.keys("streams:*").each do |key|
        stream_id = key.gsub('streams:', '')
        next if self.stream_empty?(stream_id)

        streams << self.find(stream_id)
      end
    end
    streams
  end

  def self.find(id)
    meta_json = Sidekiq.redis do |redis| ; redis.get("streams:#{ id }"); end || raise(StandardError, "cannot find stream `#{ id }`")
    meta      = JSON.parse(meta_json)

    self.new({ id: id, meta: meta })
  end

  def update(opts = {})
    opts.each do |key, value| ; meta[key.to_s] = value ; end

    Sidekiq.redis do |redis|
      json_data = JSON.generate({ notifications: notifications, subscriptions: subscriptions, created_at: created_at, updated_at: updated_at })

      redis.set "streams:#{ self.id }", json_data
    end

    self
  end

  def save!
    @id ||= Digest::SHA1.hexdigest("#{ SecureRandom.uuid }#{ current_time_in_timezone.to_i }")

    Sidekiq.redis do |redis|
      raise StandardError, 'duplicate stream found' if !!(Sidekiq.redis do |redis| ; redis.get("streams:#{ id }"); end)

      json_data = JSON.generate({ notifications: notifications, subscriptions: subscriptions, created_at: created_at, updated_at: updated_at })

      redis.set "streams:#{ self.id }", json_data
    end

    self
  end

  def self.delete(id)
    Sidekiq.redis do |redis|
      redis.del("streams:#{ id }")
      redis.del("images:#{ id }:*")
    end
  end

  def notifications
    return meta['notifications'] if meta && meta['notifications']
    []
  end

  def subscriptions
    return meta['subscriptions'] if meta && meta['subscriptions']
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
    Sidekiq.redis do |redis|
      last_key = redis.keys("images:#{ id }:*").map{ |k| k.gsub("images:#{ id }:", '').try(:to_i) }.max
      JSON.parse redis.get("images:#{ id }:#{ last_key }")
    end
  rescue
    {}
  end

  def push(image)
    # save to filesystem
    image_directory = "#{ Rails.application.config_for(:app_config)['upload_directory'] }/#{ id }"
    image_name      = current_time_in_timezone.to_i.to_s
    image_url       = "#{ root_url }stream/#{ id }/#{ image_name }.png"

    FileUtils.mkdir_p(image_directory) unless File.directory?(image_directory)
    File.open("#{ image_directory }/#{ image_name }.png", "wb") { |f| f.write(image.read) }

    # call eyeem api
    eyeem_response = begin
      res = `curl -i -XPOST #{ Rails.application.config_for(:app_config)['eyeem_api_host'] } -H "Authorization: #{ Rails.application.config_for(:app_config)['eyeem_api_token'] }" -T #{ image_directory }/#{ image_name }.png`
      raise StandardError, "eyeem api call failed (response=#{ eyeem_response })" unless /HTTP\/1.1 201 Created/.match(res)

      parts = /{"location":(.*),"retryAfter":(.*)}/.match(res)

      { location: parts[1].gsub(%r{\"}, ''), retryAfter: parts[2].to_i }
    end

    # save to redis
    Sidekiq.redis do |redis|
      json_data = JSON.generate({ image_name: "#{ image_name }.png", image_url: image_url, eyeem_location: eyeem_response[:location], tags: [], created_at: current_time_in_timezone })
      redis.set "pending:#{ self.id }:#{ image_name }", json_data
    end

    # schedule worker in *retry seconds
    EyeemWorker.perform_in eyeem_response[:retryAfter], { stream_id: id, image_name: image_name }
  end

  private

  def current_time_in_timezone
    Time.now.in_time_zone Rails.application.config_for(:app_config)['timezone']
  end

  def self.stream_empty?(stream_id)
    (Sidekiq.redis do |redis| ; redis.keys("images:#{ stream_id }:*") ; end).empty?
  end
end