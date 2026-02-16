class ApplicationController < ActionController::Base
  include Authentication
  include CanCan::ControllerAdditions
  include Pagy::Method
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

    # Replace dashes (and other tsquery-unsafe characters) with spaces
    # so codes like "WH-BLK-001" become "WH BLK 001" and don't break
    # PostgreSQL's to_tsquery parser.
    def sanitize_search_query(query)
      query.to_s.gsub(/[-]/, " ").squish.presence
    end
end
