{ __findFile, ... }:
{
  rbn.programs._.development._.toolchains._.tauri = {
    includes = [
      <rbn/programs/development/languages/rust>
      <rbn/programs/development/languages/typescript>
    ];

    hm = _: {
      mcp-servers.settings.servers = {
        tauri = {
          command = "pnpx";
          args = [
            "-y"
            "@hypothesi/tauri-mcp-server"
          ];
        };
      };
    };
  };
}
