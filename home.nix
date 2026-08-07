{ config, lib, pkgs, user, ... }:

let
  dotfiles = "${config.home.homeDirectory}/.dotfiles";

  # macOS keyboard shortcuts to turn off, keyed by the numeric ID macOS files
  # them under in com.apple.symbolichotkeys. See home.activation.disableHotkeys
  # below for how these are written and why it looks the way it does.
  #
  # The value is the modifier mask of the shortcut macOS would use were it
  # enabled: Shift 131072, Control 262144, Option 524288, Command 1048576,
  # summed. Every entry here is a Space chord, so the keycode (49) and
  # character (32) are baked into disableHotkey rather than repeated.
  disabledHotkeys = {
    "60" = { modifiers = 262144; note = "Select the previous input source (Ctrl+Space)"; };
    "61" = { modifiers = 786432; note = "Select next source in Input menu (Ctrl+Option+Space)"; };
    "64" = { modifiers = 1048576; note = "Show Spotlight search (Cmd+Space)"; };
    "65" = { modifiers = 1572864; note = "Show Finder search window (Cmd+Option+Space)"; };
  };

  # The value is an XML plist rather than the shorter old-style `{ enabled =
  # 0; }` syntax, and that is the whole point: old-style plists have no number
  # or boolean type, so every unquoted scalar lands as a string. That wrote
  # `enabled = <string>0</string>`, macOS only honours a real `<false/>` here,
  # and the shortcut stayed live no matter how many times the config was
  # applied - while `defaults read` printed `enabled = 0` either way, so the
  # plist looked correct. Every entry macOS writes itself is a boolean; match
  # that exactly. Passing `defaults` an XML plist is the only way to get a
  # typed boolean into a nested dict.
  #
  # The `value` dict is kept rather than dropped because disabling a shortcut
  # in System Settings keeps it - only `enabled` changes.
  disableHotkey = id: { modifiers, note }: ''
    # ${note}
    run /usr/bin/defaults write com.apple.symbolichotkeys AppleSymbolicHotKeys \
      -dict-add ${id} '<dict><key>enabled</key><false/><key>value</key><dict><key>parameters</key><array><integer>32</integer><integer>49</integer><integer>${toString modifiers}</integer></array><key>type</key><string>standard</string></dict></dict>'
  '';
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

    # Two zsh binaries read this same ~/.zshrc: macOS's /bin/zsh (the login
    # shell, 5.9) and nix's (5.9.1). fpath embeds $ZSH_VERSION, so each sees a
    # different set of completion functions - 1014 files vs 3006. Sharing one
    # ~/.zcompdump makes each one treat the other's dump as stale and rebuild it,
    # so alternating between them costs 1.6-2.5s per shell instead of 0.13s.
    # Keying the dump by version gives each binary its own cache, and also stops
    # a future zsh upgrade from silently reintroducing the same thrash.
    completionInit = ''
      autoload -U compinit && compinit -d "$HOME/.zcompdump-$ZSH_VERSION"
    '';
    initContent = ''
      bindkey '^f' autosuggest-accept

      # proto: puts its shims on PATH and hooks directory changes so the
      # toolchain versions pinned in .prototools take effect per project.
      eval "$(proto activate zsh)"

      # Internal CA trust for toolchains that cannot read the macOS Keychain
      # (node, bun, curl, uv, the JVM).
      [ -f "$HOME/.config/ca/env.sh" ] && source "$HOME/.config/ca/env.sh"
    '';
    shellAliases = {
      ".." = "cd ..";
      # icons render via nerd-fonts.hack above; --git needs a repo to show anything
      ll = "eza --long --header --icons --git --group-directories-first --time-style=relative";
      ze = "zed ~/.zshrc";
      gca = "git add .";
      gp = "git push";
      gpr = "git pull --rebase";
      gcm = "git switch main";
      gcmm = "git switch master";
      hcu = "cd ~/.dotfiles && gpr && ./rebuild.sh";
      # Sol rewrites its config in place, so the repo copy is refreshed by hand
      # after tuning Sol - see home.activation.solConfig below.
      solsave = "cp ~/.config/sol/config.json ~/.dotfiles/home/.config/sol/config.json";
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

  # Note: no entry for ~/.config/sol/config.json either - Sol is seeded rather
  # than linked, see home.activation.solConfig below.

  # proto (declared in configuration.nix) keeps installed toolchains, shims and
  # a lockfile under ~/.proto too, so only the authored config file is linked.
  home.file.".proto/.prototools".source =
    config.lib.file.mkOutOfStoreSymlink "${dotfiles}/home/.proto/.prototools";

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

  # Solid #202020 wallpaper, matching the menu bar.
  #
  # Not black, deliberately. configuration.nix turns on Reduce Transparency,
  # which stops the menu bar sampling the wallpaper and fills it with an opaque
  # colour instead - in Dark Mode a flat #202020 (measured off a screenshot:
  # every pixel of the 33pt bar reads 32,32,32). That colour is hardcoded in
  # AppKit. There is no defaults key for it, and it is not derived from the
  # wallpaper, the accent colour or the highlight colour, so it cannot be
  # driven to black. Against a black desktop the bar therefore reads as a grey
  # band. Matching the desktop to the bar is the only way to get one uniform
  # surface without giving up the opaque dock and sidebars.
  #
  # If Reduce Transparency is ever turned off, change this back to
  # /System/Library/Desktop Pictures/Solid Colors/Black.png - a transparent
  # menu bar shows the wallpaper through it, so there black gives a black bar
  # and #202020 would give a grey one. The two settings have to move together.
  #
  # The colour is a neutral grey, so it survives the round trip to a wide-gamut
  # display unchanged: sRGB and Display P3 share a D65 white point and the same
  # transfer curve, and R=G=B maps to itself between them.
  #
  # macOS 14+ keeps the wallpaper in an opaque binary plist under
  # ~/Library/Application Support/com.apple.wallpaper instead of a defaults key,
  # so nix-darwin has no option for it. The desktoppr cask in configuration.nix
  # sets it through NSWorkspace, which needs no Automation approval - the
  # osascript/System Events route does, and TCC has never seen an activation
  # script, so it would be denied there.
  #
  # This is a home-manager activation entry rather than a nix-darwin
  # system.activationScripts one because the wallpaper is per-user and has to be
  # written from inside the login session. nix-darwin already invokes
  # home-manager activation as `launchctl asuser <uid> sudo -u <user>
  # --set-home`, so that is taken care of here; the same script under
  # postActivation runs as root in the system bootstrap context and would have
  # to redo all three parts by hand.
  #
  # home-manager activation runs after nix-darwin's homebrew one, so the cask is
  # installed by the time this fires. /usr/local/bin is not on the activation
  # PATH, hence the absolute path. Failure is only a warning: a rebuild over SSH
  # with nobody logged in has no GUI session to write into, and a wallpaper is
  # not worth failing a switch over.
  #
  # Both the image and desktoppr's fill colour are set, to the same value. The
  # fill colour is what shows wherever the image does not reach, and it always
  # reaches somewhere: desktoppr's scale mode is stuck at `fit`, which
  # letterboxes anything whose aspect ratio does not match the screen. `desktoppr
  # scale fill` is accepted silently and then reads back as `fit`, so it cannot
  # be relied on, and with a built-in display and an ultrawide attached there is
  # no single aspect ratio that would fit both anyway. Setting both to #202020
  # makes the scale mode irrelevant rather than fighting it - the letterbox and
  # the image are the same colour, so the desktop is uniform either way.
  #
  # assets/solid-202020.png is a 64x64 sRGB-tagged PNG of nothing but that
  # colour. It is committed rather than generated because a solid square needs
  # no build step, and the size does not matter once the fill colour covers the
  # letterbox.
  home.activation.wallpaper = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    run /usr/local/bin/desktoppr all "${dotfiles}/assets/solid-202020.png" \
      || echo "warning: could not set the wallpaper" >&2
    run /usr/local/bin/desktoppr color 202020 \
      || echo "warning: could not set the wallpaper fill colour" >&2
  '';

  # Sol's config is seeded once, not symlinked.
  #
  # Sol saves settings by renaming a freshly written file over
  # ~/.config/sol/config.json. A rename replaces a symlink rather than following
  # it, so a mkOutOfStoreSymlink here survives only until the first settings
  # change: after that Sol's edits live in a plain file that the repo knows
  # nothing about, and the next switch finds a real file in the way, moves it to
  # config.json.hm-bak (see backupFileExtension in flake.nix) and links the stale
  # repo copy back over it. Every setting changed since the last commit is
  # reverted, recoverable only from the backup. Linking is simply the wrong
  # mechanism for a file its own app rewrites wholesale.
  #
  # So the repo copy is a seed for a fresh machine and a snapshot otherwise. The
  # copy is guarded on the file being absent, which means it never touches a
  # machine where Sol has already run. Going the other way is the `solsave` alias
  # above; the sync is manual on purpose, because there is no safe automatic
  # answer to "the file and the repo differ" in either direction.
  #
  # This runs after linkGeneration rather than the bare writeBoundary the entries
  # below use, so the seed cannot land before home-manager has finished with the
  # directory.
  #
  # Only config.json is seeded, never the whole ~/.config/sol directory.
  # config.json is the authored part - shortcuts, translation languages, search
  # engine. Its neighbours are not: state.json holds scratchpad text, clipboard
  # settings and calendar UUIDs, and images_pasteboard/ is clipboard image
  # history. None of that belongs in a public repo, and all of it churns on every
  # launch.
  home.activation.solConfig = lib.hm.dag.entryAfter [ "linkGeneration" ] ''
    if [ ! -e "$HOME/.config/sol/config.json" ]; then
      run mkdir -p "$HOME/.config/sol"
      run cp "${dotfiles}/home/.config/sol/config.json" "$HOME/.config/sol/config.json"
    fi
  '';

  # Free up the Space chords macOS claims by default.
  #
  # Both Spotlight shortcuts go: Cmd+Space is the point - it frees the chord
  # for the sol launcher (the cask is declared in configuration.nix) - and
  # Cmd+Option+Space goes with it so the Spotlight section of System Settings >
  # Keyboard Shortcuts is empty. Both input-source shortcuts go the same way:
  # Ctrl+Space because the switcher swallows it out from under editors that
  # want it for completion, and Ctrl+Option+Space with it, which likewise
  # leaves the Input Sources section empty. Input sources stay switchable from
  # the menu bar.
  #
  # Keyboard shortcuts live in com.apple.symbolichotkeys as one big
  # AppleSymbolicHotKeys dict keyed by numeric ID. This is a script rather than
  # a system.defaults.CustomUserPreferences entry because that escape hatch
  # writes a whole top-level key at a time, so declaring AppleSymbolicHotKeys
  # would drop every other shortcut macOS keeps in the same dict - Mission
  # Control, spaces, the input sources not listed above. `-dict-add` merges
  # into it instead and leaves the siblings alone.
  #
  # Like the input sources in configuration.nix, this is really only read at
  # login. activateSettings pushes it into the running session; if a shortcut
  # somehow survives, log out and back in.
  home.activation.disableHotkeys = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    ${lib.concatStrings (lib.mapAttrsToList disableHotkey disabledHotkeys)}
    run /System/Library/PrivateFrameworks/SystemAdministration.framework/Resources/activateSettings -u \
      || echo "warning: could not reload the shortcut settings" >&2
  '';
}
