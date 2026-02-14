class Categorization < ApplicationRecord
  audited

  include Discard::Model

  belongs_to :categorizable, polymorphic: true
  belongs_to :category
end
