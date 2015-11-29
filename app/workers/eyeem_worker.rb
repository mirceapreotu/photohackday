class EyeemWorker < BaseWorker
  sidekiq_options unique: true, expiration: 5.minutes, retry: 5

  def perform(opts = {})
    return if (image = Sidekiq.redis do |redis| ;  redis.get("pending:#{ opts["stream_id"] }:#{ opts["image_name"] }") ; end).nil?

    image          = JSON.parse(image)
    eyeem_response = `curl -i -XGET #{ image['eyeem_location'] } -H "Authorization: #{ Rails.application.config_for(:app_config)['eyeem_api_token'] }"`

    if /HTTP\/1.1 200 OK/.match(eyeem_response)
      parts         = /{"aestheticsScore":(.*),"concepts\":(.*)}/.match(eyeem_response)
      image['tags'] = JSON.parse(parts[2])

      current_stream = Stream.find(opts['stream_id'])
      notifications  = []
      current_stream.subscriptions.each do |s|
        notifications << s if image['tags'].include?(s)
      end
      current_stream.update({ notifications: notifications }) unless notifications.empty?

      Sidekiq.redis do |redis|
        redis.set "images:#{ opts["stream_id"] }:#{ opts["image_name"] }", JSON.generate(image)
        redis.del "pending:#{ opts["stream_id"] }:#{ opts["image_name"] }"
      end
    elsif /HTTP\/1.1 404 Not Found/.match(eyeem_response)
        retry_in = /{"location":(.*),"retryAfter":(.*)}/.match(eyeem_response)[2].to_i
        EyeemWorker.perform_in retry_in, opts                      
    else      
      raise StandardError, "eyeem api call failed (opts=#{ opts.to_yaml } ; response=#{ eyeem_response })"
    end
  end
end