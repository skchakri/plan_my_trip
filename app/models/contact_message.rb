# Form object for the public contact page (not persisted).
class ContactMessage
  include ActiveModel::Model
  include ActiveModel::Attributes

  attribute :name, :string
  attribute :email, :string
  attribute :body, :string
  attribute :honeypot, :string # must stay blank; bots fill every field

  validates :email, presence: true, format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :body, presence: true, length: { minimum: 10, maximum: 4000 }
  validates :name, length: { maximum: 120 }

  def to_h = { name: name.to_s.strip, email: email.to_s.strip, body: body.to_s.strip }
end
