## sops-nix convenience wrappers + path-to-flake-root helper.
##
##   get-file       — absolute path inside the flake source tree
##   get-secrets    — get a specific secrets path
##   get-secret     — sops secret definition keyed off a chosen sops file
##   get-secret'    — same, defaulting to `secrets/secrets.sops.yaml`
{ inputs, ... }:
let
  get-file = path: "${inputs.self}/${path}";
  get-secrets = filepath: get-file "secrets/${filepath}.sops.yaml";
in
{
  _rbn-lib = {
    inherit get-file get-secrets;

    get-secret = _config: secret: filepath: {
      sops.secrets.${secret} = {
        sopsFile = get-secrets filepath;
      };
    };

    get-secret' = _config: secret: {
      sops.secrets.${secret} = {
        sopsFile = get-secrets "secrets";
      };
    };
  };
}
