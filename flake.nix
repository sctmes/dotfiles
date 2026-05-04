{
  description = "SCTMES-managed NixOS hosts";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    disko = {
      url = "github:nix-community/disko";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    home-manager = {
      url = "github:nix-community/home-manager/master";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    impermanence.url = "github:nix-community/impermanence";
    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    upstream = {
      url = "github:bioinformatist/dotfiles";
      inputs.nixpkgs.follows = "nixpkgs";
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
      specialArgs = {
        inherit inputs;
        username = "ysun";
      };
    in
    {
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
