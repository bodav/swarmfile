#!/bin/sh
# install.sh — installs swarmfile to ~/.local/bin
# Usage: curl -fsSL https://raw.githubusercontent.com/bodav/swarmfile/main/install.sh | sh
set -e

# ─── Configuration ────────────────────────────────────────────────────────────
REPO="bodav/swarmfile"
BRANCH="main"
INSTALL_DIR="${SWARMFILE_INSTALL_DIR:-${HOME}/.local/bin}"
SCRIPT_NAME="swarmfile"
RAW_URL="https://raw.githubusercontent.com/${REPO}/${BRANCH}/${SCRIPT_NAME}"

# ─── Helpers ──────────────────────────────────────────────────────────────────
info()  { printf '\033[0;36m[install]\033[0m %s\n' "$*"; }
ok()    { printf '\033[0;32m[install]\033[0m %s\n' "$*"; }
warn()  { printf '\033[1;33m[install]\033[0m %s\n' "$*" >&2; }
error() { printf '\033[0;31m[install] ERROR:\033[0m %s\n' "$*" >&2; }
fatal() { error "$*"; exit 1; }

# ─── Dependency checks ────────────────────────────────────────────────────────
check_download_tool() {
  if command -v curl >/dev/null 2>&1; then
    DOWNLOAD_CMD="curl"
  elif command -v wget >/dev/null 2>&1; then
    DOWNLOAD_CMD="wget"
  else
    fatal "Neither curl nor wget found. Install one and retry."
  fi
}

download() {
  _url="$1"
  _dest="$2"
  if [ "$DOWNLOAD_CMD" = "curl" ]; then
    curl -fsSL "$_url" -o "$_dest"
  else
    wget -qO "$_dest" "$_url"
  fi
}

# ─── Install ──────────────────────────────────────────────────────────────────
main() {
  info "Installing ${SCRIPT_NAME} from ${REPO}..."

  check_download_tool

  # Create install directory if it doesn't exist
  if [ ! -d "$INSTALL_DIR" ]; then
    info "Creating ${INSTALL_DIR}..."
    mkdir -p "$INSTALL_DIR"
  fi

  INSTALL_PATH="${INSTALL_DIR}/${SCRIPT_NAME}"

  # Download to a temp file first, then move atomically
  TMP_FILE=$(mktemp /tmp/swarmfile_install.XXXXXX)
  trap 'rm -f "$TMP_FILE"' EXIT

  info "Downloading from ${RAW_URL}..."
  if ! download "$RAW_URL" "$TMP_FILE"; then
    fatal "Download failed. Check the URL and your internet connection."
  fi

  # Basic sanity check — file should start with a shebang
  first_line=$(head -1 "$TMP_FILE")
  case "$first_line" in
    '#!'*) : ;;
    *) fatal "Downloaded file does not look like a script (no shebang). Aborting." ;;
  esac

  chmod +x "$TMP_FILE"
  mv "$TMP_FILE" "$INSTALL_PATH"

  ok "Installed to ${INSTALL_PATH}"

  # ─── PATH check ───────────────────────────────────────────────────────────
  case ":${PATH}:" in
    *":${INSTALL_DIR}:"*)
      : # already in PATH
      ;;
    *)
      warn "${INSTALL_DIR} is not in your PATH."
      warn "Add the following line to your shell profile (~/.bashrc, ~/.zshrc, etc.):"
      warn ""
      warn "  export PATH=\"\${HOME}/.local/bin:\${PATH}\""
      warn ""
      ;;
  esac

  # ─── Runtime dependency hints ─────────────────────────────────────────────
  missing=""
  command -v docker >/dev/null 2>&1 || missing="${missing} docker"
  command -v yq     >/dev/null 2>&1 || missing="${missing} yq"

  if [ -n "$missing" ]; then
    warn "Missing runtime dependencies:${missing}"
    warn "  docker : https://docs.docker.com/get-docker/"
    warn "  yq     : https://github.com/mikefarah/yq/releases  (mikefarah/yq v4+)"
  fi

  ok "Done. Run: swarmfile --help"
}

main "$@"
