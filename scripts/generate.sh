#!/bin/sh
# Regenerates Sources/MyUplink/Generated from swagger.json.
set -eu
cd "$(dirname "$0")/.."

python3 -I scripts/sanitize-spec.py swagger.json OpenAPI/openapi.json

rm -rf Sources/MyUplink/Generated
swift run --package-path Tools swift-openapi-generator generate \
    --config OpenAPI/openapi-generator-config.yaml \
    --output-directory Sources/MyUplink/Generated \
    OpenAPI/openapi.json

python3 -I scripts/generate-replays.py
