Agent docs for the NymVPN Nix flake

Scope
- This AGENTS.md applies to the directory `nixos/flake/` and every file inside it.
- It tells humans and agent workers how to build, test, and iterate on the flake and the NixOS module.

Purpose
- Make it straightforward to pick up development on another machine.
- Describe the assumptions, required tools, build steps, troubleshooting steps, and how to import the NixOS module into a system flake.

Quick overview of what is inside
- `flake.nix` – the flake entrypoint. Exposes two packages (`nym-libwg`, `nym-vpnd`) and a NixOS module `nixosModules.nymvpn`.
- `modules/nym-vpn.nix` – the NixOS module with `services.nymvpn` options. Runs `nym-vpnd` as a systemd service.
- `pkgs/nym-libwg/default.nix` – derivation that builds or locates wireguard-go `libwg` artifacts in the layout the Rust crate expects.
- `pkgs/nym-vpnd/default.nix` – Rust derivation that builds `nym-vpnd` and `nym-vpnc` (Amnezia feature always enabled). Targets `x86_64-linux` only for now.
- `README.md` – short usage and troubleshooting notes.

Assumptions & constraints
- This flake targets `x86_64-linux` only.
- The flake fetches the upstream `nym-vpn-client` repository via SSH using the input `nymRepo = "git+ssh://git@github.com:nymtech/nym-vpn-client.git"`.
  - The builder machine (or the developer) must have an SSH key with GitHub access configured for the `git+ssh` fetch to succeed. If you cannot use SSH, override the `nymRepo` input to a HTTPS flake URL or to a local path.
- `nym-libwg` derivation expects upstream `make build-wireguard` (or repo build scripts) to produce `build/lib/*` artifacts.

Prerequisites on a developer machine (interactive work)
- Nix installed (preferably latest stable or flakes-enabled). For a system-wide setup on NixOS, ensure you can run `nix build`/`nix develop`.
- SSH access to `github.com` with a key authorized for `nymtech` repo clones, if you plan to let the flake fetch the repo via SSH.
- Recommended: use the dev shell provided by the flake for interactive development (includes `rustc`, `cargo`, `go`, `protoc`, and some native libs).

Dev shell and quick build commands
- Open the dev shell (inside repo root):
  - `nix develop ./nixos/flake#nixos.x86_64-linux`  # drop into a dev environment with tools
- Build the libwg package:
  - `nix build ./nixos/flake#nixos.x86_64-linux.packages.nym-libwg`
- Build the nym-vpnd package (daemon + CLI):
  - `nix build ./nixos/flake#nixos.x86_64-linux.packages.nym-vpnd`

Using a local source checkout instead of SSH fetch
- If you cloned this repo locally and want the flake to use the local path for `nymRepo` (recommended during iteration), use `--override-input` with `nix build`:
  - Example: `nix build ./nixos/flake#nixos.x86_64-linux.packages.nym-vpnd --override-input nymRepo /home/you/path/to/nym-vpn-client`
- Alternatively when using the flake from another flake as an input: in your system flake, set `inputs.myNym = { url = "/absolute/path/to/nym-vpn-client/nixos/flake"; }` or reference the repository URL directly.

How to import the module into your system flake
- In your system `flake.nix` add an input for this flake (either via local path or Git URL). Example snippet using a local path input named `nymflake`:

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    nymflake = { path = "/path/to/nym-vpn-client/nixos/flake"; };
  };

  outputs = { self, nixpkgs, nymflake, ... }: {
    nixosConfigurations.my-host = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [
        ./configuration.nix
        nymflake.outputs.nixosModules.nymvpn
      ];
      # pick packages from nymflake when needed by overriding inputs or using pkgs.callPackage
    };
  };

- After adding, enable the service in your configuration (example `configuration.nix` or module options):
  services.nymvpn.enable = true;
  services.nymvpn.socksPort = 1080;

- Build and switch your system using the flake-style command:
  - `sudo nixos-rebuild switch --flake .#my-host` (if your system flake is local)
  - If your system flake refers to this flake as input, use the appropriate flake reference.

Runtime validation & smoke tests (headless)
1. Check systemd unit:
   - `systemctl status nym-vpnd`
   - `journalctl -u nym-vpnd -f`
2. Confirm binaries are available:
   - `which nym-vpnd` and `which nym-vpnc` (they are installed via package provided by the module)
3. Use the CLI for control:
   - `nym-vpnc status`
   - `nym-vpnc connect --wait` or `nym-vpnc reconnect`
   - Enable SOCKS5 locally (per-app):
     - `nym-vpnc socks5 enable --socks5-address 127.0.0.1:1080 --rpc-address 127.0.0.1:8545 --exit-country=GB`
   - Test proxy from a client:
     - `curl --socks5-hostname 127.0.0.1:1080 https://ip.nymtech.net`
       - This verifies the proxy is being used and DNS is proxied (socks5h)

Troubleshooting common failures
- SSH fetch failure for `nymRepo`:
  - Ensure your developer machine has an SSH key, and that `ssh -T git@github.com` works without interactive prompts.
  - If SSH access is not possible, override `nymRepo` input to a HTTPS mirror or a local path.
- `nym-libwg` derivation does not find `build/lib` artifacts:
  - The derivation expects upstream scripts to produce `build/lib/*`. If those scripts fail inside the Nix build or are not run, you can produce the artifacts locally and point `nymRepo` to your local path (see "Using a local source checkout").
  - Alternatively, run upstream helper manually outside Nix and copy artifacts into the expected layout for local testing.
- Cargo/Rust build failures:
  - Use the dev shell: `nix develop ./nixos/flake#nixos.x86_64-linux` and run `cargo build -p nym-vpnd -p nym-vpnc --release --features amnezia` from the repo root to see verbose errors.
- Missing native libraries (libmnl, libnftnl, libdbus): ensure your `nixpkgs` environment includes them (the dev shell supplies them) or add them to the derivation if packaging further.

Notes about Amnezia & features
- The flake builds `nym-vpnd` with the `amnezia` crate feature always enabled (this was requested). If you later want to make it optional, modify `pkgs/nym-vpnd/default.nix` and expose a package variant.

Branching / development tips
- This flake was added on branch `develop` in this working copy. If you track the flake in a separate repository, keep the flake root stable and use descriptive commits.
- To iterate fast locally, use `--override-input nymRepo /local/path` pointing to your working copy and `nix build` the package; then test by either copying built binaries to a machine or by using the package in a local system flake.

Security & permissions
- The NixOS module runs `nym-vpnd` as root because it needs to create network interfaces and adjust routing. If you later want it to run as a dedicated user, add capability granting (`AmbientCapabilities = ["CAP_NET_ADMIN" "CAP_NET_RAW"]`) and ensure the user can access TUN devices.

If you are an agent picking this up
- Respect this AGENTS.md: it's the authoritative guide for building and testing this flake.
- If you modify build scripts or add new files under this directory, update this AGENTS.md accordingly.

Contact / upstream references
- Upstream source: git@github.com:nymtech/nym-vpn-client.git
- Nym docs: https://nym.com/docs/network

End of AGENTS.md
