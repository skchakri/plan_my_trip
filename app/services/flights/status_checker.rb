module Flights
  # Looks up one flight's live status via AeroDataBox (free tier). Opt-in: with
  # no AERODATABOX_API_KEY configured it returns nil, so the whole feature stays
  # dark until an operator adds a key at /admin/app_settings. Best-effort — any
  # error or non-200 yields nil, and PollFlightStatusJob just skips that flight.
  #
  #   Flights::StatusChecker.call(reservation) # => Status | nil
  class StatusChecker
    HOST = "aerodatabox.p.rapidapi.com".freeze
    SETTING = "AERODATABOX_API_KEY".freeze

    Status = Struct.new(:status, :gate, :terminal, :departure_delay_minutes, keyword_init: true)

    def self.call(reservation) = new(reservation).call

    def initialize(reservation)
      @reservation = reservation
    end

    def call
      key = AppSetting.get(SETTING)
      return nil if key.blank?
      return nil if @reservation.flight_number.blank? || @reservation.start_at.blank?

      body = fetch(key)
      return nil unless body

      parse(body)
    rescue StandardError => e
      Rails.logger.warn("[flight-status] #{@reservation.id}: #{e.class} #{e.message}")
      nil
    end

    private

    def fetch(key)
      date = @reservation.start_at.to_date.iso8601
      number = @reservation.flight_number.to_s.delete(" ")
      uri = URI("https://#{HOST}/flights/number/#{number}/#{date}")
      uri.query = URI.encode_www_form(withAircraftImage: false, withLocation: false)

      res = Net::HTTP.start(uri.hostname, uri.port, use_ssl: true, open_timeout: 4, read_timeout: 8) do |http|
        http.get(uri.request_uri, "X-RapidAPI-Key" => key, "X-RapidAPI-Host" => HOST, "Accept" => "application/json")
      end
      return nil unless res.is_a?(Net::HTTPSuccess)

      res.body
    end

    # AeroDataBox returns an array of matching flights; take the first departure.
    def parse(body)
      flight = Array(JSON.parse(body)).first
      return nil unless flight.is_a?(Hash)

      dep = flight["departure"] || {}
      Status.new(
        status: flight["status"].to_s.downcase.presence,
        gate: dep["gate"].presence,
        terminal: dep["terminal"].presence,
        departure_delay_minutes: departure_delay(dep)
      )
    end

    # Minutes between scheduled and revised/predicted departure, when both known.
    def departure_delay(dep)
      scheduled = dep.dig("scheduledTime", "utc")
      revised   = dep.dig("revisedTime", "utc") || dep.dig("predictedTime", "utc")
      return nil if scheduled.blank? || revised.blank?

      ((Time.parse(revised) - Time.parse(scheduled)) / 60).round
    rescue ArgumentError, TypeError
      nil
    end
  end
end
