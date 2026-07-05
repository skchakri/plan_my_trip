#!/usr/bin/env ruby
# Validates the App Store Connect API key and checks whether an app record
# exists for a bundle id. Usage:
#   ASC_KEY_ID=.. ASC_ISSUER_ID=.. ruby asc_check.rb com.wanderply.PlanMyTrip
require "openssl"; require "base64"; require "json"; require "net/http"

key_id = ENV.fetch("ASC_KEY_ID"); issuer = ENV.fetch("ASC_ISSUER_ID")
bundle = ARGV[0] || "com.wanderply.PlanMyTrip"
p8 = [ "#{ENV['HOME']}/.appstoreconnect/private_keys/AuthKey_#{key_id}.p8",
      "./private_keys/AuthKey_#{key_id}.p8" ].find { |f| File.exist?(f) }
abort "missing .p8 for #{key_id}" unless p8

b64 = ->(x) { Base64.urlsafe_encode64(x).delete("=") }
header  = b64.(JSON.dump(alg: "ES256", kid: key_id, typ: "JWT"))
now = Time.now.to_i
payload = b64.(JSON.dump(iss: issuer, iat: now, exp: now + 600, aud: "appstoreconnect-v1"))
signing_input = "#{header}.#{payload}"
ec = OpenSSL::PKey::EC.new(File.read(p8))
der = ec.sign(OpenSSL::Digest::SHA256.new, signing_input)
# DER -> raw r||s (each 32 bytes) for JOSE ES256
asn1 = OpenSSL::ASN1.decode(der)
r = asn1.value[0].value.to_s(2).rjust(32, "\x00")
s = asn1.value[1].value.to_s(2).rjust(32, "\x00")
jwt = "#{signing_input}.#{b64.(r + s)}"

uri = URI("https://api.appstoreconnect.apple.com/v1/apps?filter[bundleId]=#{bundle}")
req = Net::HTTP::Get.new(uri); req["Authorization"] = "Bearer #{jwt}"
res = Net::HTTP.start(uri.host, uri.port, use_ssl: true) { |h| h.request(req) }
puts "HTTP #{res.code}"
if res.code == "200"
  data = JSON.parse(res.body)["data"]
  if data.empty?
    puts "AUTH OK. No app record for #{bundle} yet (must be created before upload)."
  else
    a = data.first
    puts "AUTH OK. App record EXISTS: #{a['attributes']['name']} (id #{a['id']}, sku #{a['attributes']['sku']})"
  end
else
  puts res.body
end
