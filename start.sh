#!/usr/bin/env bash

set -e

# ======================================
# Hytale F2P Server Launcher (Linux)
# ======================================

echo "======================================"
echo "   Hytale F2P Server Launcher (Linux)"
echo "======================================"
echo

# ------------------------------
# Configuration
# ------------------------------

HYTALE_SERVER_URL="${HYTALE_SERVER_URL:-https://files.hytalef2p.com/jar}"
HYTALE_AUTH_DOMAIN="${HYTALE_AUTH_DOMAIN:-sanasol.ws}"
HYTALE_BIND="${HYTALE_BIND:-0.0.0.0:5520}"
HYTALE_AUTH_MODE="${HYTALE_AUTH_MODE:-authenticated}"
HYTALE_SERVER_NAME="${HYTALE_SERVER_NAME:-My Hytale Server}"

JVM_XMS="${JVM_XMS:-2G}"
JVM_XMX="${JVM_XMX:-4G}"

# ------------------------------
# Game Directory (FIXED PATH)
# ------------------------------

# Your actual game folder
GAME_DIR=".."

# Optional override
if [[ -n "$HYTALE_GAME_PATH" ]]; then
    GAME_DIR="$HYTALE_GAME_PATH"
fi

SERVER_DIR="Server"
SERVER_JAR="HytaleServer.jar"
AOT_CACHE="HytaleServer.aot"
ASSETS_PATH="Assets.zip"
UNIVERSE_PATH="universe"

# ------------------------------
# Check Java
# ------------------------------

echo "=== Checking Java ==="

if ! command -v java >/dev/null 2>&1; then
    echo "[ERROR] Java not found! Install Java 21+"
    exit 1
fi

JAVA_VERSION=$(java -version 2>&1 | grep version | awk '{print $3}' | tr -d '"')
JAVA_MAJOR=$(echo "$JAVA_VERSION" | cut -d. -f1)

echo "[INFO] Java version: $JAVA_VERSION"

if [[ "$JAVA_MAJOR" -lt 21 ]]; then
    echo "[ERROR] Java 21+ required!"
    exit 1
fi

# ------------------------------
# Check Files
# ------------------------------

echo
echo "=== Checking Files ==="
echo "[INFO] Game directory: $GAME_DIR"

if [[ ! -d "$GAME_DIR" ]]; then
    echo "[ERROR] Game directory not found"
    exit 1
fi

if [[ ! -f "$ASSETS_PATH" ]]; then
    echo "[ERROR] Assets.zip not found: $ASSETS_PATH"
    exit 1
fi

# ------------------------------
# Download Server JAR
# ------------------------------

echo
echo "=== Checking Server JAR ==="

mkdir -p "$SERVER_DIR"

if [[ ! -f "$SERVER_JAR" ]]; then
    echo "[INFO] Downloading server jar..."

    curl -L "$HYTALE_SERVER_URL" -o "$SERVER_JAR"

    if [[ ! -f "$SERVER_JAR" ]]; then
        echo "[ERROR] Download failed"
        exit 1
    fi
else
    echo "[INFO] Server JAR found"
fi

# ------------------------------
# Fetch Tokens
# ------------------------------

echo
echo "=== Fetching Server Tokens ==="

AUTH_SERVER="https://sessions.$HYTALE_AUTH_DOMAIN"
SERVER_UUID=$(uuidgen)

echo "[INFO] Auth server: $AUTH_SERVER"
echo "[INFO] Server UUID: $SERVER_UUID"
echo "[INFO] Server name: $HYTALE_SERVER_NAME"

SESSION_TOKEN=""
IDENTITY_TOKEN=""

RESPONSE=$(curl -s -X POST "$AUTH_SERVER/game-session/new" \
  -H "Content-Type: application/json" \
  -d "{\"uuid\":\"$SERVER_UUID\",\"name\":\"$HYTALE_SERVER_NAME\"}" || true)

SESSION_TOKEN=$(echo "$RESPONSE" | jq -r '.sessionToken // empty')
IDENTITY_TOKEN=$(echo "$RESPONSE" | jq -r '.identityToken // empty')

if [[ -n "$SESSION_TOKEN" ]]; then
    echo "[INFO] Session token obtained"
else
    echo "[WARN] No session token"
fi

if [[ -n "$IDENTITY_TOKEN" ]]; then
    echo "[INFO] Identity token obtained"
else
    echo "[WARN] No identity token"
fi

# ------------------------------
# Start Server
# ------------------------------

echo
echo "=== Starting Server ==="

cd "$SERVER_DIR"

echo "[INFO] Bind: $HYTALE_BIND"
echo "[INFO] Auth: $HYTALE_AUTH_MODE"
echo "[INFO] Memory: $JVM_XMS - $JVM_XMX"
echo

JAVA_ARGS="-Xms$JVM_XMS -Xmx$JVM_XMX -Dterminal.jline=false -Dterminal.ansi=true"

# Optional AOT
if [[ "$ENABLE_AOT" == "true" && -f "$AOT_CACHE" ]]; then
    if java -XX:+UnlockExperimentalVMOptions -XX:AOTMode=auto -version >/dev/null 2>&1; then
        JAVA_ARGS="$JAVA_ARGS -XX:+UnlockExperimentalVMOptions -XX:AOTCache=$AOT_CACHE -XX:AOTMode=auto"
        echo "[INFO] AOT enabled"
    else
        echo "[INFO] AOT not supported"
    fi
fi

SERVER_ARGS="--assets $ASSETS_PATH --bind $HYTALE_BIND --auth-mode $HYTALE_AUTH_MODE --disable-sentry"

if [[ -d "$UNIVERSE_PATH" ]]; then
    SERVER_ARGS="$SERVER_ARGS --universe $UNIVERSE_PATH"
fi

if [[ -n "$SESSION_TOKEN" ]]; then
    SERVER_ARGS="$SERVER_ARGS --session-token $SESSION_TOKEN"
fi

if [[ -n "$IDENTITY_TOKEN" ]]; then
    SERVER_ARGS="$SERVER_ARGS --identity-token $IDENTITY_TOKEN"
fi

# Extra args
SERVER_ARGS="$SERVER_ARGS $*"

echo "=== Server Ready ==="
echo "Press Ctrl+C to stop"
echo

exec java $JAVA_ARGS -jar "$SERVER_JAR" $SERVER_ARGS

