class PeopleController < ApplicationController
  before_action :set_trip

  def create
    authorize @trip, :update?
    raw = params.require(:person).permit(:name, :age, interests: [])
    interests = (raw[:interests] || []).map(&:to_s).reject(&:blank?)
    person = @trip.people.create!(name: raw[:name], age: raw[:age].presence, interests: interests, position: @trip.people.maximum(:position).to_i + 1)
    redirect_to @trip, notice: "Added #{person.name}."
  end

  def destroy
    authorize @trip, :update?
    person = @trip.people.find(params[:id])
    name = person.name
    person.destroy
    redirect_to @trip, notice: "Removed #{name}."
  end

  private

  def set_trip
    @trip = Trip.kept.find(params[:trip_id])
  end
end
