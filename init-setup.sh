#!/usr/bin/env bash
set -euo pipefail

STARSHIP_CONFIG_URL="https://raw.githubusercontent.com/radu-pythia/init-setup/main/starship.toml"
FONT_URL="https://github.com/ryanoasis/nerd-fonts/releases/download/v2.1.0/FiraCode.zip"
INIT_SETUP_MARKER="init-setup"

log() {
  printf '[init-setup] %s\n' "$*"
}

check_os() {
  if ! command -v apt-get >/dev/null 2>&1; then
    log "Error: apt-get not found. This script supports Debian/Ubuntu only."
    exit 1
  fi
  if [[ -f /etc/os-release ]]; then
    # shellcheck source=/dev/null
    source /etc/os-release
    case "${ID:-}" in
      ubuntu | debian | pop) ;;
      *)
        log "Warning: unsupported distro '${ID:-unknown}'. Continuing anyway (apt-get found)."
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
  sudo DEBIAN_FRONTEND=noninteractive apt-get install -y git zsh curl wget unzip fontconfig
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
  print_done
}

main "$@"
