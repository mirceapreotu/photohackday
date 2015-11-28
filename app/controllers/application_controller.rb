class ApplicationController < ActionController::Base
  # Prevent CSRF attacks by raising an exception.
  # For APIs, you may want to use :null_session instead.
  protect_from_forgery with: :exception, only: [:new_stream]

  layout :mobile_or_desktop, only: :stream

  before_filter :require_stream_name!, only: [:stream, :play, :record]

  def new_stream
    redirect_to stream_url(name: initialize_new_stream.id)
  end

  def stream
  end

  def play
  end

  def record
    current_stream.push(current_image)

    render json: {success: true}, status: 201
  rescue
    render json: { success: false }, status: 500
  end

  private

  def mobile_or_desktop
    if browser.mobile?
      'mobile'
    else
      'desktop'
    end
  end

  def initialize_new_stream
    Stream.new.save!
  end

  def require_stream_name!
    params.require(:name)
  end

  def current_image
    params[:image]
  end

  def current_stream
    @current_stream ||= Stream.find params.require(:name)
  end
end
