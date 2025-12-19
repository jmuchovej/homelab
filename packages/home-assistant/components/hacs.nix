{
  lib,
  buildHomeAssistantComponent,
  fetchFromGitHub,
  aiogithubapi,
  aiohttp,
  aiohttp-cors,
  async-timeout,
  colorlog,
  setuptools,
  ...
}:
buildHomeAssistantComponent rec {
  owner = "hacs";
  domain = "hacs";
  version = "2.0.5";

  src = fetchFromGitHub {
    owner = "hacs";
    repo = "integration";
    rev = version;
    hash = "sha256-xj+H75A6iwyGzMvYUjx61aGiH5DK/qYLC6clZ4cGDac=";
  };

  dependencies = [
    aiogithubapi
    aiohttp
    aiohttp-cors
    async-timeout
    colorlog
    setuptools
  ];

  # Skip b/c manifest also checks `manifest.json` in `hacs_frontend`... >.>
  doCheck = false;

  meta = {
    changelog = "https://github.com/hacs/integration/releases/tag/${version}";
    description = "HACS gives you a powerful UI to handle downloads of all your custom needs";
    homepage = "https://hacs.xyz/";
    maintainers = [ ];
    license = lib.licenses.mit;
  };
}
