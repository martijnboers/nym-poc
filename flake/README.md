NymVPN flake (nixos/flake)

Purpose:
- Provide a flake that builds local `nym-libwg` (wireguard-go artifacts) and `nym-vpnd` (daemon + CLI) with Amnezia enabled.
- Provide a NixOS module `nixosModules.nymvpn` you can import in your system flake.

Quick usage (after creating files):
1) From repo root:
   - Ensure build tools are available: `nix build .#nixos.x86_64-linux.packages.nym-libwg` to build libwg
   - Build nym-vpnd: `nix build .#nixos.x86_64-linux.packages.nym-vpnd`

2) To use the module in a system flake:
   - In your system flake `flake.nix`, add this repo as an input or use local path, then:
     modules = [
       inputs.thisRepo.outputs.nixosModules.nymvpn
     ];
   - Or simply add `nixosModules.nymvpn` into your `nixosConfigurations.<host>.modules` list.

3) Example `configuration.nix` fragment (flake-style):
   services.nymvpn.enable = true;
   services.nymvpn.socksPort = 1080;
   # The package used is the package built by this flake by default when imported from the flake outputs.

Notes & troubleshooting:
- Building requires `go`, `protobuf` (protoc), and native libs (libmnl, libnftnl, libdbus) available in the build environment. Use the provided `devShell` for development.
- The `nym-libwg` derivation relies on the upstream `make build-wireguard` helper to produce the static lib artifacts in `build/lib/`. If that script doesn't produce them in CI, run it locally and inspect.
- This flake targets `x86_64-linux` only for now.
