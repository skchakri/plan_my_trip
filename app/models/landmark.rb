class Landmark < ApplicationRecord
  validates :name, :country, presence: true
end
