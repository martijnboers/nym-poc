{
  stdenv,
  fetchFromGitHub,
  go,
  makeWrapper,
  src,
  pkg-config,
  libmnl,
  libnftnl,
  libc,
}:

stdenv.mkDerivation rec {
  name = "nym-libwg-0.1";
  inherit src;

  nativeBuildInputs = [
    go
    makeWrapper
    pkg-config
  ];
  buildInputs = [
    libmnl
    libnftnl
  ];

  # This derivation builds the wireguard-go library artefacts in the layout that the rust crate expects.
  # It uses the project's existing scripts. Adjust if your local layout differs.
  buildPhase = ''
    mkdir -p $out/build/lib
    # run the upstream helper that builds wireguard-go static libs:
    # This repo provides a convenient make target referenced in README: `make build-wireguard`
    # We run it from repo root (src), then copy build/lib/* to $out/build/lib.
    make -C ${src} build-wireguard || true
    if [ -d ${src}/build/lib ]; then
      cp -r ${src}/build/lib/* $out/build/lib/ || true
    fi

    # If the repo scripts did not produce the expected static libs, fail so user can inspect.
    if [ -z "$(ls -A $out/build/lib 2>/dev/null || true)" ]; then
      echo "Expected libwg artifacts under $out/build/lib but none found."
      echo "Please run the upstream wireguard build helper locally and re-run build."
      false
    fi
  '';

  installPhase = ''
    mkdir -p $out/lib
    cp -r $out/build/lib/* $out/lib/ || true
    # leave header files if present
    if [ -d ${src}/wireguard/include ]; then
      mkdir -p $out/include
      cp -r ${src}/wireguard/include/* $out/include/
    fi
  '';
}
