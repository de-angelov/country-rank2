#!/usr/bin/env bash
# Idiomatic FunScript guard: fail when a .fun / .funx file wraps logic in a
# raw `ts { ... }` escape hatch that is not an unavoidable ambient declaration.
#
# Allowed (ambient) uses:
#   - JSX namespace declarations (`declare global { namespace JSX { interface ... } }`)
#
# Forbidden (cheating) uses:
#   - `async`, `await`, promise chains
#   - React hooks / loaders: useState, useEffect, useLoaderData, useSearchParams, ...
#   - Runtime value exports: `export const`, bare `const`, `interface`, `export type`
#
# Usage: npm run check:idiomatic

set -euo pipefail

fail=0
tmp_offenders="$(mktemp)"
trap 'rm -f "$tmp_offenders"' EXIT

while IFS= read -r file; do
  if awk -v file="$file" '
    /ts[ \t]*\{/ { inblock=1; buf=$0; next }
    inblock {
      buf = buf "\n" $0
      if ($0 ~ /\}/) {
        content = buf
        gsub(/ts[ \t]*\{/, "", content)
        gsub(/\}/, "", content)
        if (content ~ /IntrinsicElements/) { inblock=0; next }
        if (content ~ /async|await|useState|useEffect|useLoaderData|useSearchParams|export[ \t]+const|^[ \t]*(const|interface|type)[ \t]/) {
          print file > "/dev/stderr"
          exit 1
        }
        inblock=0
      }
      next
    }
  ' "$file"; then
    : # no cheating block in this file
  else
    fail=1
  fi
done < <(find app -type f \( -name "*.fun" -o -name "*.funx" \) | sort -u)

if [ "$fail" -ne 0 ]; then
  echo "FAIL: idiomatic FunScript check found ts {} escape hatches with logic inside."
  echo "Idiomatic FunScript requires: schema, effect {}, pipelines, match, native JSX."
  exit 1
fi

echo "PASS: no logic-bearing ts {} blocks found in app/."
