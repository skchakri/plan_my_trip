module Admin
  class UsersController < BaseController
    before_action :set_user, only: [ :show, :edit, :update ]

    def index
      scope = User.all
      if params[:q].present?
        like = "%#{ActiveRecord::Base.sanitize_sql_like(params[:q])}%"
        scope = scope.where("email ILIKE ? OR name ILIKE ?", like, like)
      end
      scope = scope.where(admin: true) if params[:role] == "admin"

      @users = scope.order(created_at: :desc).limit(200)
      @stats = {
        total: User.count,
        admins: User.where(admin: true).count,
        with_trips: User.joins(:owned_trips).distinct.count
      }
    end

    def show
      @owned_trips = @user.owned_trips.order(created_at: :desc).limit(50)
      @member_trips = @user.trips.where.not(owner_id: @user.id).limit(50)
      @recent_calls = AiCall.where(user_id: @user.id).recent.limit(20)
    end

    def edit; end

    def update
      attrs = user_params
      # Guard against self-locking out of admin entirely.
      if @user == current_user && attrs[:admin] == "0"
        redirect_to admin_user_path(@user), alert: "You can't remove your own admin flag." and return
      end

      if @user.update(attrs)
        redirect_to admin_user_path(@user), notice: "User updated."
      else
        render :edit, status: :unprocessable_entity
      end
    end

    private

    def set_user
      @user = User.find(params[:id])
    end

    def user_params
      params.require(:user).permit(:name, :admin, :alltrails_pro)
    end
  end
end
