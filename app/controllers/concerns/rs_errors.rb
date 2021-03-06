module RsErrors
  extend ActiveSupport::Concern
  included do
    if Rails.env.production? || Rails.env.staging?
      rescue_from Exception, with: :render_500
      rescue_from ActionController::RoutingError, with: :render_404
      #rescue_from ActionController::UnknownController, with: :render_404
      rescue_from ActionController::MissingFile, with: :render_404
      if RocketCMS.mongoid?
        rescue_from Mongoid::Errors::DocumentNotFound, with: :render_404
        rescue_from Mongoid::Errors::InvalidFind, with: :render_404
      end
      if RocketCMS.active_record?
        rescue_from ActiveRecord::RecordNotFound, with: :render_404
      end
    end

    if defined?(CanCan)
      rescue_from CanCan::AccessDenied do |exception|
        if !user_signed_in?
          #scope = rails_admin? ? main_app : self
          #redirect_to scope.new_user_session_path, alert: "Необходимо авторизоваться"
          authenticate_user!
        else
          redirect_to '/', alert: t('rs.errors.access_denied')
        end
      end
    end

    rescue_from ActionController::InvalidAuthenticityToken do |exception|
      redirect_to '/', alert: t('rs.errors.form_expired')
    end
  end

  # http://stackoverflow.com/questions/13432987/rescue-from-abstractcontrolleractionnotfound-not-working
  def process(action, *args)
    super
  rescue AbstractController::ActionNotFound => e
    render_404(e)
  end

  private

  def render_404(exception = nil)
    Rails.logger.error "404: #{request.url}"
    unless exception.nil?
      Rails.logger.error exception.message
      Rails.logger.error exception.backtrace.join("\n")
      capture_error(exception)
    end
    render_error(404)
  end

  def render_500(exception)
    Rails.logger.error "500: #{request.url}"
    Rails.logger.error exception.message
    Rails.logger.error exception.backtrace.join("\n")
    capture_error(exception)
    begin
      if rails_admin?
        render text: t('rs.errors.internal_error_full', klass: exception.class.name, message: SmartExcerpt.h.strip_tags(exception.message)), status: 500
        return
      end
    rescue Exception => e
      puts "error while rendering rails admin exception"
      puts e.class.name
      puts e.message
      puts e.backtrace.join("\n")
    end
    render_error(500)
  end

  def capture_error(exception)
    return unless defined?(Raven)
    # Raven's capture_exception helper method is not defined in rails_admin
    Raven.capture_exception(exception)
  end

  def render_error(code = 500)
    render template: "errors/error_#{code}", formats: [:html], handlers: [:haml, :slim], layout: RocketCMS.config.error_layout, status: code
  end

  def rails_admin?
    self.is_a?(RailsAdmin::ApplicationController) || self.is_a?(RailsAdmin::MainController)
  end
end
