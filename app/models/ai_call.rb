class AiCall < ApplicationRecord
  STATUSES = %w[pending success failure].freeze

  belongs_to :ai_prompt, optional: true
  belongs_to :user, optional: true
  belongs_to :trip, optional: true

  validates :prompt_slug, :provider, :model, :status, presence: true
  validates :status, inclusion: { in: STATUSES }

  scope :recent, -> { order(created_at: :desc) }
  scope :successes, -> { where(status: "success") }
  scope :failures,  -> { where(status: "failure") }

  def successful?
    status == "success"
  end

  def short_response
    return image_url if image_url.present?
    return error.to_s.truncate(140) if status == "failure"
    response_text.to_s.truncate(140)
  end

  def total_tokens
    (input_tokens || 0) + (output_tokens || 0)
  end
end
