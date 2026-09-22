{
  rbn.programs._.terminal._.github.hm = _: {
    programs.gh = {
      enable = true;
      settings = {
        protocol = "ssh";
        prompt = "enabled";
        aliases = { };
      };
    };

    programs.gh-dash.enable = true;

    mcp-servers.programs.github = {
      enable = true;
      passwordCommand = {
        GITHUB_PERSONAL_ACCESS_TOKEN = [
          "gh"
          "auth"
          "token"
        ];
      };
    };
  };
}
