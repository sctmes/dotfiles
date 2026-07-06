{
  description = "SCTMES-managed NixOS hosts";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    disko = {
      url = "github:nix-community/disko";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    home-manager = {
      url = "github:nix-community/home-manager/release-26.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    impermanence.url = "github:nix-community/impermanence";
    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    yazelix-next.url = "git+ssh://git@github.com/luccahuguet/yazelix-next.git";
    upstream = {
      url = "github:bioinformatist/dotfiles";
      inputs.disko.follows = "disko";
      inputs.home-manager.follows = "home-manager";
      inputs.impermanence.follows = "impermanence";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.sops-nix.follows = "sops-nix";
    };
  };

  outputs =
    inputs@{
      nixpkgs,
      disko,
      home-manager,
      impermanence,
      sops-nix,
      upstream,
      ...
    }:
    let
      system = "x86_64-linux";
      pkgs = nixpkgs.legacyPackages.${system};
      specialArgs = {
        inherit inputs;
        username = "ysun";
      };
    in
    {
      devShells.${system}.reactive-resume = pkgs.mkShell {
        packages = with pkgs; [
          nodejs_24
          pnpm

          gcc
          gnumake
          pkg-config
          python3
        ];

        shellHook = ''
          export COREPACK_HOME="''${COREPACK_HOME:-''${XDG_CACHE_HOME:-$HOME/.cache}/corepack/reactive-resume}"
        '';
      };

      nixosConfigurations."116" = nixpkgs.lib.nixosSystem {
        inherit system specialArgs;
        modules = [
          disko.nixosModules.disko
          impermanence.nixosModules.impermanence
          sops-nix.nixosModules.sops
          home-manager.nixosModules.home-manager
          upstream.profiles.headless
          upstream.profiles.ai-serving
          {
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;
            home-manager.extraSpecialArgs = inputs // specialArgs;
            home-manager.users.${specialArgs.username} = import ./homes/ysun/default.nix;
            home-manager.users.zky = import ./homes/headless-dev {
              inherit inputs;
              username = "zky";
            };
            home-manager.users.wangrongfeng = import ./homes/headless-dev {
              inherit inputs;
              username = "wangrongfeng";
            };
          }
          ./hosts/116
        ];
      };
    };
}
