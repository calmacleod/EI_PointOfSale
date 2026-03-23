class OfflineController < ApplicationController
  allow_unauthenticated_access only: :show

  def show
    response.headers["Cache-Control"] = "no-store"
    render layout: "offline"
  end
end
