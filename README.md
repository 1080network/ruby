# Mica SDK for Ruby

Ruby client libraries for the [Mica](https://mica.io) network. Mica's API is [gRPC](https://grpc.io) over mutual TLS;
the messages and clients in this repository are generated from the [public protos](https://github.com/1080network/proto)
and use the [`grpc`](https://rubygems.org/gems/grpc) and [`google-protobuf`](https://rubygems.org/gems/google-protobuf)
gems. Ruby 3.1 or later.

## Which gem do I need?

Each role is its own gem, so you only install the code for the roles you play.

| Gem | Use it if you are |
| --- | --- |
| `mica-issuer` | an issuer |
| `mica-acceptor` | an acceptor |
| `mica-common` | everyone: shared messages and the mutual TLS helper. Installed automatically by the two above |

Versions follow the proto release in RubyGems' scheme: proto `v2.0.0` is `2.0.0`, and the pre-release `v2.0.0-pre0` is
`2.0.0.pre0`.

## Installing

The gems are published to the [GitHub Packages RubyGems registry](https://github.com/orgs/1080network/packages?ecosystem=rubygems).
GitHub requires authentication to read from it, even for public packages: create a personal access token with the
`read:packages` scope, then in your `Gemfile`:

```ruby
source "https://rubygems.pkg.github.com/1080network" do
  gem "mica-issuer", "2.0.0.pre0"   # or mica-acceptor
end
```

and give Bundler the credentials once: `bundle config set --global rubygems.pkg.github.com YOUR_GITHUB_USER:YOUR_TOKEN`.

## Connecting

Mica uses mutual TLS. You need the root CA, and the client certificate and key Mica issued to you, as PEM files. The
server certificate is verified against the root CA and its host name, and the client presents your certificate.

```ruby
require "mica/sdk/mtls"
require "mica/member/ping/v1/ping_service_services_pb"

credentials = Mica::Sdk::Mtls.credentials_from_files(
  certificate_authorities: "rootca.crt", certificate: "client.crt", key: "client.key"
)
ping = Mica::Sdk::Mtls.stub(Mica::Member::Ping::V1::PingService::Stub, "api.example.mica.io:443", credentials)

puts ping.ping(Mica::Member::Ping::V1::PingRequest.new).status
```

`Mica::Sdk::Mtls.stub` works with any generated client, for example
`Mica::Issuer::Service::V2::IssuerToMicaService::Stub` (from `require "mica-issuer"`).

`examples/ping.rb` is a complete program that connects and calls `Ping`, a good first check that your certificates and
network path work:

```bash
ruby examples/ping.rb api.example.mica.io:443 rootca.crt client.crt client.key
```

## Repository layout

| Path | Contents |
| --- | --- |
| `common/`, `issuer/`, `acceptor/` | one gem each; the generated code under `lib/mica/...`, `lib/micashared` and `lib/validate` is **generated** |
| `common/lib/mica/sdk/mtls.rb` | hand-written mutual TLS helper |
| `test/` | tests, including a real mutual TLS call to an in-process server |
| `examples/` | runnable examples |
| `scripts/update-from-proto.sh` | regenerates the SDK for a proto release, runs the tests, builds the gems and installs them into an empty gem home |

The three gems share the `mica` load path, which is how `mica-issuer` adds `mica/issuer` to the `mica/common` that
`mica-common` provides.

## Releasing (maintainers)

1. Run the **Generate SDKs** workflow in [1080network/proto](https://github.com/1080network/proto/actions) for the release tag.
2. Download its output: `gh run download <run-id> -R 1080network/proto -n generated-sdks-<version>`.
3. Run `scripts/update-from-proto.sh <version> <download-dir>`. It lays the generated code into the gems, sets the versions, runs the tests, builds the gems into `pkg/`, and installs them into an empty gem home to check they load.
4. Open a pull request with the changes and merge it.
5. Publish a GitHub release whose tag is the version (for example `v2.0.0-pre0`). The **Publish gems** workflow pushes all three gems to GitHub Packages.
