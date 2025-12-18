{ lib, pkgs, ... }@args:
lib.rebellion.mk-desktop-module args {
  name = "desktop.wezterm";
  config =
    { lib, pkgs, ... }:
    let
      inherit (lib.rebellion) get-file;
      inherit (pkgs.stdenv) isLinux;

      catppuccin = import (get-file "modules/home/theme/catppuccin/colors.part.nix");
    in
    {
      programs.wezterm = {
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

            -- This function returns the suggested title for a tab.
            -- It prefers the title that was set via `tab:set_title()`
            -- or `wezterm cli set-tab-title`, but falls back to the
            -- title of the active pane in that tab.
            function tab_title(tab_info)
              local title = tab_info.tab_title
              -- if the tab title is explicitly set, take that
              if title and #title > 0 then
                return title
              end
              -- Otherwise, use the title from the active pane
              -- in that tab
              return tab_info.active_pane.title
            end

            -- wezterm.on(
            --   "format-tab-title",
            --   function(tab, tabs, panes, config, hover, max_width)
            --     local edge_background = "${catppuccin.colors.mantle.hex}"
            --     local background = "${catppuccin.colors.base.hex}"
            --     local foreground = "${catppuccin.colors.text.hex}"

            --     if tab.is_active then
            --       background = "${catppuccin.colors.blue.hex}"
            --       foreground = "${catppuccin.colors.crust.hex}"
            --     elseif hover then
            --       background = "${catppuccin.colors.mauve.hex}"
            --       foreground = "${catppuccin.colors.crust.hex}"
            --     end

            --     local edge_foreground = background

            --     local title = tab_title(tab)

            --     -- ensure that the titles fit in the available space,
            --     -- and that we have room for the edges.
            --     title = wezterm.truncate_right(title, max_width - 2)

            --     return {
            --       { Background = { Color = edge_background } },
            --       { Foreground = { Color = edge_foreground } },
            --       { Text = SOLID_LEFT_ARROW },
            --       { Background = { Color = background } },
            --       { Foreground = { Color = foreground } },
            --       { Text = title },
            --       { Background = { Color = edge_background } },
            --       { Foreground = { Color = edge_foreground } },
            --       { Text = SOLID_RIGHT_ARROW },
            --     }
            --   end
            -- )

            return {
              -- general
              audible_bell = "Disabled",
              check_for_updates = false,
              enable_scroll_bar = false,
              exit_behavior = "CloseOnCleanExit",
              warn_about_missing_glyphs =  false,
              term = "xterm-256color",

              -- anims
              animation_fps = 1,

              -- Color scheme
              color_schemes = {
                ["Catppuccin"] = custom,
              },
              color_scheme = "Catppuccin",

              -- Cursor
              cursor_blink_ease_in = "Constant",
              cursor_blink_ease_out = "Constant",
              cursor_blink_rate = 700,
              default_cursor_style = "SteadyBar",

              -- font
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
                -- paste from the clipboard
                { key = "V", mods = "SHIFT|CTRL", action = act.PasteFrom "Clipboard" },

                -- paste from the primary selection
                { key = "S", mods = "SHIFT|CTRL", action = act.PasteFrom "PrimarySelection" },
              },

              -- Tab bar
              enable_tab_bar = true,
              show_tab_index_in_tab_bar = true,
              use_fancy_tab_bar = true,
              -- try and let the tabs stretch instead of squish
              tab_max_width = 10000,

              -- perf
              enable_wayland = ${lib.boolToString isLinux},
              front_end = "WebGpu",
              scrollback_lines = 10000,

              -- term window settings
              adjust_window_size_when_changing_font_size = false,
              inactive_pane_hsb = {
                saturation = 1.0,
                brightness = 0.8
              },
              window_background_opacity = 0.85,
              window_close_confirmation = "NeverPrompt",
              window_decorations = "RESIZE",
              window_padding = { left = 12, right = 12, top = 12, bottom = 12, },
            }
          '';
      };
    };
}
