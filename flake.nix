{
  description = "Portable dotfiles — zsh/Zprezto, tmux, kakoune, neovim, git, wenv, pi, Claude Code";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # dgrisham/wenv — personal work-environment shell tool. Kept as a flake
    # input (rather than vendored) so `nix flake update` tracks new upstream
    # commits; flake.lock pins the exact rev in the meantime.
    wenv-src = {
      url = "github:dgrisham/wenv";
      flake = false;
    };
  };

  outputs = { self, nixpkgs, home-manager, wenv-src, ... }:
    let
      systems = [ "x86_64-linux" "aarch64-linux" "x86_64-darwin" "aarch64-darwin" ];

      mkHome = system:
        home-manager.lib.homeManagerConfiguration {
          pkgs = import nixpkgs {
            inherit system;
            config.allowUnfree = true; # claude-code is unfree
          };
          extraSpecialArgs = { wenv = wenv-src; };
          modules = [ ./home.nix ];
        };
    in
    {
      # Usable standalone on any machine with just Nix installed (no NixOS/
      # nix-darwin required). Activate with:
      #   nix run home-manager -- switch --flake .#<system>
      # or, once activated once, just:
      #   home-manager switch --flake .#<system>
      #
      # Also consumable as a flake input by other flakes (e.g. a NixOS host
      # config) that want to import ./home.nix directly and layer more on
      # top — see this repo's README for details.
      homeConfigurations = nixpkgs.lib.genAttrs systems mkHome;

      # Exposed so downstream flakes can do:
      #   home-manager.users.<name> = import "${dotfiles}/home.nix";
      #   home-manager.extraSpecialArgs = { wenv = dotfiles.inputs.wenv-src; };
      # without needing to know this repo's internal layout.
      homeModule = ./home.nix;
    };
}
