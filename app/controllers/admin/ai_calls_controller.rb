module Admin
  class AiCallsController < BaseController
    def index
      @calls = AiCall.recent.includes(:ai_prompt, :user, :trip)
      @calls = @calls.where(prompt_slug: params[:slug]) if params[:slug].present?
      @calls = @calls.where(status: params[:status]) if params[:status].present?
      @calls = @calls.where(provider: params[:provider]) if params[:provider].present?
      if params[:q].present?
        like = "%#{ActiveRecord::Base.sanitize_sql_like(params[:q])}%"
        @calls = @calls.where("rendered_user ILIKE ? OR response_text ILIKE ?", like, like)
      end
      @calls = @calls.limit(200)
    end

    def show
      @call = AiCall.find(params[:id])
    end

    def destroy
      AiCall.find(params[:id]).destroy
      redirect_to admin_ai_calls_path, notice: "Call removed from log."
    end
  end
end
