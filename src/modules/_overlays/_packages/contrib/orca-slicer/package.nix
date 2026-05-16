{
  lib,
  stdenv,
  callPackage,
  fetchFromGitHub,
  fetchpatch,

  cmake,
  pkg-config,

  boost186,
  cereal,
  cgal_5,
  curl,
  eigen,
  expat,
  ffmpeg,
  freetype,
  glew,
  glfw,
  gmp,
  gtest,
  hicolor-icon-theme,
  ilmbase,
  libjpeg,
  libpng,
  libnoise,
  mpfr,
  nlopt,
  opencascade-occt_7_6,
  opencv,
  openvdb,
  onetbb,
  pcre,
  wxGTK31,
  ...
}:
let
  wxGTK' =
    (wxGTK31.override {
      withCurl = true;
      withPrivateFonts = true;
      withWebKit = true;
    }).overrideAttrs
      (old: {
        configureFlags = old.configureFlags ++ [
          "--enable-debug=no"
        ];
      });

  platformAttrs =
    if stdenv.hostPlatform.isDarwin then callPackage ./darwin.nix { } else callPackage ./linux.nix { };

  sharedCFlags = [
    "-Wno-error=format-security"
    "-Wno-ignored-attributes"
    "-I${opencv.out}/include/opencv4"
    "-DBOOST_ALLOW_DEPRECATED_HEADERS"
    "-DBOOST_MATH_DISABLE_STD_FPCLASSIFY"
    "-DBOOST_MATH_NO_LONG_DOUBLE_MATH_FUNCTIONS"
    "-DBOOST_MATH_DISABLE_FLOAT128"
    "-DBOOST_MATH_NO_QUAD_SUPPORT"
    "-DBOOST_MATH_MAX_FLOAT128_DIGITS=0"
    "-DBOOST_CSTDFLOAT_NO_LIBQUADMATH_SUPPORT"
    "-DBOOST_MATH_DISABLE_FLOAT128_BUILTIN_FPCLASSIFY"
  ];
in
stdenv.mkDerivation (finalAttrs: {
  pname = "orca-slicer";
  version = "2.3.1";

  src = fetchFromGitHub {
    owner = "SoftFever";
    repo = "OrcaSlicer";
    tag = "v${finalAttrs.version}";
    hash = "sha256-RdMBx/onLq58oI1sL0cHmF2SGDfeI9KkPPCbjyMqECI=";
  };

  patches = [
    ./patches/dont-link-opencv-world.patch
    (fetchpatch {
      name = "pr-7650-configurable-update-check.patch";
      url = "https://github.com/SoftFever/OrcaSlicer/commit/d10a06ae11089cd1f63705e87f558e9392f7a167.patch";
      hash = "sha256-t4own5AwPsLYBsGA15id5IH1ngM0NSuWdFsrxMRXmTk=";
    })
  ]
  ++ (platformAttrs.patches or [ ]);

  strictDeps = true;

  nativeBuildInputs = [
    cmake
    pkg-config
    wxGTK'
  ]
  ++ (platformAttrs.nativeBuildInputs or [ ]);

  buildInputs = [
    (boost186.override {
      enableShared = true;
      enableStatic = false;
      extraFeatures = [
        "log"
        "thread"
        "filesystem"
      ];
    })
    boost186.dev
    cereal
    cgal_5
    curl
    eigen
    expat
    ffmpeg
    freetype
    glew
    glfw
    gmp
    hicolor-icon-theme
    ilmbase
    libjpeg
    libpng
    libnoise
    mpfr
    nlopt
    opencascade-occt_7_6
    opencv.cxxdev
    openvdb
    onetbb
    pcre
    wxGTK'
  ]
  ++ (platformAttrs.buildInputs or [ ]);

  inherit (platformAttrs) separateDebugInfo;

  doCheck = true;
  checkInputs = [ gtest ];

  env = {
    NLOPT = nlopt;

    NIX_CFLAGS_COMPILE = toString (sharedCFlags ++ (platformAttrs.extraCFlags or [ ]));

    NIX_LDFLAGS = toString (platformAttrs.extraLDFlags or [ ]);
  };

  prePatch = ''
    sed -i 's|nlopt_cxx|nlopt|g' cmake/modules/FindNLopt.cmake
    sed -i 's|"libnoise/noise.h"|"noise/noise.h"|' src/libslic3r/PerimeterGenerator.cpp
    sed -i 's|"libnoise/noise.h"|"noise/noise.h"|' src/libslic3r/Feature/FuzzySkin/FuzzySkin.cpp
  ''
  + (platformAttrs.prePatch or "");

  cmakeFlags = [
    (lib.cmakeBool "SLIC3R_STATIC" false)
    (lib.cmakeBool "SLIC3R_FHS" true)
    (lib.cmakeFeature "SLIC3R_GTK" "3")
    (lib.cmakeBool "BBL_RELEASE_TO_PUBLIC" true)
    (lib.cmakeBool "BBL_INTERNAL_TESTING" false)
    (lib.cmakeBool "SLIC3R_BUILD_TESTS" false)
    (lib.cmakeFeature "CMAKE_CXX_FLAGS" "-DGL_SILENCE_DEPRECATION")
    (lib.cmakeBool "ORCA_VERSION_CHECK_DEFAULT" false)
    (lib.cmakeFeature "LIBNOISE_INCLUDE_DIR" "${libnoise}/include/noise")
    (lib.cmakeFeature "LIBNOISE_LIBRARY" "${libnoise}/lib/libnoise-static.a")
    (lib.cmakeFeature "CMAKE_POLICY_VERSION_MINIMUM" "3.13")
    "-Wno-dev"
  ]
  ++ (platformAttrs.cmakeFlags or [ ]);

  postBuild = "( cd .. && ./scripts/run_gettext.sh )";

  preFixup = platformAttrs.preFixup or "";

  postInstall = platformAttrs.postInstall or "";

  desktopItems = platformAttrs.desktopItems or [ ];

  meta = {
    description = "G-code generator for 3D printers (Bambu, Prusa, Voron, VzBot, RatRig, Creality, etc.)";
    homepage = "https://github.com/SoftFever/OrcaSlicer";
    changelog = "https://github.com/SoftFever/OrcaSlicer/releases/tag/v${finalAttrs.version}";
    license = lib.licenses.agpl3Only;
    mainProgram = "orca-slicer";
    platforms = lib.platforms.linux ++ lib.platforms.darwin;
  };
})
