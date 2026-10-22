# frozen_string_literal: true

class HelpController < ApplicationController
  before_action { authorize! :read, :help }

  def index
    @guides = Help::Guide.visible_to(current_user)
  end

  def show
    @guides = Help::Guide.visible_to(current_user)
    @guide = @guides.find { |guide| guide.fetch("slug") == params[:id] }
    raise ActiveRecord::RecordNotFound unless @guide
  end
end
