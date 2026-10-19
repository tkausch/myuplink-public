# MyUplink

Swift client for the [myUplink Public API](https://api.myuplink.com) (v2), generated with
[swift-openapi-generator](https://github.com/apple/swift-openapi-generator).

## Usage

```swift
.package(url: "<this repo>", branch: "main")
// target dependency: .product(name: "MyUplink", package: "myuplink-public")
```

```swift
import MyUplink

let client = Client.myUplink(token: { try await tokenStore.accessToken() })

let response = try await client.getV2DevicesDeviceIdAidMode(path: .init(deviceId: "…"))
switch response {
case .ok(let ok): print(try ok.body.json.aidMode as Any)
case .unauthorized, .forbidden: break
case .undocumented(let status, _): print("HTTP \(status)")
}
```

Operation names are derived from method + path (the spec has no `operationId`s),
e.g. `GET /v2/devices/{deviceId}/aidMode` → `getV2DevicesDeviceIdAidMode`.
Obtaining the OAuth token is left to the caller.

## Connecting to myUplink

The API uses OAuth 2.0 with the client credentials flow. The library only sends
the token; you get it yourself.

### 1. Register an application

Sign in to the [myUplink developer portal](https://dev.myuplink.com) with the
account that owns your heat pump, and create an application. The portal gives you
a **client ID** and a **client secret**. Keep the secret out of source control.

### 2. Request an access token

POST to the token endpoint with the scopes you need:

```sh
curl -X POST https://api.myuplink.com/oauth/token \
  -d grant_type=client_credentials \
  -d client_id=<client id> \
  -d client_secret=<client secret> \
  -d "scope=READSYSTEM WRITESYSTEM"
```

| Scope | Allows |
| --- | --- |
| `READSYSTEM` | GET methods |
| `WRITESYSTEM` | PUT, POST, PATCH and DELETE methods |

Ask for `READSYSTEM` alone if you only read data. The response contains an
`access_token` and `expires_in` (seconds). There is no refresh token. When the
token expires, request a new one the same way.

### 3. Pass the token to the client

The closure runs on every request, so it can return a cached token and fetch a
new one when it has expired:

```swift
let client = Client.myUplink(token: { try await tokenStore.accessToken() })
```

`tokenStore` is your own type. It posts to `/oauth/token` as above and caches the
result until shortly before `expires_in` runs out.

### 4. Check the connection

```swift
let response = try await client.getV2SystemsMe()
```

`.ok` means you are connected. `.unauthorized` means the token is missing, wrong
or expired. `.forbidden` means the token lacks the scope for that call.

## Repository layout

| Path | What it is |
| --- | --- |
| `swagger.json` | The spec exactly as published by myUplink. Never edit it by hand. |
| `OpenAPI/openapi.json` | The sanitized copy the generator reads. Written by the script. |
| `OpenAPI/openapi-generator-config.yaml` | Generator settings (public access, idiomatic names). |
| `Sources/MyUplink/Generated/` | Generated code, committed. Never edit it by hand. |
| `Sources/MyUplink/MyUplinkClient.swift` | Hand-written helpers: server URL, bearer-token middleware. |
| `scripts/sanitize-spec.py` | Fixes defects in the published spec. |
| `scripts/generate.sh` | Sanitizes the spec and regenerates the code and test archives. |
| `scripts/generate-replays.py` | Writes one HAR test archive per operation from the spec. |
| `Tools/Package.swift` | Pins the generator version. Not a dependency of the library. |

## Testing

The tests run the client over real `URLSession` against HTTP traffic stored in
`Tests/MyUplinkTests/Replays/*.har`, using [Replay](https://github.com/mattt/Replay).
`swift test` needs no network or token.

- `GeneratedReplayTests.swift` has one test per operation. Its archives, named
  after the operation (e.g. `getV2SystemsMe.har`), are written by
  `scripts/generate-replays.py` from `OpenAPI/openapi.json`, with response bodies
  synthesized from the schemas. `generate.sh` rewrites them, so never edit them by
  hand. A new operation needs a new test in this file.
- `ReplayTests.swift` has hand-written scenarios (`systemsAndPoints.har`,
  `patchPoints.har`, `unauthorized.har`) with realistic values.

To re-record a fixture against the live API:

```sh
MYUPLINK_TOKEN=<access token> REPLAY_RECORD_MODE=rewrite swift test --filter ReplayTests.systemsAndPoints
```

The `Authorization` header is stripped before writing, but check the HAR for
personal data (serial numbers, system names) before committing. Don't re-record
`patchPoints`, because it changes a setting on a real device.

## Adding a new swagger file

Do this whenever myUplink publishes a new version of the API.

### 1. Replace `swagger.json`

Download the new spec from the myUplink API documentation and overwrite the file
in the repository root. Keep the filename and don't change the contents:

```sh
cp ~/Downloads/swagger.json swagger.json
```

### 2. Regenerate

```sh
./scripts/generate.sh
```

This runs the sanitizer, writes `OpenAPI/openapi.json`, deletes
`Sources/MyUplink/Generated/` and generates it again. The first run builds the
generator in `Tools/.build`, which takes a minute or two.

### 3. Build and test

```sh
swift build
swift test
```

### 4. Review the diff

```sh
git diff --stat
git diff Sources/MyUplink/Generated
```

Look for:

- **Removed or renamed operations.** Method names come from the HTTP method and
  path, so a changed path renames the method. That breaks apps using the library.
- **Changed schemas.** Properties that were removed, renamed or changed type.
- **New endpoints.** These need no work, but are worth noting in the commit message.

If anything breaks existing callers, bump the major version when you tag the release.

### 5. Commit

Commit `swagger.json`, `OpenAPI/openapi.json`, `Sources/MyUplink/Generated/` and
the regenerated archives in `Tests/MyUplinkTests/Replays/` together, so the spec and the code always match:

```sh
git add swagger.json OpenAPI Sources/MyUplink/Generated Tests/MyUplinkTests/Replays
git commit -m "Update myUplink API spec"
```

## When generation fails

The published spec has had several defects that the generator rejects. The
sanitizer currently fixes these:

| Defect | Fix |
| --- | --- |
| `"authorized-groups":` with no value (invalid JSON) | Line removed |
| Security scheme names with spaces (`Client Credentials`) | Spaces become hyphens |
| Security requirements naming undefined schemes | Removed |
| Binary downloads typed as `application/json` or `text/plain` | Typed as `application/octet-stream` |

A new spec may contain a defect that isn't on this list. What the error looks like:

- **The sanitizer fails with `JSONDecodeError`.** The file is still invalid JSON.
  Open `swagger.json` at the line it reports.
- **The generator fails with a parsing error** naming a path in the document,
  such as `Document.components.securitySchemes`. The spec isn't valid OpenAPI.
- **`swift build` fails inside `Generated/`.** The spec is valid, but describes
  something the generator turns into code that doesn't compile.

In all three cases, fix it in `scripts/sanitize-spec.py`, not in `swagger.json` or
`Generated/`. Hand edits there are lost on the next regeneration. Add the new
case to the table above, then rerun `./scripts/generate.sh`.

## Updating the generator

Change the version in `Tools/Package.swift`, then regenerate:

```sh
swift package --package-path Tools update
./scripts/generate.sh
```

Review the diff as in step 4. A new generator version can change the generated
code even when the spec is the same.
