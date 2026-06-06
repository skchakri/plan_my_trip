class AiPrompt < ApplicationRecord
  PROVIDERS = %w[anthropic openai claude_cli perplexity].freeze
  KINDS = %w[text image].freeze

  has_many :ai_calls, dependent: :nullify

  validates :slug, presence: true, uniqueness: true, format: { with: /\A[a-z0-9_.\-]+\z/, message: "lowercase, digits, _, ., - only" }
  validates :name, :user_template, :model, presence: true
  validates :provider, inclusion: { in: PROVIDERS }
  validates :kind, inclusion: { in: KINDS }
  validates :temperature, numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 2, allow_nil: true }

  scope :active, -> { where(active: true) }
  scope :alpha,  -> { order(:slug) }

  def render(variables = {})
    {
      system: render_template(system_template, variables),
      user:   render_template(user_template, variables)
    }
  end

  # Default OpenAI image-quality vs Anthropic text — providers pull what they
  # need from this hash.
  def request_options
    {
      max_tokens: max_tokens || 1024,
      temperature: temperature&.to_f
    }.compact
  end

  private

  # ERB-render with locals — gives us conditionals and loops alongside
  # plain %{name}-style placeholders.
  def render_template(text, variables)
    return "" if text.blank?
    safe = variables.transform_keys(&:to_sym)
    binding_with_locals = TemplateContext.new(safe).get_binding
    ERB.new(text, trim_mode: "-").result(binding_with_locals)
  rescue StandardError => e
    Rails.logger.warn("[AiPrompt #{slug}] render error: #{e.class}: #{e.message}")
    text
  end

  # Tiny sandbox: locals available as methods + a `vars` hash.
  class TemplateContext
    def initialize(vars)
      @vars = vars
      vars.each do |k, v|
        # define a method per variable so templates can use <%= name %>
        define_singleton_method(k) { v }
      end
    end

    attr_reader :vars

    def get_binding
      binding
    end
  end
end
