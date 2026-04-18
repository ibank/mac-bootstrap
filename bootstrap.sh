#!/usr/bin/env bash
set -euo pipefail

# macOS one-shot bootstrap for Apple Silicon Macs
# Target: M1/M2/M3/M4 MacBook Air/Pro
# Safe to re-run. Installs common developer tools and applies basic preferences.

############################
# Config (edit if needed)
############################
GIT_USER_NAME="${GIT_USER_NAME:-}"
GIT_USER_EMAIL="${GIT_USER_EMAIL:-}"
INSTALL_CASK_APPS="${INSTALL_CASK_APPS:-1}"
INSTALL_AI_TOOLS="${INSTALL_AI_TOOLS:-0}"      # set 1 to install ollama
INSTALL_DB_TOOLS="${INSTALL_DB_TOOLS:-0}"      # set 1 to install redis/postgresql
INSTALL_KAKAOTALK="${INSTALL_KAKAOTALK:-1}"    # install via Mac App Store using mas
SKIP_BREW_UPDATE="${SKIP_BREW_UPDATE:-0}"

BREW_PREFIX="/opt/homebrew"
BREW_BIN="$BREW_PREFIX/bin/brew"
KAKAOTALK_APPSTORE_ID="869223134"

# Homebrew behavior: keep runs predictable and avoid the auto-cleanup that
# has been observed to silently remove unrelated casks (claude-code #18010).
export HOMEBREW_NO_INSTALL_CLEANUP=1
export HOMEBREW_NO_AUTO_UPDATE=1
export HOMEBREW_NO_ENV_HINTS=1

log()  { printf '\n\033[1;34m==> %s\033[0m\n' "$*"; }
warn() { printf '\n\033[1;33m[WARN] %s\033[0m\n' "$*"; }
err()  { printf '\n\033[1;31m[ERR] %s\033[0m\n' "$*"; }

require_sudo() {
  if ! sudo -v; then
    err "sudo 인증이 필요합니다."
    exit 1
  fi
  # Keep sudo alive while the script runs so long steps (Rosetta, CLT wait)
  # don't prompt again mid-run. The loop exits when this shell does.
  ( while true; do
      sudo -n true 2>/dev/null || exit
      sleep 60
      kill -0 "$$" 2>/dev/null || exit
    done ) &
}

is_apple_silicon() {
  [[ "$(uname -m)" == "arm64" ]]
}

ensure_rosetta() {
  if /usr/bin/pgrep oahd >/dev/null 2>&1; then
    log "Rosetta 2 already present"
    return
  fi
  log "Installing Rosetta 2 (for Intel-only apps if needed)"
  /usr/sbin/softwareupdate --install-rosetta --agree-to-license || true
}

wait_for_clt() {
  if xcode-select -p >/dev/null 2>&1; then
    log "Command Line Tools already installed: $(xcode-select -p)"
    return
  fi

  log "Requesting Xcode Command Line Tools install"
  xcode-select --install || true

  cat <<'EOF'

[중요]
macOS 팝업이 뜨면 "설치"를 눌러주세요.
설치가 끝날 때까지 이 스크립트는 대기합니다.

EOF

  until xcode-select -p >/dev/null 2>&1; do
    sleep 10
    printf "."
  done
  echo
  log "Command Line Tools installed: $(xcode-select -p)"
}

install_homebrew() {
  if [[ -x "$BREW_BIN" ]]; then
    log "Homebrew already installed: $($BREW_BIN --version | head -n 1)"
  else
    log "Installing Homebrew"
    NONINTERACTIVE=1 /bin/bash -c \
      "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  fi

  if ! grep -qs 'eval "$(/opt/homebrew/bin/brew shellenv)"' "$HOME/.zprofile" 2>/dev/null; then
    echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >> "$HOME/.zprofile"
  fi
  eval "$("$BREW_BIN" shellenv)"

  if [[ "$SKIP_BREW_UPDATE" != "1" ]]; then
    log "Updating Homebrew"
    "$BREW_BIN" update
  fi
}

brew_install_formula() {
  local pkg="$1"
  if "$BREW_BIN" list --formula "$pkg" >/dev/null 2>&1; then
    log "Formula already installed: $pkg"
  else
    log "Installing formula: $pkg"
    "$BREW_BIN" install "$pkg"
  fi
}

brew_install_cask() {
  local pkg="$1"
  if "$BREW_BIN" list --cask "$pkg" >/dev/null 2>&1; then
    log "Cask already installed: $pkg"
  else
    log "Installing cask: $pkg"
    "$BREW_BIN" install --cask "$pkg"
  fi
}

