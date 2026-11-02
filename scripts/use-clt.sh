#!/usr/bin/env bash
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
"$PROJECT_DIR/scripts/build-clt.sh"

mkdir -p "$HOME/Applications"
ditto "$PROJECT_DIR/build/clt/Switch.app" "$HOME/Applications/Switch Local.app"
open "$HOME/Applications/Switch Local.app"
