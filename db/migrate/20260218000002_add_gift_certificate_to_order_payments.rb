# frozen_string_literal: true

class AddGiftCertificateToOrderPayments < ActiveRecord::Migration[8.1]
  def change
    add_reference :order_payments, :gift_certificate, foreign_key: true, null: true
  end
end
