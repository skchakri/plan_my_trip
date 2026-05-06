demo = User.find_or_create_by!(email: "demo@example.com") do |u|
  u.name = "Kalyan"
  u.password = "password123"
  u.password_confirmation = "password123"
end

vegas_body = Rails.root.join("docs/TRIP_VEGAS_2026_05.md").read

vegas_trip = Trip.find_or_create_by!(owner: demo, title: "Vegas trip — May 7-10, 2026") do |t|
  t.destination = "Las Vegas, NV"
  t.start_date = Date.new(2026, 5, 7)
  t.end_date = Date.new(2026, 5, 10)
  t.body = vegas_body
end

[
  { name: "Calico Tanks Trail (Red Rock Canyon)",
    alltrails_url: "https://www.alltrails.com/trail/us/nevada/calico-tanks-trail",
    notes: "2.2 mi out-and-back · moderate · panoramic Strip view from the top." },
  { name: "Hoover Dam Lakeview Overlook",
    alltrails_url: "https://www.alltrails.com/trail/us/nevada/historic-railroad-trail",
    notes: "Historic Railroad Trail · easy · paved with tunnels, good for grandparents." }
].each_with_index do |attrs, i|
  vegas_trip.trails.find_or_create_by!(name: attrs[:name]) do |t|
    t.alltrails_url = attrs[:alltrails_url]
    t.notes = attrs[:notes]
    t.position = i
  end
end

puts "Seeded: #{demo.email} / password123"
puts "Trips: #{Trip.count}, Trails: #{Trail.count}"
