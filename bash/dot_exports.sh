# Non-secret configuration
export EC2_IP=159.65.33.16
export MEILI_SERVER_URL="https://ersantana-meilisearch.hf.space/"
export HERMES_API_ENDPOINT="http://107.170.61.37/v1/chat/completions"
export HERMES_MODEL_NAME="hermes"
export DB_2_PORT="5432"
export DB_2_NAME="zatlas"
export DB_PORT="5432"
export DB_NAME="zatlas"
export USER_POOL_ID=""
export PMS_DB_URL="jdbc:postgresql://localhost:5432/zatlas"
export PMS_DB_USERNAME="postgres"
export PMS_DB_PASSWORD="postgres"
export PMS_DB_DRIVER_CLASS_NAME="org.postgresql.Driver"
export SPRING_PROFILES_ACTIVE=local
export DATADOG_USER_EMAIL=erick@zatlas.com
PGPASSWORD=postgres

# Load secrets from 1Password ("Bash Secrets" item in "Dev" vault)
# Caches locally so only the first terminal needs fingerprint auth.
#   load_secrets           — loads from cache, or fetches if no cache
#   load_secrets refresh   — re-fetches from 1Password and updates cache
_OP_CACHE="$HOME/.cache/op_secrets"

load_secrets() {
  local cache="$_OP_CACHE"

  if [[ "$1" != "refresh" ]] && [[ -f "$cache" ]]; then
    source "$cache"
    return 0
  fi

  if ! command -v op &>/dev/null; then
    echo "[warn] 1Password CLI not installed — secrets not loaded"
    return 1
  fi

  mkdir -p "$(dirname "$cache")"
  op item get 'Bash Secrets' --vault=Dev --format=json \
    | jq -r '.fields[] | select(.value != null and .value != "") | "export \(.label)=\(.value | @sh)"' \
    > "$cache"
  chmod 600 "$cache"
  source "$cache"
}

load_secrets

# Additional paths
path_extras=(
  "/usr/local/go/bin"
  "/opt/nvim-linux-x86_64/bin"
  "$HOME/.pulumi/bin"
  "$HOME/dev/tools/jira-cli"
)

for p in "${path_extras[@]}"; do
  [[ -d "$p" ]] && PATH="$PATH:$p"
done
export PATH
