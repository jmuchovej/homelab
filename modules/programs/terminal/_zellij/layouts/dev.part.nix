{
  config.programs.zellij.layouts.dev.layout._children =
    let
      tab = props: children: {
        tab._props = props;
        tab._children = children;
      };
      pane = args: {
        pane = args;
      };

      # statusbar = import ./statusbar.part.nix { inherit pkgs; }
    in
    [
      {
        default_tab_template._children = [
          (pane {
            size = 1;
            borderless = true;
            plugin.location = "zellij:tab-bar";
          })
          { "children" = { }; }
          (pane {
            size = 2;
            borderless = true;
            plugin.location = "zellij:status-bar";
          })
        ];
      }
      (tab {
        name = "Project";
        focus = true;
      } [ (pane { ommand = "nvim"; }) ])
      (tab { name = "Jujutsu"; } [ (pane { command = "jjui"; }) ])
    ];
}
