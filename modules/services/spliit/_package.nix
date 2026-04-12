{
  lib,
  buildNpmPackage,
  fetchFromGitHub,
  nodejs,
  makeWrapper,
  openssl,
  prisma-engines,
  ...
}:

buildNpmPackage (finalAttrs: {
  pname = "spliit";
  version = "1.19.1";

  src = fetchFromGitHub {
    owner = "spliit-app";
    repo = "spliit";
    rev = finalAttrs.version;
    hash = "sha256-a2xz91g2tCkW+Si5mN2VQ29BE1PXHg4BBNdYt/gnIUs=";
  };

  npmDepsHash = "sha256-XBaFjoJpB6jE97G4hADdHRyywUn8gcgY0fb3DpV3NsE=";

  nativeBuildInputs = [
    makeWrapper
    openssl
  ];

  # Prisma requires the engines at build time
  env = {
    PRISMA_QUERY_ENGINE_LIBRARY = "${prisma-engines}/lib/libquery_engine.node";
    PRISMA_QUERY_ENGINE_BINARY = "${prisma-engines}/bin/query-engine";
    PRISMA_SCHEMA_ENGINE_BINARY = "${prisma-engines}/bin/schema-engine";
  };

  # Skip the postinstall script during npm ci (prisma generate runs at build time)
  npmFlags = [ "--ignore-scripts" ];

  # Patch next.config.mjs to enable standalone output
  postPatch = ''
    substituteInPlace next.config.mjs \
      --replace-fail \
        "const nextConfig = {" \
        "const nextConfig = { output: 'standalone',"
  '';

  # Build needs mock env vars for Next.js static generation
  preBuild = ''
    # Generate Prisma client
    npx prisma generate

    # Next.js needs these at build time (they get baked into static assets)
    export POSTGRES_PRISMA_URL="postgresql://localhost/spliit"
    export POSTGRES_URL_NON_POOLING="postgresql://localhost/spliit"
    export NEXT_TELEMETRY_DISABLED=1
  '';

  postInstall = ''
    mkdir -p $out/share/spliit

    # Copy the built Next.js standalone app
    cp -r .next/standalone/* $out/share/spliit/
    cp -r .next/static $out/share/spliit/.next/static
    cp -r public $out/share/spliit/public

    # Copy prisma schema and migrations for runtime
    cp -r prisma $out/share/spliit/prisma

    # Create wrapper script
    makeWrapper ${nodejs}/bin/node $out/bin/spliit \
      --add-flags "$out/share/spliit/server.js" \
      --set NODE_ENV production \
      --set PRISMA_QUERY_ENGINE_LIBRARY "${prisma-engines}/lib/libquery_engine.node" \
      --set PRISMA_QUERY_ENGINE_BINARY "${prisma-engines}/bin/query-engine" \
      --set PRISMA_SCHEMA_ENGINE_BINARY "${prisma-engines}/bin/schema-engine" \
      --prefix PATH : ${lib.makeBinPath [ prisma-engines ]}

    # Create migration script
    makeWrapper ${nodejs}/bin/npx $out/bin/spliit-migrate \
      --add-flags "prisma migrate deploy" \
      --chdir "$out/share/spliit" \
      --set PRISMA_QUERY_ENGINE_LIBRARY "${prisma-engines}/lib/libquery_engine.node" \
      --set PRISMA_SCHEMA_ENGINE_BINARY "${prisma-engines}/bin/schema-engine" \
      --prefix PATH : ${lib.makeBinPath [ prisma-engines ]}
  '';

  meta = {
    description = "Free and open-source expense sharing app";
    homepage = "https://spliit.app/";
    changelog = "https://github.com/spliit-app/spliit/releases/tag/${finalAttrs.version}";
    license = lib.licenses.agpl3Only;
    maintainers = [ ];
    mainProgram = "spliit";
    platforms = lib.platforms.linux;
  };
})
