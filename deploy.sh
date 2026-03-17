#!/usr/bin/env bash
# deploy.sh — sync the workspace to the AC Paintshop app folder.
#
# Usage:
#   ./deploy.sh          # deploy once
#   ./deploy.sh --watch  # deploy on every file save (requires inotifywait)

set -euo pipefail

AC_APP_DIR="/mnt/c/Program Files (x86)/Steam/steamapps/common/assettocorsa/apps/lua/Paintshop"

RSYNC_OPTS=(
  --archive
  --delete
  --checksum          # skip files whose content hasn't changed (faster than mtime on NTFS)
  --exclude='.git/'
  --exclude='*.bak'
  --exclude='.gitignore'
  --exclude='.gitattributes'
  --exclude='LICENSE'
  --exclude='README.md'
  --exclude='deploy.sh'
  --exclude='.dev/'
  --exclude='.vscode/'
)

deploy() {
  rsync "${RSYNC_OPTS[@]}" . "$AC_APP_DIR/"
  echo "[$(date +%T)] Deployed → $AC_APP_DIR"
}

if [[ "${1:-}" == "--watch" ]]; then
  if ! command -v inotifywait &>/dev/null; then
    echo "inotifywait not found. Install it with:"
    echo "  sudo apt install inotify-tools"
    exit 1
  fi

  echo "Watching for changes (Ctrl+C to stop)…"
  deploy

  # Watch .lua and .ini files; ignore .git and swap files
  while inotifywait -r -e close_write,moved_to,create,delete \
      --exclude '(\.git|\.bak|~$)' \
      --quiet . ; do
    deploy
  done
else
  deploy
fi
