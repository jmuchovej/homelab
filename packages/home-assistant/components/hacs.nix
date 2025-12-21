{
  lib,
  buildHomeAssistantComponent,
  fetchFromGitHub,
  fetchurl,
  aiogithubapi,
  aiohttp,
  aiohttp-cors,
  async-timeout,
  colorlog,
  setuptools,
  unzip,
  ...
}:
let
  version = "2.0.5";
  frontend = "20250128065759";

  # HACS frontend is distributed as a separate Python wheel from GitHub releases
  # When updating HACS version, get FRONTEND_VERSION from:
  # https://github.com/hacs/integration/blob/${version}/scripts/install/frontend
  hacs-frontend = fetchurl {
    url = "https://github.com/hacs/frontend/releases/download/${frontend}/hacs_frontend-${frontend}-py3-none-any.whl";
    hash = "sha256-5rGWFx+8s8s+ztLEjnifPclGtZ90kEh98W2NTkeoX8Q=";
  };
in
buildHomeAssistantComponent rec {
  owner = "hacs";
  domain = "hacs";
  inherit version;

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

  nativeBuildInputs = [ unzip ];

  # After the standard installation, unpack the frontend wheel and copy its contents
  # into the component directory, replicating what the bash script does
  postInstall = ''
    # Find the actual installation by looking for the `custom_components` directory
    component_dir=$(find $out -type d -name "custom_components" -print -quit)

    if [[ -z "$component_dir" ]]; then
      echo "ERROR: Could not find a \`custom_components\` directory in $out"
      exit 1
    fi

    # Create a temporary directory to unpack the wheel
    temp_frontend=$(mktemp -d)

    # Unpack the wheel file (which is just a zip archive)
    ${unzip}/bin/unzip -q ${hacs-frontend} -d "$temp_frontend"

    # Copy the hacs_frontend directory into the installed component
    # The wheel contains a hacs_frontend/ directory at the root
    cp -r "$temp_frontend/hacs_frontend" "$component_dir/hacs"

    # Clean up (the bash script removes .dist-info files)
    rm -rf "$component_dir/hacs"/*.dist-info

    # Verify the installation succeeded
    if [[ ! -f "$component_dir/hacs/hacs_frontend/version.py" ]]; then
      echo "ERROR: Frontend installation failed - version.py not found"
      exit 1
    fi
  '';

  meta = {
    changelog = "https://github.com/hacs/integration/releases/tag/${version}";
    description = "HACS gives you a powerful UI to handle downloads of all your custom needs";
    homepage = "https://hacs.xyz/";
    maintainers = [ ];
    license = lib.licenses.mit;
  };
}
