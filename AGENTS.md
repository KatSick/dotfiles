# Project notes for agents

Deliberate decisions in this repo - do NOT silently revert them:

- `homebrew.onActivation.cleanup = "zap"` in `configuration.nix` is intentional. It forces the good habit of declaring every Homebrew package in the Nix config instead of installing things ad-hoc, which keeps the machine reproducible. Do not soften it to `uninstall` or `none`. Users are warned about its effect in README.md; this note is for anyone tempted to change the setting itself.
- Never commit `.no-mistakes/` validation evidence to this public repo. `.no-mistakes/` is gitignored; if a validation pipeline stages evidence into a branch, drop it before merging.
- Both git identities live only in `~/.config/git/.gitconfig-personal`, `~/.config/git/.gitconfig-work`, and `~/.ssh/config.work`, all outside this repo. Never track them, never `mkOutOfStoreSymlink` them from `home.nix`, and never inline a real name, email, signing key, or GitHub org into nix - this repo is public. The tracked `home/.config/git/*.example` files hold placeholders only.
- `programs.git` in `home.nix` deliberately sets no `user.name`/`user.email`. Identity comes from `includeIf` routing plus `user.useConfigOnly = true`, so an unrouted repo fails to commit rather than guessing. Do not "fix" that by adding a global fallback identity - the missing fallback is the safety property.

## Maintaining this file

Keep this file for knowledge useful to almost every future agent session in this project.
Do not repeat what the codebase already shows; point to the authoritative file or command instead.
Prefer rewriting or pruning existing entries over appending new ones.
When updating this file, preserve this bar for all agents and keep entries concise.
