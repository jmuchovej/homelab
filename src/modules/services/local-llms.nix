{
  __findFile,
  den,
  inputs,
  ...
}:
{
  den.schema.host =
    { lib, ... }:
    let
      inherit (lib) mkOption;
      inherit (lib.types) listOf str;
    in
    {
      options.local-llms.ollama = {
        models = mkOption {
          type = listOf str;
          default = [ ];
          description = "Models to pull on startup (e.g. `llama3.2`)";
        };
      };
    };

  rbn.services._.local-llms = {
    provides = {
      ollama = {
        includes = [
          (den.batteries.unfree [ "ollama" ])
          (<rbn/mesh/register> {
            name = "ollama";
            port = 11434;
            healthcheck = "/";
            authentik = {
              name = "Ollama";
              group = "Compute";
              type = "proxy";
              access = [
                "compute"
                "compute-managers"
              ];
            };
          })
        ];

        nixos =
          {
            host,
            lib,
            ...
          }:
          let
            inherit (lib.rbn) enabled;
          in
          {
            services.ollama = enabled // {
              syncModels = true;
              loadModels = host.local-llms.ollama.models;
            };
          };
      };

      open-webui = {
        nixos =
          {
            host,
            config,
            lib,
            ...
          }:
          let
            inherit (lib.rbn) enabled get-secret' get-secret;
            inherit (host) datacenter;
            inherit (config.services) ollama;
          in
          lib.mkMerge [
            (get-secret' config "open-webui/secret-key")
            (get-secret config "open-webui/client-id" "authentik")
            (get-secret config "open-webui/client-secret" "authentik")
            {
              sops.templates."open-webui.env".content =
                let
                  client-id = config.sops.placeholder."open-webui/client-id";
                in
                ''
                  WEBUI_SECRET_KEY=${config.sops.placeholder."open-webui/secret-key"}
                  OAUTH_CLIENT_ID=${client-id}
                  OAUTH_CLIENT_SECRET=${config.sops.placeholder."open-webui/client-secret"}
                  OPENID_PROVIDER_URL=${<rbn/authentik/openid-url> client-id datacenter}
                '';
              services.open-webui = enabled // {
                inherit (ollama) host;
                port = ollama.port + 1;
                environment = {
                  WEBUI_URL = "https://chat.${datacenter}.jm0.io";
                  SSL_CERT_FILE = "/etc/ssl/certs/ca-certificates.crt";
                  REQUESTS_CA_BUNDLE = "/etc/ssl/certs/ca-certificates.crt";

                  ANONYMIZED_TELEMETRY = "False";
                  DO_NOT_TRACK = "True";
                  SCARF_NO_ANALYTICS = "True";
                  OLLAMA_BASE_URL = "http://${ollama.host}:${toString ollama.port}";
                  ENABLE_CHANNELS = "True";
                  ENABLE_FOLDERS = "True";
                  ENABLE_NOTES = "True";
                  ENABLE_MEMORIES = "True";
                  ENABLE_USER_WEBHOOKS = "True";
                  ENABLE_TITLE_GENERATION = "True";
                  ENABLE_COMPRESSION_MIDDLEWARE = "True";

                  ENABLE_CODE_EXECUTION = "True";
                  CODE_EXECUTION_ENGINE = "pyodide";
                  ENABLE_CODE_INTERPRETER = "True";
                  CODE_INTERPRETER_ENGINE = "pyodide";

                  VECTOR_DB = "chroma";
                  CHROMA_HTTP_HOST = config.services.chromadb.host;
                  CHROMA_HTTP_PORT = lib.toString config.services.chromadb.port;

                  RAG_EMBEDDING_ENGINE = "ollama";

                  ENABLE_LOGIN_FORM = "False";
                  ENABLE_PASSWORD_AUTH = "False";
                  ENABLE_OAUTH_SIGNUP = "True";
                  OAUTH_PROVIDER_NAME = "The Rebellion";
                  OAUTH_SCOPES = "openid email profile";
                  OAUTH_PICTURE_CLAIM = "avatar";
                  OAUTH_GROUP_CLAIM = "groups";
                  ENABLE_OAUTH_GROUP_MANAGEMENT = "True";
                  ENABLE_OAUTH_GROUP_CREATION = "True";
                  OAUTH_UPDATE_PICTURE_ON_LOGIN = "True";
                  OAUTH_ALLOWED_ROLES = "compute,compute-manager";
                  OAUTH_ADMIN_ROLES = "compute-manager";
                  OAUTH_ALLOWED_DOMAINS = "*.${datacenter}.jm0.io,*.jm0.io,jm0.io";
                };
                environmentFile = config.sops.templates."open-webui.env".path;
              };

              # open-webui runs under DynamicUser=true. The dynamic user isn't
              # in /etc/passwd, so Python's `pathlib.Path('~').expanduser()`
              # can't resolve a home directory and crashes at startup.
              # Set HOME explicitly to the service's state directory.
              systemd.services.open-webui.environment.HOME = "/var/lib/open-webui";
            }
          ];

        includes = [
          (den.batteries.unfree [ "open-webui" ])
          (<rbn/mesh/register> {
            name = "open-webui";
            port = 11435;
            healthcheck = "/health";
            subdomain = [
              "chat"
            ];
            authentik = {
              name = "Open WebUI";
              icon = "open-webui";
              group = "Compute";
              type = "oauth";
              access = [
                "compute"
                "compute-managers"
              ];
              redirect-uris = [
                "{{ domain }}/oauth/oidc/callback"
              ];
            };
          })
        ];
      };

      vllm = {
        __functor =
          _self:
          { model }:
          {
            nixos =
              { config, ... }:
              {
                sops.secrets."vllm" = { };

                virtualisation.oci-containers.containers.vllm = {
                  pull = "always";
                  image = "docker.io/vllm/vllm-openai:latest";
                  hostname = "vllm";
                  extraOptions = [
                    "--device=nvidia.com/gpu=all"
                    "--ipc=host"
                  ];
                  volumes = [
                    "/warp/models/huggingface:/root/.cache/huggingface"
                  ];
                  ports = [ "8556:8000" ];
                  environmentFiles = [
                    config.sops.secrets."vllm".path
                  ];
                  cmd = [ "--model=${model}" ];
                };
              };
          };
      };
    };
  };
}
