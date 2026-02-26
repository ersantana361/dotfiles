# Usage:
#   ddlog-send <service> <message>                    - Send log with service and message
#   ddlog-send <service> <message> <source>            - Send log with custom source (for grok pipeline matching)
#   ddlog-send <service> <message> <source> <tags>     - Send log with extra tags (comma-separated)
#
# Examples:
#   ddlog-send pms-middleware "[oxi-outage] OUTAGE EMAIL SENT for hotel TEST service=OPERA_ON_PREMISE_OXI"
#   ddlog-send pms-middleware "some log message" zatlas-pms-middleware-repo "env:production,team:channels"
ddlog-send() {
  local service="${1:?Usage: ddlog-send <service> <message> [source] [tags]}"
  local message="${2:?Usage: ddlog-send <service> <message> [source] [tags]}"
  local source="${3:-$service}"
  local extra_tags="${4:-}"

  local tags="service:${service},env:production"
  if [ -n "$extra_tags" ]; then
    tags="${tags},${extra_tags}"
  fi

  local response
  response=$(curl -s -w "\n%{http_code}" -X POST "https://http-intake.logs.datadoghq.com/api/v2/logs" \
    -H "DD-API-KEY: $DATADOG_API_KEY" \
    -H "Content-Type: application/json" \
    -d "[{
      \"message\": \"$message\",
      \"ddsource\": \"$source\",
      \"ddtags\": \"$tags\",
      \"service\": \"$service\"
    }]")

  local http_code
  http_code=$(echo "$response" | tail -1)
  if [ "$http_code" = "202" ] || [ "$http_code" = "200" ]; then
    echo "✓ Log sent: service=$service source=$source"
    echo "  Message: ${message:0:120}"
    echo "  Tags: $tags"
    echo "  Tip: ddlogs \"service:$service ${message:0:30}\" \"5m\" 5"
  else
    echo "✗ Failed (HTTP $http_code)"
    echo "$response" | head -1
  fi
}

ddlogs() {
  local query="${1:-*}"
  local timeframe="${2:-1h}"
  local limit="${3:-20}"

  curl -s -X POST "https://api.datadoghq.com/api/v2/logs/events/search" \
    -H "DD-API-KEY: $DATADOG_API_KEY" \
    -H "DD-APPLICATION-KEY: $DATADOG_APP_KEY" \
    -H "Content-Type: application/json" \
    -d "{\"filter\": {\"query\": \"$query\", \"from\": \"now-$timeframe\", \"to\": \"now\"}, \"page\": {\"limit\": $limit}}" \
    | jq -r '.data[]? | "\(.attributes.timestamp) | \(.attributes.message // .attributes.attributes.message // "no message")[0:200]"'
}

