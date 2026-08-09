#!/usr/bin/env bash
set -euo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
ln -sfn "$DIR" ~/.dotfiles
# zsh runs compinit -C, which never checks whether the completion dump is stale.
# A switch is the only thing that changes fpath, so this is where the dump gets
# dropped; the next shell rebuilds it. See programs.zsh.completionInit in home.nix.
rm -f ~/.zcompdump-*
exec sudo darwin-rebuild switch --flake ~/.dotfiles#mac
