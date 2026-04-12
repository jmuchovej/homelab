# OrcaSlicer macOS Port — Working Notes

## Goal

Port OrcaSlicer to build on aarch64-darwin (Apple Silicon macOS) while retaining
Linux support. The upstream nixpkgs package is Linux-only. OrcaSlicer's CMake
build system already supports macOS natively (Cocoa wxWidgets, Apple frameworks,
Objective-C++ sources).

## Architecture

Platform-specific logic is split out of the main derivation:

```
packages/contrib/orca-slicer/
  package.nix       Shared derivation — merges platform attrs
  darwin.nix        macOS: apple-sdk, deployment target, FHS resource path fix
  linux.nix         Linux: GTK3, GStreamer, dbus, webkit, GCC flags, desktop entry
  patches/
    dont-link-opencv-world.patch   Cross-platform (opencv_world -> opencv_core + opencv_imgproc)
    link-webkit2gtk.patch          Linux-only (explicit webkit2gtk linking)
```

`package.nix` calls `callPackage ./darwin.nix {}` or
`callPackage ./linux.nix {}` based on `stdenv.hostPlatform.isDarwin`, then
merges the returned attrset into the derivation (extra deps, compiler flags,
cmake flags, install steps).

## Build Commands

```bash
# Build (macOS)
nix build '.#orca-slicer' -j 24 --cores 8

# Dry-run (verify evaluation only)
nix build '.#orca-slicer' --dry-run

# Build with --keep-going to discover multiple errors
nix build '.#orca-slicer' -j 24 --cores 8 --keep-going

# View build log after failure
nix log $(nix path-info '.#orca-slicer' --derivation)

# Grep for errors
nix log <drv-path> 2>&1 | grep -E "error:" | grep -v "warning-option"
```

**Remember:** files must be `git add`-ed for the flake to see them.

## Issues Fixed So Far

1. **Untracked files invisible to flake** — `git+file://` only sees
   tracked/staged files. Fixed with `git add packages/orca-slicer/`.

2. **Missing `...` in package.nix args** — The flake's `callPackage` passes
   sibling packages as extra args via `self //`. Without `...`, Nix errors with
   "unexpected arguments". All packages in this repo need `...`.

3. **Missing `freetype`** — Required by OrcaSlicer's CMake
   (`find_package(Freetype)`). On Linux, this comes transitively through GTK3.
   On macOS, must be explicit.

4. **Missing `libjpeg`** — Same pattern. Required by `find_package(JPEG)` in
   `src/libslic3r/CMakeLists.txt`.

5. **`-Werror,-Wformat-security` on bundled imgui** — Nix stdenv hardening flags
   treat format string warnings as errors. Fixed with
   `-Wno-error=format-security` in shared `NIX_CFLAGS_COMPILE`.

## Current Status

**CMake configuration passes.** All dependencies found:

- Apple SDK 14.4, deployment target 11.3, Clang 21.1.8 arm64
- TBB, OpenSSL, CURL, Freetype, JPEG, Boost 1.86, OpenCV 4.13, CGAL 5.6
- OpenVDB 12.1, wxWidgets 3.1.7 (Cocoa backend), libnoise, nlopt, etc.

**Compilation in progress.** Got past 17%+ before session timeout. The build is
CPU-intensive (lots of CGAL template instantiation, slicer engine, GUI). Expect
20-30 minutes on Apple Silicon.

## Potential Issues Still Ahead

If the build fails after resuming, likely causes:

### Missing framework linking

The upstream CMake links Apple frameworks explicitly:

```cmake
# src/CMakeLists.txt
target_link_libraries(OrcaSlicer
  "-liconv -framework IOKit"
  "-framework CoreFoundation"
  "-framework AVFoundation" "-framework AVKit"
  "-framework CoreMedia" "-framework VideoToolbox"
  -lc++)
target_link_libraries(OrcaSlicer "-framework OpenGL")

# src/slic3r/CMakeLists.txt
target_link_libraries(libslic3r_gui ${DISKARBITRATION_LIBRARY} "-framework Security")
```

These should be found via the apple-sdk in stdenv. If not, may need to add
`apple-sdk_15` or explicit framework references.

### Availability warnings

Upstream adds `-Werror=partial-availability -Werror=unguarded-availability` on
APPLE. If APIs lack availability guards, add `-Wno-error=partial-availability`
to `darwin.nix`'s `extraCFlags`.

### wxWidgets Cocoa issues

wxGTK31 builds with `--with-osx_cocoa` on darwin. If the Cocoa backend has
issues with OrcaSlicer's custom widgets, may need wxGTK override adjustments
(e.g., `withWebKit`, `withMesa`).

### libnoise static library

The cmake flag points to `libnoise-static.a`. If this doesn't exist on darwin,
change to the dylib path.

### Linker errors for Objective-C++ (.mm files)

OrcaSlicer has macOS-specific `.mm` sources (RetinaHelperImpl.mm,
MacDarkMode.mm, RemovableDriveManagerMM.mm, wxMediaCtrl2.mm). These should
compile with Apple Clang automatically, but if there are missing ObjC framework
imports, check the apple-sdk version.

### gettext script

`postBuild` runs `./scripts/run_gettext.sh`. If `gettext` isn't in
`nativeBuildInputs`, this will fail. Add it if needed.

## Key References

- Upstream nixpkgs Linux package: `pkgs/by-name/or/orca-slicer/package.nix`
- PrusaSlicer (fork parent): `pkgs/applications/misc/prusa-slicer/default.nix`
  - Uses the same `#ifdef __APPLE__` -> `#if 0` resource path fix
- wxGTK31: `pkgs/by-name/wx/wxGTK31/package.nix` (Cocoa backend on darwin)
- OrcaSlicer upstream macOS build: `build_release_macos.sh` in repo root
- OrcaSlicer CMake APPLE handling: `CMakeLists.txt` and `src/CMakeLists.txt`

## Design Decisions

- **FHS layout on macOS** (`SLIC3R_FHS=1`): Avoids .app bundle complexity.
  Binary goes to `bin/orca-slicer`, resources to `share/OrcaSlicer/`.
- **No `CMAKE_MACOSX_BUNDLE`**: FHS mode handles install.
- **`separateDebugInfo = false` on darwin**: Not well-supported.
- **Shared `SLIC3R_GTK=3` flag**: Harmless on darwin (CMake only checks it in
  the Linux code path).
