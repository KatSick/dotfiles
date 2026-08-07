{
  description = "dotfiles";

  inputs = {
    # Use `github:NixOS/nixpkgs/nixpkgs-26.05-darwin` to use Nixpkgs 26.05.
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-26.05-darwin";
    # Use `github:nix-darwin/nix-darwin/nix-darwin-26.05` to use Nixpkgs 26.05.
    nix-darwin.url = "github:nix-darwin/nix-darwin/nix-darwin-26.05";
    nix-darwin.inputs.nixpkgs.follows = "nixpkgs";

    home-manager.url = "github:nix-community/home-manager/release-26.05";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";

    # nix-homebrew carries the pinned brew, and brew is not allowed to
    # self-update here - so a stale input means a stale brew. Formulae in
    # homebrew-core keep updating regardless, and once they started emitting
    # post_install manifests with the "run" step (brew 6.0.13), the old pinned
    # brew 6.0.1 failed every formula pulling in openssl@3 with
    # "Error: unknown install step: run". If that reappears, bump this input.
    nix-homebrew.url = "github:zhaofengli/nix-homebrew";
  };

  outputs = inputs@{ self, nix-darwin, nix-homebrew, home-manager, nixpkgs }:
    let
      # The one username line to change if this isn't your machine.
      # bootstrap.sh offers to rewrite this for you if your macOS username differs.
      user = "ostapchervak";
    in
    {
      darwinConfigurations."mac" = nix-darwin.lib.darwinSystem {
        specialArgs = { inherit user; };
        modules = [
          ./configuration.nix
          nix-homebrew.darwinModules.nix-homebrew
          home-manager.darwinModules.home-manager
          {
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;
            # Without this, a home.file target that already exists as a real
            # file aborts the whole activation with "Existing file ... is in
            # the way", and the link is silently never created - which is how
            # ~/.config/sol/config.json sat unlinked while the repo copy and
            # the file Sol actually reads drifted apart. Move the stray file
            # aside instead, so first-run and app-rewritten files self-heal.
            home-manager.backupFileExtension = "hm-bak";
            home-manager.extraSpecialArgs = { inherit user; };
            home-manager.users.${user} = import ./home.nix;
          }
        ];
      };
    };
}
