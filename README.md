Bootstrap
=========

## Motivation

Setting up a new developer machine can be an **ad-hoc, manual, and time-consuming** process.
`bootstrap` aims to **simplify** the process through a highly automatic and autonomous process.

>**`bootstrap` is geared to be an organized *reference* of various developer tools used by me.**

An opinionated list of tools, languages, shells and .dotfiles I use to configure my workstation.
This purpose of this repository is to host a tool to bootstrap my machine from scratch.
It ensures my machine is ready for backend and frontend development on kubernetes based production environments.

> I've been using a form of this script for over 10 years now. This is truly more about the journey than the destination!

## Getting Started

```sh
curl -fsSL https://raw.githubusercontent.com/olgkpln/bootstrap/main/run.sh | sh
# or, from a clone:
./bootstrap.sh [--dry-run] [--skip-macos] [--skip-accounts] [--rosetta]
```

Give your terminal Full Disk Access first (`System Settings -> Privacy & Security -> Full Disk Access`).
Intended for `arm64` Macs. Every step is idempotent and non-fatal; failures are listed at the end.

**No secrets live in this repo.** The script asks for your git name/email (stored in `~/.gitconfig.local`),
generates an SSH key if you want one, and runs `gh auth login` / `op account add` interactively.
Tokens stay in each tool's own keychain storage.

## Functionality Overview

The script is structured by means modules (directories) bundled together in functionality which is then executed by a
function call from within [bootstrap.sh](bootstrap.sh). The three main buckets are:

### MacOs
- Updates the OS (optional)
- Installs OS level dependencies like xcode-cli
- Applies OS level configurations exported from my machine (`macos/.macos`)
### Brew
- Installs Brew
- Installs Casks and Bottles
- Configures the tools installed by Brew
### Dotfiles
- Defines `zsh` as the default shell
- Configures the shell through dotfiles
- Define aliases and exports
- Configures shell tools through dotfiles

## Issues
Further improvements I'm planning to implement:

- Collaboration
- Customization
