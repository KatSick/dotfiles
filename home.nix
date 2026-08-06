{ config, pkgs, user, ... }:

let
  dotfiles = "${config.home.homeDirectory}/.dotfiles";
in

{
  home.username = user;
  home.homeDirectory = "/Users/${user}";
  home.stateVersion = "24.11";
  home.packages = with pkgs; [
    # cli i use constantly
    ripgrep   # fast search
    fd        # fast find
    fzf       # fuzzy finder
    jq        # json on the command line
    lazygit
    neovim
    # the font everything renders in
    nerd-fonts.hack
  ];
  fonts.fontconfig.enable = true;
  home.sessionVariables.EDITOR = "nvim";

  programs.zsh = {
    enable = true;
    autosuggestion.enable = true;      # ghost text from history
    syntaxHighlighting.enable = true;  # commands turn green when valid
    initContent = ''
      bindkey '^f' autosuggest-accept
    '';
    shellAliases = {
      ".." = "cd ..";
      ze = "zed ~/.zshrc";
      gca = "git add .";
      gp = "git push";
      gpr = "git pull --rebase";
      gcm = "git switch main";
      gcmm = "git switch master";
      hcu = "cd ~/.dotfiles && gpr && ./rebuild.sh";
      cc = "claude --dangerously-skip-permissions";
      co = "codex --full-auto";
    };
  };

  # Git identity is chosen by where a repo lives on disk, never guessed.
  # There is deliberately no user.name/user.email here: with useConfigOnly a repo
  # outside the directories below gets no identity at all and git refuses to
  # commit, instead of quietly attributing the commit to the wrong person.
  # A missing include file is silently ignored by git, so a machine without
  # ~/.config/git/.gitconfig-work also fails closed rather than falling back.
  programs.git = {
    enable = true;

    settings = {
      user.useConfigOnly = true;
    };

    # SSH commit signing through the 1Password agent. The key is set per identity
    # file, not here, so a signature can never be made with the other profile's key.
    signing = {
      format = "ssh";
      signer = "/Applications/1Password.app/Contents/MacOS/op-ssh-sign";
    };

    # gitdir/i: because macOS filesystems are case-insensitive; plain gitdir:
    # would let ~/Git/work/ slip past the routing.
    includes = [
      { condition = "gitdir/i:~/git/public/";   path = "~/.config/git/.gitconfig-personal"; }
      { condition = "gitdir/i:~/git/personal/"; path = "~/.config/git/.gitconfig-personal"; }
      { condition = "gitdir/i:~/git/work/";     path = "~/.config/git/.gitconfig-work"; }
    ];
  };

  # The work half of the SSH config is pulled in from ~/.ssh/config.work, which is
  # never tracked here. Include comes first in the generated file, which matters:
  # ssh keeps the first value it obtains for each directive.
  programs.ssh = {
    enable = true;
    enableDefaultConfig = false;

    includes = [ "~/.ssh/config.work" ];

    settings = {
      "github.com" = {
        HostName = "github.com";
        User = "git";
        IdentityFile = "~/.ssh/id_personal.pub";
        # Without this the agent offers every key it holds and GitHub logs you in
        # as whichever account owns the first one that matches - possibly work.
        IdentitiesOnly = true;
        IdentityAgent = ''"~/Library/Group Containers/2BUA8C4S2C.com.1password/t/agent.sock"'';
      };
      "*" = {
        IdentityAgent = ''"~/Library/Group Containers/2BUA8C4S2C.com.1password/t/agent.sock"'';
      };
    };
  };

  programs.starship = {
    enable = true;
    settings = {
      add_newline = false;
      format = "$directory$git_branch$git_status$cmd_duration$character";
      character = {
        success_symbol = "[❯](purple)";
        error_symbol = "[❯](red)";
      };
      cmd_duration.format = "[$duration]($style) ";
    };
  };

  # Edit-in-place: the real file stays in my repo, ~/.config just points at it.
  home.file.".config/nvim".source =
    config.lib.file.mkOutOfStoreSymlink "${dotfiles}/home/.config/nvim";
  home.file.".config/herdr".source =
    config.lib.file.mkOutOfStoreSymlink "${dotfiles}/home/.config/herdr";
  home.file.".config/zed".source =
    config.lib.file.mkOutOfStoreSymlink "${dotfiles}/home/.config/zed";
  home.file.".config/ghostty".source =
    config.lib.file.mkOutOfStoreSymlink "${dotfiles}/home/.config/ghostty";
  home.file.".claude/settings.json".source =
    config.lib.file.mkOutOfStoreSymlink "${dotfiles}/home/.claude/settings.json";
  # Note: no entry for ~/.config/git/.gitconfig-{personal,work}. Both identity
  # files are local-only by design - see the git block above and AGENTS.md.

  # Keep Pi's credential and runtime state local by linking only authored files and directories.
  home.file.".pi/agent/themes".source =
    config.lib.file.mkOutOfStoreSymlink "${dotfiles}/home/.pi/agent/themes";
  home.file.".pi/agent/extensions".source =
    config.lib.file.mkOutOfStoreSymlink "${dotfiles}/home/.pi/agent/extensions";
  home.file.".pi/agent/models.json".source =
    config.lib.file.mkOutOfStoreSymlink "${dotfiles}/home/.pi/agent/models.json";
  home.file.".pi/agent/settings.json".source =
    config.lib.file.mkOutOfStoreSymlink "${dotfiles}/home/.pi/agent/settings.json";

  home.file.".claude/CLAUDE.md".source =
    config.lib.file.mkOutOfStoreSymlink "${dotfiles}/home/AGENTS.md";
  home.file.".codex/AGENTS.md".source =
    config.lib.file.mkOutOfStoreSymlink "${dotfiles}/home/AGENTS.md";
  home.file.".config/opencode/AGENTS.md".source =
    config.lib.file.mkOutOfStoreSymlink "${dotfiles}/home/AGENTS.md";
}
