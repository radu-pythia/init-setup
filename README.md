# init-setup

Bootstrap a zsh dev shell on Debian/Ubuntu: Oh My Zsh, Starship, FiraCode Nerd Font, and zsh-autosuggestions.

## Install

```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/radu-pythia/init-setup/main/init-setup.sh)"
```

## Requirements

- Ubuntu, Debian, or Pop!\_OS (other distros with `apt-get` may work but are untested)
- `bash` (not `sh`/`dash` — the script uses bash-only options)
- `sudo` access
- Network access

## What it installs

- System packages: `git`, `zsh`, `curl`, `wget`, `unzip`, `fontconfig`, `nala` (on Ubuntu/Pop, enables the **universe** repo if needed)
- [Oh My Zsh](https://ohmyz.sh/)
- [Starship](https://starship.rs/) prompt
- [FiraCode Nerd Font](https://github.com/ryanoasis/nerd-fonts) (v2.1.0)
- [zsh-autosuggestions](https://github.com/zsh-users/zsh-autosuggestions) plugin
- Starship config from this repo (`starship.toml`)

## Re-running

The script is idempotent: safe to run again. Existing installs are skipped; `.zshrc` is not duplicated.

## After install

1. Set your terminal font to **FiraCode Nerd Font**
2. Open a new terminal or run `exec zsh`
3. Optionally set zsh as your default shell: `chsh -s "$(which zsh)"` (the script prompts when run interactively)

On **COSMIC** (Pop!\_OS 24.04+), the script also sets the **cosmic-term** default profile to zsh in `~/.config/cosmic/com.system76.CosmicTerm/v1/` (cosmic-term may ignore `chsh` until you open a new tab).
