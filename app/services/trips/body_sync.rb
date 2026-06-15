module Trips
  # Regenerates Trip#body (the markdown narrative rendered on the public share
  # view) from the structured TripDay/Activity rows after a manual edit, so the
  # public plan never drifts from what the owner edited in the structured editor.
  # The authenticated plan view reads the AR rows directly and is always current;
  # this just keeps the derived markdown in step.
  class BodySync
    def self.call(trip)
      new(trip).call
    end

    def initialize(trip)
      @trip = trip
    end

    def call
      structure = {
        "days" => @trip.trip_days.ordered.includes(:activities).map do |day|
          {
            "title"      => day.title,
            "date"       => day.date&.iso8601,
            "summary"    => day.summary,
            "activities" => day.activities.map do |a|
              {
                "title"         => a.title,
                "time_label"    => a.time_label,
                "location_name" => a.location_name,
                "famous_for"    => a.famous_for,
                "notes"         => a.notes
              }
            end
          }
        end
      }
      people = @trip.people.map { |p| { name: p.name } }
      body = MarkdownItinerary.from_structure(structure, destination: @trip.destination, people: people)
      @trip.update_column(:body, body)
    end
  end
end
