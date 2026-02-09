#!/bin/bash
# Patch client_runtime.js to wrap walker request body in {"fields": ...}
# The jac start API expects this format. Run this after "jac clean --all" or whenever
# the client is rebuilt.
# Usage: ./patch_client_runtime.sh

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
RUNTIME="$SCRIPT_DIR/.jac/client/compiled/client_runtime.js"

if [ ! -f "$RUNTIME" ]; then
  echo "client_runtime.js not found. Run 'jac start main.jac' first to build the client."
  exit 1
fi

if grep -q 'JSON.stringify({"fields": fields})' "$RUNTIME"; then
  echo "client_runtime.js already patched."
  exit 0
fi

sed -i.bak 's/JSON.stringify(fields)/JSON.stringify({"fields": fields})/g' "$RUNTIME"
echo "Patched client_runtime.js - walker requests now use correct format."
rm -f "${RUNTIME}.bak"
