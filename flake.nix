{
  description = "SCTMES-managed NixOS hosts";

  inputs = {
    dotlink.url = "github:abird-ai/dotlink/84cd9b7cbda48e327e15781c771e162fb8820ae7";
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
    yazelix.url = "github:Yazelix/nova/edge";
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
      self,
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
      checks.${system}.host-116 =
        let
          config = self.nixosConfigurations."116".config;
          homes = config.home-manager.users;
        in
        assert config.nix.settings.require-sigs;
        assert
          config.nix.settings.substituters == [
            "https://mirrors.ustc.edu.cn/nix-channels/store?priority=10"
            "https://cache.nixos.org?priority=40"
          ];
        assert builtins.elem "https://cache.numtide.com?priority=60" config.nix.settings.extra-substituters;
        assert builtins.elem "https://yazelix.cachix.org?priority=60"
          config.nix.settings.extra-substituters;
        assert builtins.elem "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
          config.nix.settings.trusted-public-keys;
        assert nixpkgs.lib.all (key: builtins.elem key config.nix.settings.extra-trusted-public-keys) [
          "niks3.numtide.com-1:DTx8wZduET09hRmMtKdQDxNNthLQETkc/yaX7M4qK0g="
          "yazelix.cachix.org-1:ZgxIjQvaP0VTWL8Racx27mpUNzDJ97xC2y7QWYjmGNM="
        ];
        assert nixpkgs.lib.all
          (name: !(nixpkgs.lib.attrByPath [ "programs" "yazelix" "enable" ] false homes.${name}))
          [
            "zky"
            "wangrongfeng"
          ];
        assert !config.services.xserver.enable;
        assert homes.ysun.dotfiles.maint.enable;
        assert homes.ysun.dotfiles.maint.host == "116";
        assert homes.ysun.programs.yazelix.package == inputs.yazelix.packages.${system}.yazelix-no-rio;
        assert nixpkgs.lib.all (name: homes.${name}.programs.codexBase.enable) [
          "ysun"
          "zky"
          "wangrongfeng"
        ];
        pkgs.runCommand "host-116-check" { } "touch $out";

      devShells.${system} = {
        reactive-resume = pkgs.mkShell {
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
          inputs.dotlink.nixosModules.default
          ./hosts/116
        ];
      };
    };
}
