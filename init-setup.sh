#!/usr/bin/env bash
# dash/sh (e.g. "sh -c \"$(curl ...)\"") lacks pipefail and other bash features.
if [ -z "${BASH_VERSION:-}" ]; then
  case "$0" in
    *init-setup*)
      if [ -f "$0" ] && command -v bash >/dev/null 2>&1; then
        exec bash "$0" "$@"
      fi
      ;;
  esac
  printf '%s\n' '[init-setup] Error: bash is required (this was run with sh/dash).' >&2
  printf '%s\n' '[init-setup] Use: bash -c "$(curl -fsSL https://raw.githubusercontent.com/radu-pythia/init-setup/main/init-setup.sh)"' >&2
  exit 1
fi
set -euo pipefail

STARSHIP_CONFIG_URL="https://raw.githubusercontent.com/radu-pythia/init-setup/main/starship.toml"
FONT_URL="https://github.com/ryanoasis/nerd-fonts/releases/download/v2.1.0/FiraCode.zip"
INIT_SETUP_MARKER="init-setup"
OS_ID=""

log() {
  printf '[init-setup] %s\n' "$*"
}

ubuntu_like() {
  [[ "${OS_ID}" == ubuntu || "${OS_ID}" == pop ]]
}

universe_enabled() {
  local f
  for f in /etc/apt/sources.list /etc/apt/sources.list.d/*; do
    [[ -f "${f}" ]] || continue
    if grep -qE '^[^#[:space:]].*\buniverse\b' "${f}" 2>/dev/null; then
      return 0
    fi
    if grep -qE '^Components:.*\buniverse\b' "${f}" 2>/dev/null; then
      return 0
    fi
  done
  return 1
}

ensure_universe() {
  if ! ubuntu_like; then
    return 0
  fi

  if universe_enabled; then
    log "Universe repository is enabled"
    return 0
  fi

  log "Universe repository is not enabled (required for nala)"
  log "Enabling universe..."
  sudo DEBIAN_FRONTEND=noninteractive apt-get install -y software-properties-common
  sudo add-apt-repository -y universe
  sudo apt-get update -qq

  if ! universe_enabled; then
    log "Error: failed to enable universe. Try: sudo add-apt-repository universe"
    exit 1
  fi
  log "Universe repository enabled"
}

check_os() {
  if ! command -v apt-get >/dev/null 2>&1; then
    log "Error: apt-get not found. This script supports Debian/Ubuntu only."
    exit 1
  fi
  if [[ -f /etc/os-release ]]; then
    # shellcheck source=/dev/null
    source /etc/os-release
    OS_ID="${ID:-}"
    case "${OS_ID}" in
      ubuntu | debian | pop) ;;
      *)
        log "Warning: unsupported distro '${OS_ID:-unknown}'. Continuing anyway (apt-get found)."
        ;;
    esac
  fi
}

font_installed() {
  local dir f
  for dir in "${HOME}/.fonts" "${HOME}/.local/share/fonts"; do
    [[ -d "${dir}" ]] || continue
    for f in "${dir}"/FiraCode*NerdFont*.ttf; do
      [[ -e "${f}" ]] && return 0
    done
  done
  return 1
}

install_packages() {
  log "Installing packages..."
  sudo apt-get update -qq
  ensure_universe
  sudo DEBIAN_FRONTEND=noninteractive apt-get install -y git zsh curl wget unzip fontconfig nala
}

install_oh_my_zsh() {
  if [[ -d "${HOME}/.oh-my-zsh" ]]; then
    log "oh-my-zsh already installed, skipping"
    return
  fi
  log "Installing oh-my-zsh..."
  RUNZSH=no CHSH=no sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
}

install_starship() {
  if command -v starship >/dev/null 2>&1; then
    log "starship already installed, skipping"
    return
  fi
  log "Installing starship..."
  sh -c "$(curl -fsSL https://starship.rs/install.sh)"
}

install_font() {
  if font_installed; then
    log "FiraCode Nerd Font already installed, skipping"
    return
  fi
  log "Downloading FiraCode Nerd Font..."
  mkdir -p "${HOME}/.fonts"
  wget -q -O "${TMPDIR}/FiraCode.zip" "${FONT_URL}"
  unzip -qo "${TMPDIR}/FiraCode.zip" -d "${HOME}/.fonts"
  fc-cache -fv
  log "FiraCode Nerd Font installed"
}

install_zsh_autosuggestions() {
  local plugin_dir="${ZSH_CUSTOM:-${HOME}/.oh-my-zsh/custom}/plugins/zsh-autosuggestions"
  if [[ -d "${plugin_dir}" ]]; then
    log "zsh-autosuggestions already installed, skipping"
    return
  fi
  log "Installing zsh-autosuggestions..."
  git clone https://github.com/zsh-users/zsh-autosuggestions "${plugin_dir}"
}

configure_zshrc() {
  local zshrc="${HOME}/.zshrc"

  if [[ ! -f "${zshrc}" ]]; then
    log "Error: ${zshrc} not found (oh-my-zsh should have created it)"
    exit 1
  fi

  if grep -q "${INIT_SETUP_MARKER}:begin" "${zshrc}"; then
    log "init-setup block already present in .zshrc, skipping plugin config"
  elif grep -q '^plugins=(' "${zshrc}"; then
    log "Configuring plugins in .zshrc..."
    if ! grep -q 'zsh-autosuggestions' "${zshrc}"; then
      sed -i 's/^plugins=(\(.*\))/plugins=(\1 zsh-autosuggestions)/' "${zshrc}"
    fi
    sed -i "/^plugins=(/i# ${INIT_SETUP_MARKER}:begin" "${zshrc}"
    sed -i "/^plugins=(/a# ${INIT_SETUP_MARKER}:end" "${zshrc}"
  else
    log "Adding plugins block to .zshrc..."
    cat >>"${zshrc}" <<EOF

# ${INIT_SETUP_MARKER}:begin
plugins=(git zsh-autosuggestions)
# ${INIT_SETUP_MARKER}:end
EOF
  fi

  if ! grep -q 'starship init zsh' "${zshrc}"; then
    log "Adding starship init to .zshrc..."
    echo 'eval "$(starship init zsh)"  # init-setup' >>"${zshrc}"
  fi
}

install_starship_config() {
  log "Installing starship config..."
  mkdir -p "${HOME}/.config"
  wget -q -O "${TMPDIR}/starship.toml" "${STARSHIP_CONFIG_URL}"
  install -m 644 "${TMPDIR}/starship.toml" "${HOME}/.config/starship.toml"
  log "Starship config installed to ~/.config/starship.toml"
}

cosmic_desktop() {
  local de="${XDG_CURRENT_DESKTOP:-}"
  de="${de,,}"
  case "${de}" in
    *cosmic*) return 0 ;;
  esac
  local session="${XDG_SESSION_DESKTOP:-}"
  session="${session,,}"
  case "${session}" in
    *cosmic*) return 0 ;;
  esac
  if command -v cosmic-term >/dev/null 2>&1 && [[ -d "${HOME}/.config/cosmic" ]]; then
    return 0
  fi
  return 1
}

configure_cosmic_term() {
  if ! cosmic_desktop; then
    return 0
  fi

  local zsh_path
  zsh_path="$(command -v zsh)"

  log "COSMIC desktop detected; configuring cosmic-term default profile for zsh..."

  if command -v python3 >/dev/null 2>&1; then
    ZSH_PATH="${zsh_path}" python3 <<'PY'
import os
import re
from pathlib import Path

zsh = os.environ["ZSH_PATH"]
config_dir = Path.home() / ".config/cosmic/com.system76.CosmicTerm/v1"
config_dir.mkdir(parents=True, exist_ok=True)
profiles_path = config_dir / "profiles"
default_path = config_dir / "default_profile"

def profile_block(pid: int) -> str:
    return f"""{{
    {pid}: (
        name: "zsh",
        command: "{zsh}",
        syntax_theme_dark: "COSMIC Dark",
        syntax_theme_light: "COSMIC Light",
        tab_title: "",
        working_directory: "~",
        drain_on_exit: false,
    ),
}}"""

def default_profile_id() -> int:
    if not default_path.exists():
        return 0
    m = re.search(r"Some\((\d+)\)", default_path.read_text())
    return int(m.group(1)) if m else 0

def profile_ids(content: str) -> list[int]:
    return [int(m.group(1)) for m in re.finditer(r"^\s*(\d+):\s*\(", content, re.M)]

def set_profile_command(content: str, pid: int) -> tuple[str, bool]:
    pattern = rf'(\s*{pid}:\s*\(\s*\n(?:.*\n)*?\s*command:\s*)("(?:[^"\\]|\\.)*"|[^,\n]+)(\s*,)'
    new, n = re.subn(pattern, rf'\1"{zsh}"\3', content, count=1)
    return new, n > 0

def insert_profile(content: str, pid: int) -> str:
    block_inner = profile_block(pid).strip()[1:-1].strip()  # drop outer { }
    content = content.rstrip()
    if content.endswith("}"):
        inner = content[:-1].rstrip()
        if inner.endswith(","):
            inner = inner[:-1].rstrip()
        if inner.endswith("{"):
            return f"{{\n    {block_inner},\n}}\n"
        return f"{inner},\n    {block_inner},\n}}\n"
    return profile_block(pid)

if not profiles_path.exists():
    profiles_path.write_text(profile_block(0))
    default_path.write_text("Some(0)\n")
else:
    content = profiles_path.read_text()
    pid = default_profile_id()
    if pid not in profile_ids(content):
        pid = max(profile_ids(content), default=-1) + 1
        content = insert_profile(content, pid)
    else:
        updated, ok = set_profile_command(content, pid)
        if ok:
            content = updated
        else:
            pid = max(profile_ids(content), default=-1) + 1
            content = insert_profile(content, pid)
    default_path.write_text(f"Some({pid})\n")
    profiles_path.write_text(content)
PY
    log "cosmic-term profile updated (command: ${zsh_path})"
    return 0
  fi

  # Fallback without python3: only safe for a single-profile file
  local config_dir="${HOME}/.config/cosmic/com.system76.CosmicTerm/v1"
  mkdir -p "${config_dir}"
  if [[ ! -f "${config_dir}/profiles" ]]; then
    cat >"${config_dir}/profiles" <<EOF
{
    0: (
        name: "zsh",
        command: "${zsh_path}",
        syntax_theme_dark: "COSMIC Dark",
        syntax_theme_light: "COSMIC Light",
        tab_title: "",
        working_directory: "~",
        drain_on_exit: false,
    ),
}
EOF
    echo 'Some(0)' >"${config_dir}/default_profile"
    log "cosmic-term profile created (command: ${zsh_path})"
    return 0
  fi

  if grep -cE '^[[:space:]]*[0-9]+:[[:space:]]*\(' "${config_dir}/profiles" | grep -qx 1; then
    sed -i "s/^[[:space:]]*command: .*/        command: \"${zsh_path}\",/" "${config_dir}/profiles"
    echo 'Some(0)' >"${config_dir}/default_profile"
    log "cosmic-term profile updated via sed (command: ${zsh_path})"
    return 0
  fi

  log "Warning: could not configure cosmic-term automatically (install python3 or set Profiles > default shell to zsh)"
  return 0
}

