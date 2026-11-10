#!/bin/bash
# Installs or updates the Claude Usage desktop widget.
#   curl -fsSL https://raw.githubusercontent.com/kostiantyn-kaniuka/homebrew-claude-usage/main/install.sh | bash
set -euo pipefail

FORMULA="kostiantyn-kaniuka/claude-usage/claude-usage"

bold() { printf '\033[1m%s\033[0m\n' "$*"; }
ok()   { printf '  \033[32m✓\033[0m %s\n' "$*"; }
warn() { printf '  \033[33m!\033[0m %s\n' "$*"; }
fail() { printf '  \033[31m✗\033[0m %s\n' "$*" >&2; exit 1; }
ask()  { local a; read -r -p "  $1 [y/N] " a </dev/tty || true; [[ "$a" =~ ^[Yy]$ ]]; }

# Wrapped in a function so `curl | bash` reads the whole script before running it.
main() {
  bold "Claude Usage widget installer"

  # 1. macOS 14+
  [[ "$(uname)" == "Darwin" ]] || fail "This only runs on macOS."
  MACOS_MAJOR="$(sw_vers -productVersion | cut -d. -f1)"
  (( MACOS_MAJOR >= 14 )) || fail "Needs macOS 14 (Sonoma) or newer; you have $(sw_vers -productVersion)."
  ok "macOS $(sw_vers -productVersion)"

  # 2. Homebrew
  if ! command -v brew >/dev/null 2>&1; then
    for b in /opt/homebrew/bin/brew /usr/local/bin/brew; do
      [[ -x "$b" ]] && eval "$("$b" shellenv)" && break
    done
  fi
  command -v brew >/dev/null 2>&1 || fail "Homebrew not found. Install it from https://brew.sh, then run this again."
  ok "Homebrew $(brew --version | head -1 | awk '{print $2}')"

  # 3. Apple Command Line Tools (must match your macOS version, or Homebrew refuses to build)
  CLT_VERSION="$(pkgutil --pkg-info=com.apple.pkg.CLTools_Executables 2>/dev/null | awk '/^version:/{print $2}' || true)"
  if [[ -z "$CLT_VERSION" ]]; then
    warn "Apple Command Line Tools are not installed."
    xcode-select --install 2>/dev/null || true
    fail "Click \"Install\" in the dialog that just opened, wait for it to finish, then run this again."
  elif (( ${CLT_VERSION%%.*} < MACOS_MAJOR )); then
    warn "Command Line Tools $CLT_VERSION are older than macOS $MACOS_MAJOR; Homebrew will refuse to build."
    if ask "Reinstall them now? (asks for your Mac password)"; then
      sudo rm -rf /Library/Developer/CommandLineTools
      xcode-select --install 2>/dev/null || true
      fail "Click \"Install\" in the dialog that just opened, wait for it to finish, then run this again."
    fi
    fail "Update the Command Line Tools, then run this again."
  fi
  ok "Command Line Tools $CLT_VERSION"

  # 4. Claude Code login (checks the entry exists; does not read it)
  if security find-generic-password -s "Claude Code-credentials" >/dev/null 2>&1; then
    ok "Claude Code login found"
  else
    warn "No Claude Code login found. The widget will show \"Log in to Claude Code\" until you run 'claude' and log in."
  fi

  # 5. Install or update
  if brew list --formula claude-usage >/dev/null 2>&1; then
    bold "Updating…"
    brew update --quiet </dev/null >/dev/null 2>&1 || true
    brew upgrade "$FORMULA" </dev/null 2>/dev/null || true
  else
    bold "Installing…"
    brew install "$FORMULA" </dev/null
  fi

  claude-usage install </dev/null

  echo
  bold "Done! Last step:"
  echo "  Right-click the desktop → Edit Widgets… → search \"Claude Usage\" → drag it onto the desktop."
}

main "$@"
