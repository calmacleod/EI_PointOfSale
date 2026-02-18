# frozen_string_literal: true

class CashDrawerController < ApplicationController
  include Filterable

  authorize_resource class: CashDrawerSession

  before_action :set_current_session, only: %i[show new_close create_close]
  before_action :set_reconcile_session, only: %i[new_reconcile create_reconcile]

  # GET /cash_drawer
  def show
    @session = CashDrawerSession.current
  end

  # GET /cash_drawer/open
  def new_open
    if CashDrawerSession.register_open?
      redirect_to cash_drawer_path, alert: "Register is already open."
      return
    end

    @session = CashDrawerSession.new
  end

  # POST /cash_drawer/open
  def create_open
    if CashDrawerSession.register_open?
      redirect_to cash_drawer_path, alert: "Register is already open."
      return
    end

    counts = parse_denomination_counts(params[:counts])
    total_cents = CashDrawerSession.calculate_total_cents(counts)

    @session = CashDrawerSession.new(
      opened_by: current_user,
      opened_at: Time.current,
      opening_counts: counts,
      opening_total_cents: total_cents,
      notes: params[:notes]
    )

    if @session.save
      redirect_to cash_drawer_path, notice: "Register opened successfully."
    else
      render :new_open, status: :unprocessable_entity
    end
  end

  # GET /cash_drawer/close
  def new_close
    redirect_to cash_drawer_path, alert: "Register is not open." unless @session
  end

  # POST /cash_drawer/close
  def create_close
    unless @session
      redirect_to cash_drawer_path, alert: "Register is not open."
      return
    end

    counts = parse_denomination_counts(params[:counts])
    total_cents = CashDrawerSession.calculate_total_cents(counts)

    @session.assign_attributes(
      closed_by: current_user,
      closed_at: Time.current,
      closing_counts: counts,
      closing_total_cents: total_cents,
      notes: [ @session.notes, params[:notes] ].compact_blank.join("\n---\n")
    )

    if @session.save
      redirect_to reconcile_cash_drawer_path, notice: "Cash drawer closed. Now reconcile the payment terminal."
    else
      render :new_close, status: :unprocessable_entity
    end
  end

  # GET /cash_drawer/reconcile
  def new_reconcile
    unless @session
      redirect_to cash_drawer_path, alert: "No session pending reconciliation."
      return
    end

    @reconciliation = TerminalReconciliation.new(
      cash_drawer_session: @session,
      expected_debit_total: @session.electronic_payments_total(:debit),
      expected_credit_total: @session.electronic_payments_total(:credit)
    )
  end

  # POST /cash_drawer/reconcile
  def create_reconcile
    unless @session
      redirect_to cash_drawer_path, alert: "No session pending reconciliation."
      return
    end

    @reconciliation = TerminalReconciliation.new(
      terminal_reconciliation_params.merge(
        cash_drawer_session: @session,
        expected_debit_total: @session.electronic_payments_total(:debit),
        expected_credit_total: @session.electronic_payments_total(:credit),
        reconciled_by: current_user,
        reconciled_at: Time.current
      )
    )

    if @reconciliation.save
      redirect_to session_detail_cash_drawer_path(@session), notice: "Terminal reconciled successfully."
    else
      render :new_reconcile, status: :unprocessable_entity
    end
  end

  # GET /cash_drawer/history
  def history
    @filter_config = FilterConfig.new(:cash_drawer_history, history_cash_drawer_path,
                                      search: false) do |f|
      f.date_range :opened_at, label: "Opened"

      f.column :opened_at,            label: "Opened",     default: true, sortable: true
      f.column :opened_by,            label: "Opened by",  default: true
      f.column :closed_at,            label: "Closed",     default: true, sortable: true
      f.column :closed_by,            label: "Closed by",  default: true
      f.column :opening_total_cents,  label: "Opening",    default: true, sortable: true
      f.column :closing_total_cents,  label: "Closing",    default: true, sortable: true
      f.column :diff,                 label: "Diff",       default: true
    end
    @saved_queries = current_user.saved_queries.for_resource("cash_drawer_history")

    @pagy, @sessions = filter_and_paginate(
      CashDrawerSession.includes(:opened_by, :closed_by),
      config: @filter_config
    )
  end

  # GET /cash_drawer/history/:id
  def session_detail
    @session = CashDrawerSession.find(params[:id])
  end

  private

    def set_current_session
      @session = CashDrawerSession.current
    end

    def set_reconcile_session
      @session = CashDrawerSession.pending_reconciliation
    end

    def terminal_reconciliation_params
      params.permit(:debit_total, :credit_total, :notes)
    end

    def parse_denomination_counts(raw_counts)
      return {} if raw_counts.blank?

      raw_counts.to_unsafe_h.each_with_object({}) do |(key, value), hash|
        qty = value.to_i
        hash[key] = qty if qty > 0 && CashDrawerSession::DENOMINATION_KEYS.include?(key)
      end
    end
end
