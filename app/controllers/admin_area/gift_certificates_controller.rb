# frozen_string_literal: true

module AdminArea
  class GiftCertificatesController < BaseController
    include Filterable

    before_action :set_gift_certificate, only: :show

    def index
      authorize! :read, GiftCertificate

      @filter_config = FilterConfig.new(
        :gift_certificates,
        admin_gift_certificates_path,
        sort_default: "created_at",
        sort_default_direction: "desc",
        search_placeholder: "Search by code…"
      ) do |f|
        f.select :status, label: "Status",
                 options: GiftCertificate.statuses.keys.map { |s| [ s.humanize, s ] }
        f.number_range :initial_amount,    label: "Initial Amount"
        f.number_range :remaining_balance, label: "Remaining Balance"
        f.date_range   :created_at,        label: "Issued"

        f.column :code,              label: "Code",      default: true,  sortable: true
        f.column :status,            label: "Status",    default: true
        f.column :initial_amount,    label: "Initial",   default: true,  sortable: true
        f.column :remaining_balance, label: "Remaining", default: true,  sortable: true
        f.column :customer,          label: "Customer",  default: true
        f.column :sold_on_order,     label: "Order",     default: false
        f.column :created_at,        label: "Issued",    default: true,  sortable: true
      end
      @saved_queries = current_user.saved_queries.for_resource("gift_certificates")

      @pagy, @gift_certificates = filter_and_paginate(
        GiftCertificate.includes(:customer, :sold_on_order),
        config: @filter_config
      )
    end

    def show
      authorize! :read, @gift_certificate
      @redemptions = OrderPayment.where(gift_certificate: @gift_certificate)
                                 .includes(:order, :received_by)
                                 .order(created_at: :desc)
      @audits = @gift_certificate.audits.order(created_at: :desc).limit(20)
    end

    private

      def set_gift_certificate
        @gift_certificate = GiftCertificate.find(params[:id])
      end
  end
end
