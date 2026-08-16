# generic
export EDITOR="zed --wait"

# prompt (drop the user@host prefix that /etc/zshrc sets)
PROMPT='%1~ %# '

# claude code
export CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC=1
export DISABLE_ERROR_REPORTING=1

# proto
eval "$(proto activate zsh)"

# navigation
alias ..="cd .."
alias g="cd ~/git"
alias ww="cd ~/git/work"
alias pp="cd ~/git/public"
alias ll="eza --long --all --header --icons --git --group-directories-first --time-style=relative"

# git
alias gs="git status"
alias gca="git add ."
alias gcan="git commit --amend --no-verify"
alias gcann="git commit --amend"
alias gp="git push"
alias gpf="git push --force-with-lease"
alias grm="git pull --rebase --autostash origin master"
alias grmm="git pull --rebase origin main"
alias gpr="git pull --rebase"
alias grc="git pull --continue"
alias gc="git checkout"
alias gcm="git switch master"
alias gcmm="git switch main"
alias lg="lazygit"
alias ze="zed ~/.zshrc"

# tools
alias hh="herdr"
alias rr="tuicr"
alias ze="zed ~/.zshrc"
alias cc="claude"
alias co="codex"

# local overrides
source $HOME/.zshrc.local
