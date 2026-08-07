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
      # Both are in units of 15ms. These are the fastest positions the System
      # Settings sliders can reach, so the sliders and this config agree - drag
      # them to max and nothing changes. Lower values work (1 and 10 are common)
      # but can no longer be represented in the UI.
      KeyRepeat = 2;          # 30ms between repeats
      InitialKeyRepeat = 15;  # 225ms before repeating starts
      _HIHideMenuBar = false;  # auto-hide the menu bar
      AppleShowAllExtensions = true;
    };
    dock.autohide = true;
    dock.orientation = "right";

    # Minimise with a straight scale rather than the genie warp. The other
    # accepted value is "suck", which macOS supports but never exposes in
    # System Settings.
    #
    # This still applies with reduceMotion below turned on - checked on 26.6 by
    # setting it and minimising a window. Reduce Motion flattens plenty of other
    # animations, but it leaves the minimise effect to mineffect.
    #
    # Unlike the universalaccess settings below, this one is picked up by
    # restarting the Dock (`killall Dock`) rather than needing a fresh login.
    dock.mineffect = "scale";
    finder.FXPreferredViewStyle = "Nlsv";  # list view by default
    finder.CreateDesktop = false;          # clean desktop

    # System Settings > Accessibility > Display.
    #
    # These two need Full Disk Access on the terminal you run ./rebuild.sh from,
    # and activation hard-fails without it. com.apple.universalaccess is a
    # TCC-protected domain: cfprefsd rejects the write no matter what uid asks,
    # so sudo does not help and the plist being owned by you is a red herring -
    # it reads fine, it just will not take a write. You get
    #
    #   Could not write domain com.apple.universalaccess; exiting
    #
    # and because nix-darwin's activation script runs under `set -e` with no
    # `|| true` on the defaults calls, the switch aborts *there*. Every setting
    # generated after this point is silently skipped - including
    # TISRomanSwitchState below, so the Caps Lock layout switcher quietly stops
    # being applied. A failure here is never just cosmetic.
    #
    # Granting FDA is a one-time manual step; see the README. Everything else in
    # this file applies without it, so if you would rather not hand a terminal
    # that much reach, delete these two lines and tick the boxes by hand.
    #
    # Like the input sources below, the value is only read at login and is
    # cached per running app, so a rebuild will not restyle the session you are
    # sitting in.
    universalaccess.reduceMotion = true;        # no space-switch or app-open animation
    universalaccess.reduceTransparency = true;  # opaque menu bar, dock and sidebars
  };

  # Keyboard input sources. nix-darwin has no typed option for these, so this
  # goes through the CustomUserPreferences escape hatch and mirrors exactly what
  # System Settings > Keyboard > Input Sources writes into com.apple.HIToolbox.
  #
  # Array order is the input-source order, so ABC first means English is the
  # default. The layout IDs are Apple's own (`plutil -p
  # ~/Library/Preferences/com.apple.HIToolbox.plist` to read them back); they are
  # integers, not strings, and a quoted "-2354" here would be silently ignored.
  #
  # Only read at login: a rebuild writes the file but will not switch the layout
  # of the session you are sitting in. Log out and back in to apply.
  system.defaults.CustomUserPreferences."com.apple.HIToolbox" = {
    AppleEnabledInputSources = [
      {
        InputSourceKind = "Keyboard Layout";
        "KeyboardLayout ID" = 252;
        "KeyboardLayout Name" = "ABC";
      }
      {
        InputSourceKind = "Keyboard Layout";
        "KeyboardLayout ID" = -2354;
        "KeyboardLayout Name" = "Ukrainian-PC";
      }
      # macOS adds this itself the first time you open Emoji & Symbols; listing
      # it keeps a rebuild from dropping it back out.
      {
        InputSourceKind = "Non Keyboard Input Method";
        "Bundle ID" = "com.apple.CharacterPaletteIM";
      }
    ];
    # Which one a fresh login starts in. macOS rewrites this every time you
    # switch layouts, so it only really matters on a new machine.
    AppleSelectedInputSources = [
      {
        InputSourceKind = "Keyboard Layout";
        "KeyboardLayout ID" = 252;
        "KeyboardLayout Name" = "ABC";
      }
    ];

    # What the fn/globe key does. 0 = nothing, 1 = change input source,
    # 2 = show Emoji & Symbols, 3 = start dictation.
    AppleFnUsageType = 0;

    # "Automatically switch to a document's input source" - macOS remembers the
    # layout per text field and restores it on focus. Stored as a real boolean
    # even though `defaults read` prints it as 1.
    AppleGlobalTextInputProperties = {
      TextInputGlobalPropertyPerContextInput = true;
    };
  };

  # Caps Lock switches between the Latin and non-Latin input source, i.e. ABC
  # <-> Ukrainian-PC. This is System Settings > Keyboard > Input Sources > Edit >
  # "Use the Caps Lock key to switch to and from Ukrainian-PC", and it is the
  # only thing that checkbox writes. The name is historical - "Roman" is Apple's
  # old word for Latin - and there is no typed nix-darwin option for it.
  # It only works with a non-Latin source enabled, and it costs you Caps Lock
  # itself. An int, not a bool: macOS stores 1/0 here.
  system.defaults.CustomUserPreferences.NSGlobalDomain.TISRomanSwitchState = 1;
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
      "eza"
      # proto is the toolchain version manager; ~/.proto/.prototools is linked
      # from home.nix. The three archive tools are grouped with it because they
      # are what a downloaded toolchain gets unpacked with; keeping current
      # versions here beats relying on whatever macOS happens to ship.
      # Note unzip is keg-only, so it stays off PATH and Apple's stays in front.
      "proto"
      "unzip"
      "gzip"
      "xz"
    ];
    casks = [
      "claude-code"
      "zed"
      "ghostty"
      "google-chrome"
      "1password"
      "1password-cli"
      "shottr"
      "sol"
      "desktoppr"
      # The GUI menu-bar client. Homebrew renamed the cask from `tailscale` to
      # `tailscale-app`; `tailscale` is now the CLI-only formula, which is not
      # what is wanted here.
      "tailscale-app"
    ];
  };
}