maybe_set_default_shell() {
  if [[ "${SHELL:-}" == *zsh* ]]; then
    return
  fi

  local zsh_path
  zsh_path="$(command -v zsh)"

  if [[ -t 0 ]]; then
    read -r -p "Set zsh as default shell? [y/N] " ans
    if [[ "${ans}" =~ ^[Yy]$ ]]; then
      chsh -s "${zsh_path}"
      log "Default shell set to zsh"
    fi
  else
    log "Run 'chsh -s ${zsh_path}' to switch default shell."
  fi
}

print_done() {
  log "Done!"
  log "1. Set your terminal font to 'FiraCode Nerd Font'"
  log "2. Open a new terminal or run: exec zsh"
  if [[ "${SHELL:-}" != *zsh* ]]; then
    log "3. To use zsh as default: chsh -s $(command -v zsh)"
  fi
  if cosmic_desktop; then
    log "COSMIC: cosmic-term default profile is set to zsh (open a new cosmic-term tab to apply)"
  fi
}

main() {
  check_os
  TMPDIR="$(mktemp -d)"
  trap 'rm -rf "${TMPDIR}"' EXIT

  install_packages
  install_oh_my_zsh
  install_starship
  install_font
  install_zsh_autosuggestions
  configure_zshrc
  install_starship_config
  maybe_set_default_shell
  configure_cosmic_term
  print_done
}

main "$@"
