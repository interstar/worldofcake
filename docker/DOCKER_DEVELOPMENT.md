# WorldOfCake Docker build environment

This repository provides a Linux Docker build environment for WorldOfCake. It is intended to reproduce the build and test toolchain, not to develop Layla itself and not to run graphical OpenFL previews or the VCV Rack host. Layla is distributed inside this repository as a self-contained generator JAR, so normal users do not need a separate Layla checkout or Clojure installation.

The image contains:

- Ubuntu 24.04 build tools and GCC/G++;
- Haxe 4.3.6;
- hxcpp 4.3.2;
- Lime 8.1.3;
- OpenFL 9.3.4;
- Java 11;
- a self-contained WorldOfCake/Layla layout-generator JAR (Layla parser + generator + Clojure + Instaparse);
- the Linux Rack 2.6.6 SDK.

Windows/MSYS2/Visual Studio Rack builds are not provided by this Linux image. GUI previews and MIDI/audio-device access remain host concerns.

## Prerequisites

Install Docker. The normal build uses the vendored artifact `vendor/layla/worldofcake-laylagen.jar` and its checksum file.

## Build the image

From the repository root:

```bash
./docker/docker-build-linux.sh
```

The build verifies the SHA-256 checksums of both the Linux Rack SDK archive and the vendored generator JAR. The image is tagged `worldofcake:linux`.


## Run commands in the container

Use the repository helper to mount this checkout at `/opt/worldofcake`:

```bash
./docker/docker-run-linux-build.sh bash
```

The helper mounts the repository read/write, so generated files and build products appear in the normal repository locations. The image's installed tools and dependencies are not hidden by this mount.

For a one-shot command:

```bash
./docker/docker-run-linux-build.sh bash -lc 'haxe --version'
```

The helper passes `RACK_DIR=/opt/rack-sdk/Rack-SDK`.

## Haxe headless tests

Run all five model test suites:

```bash
./docker/docker-run-linux-build.sh bash -lc '
  set -e
  for app in gbloink timeslider kdiagram tileland zewp; do
    haxe hxml/tests/test-$app-headless.hxml
  done
'
```

Run one suite:

```bash
./docker/docker-run-linux-build.sh haxe hxml/tests/test-gbloink-headless.hxml
```

Native Haxe test targets can be run in the same way:

```bash
./docker/docker-run-linux-build.sh haxe hxml/tests/test-gbloink-native.hxml
```

The native target writes its generated executable beneath the repository's `build/` tree.

Two shared-framework headless suites are also available: `hxml/tests/test-sequence-player-headless.hxml` and `hxml/tests/test-sequencer-core-status-headless.hxml`.

## Layla generation and checks

The bundled JAR includes Layla, the WorldOfCake generator, Clojure, and Instaparse. It requires only Java:

```bash
./docker/docker-run-linux-build.sh java -jar vendor/layla/worldofcake-laylagen.jar \
  --input layouts/openfl/gbloink.layla \
  --config layouts/openfl/gbloink.edn \
  --output Source \
  --native-output bridge/native
```

Use `--check` instead of generating files. To check all OpenFL layouts:

```bash
./docker/docker-run-linux-build.sh bash -lc '
  set -e
  for app in gbloink timeslider kdiagram tileland zewp; do
    java -jar vendor/layla/worldofcake-laylagen.jar \
      --input layouts/openfl/$app.layla \
      --config layouts/openfl/$app.edn \
      --output Source \
      --native-output bridge/native \
      --check
  done
'
```

Generated files under `Source/generated/` and `bridge/native/worldofcake/generated/` should not be hand-edited.

## OpenFL builds

Build an OpenFL Neko target without opening a window:

```bash
./docker/docker-run-linux-build.sh haxelib run lime build derivatives/openfl/project-gbloink.xml neko
```

Build the other applications by replacing `gbloink` with `kdiagram`, `tileland`, `timeslider`, or `zewp`.

The container can compile OpenFL targets, but it is not configured for interactive graphical preview. Use the host-side preview scripts when a display is required.

## Linux Rack builds

Build the available Gbloink Rack module:

```bash
./docker/docker-run-linux-build.sh bash -lc '
  set -e
  make -C derivatives/vcvrack/gbloink \
    RACK_DIR=/opt/rack-sdk/Rack-SDK clean
  make -C derivatives/vcvrack/gbloink \
    RACK_DIR=/opt/rack-sdk/Rack-SDK build
'
```

The plugin is written beneath:

```text
build/vcvrack/gbloink/plugin.so
```

The Rack build may emit warnings from hxcpp headers and GCC; warnings do not by themselves indicate a failed build. The image does not install the plugin into a host Rack user directory or launch Rack.

## Persistent build outputs and caches

The standard helper mounts the repository, so `build/`, `derivatives/openfl/Export/`, generated files, and Rack artifacts persist on the host. The Haxe libraries are installed into the image and do not need a separate volume.

For an interactive container with an additional named cache volume:

```bash
docker volume create worldofcake-build-cache
docker run --rm -it \
  -v "$PWD:/opt/worldofcake" \
  -v worldofcake-build-cache:/opt/worldofcake/build \
  -e RACK_DIR=/opt/rack-sdk/Rack-SDK \
  -w /opt/worldofcake \
  worldofcake:linux bash
```

Use a cache volume only when you deliberately want build artifacts to survive independently of the checkout. A clean build can remove the repository `build/` tree or the named volume as appropriate.

## Updating the bundled Layla generator

Normal users do not need Layla installed. The generator is maintained outside this repository; the project maintainer rebuilds `vendor/layla/worldofcake-laylagen.jar` (a self-contained JAR combining the Layla parser, the WorldOfCake generator, Clojure, and Instaparse) and commits the JAR together with its SHA-256 checksum.

The image pins the Haxe ecosystem versions and verifies both the bundled Rack SDK and the bundled Layla generator artifact.