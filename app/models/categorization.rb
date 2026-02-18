class Categorization < ApplicationRecord
  audited async: true

  include Discard::Model

  belongs_to :categorizable, polymorphic: true
  belongs_to :category
end
