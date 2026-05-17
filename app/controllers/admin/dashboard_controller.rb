module Admin
  class DashboardController < BaseController
    def index
      @prompts = AiPrompt.alpha
      @recent_calls = AiCall.recent.includes(:ai_prompt, :user, :trip).limit(20)
      @stats = {
        prompts: AiPrompt.count,
        active: AiPrompt.active.count,
        calls_total: AiCall.count,
        calls_24h: AiCall.where("created_at >= ?", 24.hours.ago).count,
        failures_24h: AiCall.failures.where("created_at >= ?", 24.hours.ago).count,
        tokens_24h: AiCall.where("created_at >= ?", 24.hours.ago).sum("coalesce(input_tokens,0) + coalesce(output_tokens,0)")
      }
    end
  end
end
