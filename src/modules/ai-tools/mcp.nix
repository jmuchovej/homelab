{ inputs, ... }: {
  flake-file.inputs.mcp-servers.url = "github:natsukium/mcp-servers-nix";

  den.default.homeManager.imports = [
    inputs.mcp-servers.homeManagerModules.default
  ];

  rbn.programs._.ai-tools._.mcp = {
    hm = { lib, pkgs, ... }: {
      programs.mcp.enable = true;
      mcp-servers.settings.servers = {
        devenv = {
          type = "stdio";
          command = lib.getExe pkgs.devenv;
          args = [ "mcp" ];
        };
      };

      programs.claude-code.enableMcpIntegration = true;
      programs.antigravity-cli.enableMcpIntegration = true;
      programs.opencode.enableMcpIntegration = true;
      programs.codex.enableMcpIntegration = true;
    };

    _.sequential-thinking.hm = _: {
      mcp-servers.programs.sequential-thinking.enable = true;
    };

    _.filesystem.__functor =
      _self:
      {
        directories ? [ ],
      }:
      {
        hm = { config, lib, ... }: {
          mcp-servers.programs.filesystem = {
            enable = true;
            args = lib.mkDefault ([ config.home.homeDirectory ] ++ directories);
          };
        };
      };
  };

}
