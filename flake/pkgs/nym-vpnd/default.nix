{
  lib,
  stdenv,
  fetchFromGitHub,
  rustPlatform,
  pkg-config,
  protobuf,
  src,
  nym-libwg,
  cacert,
}:

let
  rust = rustPlatform.default;
in

rust.buildRustPackage rec {
  pname = "nym-vpnd";
  version = "local";

  inherit src;

  cargoLock = null; # use local lock if present, or allow cargo to fetch

  cargoBuildFlags = [ "--release" ];
  # enable amnezia feature unconditionally
  cargoFeatures = [ "amnezia" ];

  nativeBuildInputs = [
    pkg-config
    protobuf
  ];
  buildInputs = [
    nym-libwg
    cacert
  ];

  # cut targets to minimal binaries -> build nym-vpnd + nym-vpnc
  buildPhase = ''
    export RUSTFLAGS="${stdenv.lib.optionalString stdenv.hostPlatform.rustPlatform.isMusl "-C link-arg=-Wl,--no-export-dynamic"}"
    # build both binaries
    cargo build --release -p nym-vpnd -p nym-vpnc --features amnezia
  '';

  installPhase = ''
    mkdir -p $out/bin
    cp target/release/nym-vpnd $out/bin/
    cp target/release/nym-vpnc $out/bin/
  '';

  meta = with lib; {
    description = "NymVPN daemon + CLI (local build, amnezia enabled)";
    license = licenses.gpl3;
    platforms = [ "x86_64-linux" ];
    maintainers = with maintainers; [ ];
  };
}
