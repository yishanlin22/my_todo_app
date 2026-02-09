#!/bin/bash
# Run this with the server already running (jac start main.jac)
# Usage: ./debug_walker.sh

BASE="http://localhost:8000"

echo "1. Registering user..."
REG=$(curl -s -X POST "$BASE/user/register" -H "Content-Type: application/json" -d '{"username": "debuguser", "password": "test1234"}')
echo "Register response: $REG"
TOKEN=$(echo "$REG" | python3 -c "
import sys,json
d=json.load(sys.stdin)
t=d.get('token') or (d.get('data') or {}).get('token') or ''
print(t or '')
" 2>/dev/null)

if [ -z "$TOKEN" ]; then
  echo "2. Trying login instead..."
  LOGIN=$(curl -s -X POST "$BASE/user/login" -H "Content-Type: application/json" -d '{"username": "debuguser", "password": "test1234"}')
  TOKEN=$(echo "$LOGIN" | python3 -c "
import sys,json
d=json.load(sys.stdin)
t=d.get('token') or (d.get('data') or {}).get('token') or ''
print(t or '')
" 2>/dev/null)
fi

if [ -z "$TOKEN" ]; then
  echo "Could not get token. Full register response above."
  exit 1
fi

echo "3. Got token. Calling ListTodos..."
RESP=$(curl -s -w "\n%{http_code}" -X POST "$BASE/walker/ListTodos" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"fields": {}}')

HTTP_CODE=$(echo "$RESP" | tail -n 1)
HTTP_BODY=$(echo "$RESP" | sed '$d')

echo "HTTP Status: $HTTP_CODE"
echo "Response body:"
echo "$HTTP_BODY" | python3 -m json.tool 2>/dev/null || echo "$HTTP_BODY"
