{
  lib,
  stdenv,
  fetchFromGitHub,
  fetchPnpmDeps,
  pnpmConfigHook,
  pnpm,
  nodejs,
  makeWrapper,
  postgresql,
  openssl,
  rsync,
  poppins,
  # split-pro requires Prisma v6, rather than v7. In `nixos-unstable`, `prisma-engines_{6,7}` exists.
  prisma_6,
  prisma-engines_6,
  bash,
  ...
}:

stdenv.mkDerivation (finalAttrs: {
  pname = "split-pro";
  version = "2.0.0-beta.9";

  src = fetchFromGitHub {
    owner = "oss-apps";
    repo = "split-pro";
    rev = "v${finalAttrs.version}";
    hash = "sha256-ayBjNUFshznxK/uODl7KbSrD473avZZJRA2TmiSpAbo=";
  };

  pnpmDeps = fetchPnpmDeps {
    inherit (finalAttrs) pname version src;
    inherit pnpm;
    fetcherVersion = 2;
    hash = "sha256-UOegwvDH+e4Qe9vAbRiFyarl7ob91GzTkSyOD5aNCh8=";
  };

  nativeBuildInputs = [
    nodejs
    pnpm
    pnpmConfigHook
    makeWrapper
    openssl
    rsync
  ];

  patches = [
    # Use local Poppins font instead of Google Fonts
    ./local-poppins-font.patch
  ];

  # Copy Poppins fonts to public directory for local loading
  postPatch = ''
    mkdir -p public/fonts
    rsync -a ${poppins}/share/fonts/truetype/ public/fonts/
  '';

  # Prisma requires the engines at build time
  env = {
    PRISMA_QUERY_ENGINE_LIBRARY = "${prisma-engines_6}/lib/libquery_engine.node";
    PRISMA_QUERY_ENGINE_BINARY = "${prisma-engines_6}/bin/query-engine";
    PRISMA_SCHEMA_ENGINE_BINARY = "${prisma-engines_6}/bin/schema-engine";
    # Required for Next.js standalone build
    DOCKER_OUTPUT = "1";
    SKIP_ENV_VALIDATION = "true";
    NEXT_TELEMETRY_DISABLED = "1";
  };

  buildPhase = ''
    runHook preBuild

    # Generate Prisma client
    pnpm prisma generate

    # Build Next.js app
    pnpm build

    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall

    # Copy the built Next.js standalone app
    mkdir -p $out/share/split-pro
    rsync -a .next/standalone/ $out/share/split-pro/
    rsync -aR ./.next/static/ $out/share/split-pro/
    rsync -aR ./public/ $out/share/split-pro/
    rsync -aR ./prisma/ $out/share/split-pro/

    # Create wrapper script
    makeWrapper ${lib.getExe nodejs} $out/bin/sp-server \
      --add-flags "$out/share/split-pro/server.js" \
      --set NODE_ENV production \
      --set PRISMA_QUERY_ENGINE_LIBRARY "${prisma-engines_6}/lib/libquery_engine.node" \
      --set PRISMA_QUERY_ENGINE_BINARY "${prisma-engines_6}/bin/query-engine" \
      --set PRISMA_SCHEMA_ENGINE_BINARY "${prisma-engines_6}/bin/schema-engine" \
      --prefix PATH : ${lib.makeBinPath [ prisma-engines_6 ]}

    # Create migration script - call prisma directly instead of via pnpm
    # (pnpm tries to self-manage versions which fails in read-only/sandboxed environments)
    makeWrapper ${lib.getExe prisma_6} $out/bin/sp-migrate \
      --add-flags "migrate" \
      --add-flags "deploy" \
      --chdir "$out/share/split-pro" \
      --set PRISMA_QUERY_ENGINE_LIBRARY "${prisma-engines_6}/lib/libquery_engine.node" \
      --set PRISMA_SCHEMA_ENGINE_BINARY "${prisma-engines_6}/bin/schema-engine" \
      --prefix PATH : ${
        lib.makeBinPath [
          nodejs
          prisma-engines_6
        ]
      }

    # Create database setup script (must be run as postgres superuser)
    # This handles pg_cron extension, permissions, and failed migration recovery
    cat > $out/bin/sp-db-setup << 'SCRIPT'
    #!${lib.getExe bash}
    set -euo pipefail

    DB_NAME="''${1:-split-pro}"
    DB_USER="''${2:-split-pro}"

    PSQL="${postgresql}/bin/psql"
    PRISMA="${lib.getExe prisma_6}"

    echo "Setting up database: $DB_NAME for user: $DB_USER"

    # Create pg_cron extension (requires superuser)
    $PSQL -d "$DB_NAME" -c "CREATE EXTENSION IF NOT EXISTS pg_cron;"

    # Create _prisma_migrations table owned by app user
    # This prevents Prisma from seeing cron schema as "non-empty database"
    $PSQL -d "$DB_NAME" <<EOF
    CREATE TABLE IF NOT EXISTS _prisma_migrations (
      id VARCHAR(36) PRIMARY KEY,
      checksum VARCHAR(64) NOT NULL,
      finished_at TIMESTAMPTZ,
      migration_name VARCHAR(255) NOT NULL,
      logs TEXT,
      rolled_back_at TIMESTAMPTZ,
      started_at TIMESTAMPTZ NOT NULL DEFAULT now(),
      applied_steps_count INTEGER NOT NULL DEFAULT 0
    );
    ALTER TABLE IF EXISTS _prisma_migrations OWNER TO "$DB_USER";

    -- Grant access to cron schema for foreign key references
    GRANT USAGE ON SCHEMA cron TO "$DB_USER";
    GRANT SELECT, REFERENCES ON ALL TABLES IN SCHEMA cron TO "$DB_USER";
    EOF

    # Mark any failed migrations as rolled back so they can be retried
    failed_migrations=$($PSQL -d "$DB_NAME" -t -A -c \
      "SELECT migration_name FROM _prisma_migrations WHERE finished_at IS NULL AND rolled_back_at IS NULL;")

    for migration in $failed_migrations; do
      echo "Marking failed migration as rolled back: $migration"
      cd $out/share/split-pro
      DATABASE_URL="postgresql://$DB_USER@localhost/$DB_NAME" \
        PRISMA_QUERY_ENGINE_LIBRARY="${prisma-engines_6}/lib/libquery_engine.node" \
        PRISMA_SCHEMA_ENGINE_BINARY="${prisma-engines_6}/bin/schema-engine" \
        $PRISMA migrate resolve --rolled-back "$migration"
    done

    echo "Database setup complete"
    SCRIPT
    chmod +x $out/bin/sp-db-setup

    runHook postInstall
  '';

  meta = {
    description = "Self-hosted expense sharing and splitting app with user accounts";
    homepage = "https://splitpro.app/";
    changelog = "https://github.com/oss-apps/split-pro/releases/tag/v${finalAttrs.version}";
    license = lib.licenses.agpl3Only;
    maintainers = [ ];
    mainProgram = "sp-server";
    platforms = lib.platforms.linux;
  };
})
