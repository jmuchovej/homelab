_: {
  rbn.programs._.ai-tools._.paseo = {
    dock.key = "Paseo";
    dock.source = "brew";

    # `llm-agents` doesn't mark it as supported on macOS 🥲
    hm-linux = { pkgs, ... }: {
      home.packages = [ pkgs.llm-agents.paseo-desktop ];
    };

    macos = _: {
      homebrew.casks = [ "paseo" ];
    };
  };
}
