#!/usr/bin/env python3
"""Turn the published myUplink swagger.json into a valid openapi.json.

Fixes applied to the upstream file:
- `"authorized-groups":` keys with no value (invalid JSON) are dropped, along
  with the dangling comma before them.
- Security scheme names containing spaces (not allowed as component keys) are
  rewritten with hyphens, e.g. `Client Credentials` -> `Client-Credentials`.
- Security requirements naming schemes that are not defined are removed.
- Binary responses (`format: binary`) declared under text/JSON content types
  are collapsed into a single `application/octet-stream` entry.
"""
import json
import re
import sys

src, dst = sys.argv[1], sys.argv[2]
lines = open(src, encoding="utf-8").read().splitlines()
out = []
for line in lines:
    if re.match(r'^\s*"[^"]+":\s*$', line):
        # drop the key and the trailing comma of the previous entry
        for i in range(len(out) - 1, -1, -1):
            if out[i].strip():
                out[i] = re.sub(r",\s*$", "", out[i])
                break
        continue
    out.append(line)

spec = json.loads("\n".join(out))


def scheme_key(name):
    return name.replace(" ", "-")


schemes = spec.get("components", {}).get("securitySchemes", {})
schemes = {scheme_key(k): v for k, v in schemes.items()}
spec["components"]["securitySchemes"] = schemes


def fix_requirements(requirements):
    fixed = []
    for req in requirements:
        req = {scheme_key(k): v for k, v in req.items() if scheme_key(k) in schemes}
        if req:
            fixed.append(req)
    return fixed


if "security" in spec:
    spec["security"] = fix_requirements(spec["security"])
for path_item in spec.get("paths", {}).values():
    for operation in path_item.values():
        if isinstance(operation, dict) and "security" in operation:
            operation["security"] = fix_requirements(operation["security"])
        if not isinstance(operation, dict):
            continue
        for response in operation.get("responses", {}).values():
            content = response.get("content", {})
            binary = [c["schema"] for c in content.values() if c.get("schema", {}).get("format") == "binary"]
            if binary:
                response["content"] = {"application/octet-stream": {"schema": binary[0]}}

with open(dst, "w", encoding="utf-8") as f:
    json.dump(spec, f, indent=2)
    f.write("\n")