apply_macos_defaults() {
  log "Applying Finder / Dock / keyboard / appearance preferences"

  # Enable dark mode
  osascript -e 'tell application "System Events" to tell appearance preferences to set dark mode to true' || true

  # Show all filename extensions
  defaults write NSGlobalDomain AppleShowAllExtensions -bool true

  # Show hidden files in Finder
  defaults write com.apple.finder AppleShowAllFiles -bool true

  # Finder list view by default
  defaults write com.apple.finder FXPreferredViewStyle -string "Nlsv"

  # Dock auto-hide
  defaults write com.apple.dock autohide -bool true

  # Fast key repeat
  defaults write NSGlobalDomain KeyRepeat -int 2
  defaults write NSGlobalDomain InitialKeyRepeat -int 15

  # Tap to click (needs all three domains to apply for login window + new sessions)
  defaults write com.apple.AppleMultitouchTrackpad Clicking -bool true
  defaults write com.apple.driver.AppleBluetoothMultitouch.trackpad Clicking -bool true
  defaults -currentHost write NSGlobalDomain com.apple.mouse.tapBehavior -int 1
  defaults write NSGlobalDomain com.apple.mouse.tapBehavior -int 1

  killall Finder >/dev/null 2>&1 || true
  killall Dock >/dev/null 2>&1 || true
}

install_core_tools() {
  local formulas=(
    git gh wget curl jq fzf ripgrep fd bat tree htop coreutils gnu-sed
    mas python pipx node pnpm
  )

  for pkg in "${formulas[@]}"; do
    brew_install_formula "$pkg"
  done

  # bun lives in its own tap. Using the tap-qualified name installs and
  # auto-taps in one step without a separate `brew tap` call.
  if "$BREW_BIN" list --formula bun >/dev/null 2>&1; then
    log "Formula already installed: bun"
  else
    log "Installing bun from oven-sh/bun tap"
    "$BREW_BIN" install oven-sh/bun/bun
  fi

  log "Ensuring pipx path"
  pipx ensurepath || true

  warn "GitHub CLI(gh)는 설치만 합니다. 로그인은 나중에 'gh auth login'으로 진행하세요."

  if [[ -n "$GIT_USER_NAME" ]]; then
    git config --global user.name "$GIT_USER_NAME"
  fi
  if [[ -n "$GIT_USER_EMAIL" ]]; then
    git config --global user.email "$GIT_USER_EMAIL"
  fi

  git config --global credential.helper osxkeychain
}

install_optional_db_tools() {
  if [[ "$INSTALL_DB_TOOLS" == "1" ]]; then
    brew_install_formula redis
    brew_install_formula postgresql@18
  fi
}

install_optional_ai_tools() {
  if [[ "$INSTALL_AI_TOOLS" == "1" ]]; then
    brew_install_formula ollama
  fi
}

install_cask_apps() {
  [[ "$INSTALL_CASK_APPS" == "1" ]] || return 0

  local casks=(
    google-chrome
    visual-studio-code
    iterm2
    rectangle
    appcleaner

    # requested apps
    obsidian
    claude
    claude-code
    ghostty
    orbstack
  )

  for pkg in "${casks[@]}"; do
    brew_install_cask "$pkg"
  done

  warn "OrbStack는 Docker Desktop 대체제입니다. 둘을 함께 쓸 계획이 없다면 Docker Desktop은 굳이 설치하지 않아도 됩니다."
  warn "OrbStack는 설치 후 한 번 직접 실행해서 초기 설정을 마무리하세요."
  warn "Claude Code를 최신 채널로 원하면: brew install --cask claude-code@latest"
}

install_kakaotalk() {
  [[ "$INSTALL_KAKAOTALK" == "1" ]] || return 0

  if ! command -v mas >/dev/null 2>&1; then
    warn "mas가 없어 카카오톡 설치를 건너뜁니다."
    return 0
  fi

  log "Installing KakaoTalk via Mac App Store (mas)"
  # `mas list` prints "<id> <name> (<ver>)" — match the id as a whole token.
  if mas list 2>/dev/null | awk '{print $1}' | grep -qx "$KAKAOTALK_APPSTORE_ID"; then
    log "KakaoTalk already installed via App Store"
    return 0
  fi

  # `mas account` was removed in mas 2.x, so we just attempt install and let
  # mas surface the actual error (usually "not signed in to the App Store").
  if ! mas install "$KAKAOTALK_APPSTORE_ID"; then
    warn "카카오톡 설치 실패. App Store 앱에서 로그인했는지 확인 후 다시 실행하세요."
  fi
}

