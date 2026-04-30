#!/bin/bash
# API commands: issue search and get
# Sourced by jira.sh — requires core.sh

[[ -n "${_API_ISSUE_LOADED:-}" ]] && return 0
_API_ISSUE_LOADED=1

cmd_search() {
  local jql="$1"
  local limit="${2:-50}"
  local fields_json="${3:-$SEARCH_FIELDS_JSON}"
  local payload
  payload=$(python3 -c "
import json, sys
print(json.dumps({
  'jql': sys.argv[1],
  'maxResults': int(sys.argv[2]),
  'fields': json.loads(sys.argv[3])
}))
" "$jql" "$limit" "$fields_json")
  _curl -X POST "${JIRA_BASE}/rest/api/3/search/jql" -d "$payload"
}

cmd_get() {
  local key="$1"
  local fields="${2:-}"
  if [[ -n "$fields" ]]; then
    _curl "${JIRA_BASE}/rest/api/3/issue/${key}?fields=${fields}"
  else
    _curl "${JIRA_BASE}/rest/api/3/issue/${key}"
  fi
}

cmd_create() {
  local project="$1"
  local issuetype="$2"
  local summary="$3"
  local extra_fields="${4:-}"
  local payload
  payload=$(python3 -c "
import json, sys
project, issuetype, summary = sys.argv[1], sys.argv[2], sys.argv[3]
extra = sys.argv[4] if len(sys.argv) > 4 and sys.argv[4] else '{}'
try:
    extra_parsed = json.loads(extra)
except (json.JSONDecodeError, ValueError):
    extra_parsed = {}
fields = {
    'project': {'key': project},
    'issuetype': {'name': issuetype},
    'summary': summary,
}
fields.update(extra_parsed)
print(json.dumps({'fields': fields}))
" "$project" "$issuetype" "$summary" "$extra_fields")
  _curl -X POST "${JIRA_BASE}/rest/api/3/issue" -d "$payload"
}

cmd_find_user() {
  local query="$1"
  local root_dir
  root_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../" && pwd)"
  python3 -c "
import json, sys, os, glob

query = sys.argv[1].lower()
root_dir = sys.argv[2]
na_dir = os.path.expanduser('~/.node-assistant')

# Search roster files first
roster_files = []
for d in [na_dir, os.path.join(root_dir, 'config')]:
    roster_files.extend(glob.glob(os.path.join(d, 'team-roster-*.json')))

for rf in roster_files:
    try:
        with open(rf) as f:
            data = json.load(f)
        for name, github in data.get('members', {}).items():
            if query in name.lower():
                print(json.dumps({'displayName': name, 'github': github, 'source': os.path.basename(rf)}))
    except Exception:
        continue
" "$query" "$root_dir"

  # Also search via Jira API
  local encoded
  encoded=$(_jql_encode "$query")
  local results
  results=$(_curl "${JIRA_BASE}/rest/api/3/user/search?query=${query}&maxResults=5" 2>/dev/null) || true
  if [[ -n "$results" && "$results" != "[]" ]]; then
    echo "$results" | python3 -c "
import json, sys
users = json.load(sys.stdin)
for u in users:
    if u.get('accountType') == 'atlassian':
        print(json.dumps({'accountId': u['accountId'], 'displayName': u.get('displayName', ''), 'email': u.get('emailAddress', ''), 'source': 'jira-api'}))
" 2>/dev/null || true
  fi
}

cmd_assign() {
  local key="$1"
  local assignee="$2"

  local account_id=""

  # If it looks like an accountId already (contains colon), use directly
  if [[ "$assignee" == *":"* ]]; then
    account_id="$assignee"
  else
    # Try to resolve via find-user
    local matches
    matches=$(cmd_find_user "$assignee" 2>/dev/null)
    if [[ -n "$matches" ]]; then
      # Prefer Jira API result (has accountId)
      account_id=$(echo "$matches" | python3 -c "
import json, sys
lines = [l.strip() for l in sys.stdin if l.strip()]
for l in lines:
    d = json.loads(l)
    if 'accountId' in d:
        print(d['accountId'])
        sys.exit(0)
print('')
" 2>/dev/null)
    fi
    if [[ -z "$account_id" ]]; then
      echo "{\"error\":\"Could not resolve user '${assignee}'. Try jira.sh find-user '${assignee}' to search.\"}" >&2
      return 1
    fi
  fi

  local result
  result=$(_curl -X PUT "${JIRA_BASE}/rest/api/3/issue/${key}/assignee" \
    -d "{\"accountId\": \"${account_id}\"}" -w "\nHTTP_%{http_code}")
  local code
  code=$(echo "$result" | grep "HTTP_" | sed 's/HTTP_//')
  if [[ "$code" == "204" ]]; then
    echo "{\"key\":\"${key}\",\"assignee\":\"${assignee}\",\"accountId\":\"${account_id}\",\"status\":\"ok\"}"
  else
    local body
    body=$(echo "$result" | grep -v "HTTP_")
    echo "{\"key\":\"${key}\",\"status\":\"error\",\"code\":\"${code}\",\"response\":${body:-\"{}\"}}" >&2
    return 1
  fi
}
