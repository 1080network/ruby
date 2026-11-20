# frozen_string_literal: true

# Connects to Mica with mutual TLS and calls Ping, a good first check that your certificates and network path work.
#
#   ruby examples/ping.rb api.example.mica.io:443 rootca.crt client.crt client.key
require "mica/sdk/mtls"
require "mica/member/ping/v1/ping_service_services_pb"

target, ca, cert, key = ARGV
abort "usage: ping.rb <host:port> <rootca.crt> <client.crt> <client.key>" unless key

credentials = Mica::Sdk::Mtls.credentials_from_files(certificate_authorities: ca, certificate: cert, key: key)
ping = Mica::Sdk::Mtls.stub(Mica::Member::Ping::V1::PingService::Stub, target, credentials)
response = ping.ping(Mica::Member::Ping::V1::PingRequest.new, deadline: Time.now + 15)
puts "status=#{response.status} service=#{response.service_type} version=#{response.build_version}"
