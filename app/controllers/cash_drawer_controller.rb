# frozen_string_literal: true

class CashDrawerController < ApplicationController
  include Filterable

  authorize_resource class: CashDrawerSession

  before_action :set_current_session, only: %i[show new_close create_close]

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
      redirect_to session_detail_cash_drawer_path(@session), notice: "Register closed successfully."
    else
      render :new_close, status: :unprocessable_entity
    end
  end

  # GET /cash_drawer/history
  def history
    @pagy, @sessions = filter_and_paginate(
      CashDrawerSession.includes(:opened_by, :closed_by),
      search: false,
      sort_allowed: %w[opened_at closed_at opening_total_cents closing_total_cents],
      sort_default: "opened_at",
      sort_default_direction: "desc"
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

    def parse_denomination_counts(raw_counts)
      return {} if raw_counts.blank?

      raw_counts.to_unsafe_h.each_with_object({}) do |(key, value), hash|
        qty = value.to_i
        hash[key] = qty if qty > 0 && CashDrawerSession::DENOMINATION_KEYS.include?(key)
      end
    end
end
