{
  cfg,
  config,
  lib,
  hostname,
  datacenter,
  ...
}:
let
  inherit (lib.rebellion.network)
    mk-traefik-service
    with-consul
    mk-authentik
    mk-healthcheck
    mk-openid-url
    ;
  inherit (lib.rebellion) enabled;
  inherit (lib.rebellion.file) get-secret' get-secret;
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
        OAUTH_CLIENT_ID="${client-id}"
        OAUTH_CLIENT_SECRET="${config.sops.placeholder."open-webui/client-secret"}"
        OPENID_PROVIDER_URL="${mk-openid-url client-id datacenter}"
      '';
    services.open-webui =
      let
        ollama = config.services.ollama;
      in
      enabled
      // {
        host = ollama.host;
        port = ollama.port + 1;
        environment = {
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

          # Code Execution & Interpreter:
          #   https://docs.openwebui.com/getting-started/env-configuration/#code-execution
          #   https://docs.openwebui.com/getting-started/env-configuration/#code-interpreter
          ENABLE_CODE_EXECUTION = "True";
          CODE_EXECUTION_ENGINE = "pyodide";
          ENABLE_CODE_INTERPRETER = "True";
          CODE_INTERPRETER_ENGINE = "pyodide";

          # Vector Database: https://docs.openwebui.com/getting-started/env-configuration/#vector-database
          VECTOR_DB = "chroma";
          # CHROMA_TENANT
          # CHROMA_DATABASE
          # CHROMA_HTTP_PORT
          # CHROMA_CLIENT_AUTH_PROVIDER
          # CHROMA_CLIENT_AUTH_CREDENTIALS

          # RAG: https://docs.openwebui.com/getting-started/env-configuration/#retrieval-augmented-generation-rag
          RAG_EMBEDDING_ENGINE = "ollama";

          # OAuth: https://docs.openwebui.com/getting-started/env-configuration/#openid-oidc
          OAUTH_PROVIDER_NAME = "The Rebellion";
          OAUTH_SCOPES = "openid email profile";
          OAUTH_PICTURE_CLAIM = "avatar";
          OAUTH_GROUP_CLAIM = "groups";
          ENABLE_OAUTH_GROUP_MANAGEMENT = "True";
          ENABLE_OAUTH_GROUP_CREATION = "True";
          OAUTH_ALLOWED_ROLES = "compute,compute-manager";
          OAUTH_ADMIN_ROLES = "compute-manager";
          OAUTH_ALLOWED_DOMAINS = "jm0.io";

          # Cloud Storage: https://docs.openwebui.com/getting-started/env-configuration/#cloud-storage
          # STORAGE_PROVIDER = "s3";
          # S3_BUCKET_NAME = "ollama";
          # S3_ENDPOINT_URL = "";
          # S3_REGION_NAME = "";
        };
        environmentFile = config.sops.templates."open-webui.env".path;
      };
  }
  (
    let
      service = mk-traefik-service {
        inherit hostname datacenter;
        name = "open-webui";
        subdomain = "chat";
        port = config.services.open-webui.port;
      };
      healthcheck = mk-healthcheck service {
        route = "/health";
      };
      authentik-tags = mk-authentik service {
        name = "Open WebUI";
        icon = "open-webui";
        group = "Compute";
        type = "oauth";
        access = [
          "compute"
          "compute-managers"
        ];
      };
    in
    with-consul config (
      service
      // {
        checks = [ healthcheck ];
        tags = authentik-tags;
        address = config.services.open-webui.host;
      }
    )
  )
]
