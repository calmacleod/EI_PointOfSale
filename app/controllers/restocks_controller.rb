# frozen_string_literal: true

class RestocksController < ApplicationController
  load_and_authorize_resource :product
  load_and_authorize_resource :restock, through: :product

  def index
    @restocks = @product.restocks.includes(:user).order(created_at: :desc)
    @pagy, @restocks = pagy(@restocks, limit: 20)
  end
end
