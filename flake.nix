{
  description = "NixOS support and libfprint driver for Goodix 27c6:5125 / 27c6:5135 fingerprint readers";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
  };

  outputs = { self, nixpkgs }:
    let
      supportedSystems = [ "x86_64-linux" "aarch64-linux" ];
      forAllSystems = nixpkgs.lib.genAttrs supportedSystems;
      pkgsFor = system: import nixpkgs {
        inherit system;
        overlays = [ self.overlays.default ];
      };
    in
    {
      overlays.default = final: prev: {
        libfprint-goodix-5125 = final.callPackage ./pkgs/libfprint-goodix-5125.nix { };
        goodix-linux-5125 = final.libfprint-goodix-5125;
        goodix-cli = final.callPackage ./pkgs/goodix-cli.nix { };
      };

      packages = forAllSystems (system:
        let
          pkgs = pkgsFor system;
        in
        {
          inherit (pkgs) libfprint-goodix-5125 goodix-cli;
          default = pkgs.libfprint-goodix-5125;
        }
      );

      nixosModules = {
        goodix-5125 = { ... }: {
          imports = [ ./modules/goodix-5125.nix ];
          nixpkgs.overlays = [ self.overlays.default ];
        };
        default = self.nixosModules.goodix-5125;
      };
    };
}
