# frozen_string_literal: true

module FilterableByDate
  extend ActiveSupport::Concern

  DATE_FILTER_PARAMS = %w[ created_at_from created_at_to updated_at_from updated_at_to ].freeze

  private

    def apply_date_filters(scope)
      scope = scope.where("created_at >= ?", parse_date_to_beginning(params[:created_at_from])) if params[:created_at_from].present? && parse_date_to_beginning(params[:created_at_from])
      scope = scope.where("created_at <= ?", parse_date_to_end(params[:created_at_to])) if params[:created_at_to].present? && parse_date_to_end(params[:created_at_to])
      scope = scope.where("updated_at >= ?", parse_date_to_beginning(params[:updated_at_from])) if params[:updated_at_from].present? && parse_date_to_beginning(params[:updated_at_from])
      scope = scope.where("updated_at <= ?", parse_date_to_end(params[:updated_at_to])) if params[:updated_at_to].present? && parse_date_to_end(params[:updated_at_to])
      scope
    end

    def parse_date_to_beginning(value)
      return nil if value.blank?

      Time.zone.parse(value.to_s).beginning_of_day
    rescue ArgumentError
      nil
    end

    def parse_date_to_end(value)
      return nil if value.blank?

      Time.zone.parse(value.to_s).end_of_day
    rescue ArgumentError
      nil
    end
end
