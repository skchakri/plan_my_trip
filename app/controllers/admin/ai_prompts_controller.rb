module Admin
  class AiPromptsController < BaseController
    before_action :set_prompt, only: %i[show edit update destroy test_run]

    def index
      @prompts = AiPrompt.alpha
    end

    def show
      @recent_calls = @prompt.ai_calls.recent.limit(20)
    end

    def new
      @prompt = AiPrompt.new(provider: "anthropic", model: "claude-sonnet-4-6", kind: "text", max_tokens: 1024, active: true)
    end

    def create
      @prompt = AiPrompt.new(prompt_params)
      if @prompt.save
        redirect_to admin_ai_prompt_path(@prompt), notice: "Prompt created."
      else
        render :new, status: :unprocessable_entity
      end
    end

    def edit
    end

    def update
      if @prompt.update(prompt_params)
        redirect_to admin_ai_prompt_path(@prompt), notice: "Prompt updated."
      else
        render :edit, status: :unprocessable_entity
      end
    end

    def destroy
      @prompt.destroy
      redirect_to admin_ai_prompts_path, notice: "Prompt removed."
    end

    # Run a one-off invocation against the live prompt with JSON-supplied
    # variables. Useful for verifying a prompt edit before letting it loose
    # on real user traffic. Result is rendered inline.
    def test_run
      vars = parse_variables(params[:variables])
      result = Ai::Caller.call(slug: @prompt.slug, variables: vars, user: current_user)
      redirect_to admin_ai_prompt_path(@prompt, test: result.call&.id), notice: result.success? ? "Test run succeeded — see latest call." : "Test run failed: #{result.error}"
    end

    private

    def set_prompt
      @prompt = AiPrompt.find(params[:id])
    end

    def prompt_params
      params.require(:ai_prompt).permit(:slug, :name, :description, :system_template, :user_template,
                                        :provider, :model, :kind, :max_tokens, :temperature, :active, :notes)
    end

    def parse_variables(raw)
      return {} if raw.blank?
      JSON.parse(raw)
    rescue JSON::ParserError
      {}
    end
  end
end
