#!/usr/bin/env zsh
set -euo pipefail

DIR="${0:A:h}"
BREWFILE="$DIR/Brewfile"

# The repo file is the live file: edits in ~ and edits here are the same edit.
# A real file already sitting at the target is moved aside, never clobbered.
link() {
  local src="$1" dst="$2"
  if [[ -L "$dst" && "$(readlink "$dst")" == "$src" ]]; then
    return
  fi
  if [[ -L "$dst" ]]; then
    rm "$dst"
  elif [[ -e "$dst" ]]; then
    mv "$dst" "$dst.bak.$(date +%Y%m%d%H%M%S)"
    print "  backed up $dst"
  fi
  mkdir -p "${dst:h}"
  ln -s "$src" "$dst"
  print "  ${dst/#$HOME/~} -> ${src/#$DIR/.}"
}

print "==> symlinking configs"
# git decides what ships: tracked files plus new ones that are not gitignored.
# That keeps herdr's logs and session.json - which land in this repo because the
# config dir is linked - from being pushed back out into ~.
files=("${(@f)$(git -C "$DIR" ls-files --cached --others --exclude-standard home)}")
for rel in $files; do
  [[ "$rel" == "home/AGENTS.md" ]] && continue
  link "$DIR/$rel" "$HOME/${rel#home/}"
done

# mkdir -p makes ~/.ssh with the umask, i.e. 755. ssh only rejects a config
# that is group- or other-writable, so this is hygiene rather than a fix - but
# a key dropped in here later would be refused at 755.
if [[ -d "$HOME/.ssh" ]]; then
  chmod 700 "$HOME/.ssh"
fi

print "==> agent instructions"
# One authored file, three names: each agent looks for its own filename.
for dst in "$HOME/.claude/CLAUDE.md" "$HOME/.codex/AGENTS.md" "$HOME/.config/opencode/AGENTS.md"; do
  link "$DIR/home/AGENTS.md" "$dst"
done

print "==> homebrew"
if ! command -v brew >/dev/null 2>&1; then
  print -u2 "brew not found - run ./bootstrap.sh first"
  exit 1
fi
brew bundle install --file="$BREWFILE"
# zap rather than uninstall, so a removed cask takes its prefs and support files
# with it. Anything not in the Brewfile goes - declare it there or lose it.
brew bundle cleanup --file="$BREWFILE" --zap --force