# Usage:
#   ddmonitor list                      - List all monitors (id, name, status)
#   ddmonitor list <tag>                - List monitors filtered by tag (e.g. "service:zatlas-mono")
#   ddmonitor get <id>                  - Get full monitor details
#   ddmonitor create <file.json>        - Create monitor from JSON file
#   ddmonitor update <id> <file.json>   - Update monitor from JSON file
#   ddmonitor delete <id>               - Delete a monitor
#   ddmonitor mute <id> [minutes]       - Mute monitor (default: 60 min)
#   ddmonitor unmute <id>               - Unmute monitor
#   ddmonitor search <name_query>       - Search monitors by name
#   ddmonitor mine [email]              - List monitors created by you (or by email)
ddmonitor() {
  local api="https://api.datadoghq.com/api/v1/monitor"
  local auth=(-H "DD-API-KEY: $DATADOG_API_KEY" -H "DD-APPLICATION-KEY: $DATADOG_APP_KEY")
  local cmd="${1:-help}"
  shift 2>/dev/null

  case "$cmd" in
    list)
      local tag="$1"
      local url="$api"
      if [ -n "$tag" ]; then
        url="${api}?monitor_tags=$(python3 -c "import urllib.parse; print(urllib.parse.quote('$tag'))")"
      fi
      curl -s -X GET "$url" "${auth[@]}" \
        | jq -r '.[] | "\(.id)\t\(.overall_state)\t\(.name)"' \
        | column -t -s $'\t'
      ;;

    get)
      if [ -z "$1" ]; then echo "Usage: ddmonitor get <id>"; return 1; fi
      curl -s -X GET "${api}/$1" "${auth[@]}" | jq .
      ;;

    create)
      if [ -z "$1" ] || [ ! -f "$1" ]; then
        echo "Usage: ddmonitor create <file.json>"
        return 1
      fi
      curl -s -X POST "$api" "${auth[@]}" \
        -H "Content-Type: application/json" \
        -d @"$1" \
        | jq '{id: .id, name: .name, status: .overall_state, created: .created}'
      ;;

    update)
      if [ -z "$1" ] || [ -z "$2" ] || [ ! -f "$2" ]; then
        echo "Usage: ddmonitor update <id> <file.json>"
        return 1
      fi
      curl -s -X PUT "${api}/$1" "${auth[@]}" \
        -H "Content-Type: application/json" \
        -d @"$2" \
        | jq '{id: .id, name: .name, status: .overall_state, modified: .modified}'
      ;;

    delete)
      if [ -z "$1" ]; then echo "Usage: ddmonitor delete <id>"; return 1; fi
      echo -n "Delete monitor $1? [y/N] "
      read -r confirm
      if [ "$confirm" = "y" ] || [ "$confirm" = "Y" ]; then
        curl -s -X DELETE "${api}/$1" "${auth[@]}" | jq .
      else
        echo "Cancelled."
      fi
      ;;

    mute)
      if [ -z "$1" ]; then echo "Usage: ddmonitor mute <id> [minutes]"; return 1; fi
      local minutes="${2:-60}"
      local end_ts=$(date -d "+${minutes} minutes" +%s 2>/dev/null || date -v+${minutes}M +%s)
      curl -s -X POST "${api}/$1/mute" "${auth[@]}" \
        -H "Content-Type: application/json" \
        -d "{\"end\": $end_ts}" \
        | jq '{id: .id, name: .name, muted: true, mute_until: (.options.silenced // "indefinite")}'
      ;;

    unmute)
      if [ -z "$1" ]; then echo "Usage: ddmonitor unmute <id>"; return 1; fi
      curl -s -X POST "${api}/$1/unmute" "${auth[@]}" \
        | jq '{id: .id, name: .name, muted: false}'
      ;;

    search)
      if [ -z "$1" ]; then echo "Usage: ddmonitor search <name_query>"; return 1; fi
      local query="$1"
      curl -s -X GET "${api}/search?query=$query" "${auth[@]}" \
        | jq -r '.monitors[]? | "\(.id)\t\(.status)\t\(.name)"' \
        | column -t -s $'\t'
      ;;

    mine)
      local email="${1:-$DATADOG_USER_EMAIL}"
      if [ -z "$email" ]; then
        echo "Set DATADOG_USER_EMAIL or pass email: ddmonitor mine <email>"
        return 1
      fi
      curl -s -X GET "$api" "${auth[@]}" \
        | jq -r --arg email "$email" '.[] | select(.creator.email == $email) | "\(.id)\t\(.overall_state)\t\(.name)"' \
        | column -t -s $'\t'
      ;;

    test)
      if [ -z "$1" ] || [ -z "$2" ]; then
        echo "Usage: ddmonitor test <service> <message> [source]"
        echo ""
        echo "Send a test log to trigger a log-based monitor."
        echo "The message must match the monitor's query and any grok parser patterns."
        echo ""
        echo "Examples:"
        echo "  ddmonitor test pms-middleware '[oxi-outage] OUTAGE EMAIL SENT for hotel TEST service=OPERA_ON_PREMISE_OXI'"
        echo "  ddmonitor test pms-middleware '[health-check-email] OUTAGE EMAIL SENT for hotel TEST service=OPERA_ON_PREMISE_OWS'"
        return 1
      fi
      local service="$1"
      local message="$2"
      local source="${3:-${service}}"
      ddlog-send "$service" "$message" "$source"
      echo ""
      echo "Monitor should evaluate within ~2 minutes."
      echo "Check status: ddmonitor search <name> | ddmonitor get <id>"
      ;;

    help|*)
      echo "Usage: ddmonitor <command> [args]"
      echo ""
      echo "Commands:"
      echo "  list [tag]                List monitors (optionally filter by tag)"
      echo "  get <id>                  Get full monitor details"
      echo "  create <file.json>        Create monitor from JSON file"
      echo "  update <id> <file.json>   Update monitor from JSON file"
      echo "  delete <id>               Delete a monitor (with confirmation)"
      echo "  mute <id> [minutes]       Mute monitor (default: 60 min)"
      echo "  unmute <id>               Unmute monitor"
      echo "  search <name_query>       Search monitors by name"
      echo "  mine [email]              List monitors you created (auto-detects email)"
      echo "  test <svc> <msg> [src]    Send test log to trigger a log-based monitor"
      ;;
  esac
}
