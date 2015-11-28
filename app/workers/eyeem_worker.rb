class EyeemWorker < BaseWorker
  sidekiq_options unique: true, expiration: 5.minutes, retry: 5

  def perform(opts = {})
    binding.pry
  end
end