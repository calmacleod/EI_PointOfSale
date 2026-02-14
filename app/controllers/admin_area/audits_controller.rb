# frozen_string_literal: true

module AdminArea
  class AuditsController < BaseController
    AUDIT_ACTIONS = %w[create update destroy].freeze

    def index
      scope = Audited::Audit.reorder(created_at: :desc)
      scope = apply_audit_filters(scope)

      @audit_action_options = [ [ "All actions", "" ] ] + AUDIT_ACTIONS.map { |a| [ a.capitalize, a ] }
      @auditable_type_options = [ [ "All models", "" ] ] + Audited::Audit.distinct.pluck(:auditable_type).compact.sort.map { |t| [ t, t ] }
      @user_options = [ [ "All users", "" ] ] + users_with_audits

      @pagy, @audits = pagy(scope, items: 25)
    end

    private

      def apply_audit_filters(scope)
        scope = scope.where(action: params[:audit_action]) if params[:audit_action].present?
        scope = scope.where(auditable_type: params[:auditable_type]) if params[:auditable_type].present?
        scope = apply_user_filter(scope)
        scope = apply_date_filter(scope)
        scope
      end

      def apply_user_filter(scope)
        return scope unless params[:user_id].present?

        scope.where(user_type: "User", user_id: params[:user_id])
      end

      def apply_date_filter(scope)
        return scope unless params[:created_at_from].present? || params[:created_at_to].present?

        scope = scope.where("created_at >= ?", parse_date_start(params[:created_at_from])) if params[:created_at_from].present?
        scope = scope.where("created_at <= ?", parse_date_end(params[:created_at_to])) if params[:created_at_to].present?
        scope
      end

      def parse_date_start(value)
        return nil if value.blank?

        Time.zone.parse(value.to_s).beginning_of_day
      rescue ArgumentError
        nil
      end

      def parse_date_end(value)
        return nil if value.blank?

        Time.zone.parse(value.to_s).end_of_day
      rescue ArgumentError
        nil
      end

      def users_with_audits
        User.where(id: Audited::Audit.where(user_type: "User").select(:user_id).distinct)
            .order(:email_address)
            .pluck(:email_address, :id)
            .map { |email, id| [ email, id.to_s ] }
      end
  end
end
