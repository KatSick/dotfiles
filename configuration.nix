{ user, pkgs, ... }:

{
  # Determinate already manages the Nix daemon, so nix-darwin shouldn't.
  nix.enable = false;

  nixpkgs.config.allowUnfree = true;
  nixpkgs.hostPlatform = "aarch64-darwin"; # use x86_64-darwin for Intel CPU

  system.primaryUser = user;
  users.users.${user} = {
    home = "/Users/${user}";
  };
  system.stateVersion = 6;

  # home-manager already runs `compinit` in ~/.zshrc, and it runs it *after*
  # `typeset -U fpath` dedups fpath. nix-darwin's own compinit in /etc/zshrc runs
  # before that dedup, so the two disagree on the completion-file count (3096 vs
  # 3006). Each one therefore considers the other's ~/.zcompdump stale and does a
  # full rebuild, so the dump can never be reused: every single shell start pays
  # two compaudit+compdump passes over ~3000 completion files. Dropping the global
  # one takes interactive startup from ~7.4s to ~0.14s.
  programs.zsh.enableGlobalCompInit = false;

  # Nix language servers, available to every user and to editors launched
  # outside a home-manager shell.
  environment.systemPackages = with pkgs; [
    nil
    nixd
  ];

  system.defaults = {
    NSGlobalDomain = {
      AppleInterfaceStyle = "Dark";
      KeyRepeat = 2;          # fast key repeat
      InitialKeyRepeat = 15;  # short delay before repeat
      _HIHideMenuBar = false;  # auto-hide the menu bar
      AppleShowAllExtensions = true;
    };
    dock.autohide = true;
    finder.FXPreferredViewStyle = "Nlsv";  # list view by default
    finder.CreateDesktop = false;          # clean desktop
  };
  nix-homebrew = {
    enable = true;
    inherit user;
  };
  homebrew = {
    enable = true;
    onActivation.cleanup = "zap";  # remove anything not listed here
    onActivation.autoUpdate = true;
    onActivation.extraFlags = [ "--force" ];
    brews = [
      "herdr"
    ];
    casks = [
      "claude-code"
      "zed"
      "ghostty"
      "google-chrome"
      "1password"
    ];
  };
}
