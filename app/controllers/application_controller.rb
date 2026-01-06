class ApplicationController < ActionController::Base
  include Authentication
  include CanCan::ControllerAdditions
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  # Changes to the importmap will invalidate the etag for HTML responses
  stale_when_importmap_changes

  helper_method :current_user

  rescue_from CanCan::AccessDenied do
    redirect_to(root_path, alert: "Not authorized.", status: :see_other)
  end

  private

    def current_user
      Current.user
    end
end
