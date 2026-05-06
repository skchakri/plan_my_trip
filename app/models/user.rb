class User < ApplicationRecord
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable

  has_many :owned_trips, class_name: "Trip", foreign_key: :owner_id, dependent: :destroy, inverse_of: :owner
  has_many :trip_memberships, dependent: :destroy
  has_many :trips, through: :trip_memberships

  validates :name, presence: true

  def display_name
    name.presence || email.split("@").first
  end
end
