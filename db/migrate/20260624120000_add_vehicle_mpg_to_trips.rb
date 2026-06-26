class AddVehicleMpgToTrips < ActiveRecord::Migration[8.1]
  def change
    # Self-declared fuel economy (miles per gallon) for the group's own car.
    # Feeds RoadTripEstimator's fuel-cost math; nullable — a sensible default
    # is used (and labelled an estimate) when blank.
    add_column :trips, :vehicle_mpg, :decimal, precision: 5, scale: 1
  end
end
