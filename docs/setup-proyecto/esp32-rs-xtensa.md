# Setup de ambiente de desarrollo para Rust en ESP32 usando arquitectura Xtensa

## Setup de nix-ld (solamente para NixOS)

El compilador de Rust de Xtensa que descarga `espup` is un binario prebuildeado que esta dinamicamente linkeado.

En NixOS eso requiere tener `nix-ld`, asi que a tu config de Nix (como `/etc/nixos/configuration.nix`) le tenes que agregar esto:

```nix
programs.nix-ld = {
  enable = true;
  libraries = with pkgs; [
    stdenv.cc.cc  # libstdc++, libgcc_s
    zlib
  ];
};
```

## Setup de devenv

Dentro de la carpeta de tu proyecto, crea estos archivos

### `devenv.nix`

```nix
{
  pkgs,
  inputs,
  ...
}:
let
  # We cant  use pkgs.rust-analyzer !
  # pkgs.rust-analyzer tracks nixpkgs-unstable and updates daily, so it drifts ahead of the esp toolchain's cargo.
  # When they're out of sync, rust-analyzer's `cargo metadata` calls fails , so esp-idf-hal get no completions.
  # We solve that by pinning rust-analyzer to the same nightly date as the esp toolchain's cargo instead
  # (check the date with `cargo --version --verbose`).
  espRustAnalyzer =
    (inputs.fenix.packages.${pkgs.stdenv.hostPlatform.system}.toolchainOf {
      channel = "nightly";
      date = "2026-03-21";
      sha256 = "sha256-rboGKQLH4eDuiY01SINOqmXUFUNr9F4awoFZGzib17o=";
    }).rust-analyzer;
in
{
  packages = [
    pkgs.rustup           # base Rust install required by espup
    pkgs.espup            # installs the Xtensa Rust toolchain on top of rustup
    pkgs.espflash         # flashing over USB serial
    pkgs.ldproxy          # linker proxy required by esp-idf-sys
    pkgs.cargo-generate   # cargo generate esp-rs/esp-idf-template
    pkgs.cargo-espmonitor # serial monitor
    pkgs.python3          # required by ESP-IDF build scripts
    pkgs.cmake
    pkgs.ninja
    pkgs.git
    pkgs.pkg-config
    # esp-idf prerequisites (see esp-rs/esp-idf-template#prerequisites)
    pkgs.flex
    pkgs.bison
    pkgs.gperf
    pkgs.ccache
    pkgs.libffi
    pkgs.openssl
    pkgs.libusb1
    # libstdc++ :
    # the Espressif bundled libclang.so dlopen loads this at build time
    # nix-ld only covers executable loading, not dlopen, so we need it
    # on LD_LIBRARY_PATH explicitly (set in enterShell below).
    pkgs.stdenv.cc.cc.lib
    # the esp toolchain doesn't ship rust-analyzer.
    espRustAnalyzer
  ];

  enterShell = ''
    export RUSTUP_HOME="$HOME/.rustup-esp"
    export CARGO_HOME="$HOME/.cargo-esp"
    export IDF_TOOLS_PATH="$HOME/.espressif"

    if [ -f "$HOME/export-esp.sh" ]; then
      source "$HOME/export-esp.sh"
    else
      echo ""
      echo "  First-time setup:"
      echo "    rustup toolchain install stable  # base toolchain required by espup"
      echo "    espup install                    # generates ~/export-esp.sh and installs the Xtensa toolchain"
      echo ""
    fi

    # Prepend the real rust-analyzer store path (not the rustup shim) so it
    # wins over the pkgs.rustup shim, which loops infinitely on the esp toolchain.
    export PATH="${espRustAnalyzer}/bin:$PATH:$CARGO_HOME/bin"

    # The Espressif bundled libclang.so dynamically links libstdc++.so.6.
    # nix-ld handles executable loading but not dlopen, so we expose libstdc++
    # explicitly for bindgen to find at cargo build time.
    export LD_LIBRARY_PATH="${pkgs.stdenv.cc.cc.lib}/lib:$LD_LIBRARY_PATH"
  '';

  # See full reference at https://devenv.sh/reference/options/
}
```

### `devenv.yaml`

```yaml
# yaml-language-server: $schema=https://devenv.sh/devenv.schema.json
inputs:
  nixpkgs:
    url: github:cachix/devenv-nixpkgs/rolling
    # Rust toolchains and rust-analyzer nightly for Nix
  fenix:
    url: github:nix-community/fenix
    inputs:
      nixpkgs:
        follows: nixpkgs
```

### `.envrc`

```bash
#!/usr/bin/env bash
# this is the file .envrc , it runs when you enter the folder with cd
eval "$(devenv direnvrc)"
use devenv
```

### Setup de espup

`espup` necesita el toolchain base de Rust antes de que pueda poner la layer de Xtensa arriba.

Tambien genera `~/export-esp.sh` que la shell de devenv sourcea automaticamente

```bash
devenv shell
rustup toolchain install stable   # base toolchain required by espup
espup install                     # installs Xtensa toolchain, generates ~/export-esp.sh
```

## Scaffoldear el proyecto usando el template de ESP-IDF

```
cargo generate --init esp-rs/esp-idf-template
```

Una vez creados esos archivos, corre este comando para generar el proyecto de Rust. `--init` genera el proyecto en el directorio que estas parado, asi que esto tendria que ser donde tenes los archivos de devenv

```
cargo generate --init esp-rs/esp-idf-template
```

Y responde de esta forma

| Prompt                                           | Answer                   |
| ------------------------------------------------ | ------------------------ |
| Which template should be expanded?               | `cargo`                  |
| Project Name                                     | `your_project_name_here` |
| Which MCU to target?                             | `choose_yourself`        |
| Configure advanced template options?             | `true`                   |
| ESP-IDF version                                  | `v5.5.3`                 |
| Use latest GIT versions of the esp-idf-* crates? | `true`                  |
| Installation location of managed ESP-IDF         | `workspace`              |
| Configure project to use Dev Containers?         | `false`                  |
| Configure project to support Wokwi simulation?   | `false`                  |
| Add CI files for GitHub Action?                  | `true`                   |


The generated `.cargo/config.toml` sets the Xtensa target, `ldproxy` as linker, and `espflash` as runner.

El archivo `.cargo/config.toml` que se genera setea Xtensa como el target, `ldproxy` como el linker, y `espflash` como el runner.

Luego añadí `.devenv` y `.direnv` a tu `.gitignore`:

```bash
echo ".direnv" >> .gitignore
echo ".devenv" >> .gitignore
```
