class UsState < ApplicationRecord
  validates :name, :capital, :abbreviation, presence: true
end
