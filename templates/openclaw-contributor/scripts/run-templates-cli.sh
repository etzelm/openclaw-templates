#!/bin/zsh
# Run validate, dev and build from the openclaw source checkout with an isolated state dir.
# Usage: run-templates-cli.sh <package dir> <out tgz>
set -u
PKG="$1"; OUT="$2"
B="${OCC_WORK:-${0:A:h}/../tmp}"
export OPENCLAW_STATE_DIR="$B/oc-state"
mkdir -p "$OPENCLAW_STATE_DIR" "$B/logs" "$(dirname "$OUT")"
cd "${OPENCLAW_SRC:?set OPENCLAW_SRC to an openclaw source checkout}" || exit 1
oc() { node --import ./scripts/tsx.mjs src/entry.ts --profile occstage templates "$@"; }
echo "== openclaw checkout: $(git rev-parse --short HEAD), origin/main $(git rev-parse --short origin/main)"
echo "== validate"; oc validate "$PKG"; echo "validate exit=$?"
echo "== dev"; oc dev "$PKG"; echo "dev exit=$?"
echo "== dev --json"; oc dev "$PKG" --json > "$B/logs/dev.json"; echo "dev-json exit=$?"
echo "== build"; oc build "$PKG" --out "$OUT"; echo "build exit=$?"
echo "== state dir contents after run:"; find "$OPENCLAW_STATE_DIR" | head -20
