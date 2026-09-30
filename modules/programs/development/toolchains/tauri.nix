{ __findFile, ... }:
{
  rbn.programs._.development._.toolchains._.tauri = {
    includes = [
      <rbn/programs/development/languages/rust>
      <rbn/programs/development/languages/typescript>
    ];

    hm = { lib, ... }: {
      mcp-servers.settings.servers = {
        tauri = {
          command = "pnpx";
          args = lib.rbn.argv "-y @hypothesi/tauri-mcp-server";
        };
      };
    };
  };
}
