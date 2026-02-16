# frozen_string_literal: true

class DevToolsController < ApplicationController
  layout "dev"

  before_action :require_development
  before_action :set_dev_theme

  def show
    # Dev tools index page
  end

  def test_job
    SolidQueueVerificationJob.perform_later
    redirect_to dev_tools_path, notice: "Test job enqueued. Open Mission Control to see it process."
  end

  def reindex_search
    models = [ Product, Service, Customer, User, Category, Supplier, TaxCode ]
    count = 0

    models.each do |model|
      PgSearch::Multisearch.rebuild(model)
      count += model.count
    end

    redirect_to dev_tools_path, notice: "Search index rebuilt for #{models.size} models (#{count} records)."
  end

  private

    def require_development
      raise ActionController::RoutingError, "Not Found" unless Rails.env.development?
    end

    def set_dev_theme
      @dev_theme = %w[light dark dim].include?(params[:theme]) ? params[:theme] : "light"
    end
end
