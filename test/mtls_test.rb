# frozen_string_literal: true

# Makes real mutual TLS Ping calls to an in-process server, using certificates generated for the test.
require "minitest/autorun"
require "openssl"
require "mica-issuer"
require "mica-acceptor"
require "mica/member/ping/v1/ping_service_services_pb"

class MtlsTest < Minitest::Test
  Identity = Struct.new(:cert, :key) do
    def cert_pem = cert.to_pem
    def key_pem = key.to_pem
  end

  class Pinger < Mica::Member::Ping::V1::PingService::Service
    def ping(_request, _call)
      Mica::Member::Ping::V1::PingResponse.new(status: :STATUS_SUCCESS, service_type: "test")
    end
  end

  def new_identity(name, ca = nil)
    key = OpenSSL::PKey::EC.generate("prime256v1")
    cert = OpenSSL::X509::Certificate.new
    cert.version = 2
    cert.serial = rand(1 << 32)
    cert.subject = OpenSSL::X509::Name.parse("/CN=#{name}")
    cert.issuer = ca ? ca.cert.subject : cert.subject
    cert.public_key = key
    cert.not_before = Time.now - 60
    cert.not_after = Time.now + 3600
    ef = OpenSSL::X509::ExtensionFactory.new
    ef.subject_certificate = cert
    ef.issuer_certificate = ca ? ca.cert : cert
    cert.add_extension(ef.create_extension("basicConstraints", ca ? "CA:FALSE" : "CA:TRUE", true))
    cert.add_extension(ef.create_extension("subjectAltName", "DNS:localhost,IP:127.0.0.1"))
    cert.sign(ca ? ca.key : key, OpenSSL::Digest.new("SHA256"))
    Identity.new(cert, key)
  end

  def test_ping_succeeds_over_mutual_tls_and_a_server_from_an_unknown_authority_is_rejected
    ca = new_identity("test ca")
    server_identity = new_identity("server", ca)
    client = new_identity("client", ca)

    server = GRPC::RpcServer.new
    creds = GRPC::Core::ServerCredentials.new(
      ca.cert_pem, [{ private_key: server_identity.key_pem, cert_chain: server_identity.cert_pem }], true
    )
    port = server.add_http2_port("127.0.0.1:0", creds)
    server.handle(Pinger)
    thread = Thread.new { server.run }
    server.wait_till_running(10)
    target = "localhost:#{port}"

    begin
      credentials = Mica::Sdk::Mtls.credentials(
        certificate_authorities: ca.cert_pem, certificate: client.cert_pem, key: client.key_pem
      )
      ping = Mica::Sdk::Mtls.stub(Mica::Member::Ping::V1::PingService::Stub, target, credentials)
      response = ping.ping(Mica::Member::Ping::V1::PingRequest.new, deadline: Time.now + 10)
      assert_equal :STATUS_SUCCESS, response.status

      other_ca = new_identity("other ca")
      untrusting = Mica::Sdk::Mtls.credentials(
        certificate_authorities: other_ca.cert_pem, certificate: client.cert_pem, key: client.key_pem
      )
      rejected = Mica::Sdk::Mtls.stub(Mica::Member::Ping::V1::PingService::Stub, target, untrusting)
      assert_raises(GRPC::BadStatus) do
        rejected.ping(Mica::Member::Ping::V1::PingRequest.new, deadline: Time.now + 10)
      end
    ensure
      server.stop
      thread.join(5)
    end
  end

  def test_issuer_and_acceptor_clients_load
    assert Mica::Issuer::Service::V2::IssuerToMicaService::Stub
    assert Mica::Acceptor::Service::V2::AcceptorToMicaService::Stub
  end
end
