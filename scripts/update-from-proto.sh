#!/bin/bash
# Regenerate the SDK from the output of the "Generate SDKs" workflow in https://github.com/1080network/proto.
#
# Usage: scripts/update-from-proto.sh <version> <generated-dir>
#   <version>        release tag the code was generated from: vX.Y.Z or vX.Y.Z-preN
#   <generated-dir>  the downloaded workflow artifact (the directory containing ruby/)
#
# Download the generated code for a release with:
#   gh run download <run-id> -R 1080network/proto -n generated-sdks-<version>
set -euo pipefail

VERSION=${1:?usage: $0 <version> <generated-dir>}
GEN=${2:?usage: $0 <version> <generated-dir>}
ROOT=$(cd "$(dirname "$0")/.." && pwd)

if [[ ! "$VERSION" =~ ^v([0-9]+\.[0-9]+\.[0-9]+)(-pre([0-9]+))?$ ]]; then
    echo "version '$VERSION' must look like v1.2.3 or v1.2.3-pre0" >&2
    exit 1
fi
# RubyGems' version scheme: v2.0.0-pre0 is 2.0.0.pre0
GEM_VERSION=${BASH_REMATCH[1]}
[[ -n "${BASH_REMATCH[3]}" ]] && GEM_VERSION="${GEM_VERSION}.pre${BASH_REMATCH[3]}"
if [[ ! -d "$GEN/ruby/mica/issuer" ]]; then
    echo "'$GEN' does not look like generated output (expected ruby/mica/issuer)" >&2
    exit 1
fi

echo "Laying out $VERSION ($GEM_VERSION) from $GEN"
# Generated code only: hand-written code (lib/mica/sdk, the entry points, tests) is left alone.
rm -rf "$ROOT/common/lib/mica/common" "$ROOT/common/lib/mica/member" "$ROOT/common/lib/micashared" \
       "$ROOT/common/lib/validate" "$ROOT/issuer/lib/mica" "$ROOT/acceptor/lib/mica"
mkdir -p "$ROOT/common/lib/mica" "$ROOT/issuer/lib/mica" "$ROOT/acceptor/lib/mica"
# common: shared messages, plus validate.proto's generated code which the messages require
cp -r "$GEN/ruby/micashared" "$GEN/ruby/validate" "$ROOT/common/lib/"
cp -r "$GEN/ruby/mica/common" "$GEN/ruby/mica/member" "$ROOT/common/lib/mica/"
cp -r "$GEN/ruby/mica/issuer" "$ROOT/issuer/lib/mica/"
cp -r "$GEN/ruby/mica/acceptor" "$ROOT/acceptor/lib/mica/"

for gem in common issuer acceptor; do
    sed -i.bak -E "s/s.version += \".*\"/s.version     = \"$GEM_VERSION\"/; s/\"= [0-9][^\"]*\"/\"= $GEM_VERSION\"/" "$ROOT/$gem/mica-$gem.gemspec"
    rm "$ROOT/$gem/mica-$gem.gemspec.bak"
done

cd "$ROOT"
bundle install --quiet
bundle exec rake test

# Build the gems, install them into an empty gem home, and load them as a client would
rm -rf "$ROOT/pkg" && mkdir -p "$ROOT/pkg"
for gem in common issuer acceptor; do
    (cd "$gem" && gem build "mica-$gem.gemspec" --output "$ROOT/pkg/mica-$gem-$GEM_VERSION.gem" >/dev/null)
done
CONSUMER=$(mktemp -d)
GEM_HOME="$CONSUMER" GEM_PATH="$CONSUMER" gem install --quiet --no-document \
    "$ROOT/pkg/mica-common-$GEM_VERSION.gem" "$ROOT/pkg/mica-issuer-$GEM_VERSION.gem" "$ROOT/pkg/mica-acceptor-$GEM_VERSION.gem" 2>&1 | tail -3
(cd "$CONSUMER" && GEM_HOME="$CONSUMER" GEM_PATH="$CONSUMER" ruby -e '
require "mica-issuer"; require "mica-acceptor"
puts "consumer OK: #{Mica::Issuer::Service::V2::IssuerToMicaService::Stub} #{Mica::Acceptor::Service::V2::AcceptorToMicaService::Stub}"')
rm -rf "$CONSUMER"
echo "Done: gems in pkg/ ($GEM_VERSION)."
