namespace :places do
  desc "Merge duplicate Place rows (proximity + name variants). Dry-run unless COMMIT=1."
  task dedupe: :environment do
    commit = ENV["COMMIT"] == "1"
    result = Places::Deduper.call(commit: commit)

    puts "[places:dedupe] #{commit ? 'COMMIT' : 'DRY RUN'} — #{result.groups.size} duplicate group(s), " \
         "#{result.discarded_count} row(s) #{commit ? 'discarded' : 'would be discarded'}"

    result.groups.each do |group|
      canonical = group[:canonical]
      puts "\n  KEEP   #{canonical.name} (#{canonical.id}) " \
           "[usage #{canonical.usage_count}#{canonical.verified? ? ', verified' : ''}]"
      group[:redundant].each do |dup|
        km = if dup.latitude && canonical.latitude
          (Place.haversine_m(canonical.latitude.to_f, canonical.longitude.to_f,
                             dup.latitude.to_f, dup.longitude.to_f) / 1000.0).round(1)
        end
        puts "  MERGE  #{dup.name} (#{dup.id}) [usage #{dup.usage_count}#{km ? ", #{km} km" : ''}]"
      end
    end

    puts "\nDry run — re-run with COMMIT=1 to apply." unless commit
  end
end
