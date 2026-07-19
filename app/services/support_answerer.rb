# Runs one support ticket through the support_answer.v1 prompt and returns the
# AI's decision: the reply text, whether it needs a human, the escalation
# reason, and a confidence band. Mirrors the thin-service pattern of
# ActivityNarrator. Returns nil on AI failure so the caller can leave the
# ticket open for the next hourly pass.
class SupportAnswerer
  PROMPT_SLUG = "support_answer.v1".freeze

  Decision = Struct.new(:reply, :needs_human, :reason, :confidence, keyword_init: true) do
    def needs_human? = !!needs_human
  end

  def self.call(...) = new(...).call

  def initialize(ticket)
    @ticket = ticket
  end

  def call
    result = Ai::Caller.call(
      slug: PROMPT_SLUG,
      user: @ticket.user,
      variables: {
        subject:   @ticket.subject,
        user_name: @ticket.user.display_name,
        thread:    transcript
      }
    )
    json = result.json
    return nil unless json.is_a?(Hash)

    reply = json["reply"].to_s.strip
    return nil if reply.blank?

    Decision.new(
      reply:       reply,
      needs_human: json["needs_human"] == true,
      reason:      json["reason"].to_s.strip,
      confidence:  json["confidence"].to_s.strip.presence || "medium"
    )
  rescue StandardError => e
    Rails.logger.warn("[SupportAnswerer] ticket=#{@ticket&.id}: #{e.class}: #{e.message}")
    nil
  end

  private

  # Role-labelled plain-text transcript the prompt reads.
  def transcript
    @ticket.support_messages.ordered.map do |m|
      speaker = { "user" => "Customer", "assistant" => "Support (AI)", "admin" => "Support" }[m.role]
      "#{speaker}: #{m.body}"
    end.join("\n\n")
  end
end
