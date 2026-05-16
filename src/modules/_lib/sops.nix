## sops-nix convenience wrappers + path-to-flake-root helper.
##
##   get-file       — absolute path inside the flake source tree
##   get-secret     — sops secret definition keyed off a chosen sops file
##   get-secret'    — same, defaulting to `secrets/secrets.sops.yaml`
{ inputs, ... }:
let
  get-file = path: "${inputs.self}/${path}";
in
{
  _rbn-lib = {
    inherit get-file;

    get-secret = _config: secret: filepath: {
      sops.secrets.${secret} = {
        sopsFile = get-file "secrets/${filepath}.sops.yaml";
      };
    };

    get-secret' = _config: secret: {
      sops.secrets.${secret} = {
        sopsFile = get-file "secrets/secrets.sops.yaml";
      };
    };
  };
}
