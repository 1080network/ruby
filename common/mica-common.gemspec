Gem::Specification.new do |s|
  s.name        = "mica-common"
  # Set from the proto release by scripts/update-from-proto.sh (v2.0.0-pre0 is 2.0.0.pre0 in RubyGems' scheme)
  s.version     = "2.0.0.pre0"
  s.summary     = "Shared messages and the mutual TLS helper for the Mica network SDK"
  s.authors     = ["Mica"]
  s.email       = "engineering@mica.io"
  s.homepage    = "https://mica.io/"
  s.license     = "Apache-2.0"
  s.metadata    = { "source_code_uri" => "https://github.com/1080network/ruby" }
  s.files       = Dir["lib/**/*.rb"] + ["README.md"]
  s.require_paths = ["lib"]
  s.required_ruby_version = ">= 3.1"
  s.add_dependency "google-protobuf", ">= 4.32", "< 5"
  s.add_dependency "grpc", ">= 1.74", "< 2"
end
