{ inputs, ... }:
{
  flake-file.inputs.mcp-servers.url = "github:natsukium/mcp-servers-nix";

  den.default.homeManager.imports = [
    inputs.mcp-servers.homeManagerModules.default
  ];

  rbn.programs._.ai-tools._.mcp = {
    homeManager =
      { lib, pkgs, ... }:
      {
        programs.mcp.enable = true;
        mcp-servers.settings.servers = {
          devenv = {
            type = "stdio";
            command = lib.getExe pkgs.devenv;
            args = [ "mcp" ];
          };
        };
      };

    provides.sequential-thinking.homeManager = {
      mcp-servers.programs.sequential-thinking.enable = true;
    };

    provides.filesystem = {
      __functor =
        _self:
        {
          directories ? [ ],
        }:
        {
          homeManager =
            {
              config,
              lib,
              ...
            }:
            {
              mcp-servers.programs.filesystem = {
                enable = true;
                args = lib.mkDefault ([ config.home.homeDirectory ] ++ directories);
              };
            };
        };
    };
  };

}
