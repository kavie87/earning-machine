#!/usr/bin/env bash
# Ask which bandwidth-sharing apps to run, store secrets in .env, and start them.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$ROOT"

if [[ "${OSTYPE:-}" == msys* || "${OSTYPE:-}" == win32* || "${OSTYPE:-}" == cygwin* ]]; then
  echo "Run this on the Debian or Ubuntu computer that will share its connection."
  exit 1
fi

echo "Earning machine setup"
echo
echo "Each app you enable shares this computer's internet connection."
echo "Read that app's terms before you continue. Enable only the apps you want."
echo "Passwords stay in .env on this computer."
echo

if [[ -f .env ]]; then
  read -rp ".env already exists. Replace it? (yes/no): " replace_env
  if [[ "$replace_env" != "yes" ]]; then
    echo "Left the existing .env in place."
    exit 0
  fi
fi

if ! command -v docker >/dev/null 2>&1; then
  echo "Docker is not installed."
  read -rp "Install Docker with the official get.docker.com script? (yes/no): " install_docker
  if [[ "$install_docker" != "yes" ]]; then
    echo "Install Docker, then run this script again."
    echo "https://docs.docker.com/engine/install/"
    exit 1
  fi
  if ! command -v curl >/dev/null 2>&1; then
    echo "curl is required to download the Docker installer."
    exit 1
  fi
  curl -fsSL https://get.docker.com -o /tmp/get-docker.sh
  sudo sh /tmp/get-docker.sh
  rm -f /tmp/get-docker.sh
fi

if ! docker compose version >/dev/null 2>&1; then
  echo "Docker Compose is not available. Install the Docker Compose plugin, then run this again."
  exit 1
fi

read -rp "Device name (letters, numbers, and dashes): " DEVICE_NAME
if [[ ! "$DEVICE_NAME" =~ ^[A-Za-z0-9][A-Za-z0-9-]{0,30}$ ]]; then
  echo "Use a device name like homelab or kurt-01."
  exit 1
fi

read -rp "Timezone [${TZ:-Australia/Sydney}]: " TZ_INPUT
TZ_VALUE="${TZ_INPUT:-${TZ:-Australia/Sydney}}"

quote_env() {
  local value="$1"
  value="${value//\\/\\\\}"
  value="${value//\"/\\\"}"
  value="${value//\$/\$\$}"
  value="${value//$'\r'/}"
  value="${value//$'\n'/}"
  printf '"%s"' "$value"
}

declare -a PROFILES=()
ENV_BODY=""

add_env() {
  ENV_BODY+="$1=$(quote_env "$2")"$'\n'
}

ask_yes() {
  local answer
  read -rp "$1 (yes/no): " answer
  [[ "$answer" == "yes" ]]
}

read_secret() {
  local prompt="$1"
  local __var="$2"
  local secret
  read -rsp "$prompt" secret
  echo
  if [[ -z "$secret" ]]; then
    echo "That value cannot be empty."
    exit 1
  fi
  printf -v "$__var" '%s' "$secret"
}

add_env DEVICE_NAME "$DEVICE_NAME"
add_env TZ "$TZ_VALUE"

echo
if ask_yes "Enable Honeygain? It shares bandwidth. Type yes only after you accept Honeygain's terms"; then
  read -rp "Honeygain email: " HONEYGAIN_EMAIL
  read_secret "Honeygain password: " HONEYGAIN_PASSWORD
  add_env HONEYGAIN_EMAIL "$HONEYGAIN_EMAIL"
  add_env HONEYGAIN_PASSWORD "$HONEYGAIN_PASSWORD"
  PROFILES+=("honeygain")
fi

echo
if ask_yes "Enable Pawns? Type yes only after you accept Pawns' terms"; then
  read -rp "Pawns email: " PAWNS_EMAIL
  read_secret "Pawns password: " PAWNS_PASSWORD
  add_env PAWNS_EMAIL "$PAWNS_EMAIL"
  add_env PAWNS_PASSWORD "$PAWNS_PASSWORD"
  PROFILES+=("pawns")
