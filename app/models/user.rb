class User < ApplicationRecord
  audited async: true, except: [ :password_digest, :theme, :font_size, :sidebar_collapsed, :dashboard_metric_keys ]

  include PgSearch::Model
  include AsyncPgSearch

  multisearchable against: [ :name, :email_address, :notes ]
  pg_search_scope :search, against: [ :name, :email_address, :notes ], using: { tsearch: { prefix: true }, trigram: {} }

  has_secure_password
  has_many :sessions, dependent: :destroy
  has_many :notifications, dependent: :destroy
  has_many :push_subscriptions, dependent: :destroy
  has_many :saved_queries, dependent: :destroy
  has_many :store_tasks, foreign_key: :assigned_to_id, dependent: :nullify, inverse_of: :assigned_to

  normalizes :email_address, with: ->(e) { e.strip.downcase }

  validates :email_address, presence: true, uniqueness: true
  validates :theme, inclusion: { in: %w[light dark dim] }, allow_nil: false
  validates :font_size, inclusion: { in: %w[default large xlarge] }, allow_nil: false

  def visible_dashboard_metric_keys
    return DashboardMetrics.available_keys if dashboard_metric_keys.blank?

    dashboard_metric_keys & DashboardMetrics.available_keys
  end

  # For profile form: when user has never set preferences, show all as selected.
  def dashboard_metric_keys_for_form
    dashboard_metric_keys.presence || DashboardMetrics.available_keys
  end
end
