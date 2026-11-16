#!/bin/bash
#
# Bootstrap a fresh arm64 macOS machine.
#
#   ./bootstrap.sh [--dry-run] [--skip-macos] [--skip-accounts] [--rosetta]
#
# Every step is idempotent and non-fatal: failures are collected and printed at the end.
# Nothing secret is ever written into this repo. Identity and logins are asked for interactively
# and live only in ~/.gitconfig.local, ~/.ssh, and the tools' own keychain storage.

set -u -o pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DRY_RUN=0
SKIP_MACOS=0
SKIP_ACCOUNTS=0
WITH_ROSETTA=0
FAILURES=()

for arg in "$@"; do
    case "$arg" in
        --dry-run)       DRY_RUN=1 ;;
        --skip-macos)    SKIP_MACOS=1 ;;
        --skip-accounts) SKIP_ACCOUNTS=1 ;;
        --rosetta)       WITH_ROSETTA=1 ;;
        -h|--help)       sed -n '2,10p' "${BASH_SOURCE[0]}"; exit 0 ;;
        *) echo "Unknown option: $arg" >&2; exit 1 ;;
    esac
done

INTERACTIVE=0
[[ -t 0 && -t 1 ]] && INTERACTIVE=1

# ---------------------------------------------------------------- helpers

# Print a command, and run it unless --dry-run.
run() {
    printf '+ %s\n' "$*"
    (( DRY_RUN )) && return 0
    "$@"
}

# step "title" function: run a function, record failure instead of aborting.
step() {
    local title="$1"; shift
    printf '\n== %s\n' "$title"
    if ! "$@"; then
        FAILURES+=("$title")
        printf '!! "%s" failed, continuing\n' "$title" >&2
    fi
}

# ask "question" [default]: read a line, echo the answer. Empty when not interactive.
ask() {
    local answer
    (( INTERACTIVE )) || { echo "${2:-}"; return; }
    read -r -p "$1${2:+ [$2]}: " answer </dev/tty
    echo "${answer:-${2:-}}"
}

# confirm "question": y/N, always "no" when not interactive.
confirm() {
    local answer
    (( INTERACTIVE )) || return 1
    read -r -p "$1 [y/N]: " answer </dev/tty
    [[ "$answer" =~ ^[Yy]$ ]]
}

# ---------------------------------------------------------------- steps

create_dirs() {
    run mkdir -p "$HOME/dev" "$HOME/dev/work"
}

install_xcode() {
    xcode-select --print-path &>/dev/null && return 0
    run xcode-select --install || true
    (( DRY_RUN )) && return 0
    until xcode-select --print-path &>/dev/null; do sleep 5; done
}

install_rosetta() {
    run softwareupdate --install-rosetta --agree-to-license
}

install_brew() {
    if ! command -v brew &>/dev/null && [[ ! -x /opt/homebrew/bin/brew ]]; then
        (( DRY_RUN )) && { echo "+ install Homebrew"; return 0; }
        /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)" || return 1
    fi
    eval "$(/opt/homebrew/bin/brew shellenv)"
    # shellenv for future login shells (stowed .zshrc also does this via .exports)
    grep -qs 'brew shellenv' "$HOME/.zprofile" 2>/dev/null \
        || run bash -c "echo 'eval \"\$(/opt/homebrew/bin/brew shellenv)\"' >> \"$HOME/.zprofile\""
}

install_brew_packages() {
    run brew bundle --file="$ROOT/Brewfile" || return 1
    run brew cleanup
}

# Symlink dotfiles with stow. Pre-existing real files that would conflict are moved aside, never deleted.
stow_dotfiles() {
    local pkgs=(git vim nvim zsh) backup
    backup="$HOME/.dotfiles-backup/$(date +%Y%m%d-%H%M%S)"
    local pkg conflict
    for pkg in "${pkgs[@]}"; do
        while IFS= read -r conflict; do
            [[ -n "$conflict" ]] || continue
            run mkdir -p "$backup/$(dirname "$conflict")"
            run mv "$HOME/$conflict" "$backup/$conflict"
        done < <(cd "$ROOT" && stow -n -d "$ROOT" -t "$HOME" "$pkg" 2>&1 \
                    | sed -n 's/.*existing target \(.*\) since.*/\1/p')
    done
    run stow -d "$ROOT" -t "$HOME" "${pkgs[@]}"
}

install_vim_plug() {
    local plug="$HOME/.vim/autoload/plug.vim"
    [[ -f "$plug" ]] || run curl -fsSLo "$plug" --create-dirs \
        https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim || return 1
    run nvim --headless +PlugInstall +qall
}

