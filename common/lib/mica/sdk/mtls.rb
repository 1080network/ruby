# frozen_string_literal: true

require "grpc"

module Mica
  module Sdk
    # Connect to the Mica network with mutual TLS.
    #
    # Every connection to Mica uses mutual TLS: the client presents a certificate issued by Mica and verifies Mica's
    # server certificate (including its host name) against the root certificate authority Mica provides.
    module Mtls
      module_function

      # Builds gRPC channel credentials from PEM strings.
      #
      # @param certificate_authorities [String] root certificate(s) used to verify Mica's server certificate
      # @param certificate [String] the client certificate chain issued by Mica
      # @param key [String] the private key for +certificate+
      def credentials(certificate_authorities:, certificate:, key:)
        GRPC::Core::ChannelCredentials.new(certificate_authorities, key, certificate)
      end

      # Builds channel credentials from PEM files on disk.
      def credentials_from_files(certificate_authorities:, certificate:, key:)
        credentials(
          certificate_authorities: File.read(certificate_authorities),
          certificate: File.read(certificate),
          key: File.read(key)
        )
      end

      # Creates a generated client for +target+ (for example "api.example.mica.io:443") that connects with mutual TLS.
      #
      #   ping = Mica::Sdk::Mtls.stub(Mica::Member::Ping::V1::PingService::Stub, "api.example.mica.io:443", credentials)
      def stub(stub_class, target, credentials, **options)
        stub_class.new(target, credentials, **options)
      end
    end
  end
end
