# frozen_string_literal: true

module AdminArea
  class AuditsController < BaseController
    include Filterable

    AUDIT_ACTIONS = %w[create update destroy].freeze

    def show
      @audit = Audited::Audit.find(params[:id])
    end

    def index
      @filter_config = FilterConfig.new(:audits, admin_audits_path,
                                        sort_default: "created_at", sort_default_direction: "desc",
                                        search: false) do |f|
        f.select :action, label: "Action",
                 options: AUDIT_ACTIONS.map { |a| [ a.capitalize, a ] }

        f.select :auditable_type, label: "Model",
                 options: Audited::Audit.distinct.pluck(:auditable_type).compact.sort.map { |t| [ t, t ] }

        f.association :user_id, label: "User",
                      collection: -> { users_with_audits_collection },
                      display: :email_address,
                      scope: ->(s, v) { s.where(user_type: "User", user_id: v) }

        f.date_range :created_at, label: "Date"

        f.column :created_at,     label: "When",    default: true,  sortable: true
        f.column :action,         label: "Action",  default: true
        f.column :auditable_type, label: "Model",   default: true
        f.column :record,         label: "Record",  default: true
        f.column :user,           label: "User",    default: true
        f.column :details,        label: "Details", default: true
      end
      @saved_queries = current_user.saved_queries.for_resource("audits")

      @pagy, @audits = filter_and_paginate(
        Audited::Audit.all,
        config: @filter_config,
        items: 25
      )
    end

    private

      def users_with_audits_collection
        User.where(id: Audited::Audit.where(user_type: "User").select(:user_id).distinct)
            .order(:email_address)
      end
  end
end
