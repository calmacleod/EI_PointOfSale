# frozen_string_literal: true

class SavedQueriesController < ApplicationController
  before_action :set_saved_query, only: :destroy

  def create
    @saved_query = current_user.saved_queries.build(saved_query_params)

    if @saved_query.save
      respond_to do |format|
        format.turbo_stream { render turbo_stream: turbo_stream.append("saved_queries_list", partial: "saved_queries/saved_query", locals: { saved_query: @saved_query }) }
        format.html { redirect_back fallback_location: root_path, notice: "Query saved." }
      end
    else
      respond_to do |format|
        format.turbo_stream { head :unprocessable_entity }
        format.html { redirect_back fallback_location: root_path, alert: "Could not save query." }
      end
    end
  end

  def destroy
    authorize! :destroy, @saved_query
    @saved_query.destroy
    respond_to do |format|
      format.turbo_stream { render turbo_stream: turbo_stream.remove(@saved_query) }
      format.html { redirect_back fallback_location: root_path, notice: "Query deleted." }
    end
  end

  private

    def set_saved_query
      @saved_query = current_user.saved_queries.find(params[:id])
    end

    def saved_query_params
      params.require(:saved_query).permit(:name, :resource_type, query_params: {})
    end
end
