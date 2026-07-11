{
  description = "Compare versions according to the UAPI Version Format Specification";

  inputs = {

    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    pre-commit = {
      url = "github:cachix/pre-commit-hooks.nix";
      inputs = {
        nixpkgs.follows = "nixpkgs";
      };
    };

  };

  outputs =
    inputs@{
      self,
      nixpkgs,
      ...
    }:
    let
      eachSystem = nixpkgs.lib.genAttrs [
        "aarch64-darwin"
        "aarch64-linux"
        "x86_64-darwin"
        "x86_64-linux"
      ];
    in

    {
      packages = eachSystem (system: {
        uapiVersion = nixpkgs.legacyPackages.${system}.callPackage ./nix/build.nix { };
        default = self.packages.${system}.uapiVersion;
      });

      checks = eachSystem (
        system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
        in
        {
          clippy = self.packages.${system}.uapiVersion.overrideAttrs (
            _: previousAttrs: {
              pname = "${previousAttrs.pname}-clippy";
              nativeCheckInputs = (previousAttrs.nativeCheckInputs or [ ]) ++ [ pkgs.clippy ];
              checkPhase = "cargo clippy";
            }
          );
          rustfmt = self.packages.${system}.uapiVersion.overrideAttrs (
            _: previousAttrs: {
              pname = "${previousAttrs.pname}-rustfmt";
              nativeCheckInputs = (previousAttrs.nativeCheckInputs or [ ]) ++ [ pkgs.rustfmt ];
              checkPhase = "cargo fmt --check";
            }
          );
          pre-commit = inputs.pre-commit.lib.${system}.run {
            src = ./.;
            hooks = {
              nixfmt.enable = true;
              deadnix.enable = true;
            };
          };
        }
      );

      devShells = eachSystem (
        system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
        in
        {
          default = pkgs.mkShell {
            shellHook = ''
              ${self.checks.${system}.pre-commit.shellHook}
            '';

            packages = [
              pkgs.nixfmt
              pkgs.clippy
              pkgs.rustfmt
              pkgs.cargo-machete
              pkgs.cargo-edit
              pkgs.cargo-bloat
              pkgs.cargo-deny
              pkgs.cargo-cyclonedx
            ];

            inputsFrom = [ self.packages.${system}.uapiVersion ];

            RUST_SRC_PATH = "${pkgs.rust.packages.stable.rustPlatform.rustLibSrc}";
          };
        }
      );

    };
}