# Ask for git identity and keep it OUT of the repo: ~/.gitconfig.local is included by git/.gitconfig.
configure_git_identity() {
    local file="$HOME/.gitconfig.local"
    if [[ -f "$file" ]]; then
        echo "$file already exists, keeping it"
        return 0
    fi
    local name email
    name="$(ask 'Git name')"
    email="$(ask 'Git email')"
    if [[ -z "$name" || -z "$email" ]]; then
        echo "Skipped: set later with 'git config -f ~/.gitconfig.local user.email you@example.com'"
        return 0
    fi
    run git config -f "$file" user.name "$name"
    run git config -f "$file" user.email "$email"
}

# SSH key + GitHub login. The key stays in ~/.ssh, the GitHub token is kept by gh in the macOS keychain.
setup_github() {
    if ! command -v gh &>/dev/null; then echo "gh not installed"; return 1; fi
    if gh auth status &>/dev/null; then echo "Already logged in to GitHub"; return 0; fi
    (( INTERACTIVE )) || { echo "Not interactive, run 'gh auth login' yourself"; return 0; }
    confirm "Log in to GitHub now?" || return 0

    local key="$HOME/.ssh/id_ed25519"
    if [[ ! -f "$key" ]] && confirm "No SSH key found. Generate one?"; then
        local email; email="$(git config --get user.email || true)"
        run mkdir -p -m 700 "$HOME/.ssh"
        run ssh-keygen -t ed25519 -C "${email:-$(whoami)@$(hostname -s)}" -f "$key"   # prompts for passphrase
        if [[ ! -f "$HOME/.ssh/config" ]]; then
            run bash -c "printf 'Host *\n  AddKeysToAgent yes\n  UseKeychain yes\n  IdentityFile ~/.ssh/id_ed25519\n' > '$HOME/.ssh/config'"
        fi
        run ssh-add --apple-use-keychain "$key"
    fi
    run gh auth login -h github.com -p ssh -w   # offers to upload the public key
}

setup_1password() {
    command -v op &>/dev/null || return 0
    op account list 2>/dev/null | grep -q . && return 0
    confirm "Sign in to 1Password CLI now?" || return 0
    run op account add
}

apply_macos_settings() {
    run bash "$ROOT/macos/.macos"
}

set_default_shell() {
    [[ "$SHELL" == */zsh ]] && return 0
    run chsh -s /bin/zsh
}

print_checklist() {
    cat <<'EOF'

== Manual steps (cannot or should not be scripted)
  [ ] Chrome: sign in with your Google account, extensions sync (list in chrome/extensions.md)
  [ ] Raycast: Settings > Advanced > Import, using your exported .rayconfig (extensions in raycast/extensions.md)
  [ ] Claude, Docker, JetBrains, VS Code, Warp: sign in on first launch
  [ ] Keyboard: add the Hebrew input source (System Settings > Keyboard > Input Sources)
  [ ] Terminal: set the font to "MesloLGS NF" (Warp/iTerm/Terminal), then run 'p10k configure' if you want to restyle the prompt
  [ ] Work apps: add them to the Brewfile and re-run ./bootstrap.sh
EOF
}

# ---------------------------------------------------------------- main

(( DRY_RUN )) && echo "DRY RUN: nothing will be changed"

# Keep sudo alive for the duration of the script.
if (( ! DRY_RUN )) && (( INTERACTIVE )); then
    sudo -v && { while true; do sudo -n true; sleep 60; kill -0 "$$" || exit; done 2>/dev/null & }
fi

step "Creating directories"            create_dirs
step "Installing Xcode CLI tools"      install_xcode
(( WITH_ROSETTA )) && step "Installing Rosetta 2" install_rosetta
step "Installing Homebrew"             install_brew
step "Installing Homebrew packages"    install_brew_packages
step "Linking dotfiles (stow)"         stow_dotfiles
step "Setting default shell"           set_default_shell
step "Installing vim plugins"          install_vim_plug
if (( ! SKIP_ACCOUNTS )); then
    step "Git identity"                configure_git_identity
    step "GitHub login"                setup_github
    step "1Password login"             setup_1password
fi
(( SKIP_MACOS )) || step "Applying macOS settings" apply_macos_settings

print_checklist

if (( ${#FAILURES[@]} )); then
    printf '\n!! Steps that failed:\n'
    printf '   - %s\n' "${FAILURES[@]}"
    exit 1
fi
printf '\nDone!\n'
