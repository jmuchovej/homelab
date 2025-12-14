{
  # Snowfall Lib provides a customized `lib` instance with access to your flake's library
  # as well as the libraries available from your flake's inputs.
  lib,
  # You also have access to your flake's inputs.
  inputs,

  # The namespace used for your flake, defaulting to "internal" if not set.
  namespace,

  # All other arguments come from NixPkgs. You can use `pkgs` to pull packages or helpers
  # programmatically or you may add the named attributes as arguments here.
  pkgs,
  stdenv,

  buildHomeAssistantComponent,
  fetchzip,
  home-assistant,
  ...
}:

buildHomeAssistantComponent rec {
  owner = "hacs";
  domain = "hacs";
  version = "2.0.5";

  # src = fetchFromGitHub {
  #   owner = "hacs";
  #   repo = "integration";
  #   rev = version;
  #   hash = "sha256-xj+H75A6iwyGzMvYUjx61aGiH5DK/qYLC6clZ4cGDac=";
  # };
  src = fetchzip {
    url = "https://github.com/hacs/integration/releases/download/${version}/hacs.zip";
    hash = "sha256-iMomioxH7Iydy+bzJDbZxt6BX31UkCvqhXrxYFQV8Gw=";
    stripRoot = false;
  };

  # HACS has some specific dependencies
  propagatedBuildInputs = with home-assistant.python.pkgs; [
    aiogithubapi
    aiohttp
    aiohttp-cors
    async-timeout
    colorlog
    setuptools
  ];

  # Skip b/c manifest also checks `manifest.json` in `hacs_frontend`... >.>
  doCheck = false;

  meta = with lib; {
    changelog = "https://github.com/hacs/integration/releases/tag/${version}";
    description = "HACS gives you a powerful UI to handle downloads of all your custom needs";
    homepage = "https://hacs.xyz/";
    maintainers = [ ];
    license = licenses.mit;
  };
}
