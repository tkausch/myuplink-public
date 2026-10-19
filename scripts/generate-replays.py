#!/usr/bin/env python3
"""Writes a Replay HAR fixture for every /v2 and /v3 operation in the spec.

Each archive holds one request/response pair for the operation's success
response. The spec has no response examples, so bodies are synthesized from
the schemas: every property is filled (nullable ones too), enums take their
first case, arrays get one element. The output is deterministic.

Usage: scripts/generate-replays.py [spec] [client.swift] [output dir]
"""

import base64
import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SPEC = Path(sys.argv[1]) if len(sys.argv) > 1 else ROOT / "OpenAPI/openapi.json"
CLIENT = Path(sys.argv[2]) if len(sys.argv) > 2 else ROOT / "Sources/MyUplink/Generated/Client.swift"
OUT = Path(sys.argv[3]) if len(sys.argv) > 3 else ROOT / "Tests/MyUplinkTests/Replays"

BASE_URL = "https://api.myuplink.com"
TIMESTAMP = "2026-01-01T00:00:00Z"

# Values for path parameters. Tests must use the same ones.
PATH_VALUES = {
    "deviceId": "device-1",
    "systemId": "00000000-0000-0000-0000-000000000001",
    "zoneId": "1",
    "brandId": "brand-1",
    "firmwareTypeId": "1",
    "version": "1.0.0",
}

STATUS_TEXT = {200: "OK", 204: "No Content"}
METHODS = ("get", "post", "put", "patch", "delete")

spec = json.loads(SPEC.read_text())
schemas = spec["components"]["schemas"]


def operation_names():
    """Maps (METHOD, path) to the Swift method name the generator produced."""
    text = CLIENT.read_text()
    pairs = re.findall(r"Remark: HTTP `(\w+) ([^`]+)`\.\n\s+/// - Remark: .*\n\s+public func (\w+)\(", text)
    return {(method, path): name for method, path, name in pairs}


def sample(schema, name="value", seen=()):
    if "$ref" in schema:
        ref = schema["$ref"].rsplit("/", 1)[-1]
        if ref in seen:
            return None
        return sample(schemas[ref], name, seen + (ref,))
    for key in ("allOf", "oneOf", "anyOf"):
        if key in schema:
            return sample(schema[key][0], name, seen)
    if "example" in schema:
        return schema["example"]
    if "enum" in schema:
        return schema["enum"][0]

    kind = schema.get("type")
    if kind == "object" or "properties" in schema:
        result = {key: sample(prop, key, seen) for key, prop in schema.get("properties", {}).items()}
        extra = schema.get("additionalProperties")
        if isinstance(extra, dict):
            result["key"] = sample(extra, "key", seen)
        return result
    if kind == "array":
        return [sample(schema.get("items", {}), name, seen)]
    if kind == "string":
        return {
            "uuid": PATH_VALUES["systemId"],
            "date-time": TIMESTAMP,
            "date": TIMESTAMP[:10],
            "binary": "",
        }.get(schema.get("format"), f"{name}-1")
    if kind == "integer":
        return 1
    if kind == "number":
        return 1.5
    if kind == "boolean":
        return True
    return 1  # Untyped, e.g. ParameterData.value.


def body(content):
    """Returns (mimeType, text, encoding) for a request or response content map."""
    if "application/json" in content:
        media = content["application/json"]
        value = media["example"] if "example" in media else sample(media.get("schema", {}))
        return "application/json", json.dumps(value, ensure_ascii=False, sort_keys=True), None
    if "application/octet-stream" in content:
        return "application/octet-stream", base64.b64encode(b"firmware").decode(), "base64"
    return None


def entry(method, path, operation):
    url_path = re.sub(r"\{(\w+)\}", lambda m: PATH_VALUES[m.group(1)], path)
    request = {
        "method": method,
        "url": BASE_URL + url_path,
        "httpVersion": "HTTP/1.1",
        "cookies": [],
        "headers": [],
        "queryString": [],
        "headersSize": -1,
        "bodySize": 0,
    }
    if "requestBody" in operation:
        mime, text, _ = body(operation["requestBody"]["content"])
        request["postData"] = {"mimeType": mime, "text": text}
        request["bodySize"] = len(text.encode())

    status = min(int(code) for code in operation["responses"] if code.startswith("2"))
    content = {"size": 0, "mimeType": "application/json", "text": ""}
    headers = []
    found = body(operation["responses"][str(status)].get("content", {}))
    if found:
        mime, text, encoding = found
        content = {"size": len(text.encode()), "mimeType": mime, "text": text}
        if encoding:
            content["encoding"] = encoding
            content["size"] = len(base64.b64decode(text))
        headers = [{"name": "Content-Type", "value": mime}]

    return {
        "startedDateTime": TIMESTAMP,
        "time": 0,
        "request": request,
        "response": {
            "status": status,
            "statusText": STATUS_TEXT.get(status, ""),
            "httpVersion": "HTTP/1.1",
            "cookies": [],
            "headers": headers,
            "content": content,
            "redirectURL": "",
            "headersSize": -1,
            "bodySize": content["size"],
        },
        "cache": {},
        "timings": {"send": 0, "wait": 0, "receive": 0},
    }


def main():
    names = operation_names()
    OUT.mkdir(parents=True, exist_ok=True)
    count = 0
    for path, item in spec["paths"].items():
        if not path.startswith(("/v2/", "/v3/")):
            continue
        for method in METHODS:
            if method not in item:
                continue
            name = names[(method.upper(), path)]
            archive = {
                "log": {
                    "version": "1.2",
                    "creator": {"name": "generate-replays.py", "version": "1"},
                    "entries": [entry(method.upper(), path, item[method])],
                }
            }
            (OUT / f"{name}.har").write_text(json.dumps(archive, indent=2, ensure_ascii=False) + "\n")
            count += 1
    print(f"Wrote {count} archives to {OUT}")


if __name__ == "__main__":
    main()
