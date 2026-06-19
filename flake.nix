{
  inputs = {
    flake-utils.url = "github:numtide/flake-utils";
    rust-overlay.url = "github:oxalica/rust-overlay";
    cargo2nix = {
      url = "github:cargo2nix/cargo2nix";
      inputs = {
        nixpkgs.follows = "nixpkgs";
        flake-utils.follows = "flake-utils";
        rust-overlay.follows = "rust-overlay";
      };
    };
    aarch64-esr-decoder = {
      url = "github:google/aarch64-esr-decoder";
      flake = false;
    };
  };
  outputs = { self, nixpkgs, flake-utils, rust-overlay, cargo2nix, aarch64-esr-decoder }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs {
          inherit system;
          overlays = [
            rust-overlay.overlays.default
            cargo2nix.overlays.default
          ];
        };

        pkgsCross = import nixpkgs {
          inherit system;
          crossSystem.config = "aarch64-none-elf";
        };

        rustVersion = "1.93.0";

        rustPkgs = pkgs.rustBuilder.makePackageSet {
          inherit rustVersion;
          packageFun = import ./Cargo.nix;
          workspaceSrc = aarch64-esr-decoder;
        };
      in {
        packages.default = rustPkgs.workspace.aarch64-esr-decoder {};

        devShell =
          pkgs.mkShell {
            buildInputs = with pkgs; [
              (writeScriptBin "update" ''
                cargo2nix --locked ${aarch64-esr-decoder}
              '')
              # Rust
              (rust-bin.selectLatestNightlyWith (toolchain: toolchain.default.override {
                extensions = [
                  "cargo"
                  "clippy"
                  "rustc"
                  "rust-src"
                  "rustfmt"
                  "rust-analyzer"
                ];
                targets = [
                  "x86_64-unknown-linux-gnu"
                  "aarch64-unknown-none-softfloat"
                ];
              }))
              cargo2nix.packages.${system}.default

              # Haskell (for tools)
              haskellPackages.ghc
              cabal-install
              haskell-language-server

              just
              haskellPackages.fourmolu
              haskellPackages.implicit-hie
              fd

              zlib

              # Project tooling
              just qemu tio

              # Cross compiler
              pkgsCross.buildPackages.gcc
              pkgsCross.buildPackages.gdb
            ];
          };
      }
    );
}
