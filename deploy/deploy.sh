#!/bin/bash
set -e

# =========================
# CONFIG
# =========================

SERVER_HOST="root@46.224.63.244"
REMOTE_DIR="~/smash-dash"

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TEMP_DIR="/tmp/smash-dash"

BACKEND_DIR="$REPO_ROOT/backend"
GODOT_PROJECT_DIR="$REPO_ROOT/godot"

GODOT_BIN="/Applications/Godot.app/Contents/MacOS/Godot"
GODOT_EXPORT_PRESET="Server"

# =========================
# CLEAN TEMP FOLDER
# =========================

echo "Cleaning temp deploy folder..."
rm -rf "$TEMP_DIR"
mkdir -p "$TEMP_DIR/backend"
mkdir -p "$TEMP_DIR/godot-server"

# =========================
# COPY BACKEND SOURCE
# =========================

echo "Copying backend..."
rsync -a \
  --progress \
  --exclude node_modules \
  --exclude .git \
  --exclude dist \
  "$BACKEND_DIR/" "$TEMP_DIR/backend/"

# =========================
# EXPORT GODOT SERVER
# =========================

echo "Exporting Godot server..."

"$GODOT_BIN" \
  --headless \
  --path "$GODOT_PROJECT_DIR" \
  --export-release "$GODOT_EXPORT_PRESET" \
  "$TEMP_DIR/godot-server/server.x86_64"

# =========================
# COPY DEPLOY FILES
# =========================

echo "Copying deploy files..."

cp "$REPO_ROOT/deploy/docker-compose.yml" "$TEMP_DIR/docker-compose.yml"
cp "$REPO_ROOT/deploy/godot-server.Dockerfile" "$TEMP_DIR/godot-server/Dockerfile"
cp "$REPO_ROOT/deploy/godot-server.dockerignore" "$TEMP_DIR/godot-server/.dockerignore"
cp "$REPO_ROOT/deploy/backend.Dockerfile" "$TEMP_DIR/backend/Dockerfile"
cp "$REPO_ROOT/deploy/backend.dockerignore" "$TEMP_DIR/backend/.dockerignore"

# =========================
# UPLOAD TO VM
# =========================

echo "Uploading to VM..."

rsync -a \
  --progress \
  --delete \
  --exclude node_modules \
  --exclude dist \
  --exclude .git \
  -e "ssh -o ServerAliveInterval=30 -o ServerAliveCountMax=10" \
  "$TEMP_DIR/" \
  "$SERVER_HOST:$REMOTE_DIR/"

# =========================
# DEPLOY ON VM
# =========================

echo "Deploying on VM..."

ssh "$SERVER_HOST" "
  cd $REMOTE_DIR &&
  docker compose down &&
  docker compose build &&
  docker compose up -d backend postgres
"

echo "Deployment complete."