class ExpensesController < ApplicationController
  before_action :set_trip

  # Shared cost ledger + settle-up. Any active trip member can view and add
  # (collaborative, like comments); a member can remove an expense they logged,
  # and the trip owner can remove any (moderation).
  def index
    authorize @trip, :show?
    @people = @trip.people.ordered.to_a
    @expenses = @trip.expenses.kept.includes(:paid_by).ordered
    @groups = Trips::SettleUp.new(@trip).groups
    @expense = @trip.expenses.build(currency: default_currency)
  end

  def create
    authorize @trip, :show?
    @expense = @trip.expenses.build(expense_params)
    @expense.created_by = current_user

    if @expense.save
      redirect_to trip_expenses_path(@trip), notice: "Added “#{@expense.description}”."
    else
      @people = @trip.people.ordered.to_a
      @expenses = @trip.expenses.kept.includes(:paid_by).ordered
      @groups = Trips::SettleUp.new(@trip).groups
      flash.now[:alert] = @expense.errors.full_messages.to_sentence
      render :index, status: :unprocessable_entity
    end
  end

  def destroy
    @expense = @trip.expenses.kept.find(params[:id])
    authorize @trip, :show?
    unless can_remove?(@expense)
      return redirect_to trip_expenses_path(@trip), alert: "Only who logged an expense (or the trip owner) can remove it."
    end

    @expense.discard
    redirect_to trip_expenses_path(@trip), notice: "Removed “#{@expense.description}”."
  end

  private

  def set_trip
    @trip = Trip.kept.find(params[:trip_id])
  end

  def can_remove?(expense)
    expense.created_by_id == current_user.id || @trip.owner_id == current_user.id
  end

  def default_currency
    @trip.expenses.kept.order(:created_at).last&.currency || "USD"
  end

  def expense_params
    params.require(:expense)
          .permit(:description, :amount, :currency, :category, :paid_by_id, :incurred_on, split_between: [])
  end
end
