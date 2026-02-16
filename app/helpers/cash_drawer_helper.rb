# frozen_string_literal: true

module CashDrawerHelper
  def denom_label(key)
    roll_info = CashDrawerSession::COIN_ROLLS[key]
    return roll_info[:label] if roll_info

    key
  end
end
