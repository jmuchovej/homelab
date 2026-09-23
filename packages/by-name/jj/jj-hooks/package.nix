{
  lib,
  rustPlatform,
  fetchFromGitHub,
}:
rustPlatform.buildRustPackage {
  pname = "jj-hooks";
  version = "0.3.12";
  src = fetchFromGitHub {
    owner = "mattwilkinsonn";
    repo = "jj-hooks";
    tag = "v0.3.12";
    hash = "sha256-1jJg199ppkqtDPAxrJtc1G42kXjP0BJDEWv619nYVus=";
  };
  cargoHash = "sha256-nQ5gVsHVPNfIqTUaP6ep4EeY5KfMrj4KV5DhY3ZzqGI=";
  # Tests drive real jj repos and pre-commit/lefthook/hk backends.
  doCheck = false;
  meta = {
    description = "Run pre-commit / lefthook / hk hooks against jj bookmark pushes";
    homepage = "https://github.com/mattwilkinsonn/jj-hooks";
    license = with lib.licenses; [
      mit
      asl20
    ];
    mainProgram = "jj-hooks";
  };
}
