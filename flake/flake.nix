{
  description = "NixOS flake for NymVPN (nym-vpnd + libwg) - x86_64-linux only";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
    nymRepo = {
      url = "git+ssh://git@github.com:nymtech/nym-vpn-client.git";
    };
  };

  outputs =
    {
      self,
      nixpkgs,
      flake-utils,
      nymRepo,
      ...
    }:
    flake-utils.lib.eachDefaultSystem (
      system:
      let
        pkgs = import nixpkgs { inherit system; };
        src = nymRepo; # fetch the nym-vpn-client repository via SSH
        nym-libwg = pkgs.callPackage ./pkgs/nym-libwg/default.nix { inherit src; };
        nym-vpnd = pkgs.callPackage ./pkgs/nym-vpnd/default.nix {
          inherit src nym-libwg;
          rustPlatform = pkgs.rustPlatform;
          protobuf = pkgs.protobuf;
          pkg-config = pkgs.pkg-config;
          cacert = pkgs.cacert;
        };
      in
      {
        packages.${system} = {
          nym-libwg = nym-libwg;
          nym-vpnd = nym-vpnd;
        };

        nixosModules = {
          nymvpn = ./modules/nym-vpn.nix;
        };

        devShells.${system}.default = pkgs.mkShell {
          buildInputs = [
            pkgs.rustc
            pkgs.cargo
            pkgs.go
            pkgs.protobuf
            pkgs.pkg-config
            pkgs.libmnl
            pkgs.libnftnl
            pkgs.libdbus
          ];
          shellHook = ''
            echo "Dev shell for building nym-vpnd (x86_64-linux)."
          '';
        };
      }
    );
}
