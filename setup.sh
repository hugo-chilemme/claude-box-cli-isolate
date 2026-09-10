#!/usr/bin/env bash
set -euo pipefail

echo "=== claude-box setup (macOS) ==="

if ! docker ps >/dev/null 2>&1; then
  echo "ERROR: Docker is not responding. Start Docker Desktop first (open -a Docker)."
  exit 1
fi

echo "[1/3] Building Docker image..."
DOCKERFILE="$(mktemp)"
cat > "$DOCKERFILE" <<'EOF'
FROM node:22
RUN npm install -g @anthropic-ai/claude-code
WORKDIR /workspace
ENTRYPOINT ["claude"]
EOF
docker build -t claude-box:latest -f "$DOCKERFILE" "$(dirname "$DOCKERFILE")"
rm -f "$DOCKERFILE"

echo "[2/3] Creating persistent auth volume..."
docker volume create claude-auth >/dev/null

echo "[3/3] Installing script..."
BIN="/usr/local/bin/claude-box"
if [ ! -w "$(dirname "$BIN")" ]; then
  mkdir -p "$HOME/.local/bin"
  BIN="$HOME/.local/bin/claude-box"
  echo "  (installed in ~/.local/bin, make sure it is in your PATH)"
fi

cat > "$BIN" <<'SCRIPT'
#!/usr/bin/env bash
set -euo pipefail

CMD="${1:-}"; shift || true

case "$CMD" in
  up)
    [ $# -eq 0 ] && { echo "Usage: claude-box up <item1> [item2] ..."; exit 1; }

    MOUNTS=()
    for ITEM in "$@"; do
      ABS="$(pwd)/$ITEM"
      [ ! -e "$ABS" ] && { echo "ERROR: '$ITEM' does not exist"; exit 1; }
      MOUNTS+=( -v "$ABS:/workspace/$ITEM" )
      echo "  mounted: $ITEM -> /workspace/$ITEM (live sync)"
    done

    WORKDIR_HOST="$(pwd)"
    cleanup() {
      echo ""
      echo "Cleaning up claude-box files..."
      rm -rf "$WORKDIR_HOST/.claude" "$WORKDIR_HOST/CLAUDE.md" 2>/dev/null || true
      echo "Done."
    }
    trap cleanup EXIT

    echo "Starting Claude (container-isolated, /workspace live-synced)"
    docker run -it --rm \
      "${MOUNTS[@]}" \
      -v claude-auth:/root/.claude \
      -e CLAUDE_CONFIG_DIR=/root/.claude \
      -w /workspace \
      --entrypoint bash \
      claude-box:latest \
      -c 'cat > /workspace/CLAUDE.md <<EOF
# Workspace rule
All created or modified files must go DIRECTLY in /workspace. This directory is live-synced with the user machine.
EOF
exec claude'
    ;;

  down)
    echo "Cleaning up claude-box containers..."
    docker ps -a --filter "ancestor=claude-box:latest" -q | xargs -r docker rm -f
    rm -rf "$(pwd)/.claude" "$(pwd)/CLAUDE.md" 2>/dev/null || true
    echo "Done."
    ;;

  *)
    echo "claude-box <up|down>"
    echo "  up <items...>   mount each item into /workspace and start Claude"
    echo "  down            clean up containers and residual files"
    ;;
esac
SCRIPT

chmod +x "$BIN"

echo ""
echo "=== Done ==="
echo "Command: $BIN"
echo ""
echo "  cd ~/project"
echo "  claude-box up config.json app/routes"
echo "  claude-box down"
echo ""
echo "(First run: use /login inside Claude, then it is saved)"
