class EyeemWorker < BaseWorker
  sidekiq_options unique: true, expiration: 5.minutes, retry: 5

  def perform(opts = {})
    image = Sidekiq.redis do |redis| ;  redis.get("pending:#{ opts["stream_id"] }:#{ opts["image_name"] }") ; end || raise(StandardError, 'image not found')
    image = JSON.parse(image)

    image['tags'] = begin
      res   = `curl -i -XGET #{ image['eyeem_location'] } -H "Authorization: #{ Rails.application.config_for(:app_config)['eyeem_api_token'] }"`
      raise StandardError, "eyeem api call failed (response=#{ res })" unless /HTTP\/1.1 200 OK/.match(res)

      parts = /{"aestheticsScore":(.*),"concepts\":(.*)}/.match(res)
      JSON.parse(parts[2])
    end

    Sidekiq.redis do |redis|
      redis.set "images:#{ opts["stream_id"] }:#{ opts["image_name"] }", JSON.generate(image)
      redis.del "pending:#{ opts["stream_id"] }:#{ opts["image_name"] }"
    end
  end
end