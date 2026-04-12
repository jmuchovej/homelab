_: {
  rbn.programs._.emulators._.wezterm = {
    darwin =
      { host, lib, ... }:
      lib.mkIf host.homebrew.enable {
        homebrew.casks = [ "wezterm" ];
      };

    homeManager =
      { lib, pkgs, ... }:
      let
        inherit (pkgs.stdenv) isLinux;
      in
      {
        rebellion.dock.entries = [
          {
            name = "WezTerm.app";
            source = "applications";
            group = "terminals";
            order = 610;
          }
        ];

        programs.wezterm = lib.mkIf isLinux {
          enable = true;
          package = pkgs.wezterm;
          enableBashIntegration = true;
          enableZshIntegration = true;

          extraConfig =
            # lua
            ''
              function scheme_for_appearance(appearance)
                if appearance:find "Dark" then
                  return "Catppuccin Frappé (Gogh)"
                else
                  return "Catppuccin Latte (Gogh)"
                end
              end

              local act = wezterm.action
              local custom = wezterm.color.get_builtin_schemes()[scheme_for_appearance(wezterm.gui.get_appearance())]
              local SOLID_LEFT_ARROW = wezterm.nerdfonts.pl_right_hard_divider
              local SOLID_RIGHT_ARROW = wezterm.nerdfonts.pl_left_hard_divider

              function tab_title(tab_info)
                local title = tab_info.tab_title
                if title and #title > 0 then
                  return title
                end
                return tab_info.active_pane.title
              end

              return {
                audible_bell = "Disabled",
                check_for_updates = false,
                enable_scroll_bar = false,
                exit_behavior = "CloseOnCleanExit",
                warn_about_missing_glyphs = false,
                term = "xterm-256color",
                animation_fps = 1,

                color_schemes = { ["Catppuccin"] = custom },
                color_scheme = "Catppuccin",

                cursor_blink_ease_in = "Constant",
                cursor_blink_ease_out = "Constant",
                cursor_blink_rate = 700,
                default_cursor_style = "SteadyBar",

                font_size = 13.0,
                font = wezterm.font_with_fallback {
                  {
                    family = "MonaspiceKr Nerd Font",
                    weight = "Regular",
                    harfbuzz_features = {
                      "calt=1",
                      "ss01=1", "ss02=1", "ss03=1",
                      "ss04=1", "ss05=1", "ss06=1",
                      "ss07=1", "ss08=1", "ss09=1",
                      "liga=1"
                    },
                  },
                  { family = "CaskaydiaCove Nerd Font", weight = "Regular" },
                  { family = "Symbols Nerd Font", weight = "Regular" },
                  { family = "Noto Color Emoji", weight = "Regular" },
                },

                keys = {
                  { key = "V", mods = "SHIFT|CTRL", action = act.PasteFrom "Clipboard" },
                  { key = "S", mods = "SHIFT|CTRL", action = act.PasteFrom "PrimarySelection" },
                },

                enable_tab_bar = true,
                show_tab_index_in_tab_bar = true,
                use_fancy_tab_bar = true,
                tab_max_width = 10000,

                enable_wayland = ${lib.boolToString isLinux},
                front_end = "WebGpu",
                scrollback_lines = 10000,

                adjust_window_size_when_changing_font_size = false,
                inactive_pane_hsb = { saturation = 1.0, brightness = 0.8 },
                window_background_opacity = 0.85,
                window_close_confirmation = "NeverPrompt",
                window_decorations = "RESIZE",
                window_padding = { left = 12, right = 12, top = 12, bottom = 12 },
              }
            '';
        };
      };
  };
}
