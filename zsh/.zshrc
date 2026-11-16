# Enable Powerlevel10k instant prompt. Should stay close to the top of ~/.zshrc.
# Initialization code that may require console input (password prompts, [y/n]
# confirmations, etc.) must go above this block; everything else may go below.
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

# where this repo lives (this file is a stow symlink into it)
export BOOTSTRAP_DIR="${${(%):-%x}:A:h:h}"

export EDITOR=nvim

# history
HISTSIZE=50000
SAVEHIST=10000

# paths and environment (sets up brew too)
source "$HOME/.exports"

# plugins (antigen is vendored and stowed as ~/antigen.zsh)
source "$HOME/antigen.zsh"
antigen use oh-my-zsh
antigen bundle git
antigen apply

# prompt
source "$(brew --prefix)/share/powerlevel10k/powerlevel10k.zsh-theme"
# To customize prompt, run `p10k configure` or edit ~/.p10k.zsh.
[[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh

# aliases last, so they win over the plugin ones
source "$HOME/.aliases"