fi

echo
if ask_yes "Enable PacketStream? Type yes only after you accept PacketStream's terms"; then
  read_secret "PacketStream CID: " PACKETSTREAM_CID
  add_env PACKETSTREAM_CID "$PACKETSTREAM_CID"
  PROFILES+=("packetstream")
fi

echo
if ask_yes "Enable TraffMonetizer? Type yes only after you accept TraffMonetizer's terms"; then
  read_secret "TraffMonetizer token: " TRAFFMONETIZER_TOKEN
  add_env TRAFFMONETIZER_TOKEN "$TRAFFMONETIZER_TOKEN"
  PROFILES+=("traffmonetizer")
fi

echo
if ask_yes "Enable Repocket? Type yes only after you accept Repocket's terms"; then
  read_secret "Repocket API key: " REPOCKET_API_KEY
  add_env REPOCKET_API_KEY "$REPOCKET_API_KEY"
  PROFILES+=("repocket")
fi

echo
if ask_yes "Enable Mysterium? The node uses host networking. Type yes only after you accept Mysterium's terms"; then
  PROFILES+=("mysterium")
fi

echo
if ask_yes "Enable Bitping? Type yes only after you accept Bitping's terms"; then
  read -rp "Bitping email: " BITPING_EMAIL
  read_secret "Bitping password: " BITPING_PASSWORD
  add_env BITPING_EMAIL "$BITPING_EMAIL"
  add_env BITPING_PASSWORD "$BITPING_PASSWORD"
  PROFILES+=("bitping")
fi

echo
if ask_yes "Enable AntGain? Type yes only after you accept AntGain's terms"; then
  read_secret "AntGain API key: " ANTGAIN_API_KEY
  add_env ANTGAIN_API_KEY "$ANTGAIN_API_KEY"
  PROFILES+=("antgain")
fi

echo
if ask_yes "Enable Watchtower to update these containers every 12 hours? It needs access to the Docker socket"; then
  PROFILES+=("watchtower")
fi

umask 077
printf '%s' "$ENV_BODY" > .env
chmod 600 .env
echo
echo "Wrote .env with permissions restricted to this user."

if ((${#PROFILES[@]} > 0)); then
  compose_args=()
  for profile in "${PROFILES[@]}"; do
    compose_args+=(--profile "$profile")
  done
  echo "Checking Compose file..."
  docker compose "${compose_args[@]}" config >/dev/null
  if ask_yes "Start the selected containers now?"; then
    docker compose "${compose_args[@]}" up -d
    docker compose "${compose_args[@]}" ps
  else
    echo "Containers were not started. Start them later with:"
    printf '  docker compose'
    for profile in "${PROFILES[@]}"; do
      printf ' --profile %s' "$profile"
    done
    printf ' up -d\n'
  fi
else
  echo "No Docker apps selected."
fi

echo
if ask_yes "Install EarnApp with its official Linux installer? You will accept EarnApp's terms in that installer and link the device in a browser"; then
  if ! command -v curl >/dev/null 2>&1; then
    echo "curl is required to download the EarnApp installer."
    exit 1
  fi
  earnapp_script="$(mktemp)"
  trap 'rm -f "$earnapp_script"' EXIT
  curl --fail --location --silent --show-error \
    https://brightdata.com/static/earnapp/install.sh \
    --output "$earnapp_script"
  echo "Downloaded EarnApp's installer to a temporary file."
  sudo bash "$earnapp_script"
  echo
  echo "If the installer did not open a link, run: sudo earnapp register"
  echo "Check it with: sudo earnapp status"
fi

echo
echo "Finished."
echo "Dashboards are where you confirm each device is online."
echo "Honeygain and TraffMonetizer receive their secret as a container argument, so anyone who can run docker inspect on this machine can read it."