generate_ssh_key_if_missing() {
  local email="${GIT_USER_EMAIL:-}"
  local key="$HOME/.ssh/id_ed25519"

  mkdir -p "$HOME/.ssh"
  chmod 700 "$HOME/.ssh"

  if [[ -f "$key" ]]; then
    log "SSH key already exists: $key"
  else
    if [[ -z "$email" ]]; then
      email="mac-bootstrap@local"
    fi
    # Non-interactive run: create the key without a passphrase. macOS launchd
    # manages ssh-agent automatically, so we skip ssh-add / Keychain (Keychain
    # only stores a passphrase — a passphrase-less key has nothing to store).
    log "Generating SSH key (no passphrase — non-interactive bootstrap)"
    warn "보안을 높이려면 나중에 'ssh-keygen -p -f $key' 로 passphrase를 설정하고,"
    warn "  passphrase를 Keychain에 저장: ssh-add --apple-use-keychain $key"
    ssh-keygen -t ed25519 -C "$email" -f "$key" -N ""
  fi

  if ! grep -q "Host github.com" "$HOME/.ssh/config" 2>/dev/null; then
    cat >> "$HOME/.ssh/config" <<'EOF'

Host github.com
  AddKeysToAgent yes
  UseKeychain yes
  IdentityFile ~/.ssh/id_ed25519
EOF
    chmod 600 "$HOME/.ssh/config"
  fi

  log "Public SSH key copied below. Add it to GitHub / GitLab if needed:"
  echo "------------------------------------------------------------"
  cat "${key}.pub"
  echo "------------------------------------------------------------"
}

write_brewfile() {
  local brewfile="$HOME/Brewfile"
  log "Writing $brewfile"
  # Note: optional AI/DB tools (INSTALL_AI_TOOLS, INSTALL_DB_TOOLS) are intentionally
  # not included here. Edit this Brewfile to match your install before `brew bundle`.
  cat > "$brewfile" <<'EOF'
tap "oven-sh/bun"

brew "git"
brew "gh"
brew "wget"
brew "curl"
brew "jq"
brew "fzf"
brew "ripgrep"
brew "fd"
brew "bat"
brew "tree"
brew "htop"
brew "coreutils"
brew "gnu-sed"
brew "mas"
brew "python"
brew "pipx"
brew "node"
brew "pnpm"
brew "bun"

cask "google-chrome"
cask "visual-studio-code"
cask "iterm2"
cask "rectangle"
cask "appcleaner"
cask "obsidian"
cask "claude"
cask "claude-code"
cask "ghostty"
cask "orbstack"

mas "KakaoTalk", id: 869223134
EOF
}

post_install_notes() {
  cat <<'EOF'

완료되었습니다.

다음 권장 작업:
1) 새 터미널 열기 (PATH / zprofile 반영)
2) GitHub 로그인:
   gh auth login
3) Claude Code 로그인:
   claude
4) VS Code 실행 후 "Shell Command: Install 'code' command in PATH"
5) OrbStack 1회 실행해 초기 설정 마무리
6) KakaoTalk이 안 깔렸다면 App Store 로그인 후 스크립트 재실행
7) Brewfile 재사용:
   brew bundle --file ~/Brewfile

선택 설치:
- AI 툴 포함: INSTALL_AI_TOOLS=1 ./bootstrap.sh
- DB 툴 포함: INSTALL_DB_TOOLS=1 ./bootstrap.sh
- Git 사용자 정보 포함:
  GIT_USER_NAME="홍길동" GIT_USER_EMAIL="me@example.com" ./bootstrap.sh

참고:
- Claude Code Homebrew cask는 auto-update가 없음. Anthropic 공식 권장은 native installer:
    curl -fsSL https://claude.ai/install.sh | bash
  cask를 유지하면서 최신 채널을 쓰려면: brew install --cask claude-code@latest
- KakaoTalk은 Mac App Store 앱으로 설치됩니다. 처음 실행 전 App Store 로그인 필요.
- SSH 키는 passphrase 없이 생성되었습니다. 보안을 올리려면:
    ssh-keygen -p -f ~/.ssh/id_ed25519
    ssh-add --apple-use-keychain ~/.ssh/id_ed25519

EOF
}

main() {
  log "Starting macOS bootstrap"

  if ! is_apple_silicon; then
    err "이 스크립트는 Apple Silicon(arm64) 전용입니다. 현재 아키텍처: $(uname -m)"
    err "Intel Mac은 /opt/homebrew가 아닌 /usr/local 경로를 사용하므로 이 스크립트는 동작하지 않습니다."
    exit 1
  fi

  require_sudo

  # CLT는 Homebrew 설치의 전제조건이므로 항상 먼저 확인/설치한다.
  wait_for_clt
  ensure_rosetta

  install_homebrew
  install_core_tools
  install_optional_db_tools
  install_optional_ai_tools
  install_cask_apps
  install_kakaotalk
  generate_ssh_key_if_missing
  write_brewfile

  # defaults는 Finder/Dock을 재시작하므로 설치 작업이 모두 끝난 뒤 적용한다.
  apply_macos_defaults

  post_install_notes
}

main "$@"
