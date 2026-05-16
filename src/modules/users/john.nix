{
  __findFile,
  lib,
  den,
  ...
}:
{
  # ── Dock placement for john's programs ──────────────────────────────
  # Each sets dock.{group,order} on the aspect. The dock builder walks rbn.*
  # to find aspects with dock.group set and reads meta.dock.app for the name.
  rbn.programs._.ai-tools._.claude.provides.desktop.dock = {
    group = "development";
    order = 100;
  };
  rbn.programs._.social.provides.beeper.dock = {
    group = "communication";
    order = 220;
  };
  rbn.programs._.media.provides.spotify.dock = {
    group = "media";
    order = 230;
  };
  rbn.programs._.browsers._.brave.dock = {
    group = "browsers";
    order = 310;
  };
  rbn.programs._.browsers._.firefox.dock = {
    group = "browsers";
    order = 320;
  };
  rbn.programs._.documents._.obsidian.dock = {
    group = "pkm";
    order = 410;
  };
  rbn.programs._.documents._.notion.dock = {
    group = "pkm";
    order = 420;
  };
  rbn.programs._.documents._.logseq.dock = {
    group = "pkm";
    order = 440;
  };
  rbn.programs._.documents._.appflowy.dock = {
    group = "pkm";
    order = 450;
  };
  rbn.programs._.editors._.zed.dock = {
    group = "editors";
    order = 510;
  };
  rbn.programs._.toolchains._.api.provides.bruno.dock = {
    group = "editors";
    order = 520;
  };
  rbn.programs._.emulators._.wezterm.dock = {
    group = "terminals";
    order = 610;
  };
  rbn.programs._.emulators._.ghostty.dock = {
    group = "terminals";
    order = 620;
  };

  den.aspects.john = {
    includes = [
      <den/primary-user>
      (den.batteries.user-shell "zsh")

      <rbn/suite/common>

      <rbn/programs/vcs/gh>
      <rbn/programs/terminal/bacon>
      <rbn/programs/terminal/topgrade>
      <rbn/programs/terminal/k9s>
      <rbn/programs/vcs/lazygit>
      <rbn/programs/terminal/zellij>
      <rbn/programs/toolchains/development>
      <rbn/programs/ai-tools/gemini>
      <rbn/programs/ai-tools/claude/code>
      <rbn/programs/ai-tools/mcp>

      # Shells
      <rbn/shells/nushell>

      # Editors
      <rbn/programs/editors/helix>
      <rbn/programs/editors/micro>

      # Development
      <rbn/programs/development/go>
      <rbn/programs/development/python>
      <rbn/programs/development/web>
      <rbn/programs/development/nix>
      <rbn/programs/development/rust>
      <rbn/programs/development/julia>
      <rbn/programs/development/typst>
      <rbn/programs/development/rlang>
      <rbn/programs/development/apps>
      <rbn/programs/development/homelab>

      # Services
      <rbn/services/syncthing>

      # Desktop (only on hosts with desktop = true)
      (
        { host, ... }:
        lib.optionalAttrs (host.desktop or false) {
          includes = [
            <rbn/programs/ai-tools/claude/desktop>
            # (<rbn/programs/ai-tools/mcp/filesystem> {
            #   directions = [ "${user.home.homeDirectory}/Syncthing" ];
            # })
            <rbn/programs/browsers/brave>
            <rbn/programs/media/spotify>
            <rbn/programs/documents/obsidian>
            <rbn/programs/documents/logseq>
            <rbn/programs/documents/appflowy>
            <rbn/programs/documents/notion>
            <rbn/programs/documents/anytype>
            <rbn/programs/social/beeper>
            <rbn/programs/social/zoom>
            <rbn/programs/social/zulip>
            <rbn/programs/browsers/arc>
            <rbn/programs/media/ferium>
            <rbn/programs/desktop/openconnect>
            <rbn/programs/desktop/setapp>
            <rbn/programs/documents/waypoints>
            <rbn/programs/emulators/alacritty>
            <rbn/programs/emulators/ghostty>
            <rbn/programs/emulators/kitty>
            <rbn/programs/emulators/rio>
            <rbn/programs/emulators/wezterm>
            <rbn/services/ssh-agent>
            <rbn/programs/editors/zed>
            <rbn/programs/toolchains/api/bruno>
            <rbn/programs/toolchains/api/postman>
            <rbn/programs/databases/beekeeper>
            <rbn/programs/databases/dbeaver>

            # macOS desktop utilities
            <rbn/programs/desktop/utils/alt-tab>
            <rbn/programs/desktop/utils/appcleaner>
            <rbn/programs/desktop/utils/bartender>
            <rbn/programs/desktop/utils/blueutil>
            <rbn/programs/desktop/utils/monitorcontrol>
            <rbn/programs/desktop/utils/raycast>
            <rbn/programs/desktop/utils/switchaudio>
            <rbn/programs/desktop/utils/stats>
          ];
        }
      )
    ];

    homeManager = {
      programs.ssh.settings = {
        "Host git*" = {
          IdentitiesOnly = true;
          IdentityFile = "~/.ssh/1p-%h.pub";
        };
      };

    };

    nixos.users.users.john = { };
  };

  # den.hosts.x86_64-linux.da-vcx-1.users.john = { };
  # den.hosts.x86_64-linux.da-vcx-2.users.john = { };
  # den.hosts.x86_64-linux.da-vcx-3.users.john = { };
  den.hosts.aarch64-darwin.da-n1x = {
    desktop = true;
    users.john = {
      # Dock layout — explicit entries for now.
      # When den's fx pipeline releases, aspect-backed entries will auto-resolve
      # from dock.{app,group,order} set on rbn.* aspects. See memory/dock-class-design.md.
      dock = [
        {
          name = "Claude.app";
          source = "applications";
          group = "development";
          order = 100;
        }
        {
          name = "System Settings.app";
          source = "system";
          group = "system";
          order = 110;
        }
        {
          path = "/System/Applications/Utilities/Activity Monitor.app";
          group = "system";
          order = 120;
        }
        {
          name = "Messages.app";
          source = "system";
          group = "communication";
          order = 210;
        }
        {
          name = "Beeper Desktop.app";
          source = "applications";
          group = "communication";
          order = 220;
        }
        {
          name = "Spotify.app";
          source = "applications";
          group = "media";
          order = 230;
        }
        {
          name = "Things3.app";
          source = "applications";
          group = "communication";
          order = 240;
        }
        {
          name = "Brave Browser.app";
          source = "applications";
          group = "browsers";
          order = 310;
        }
        {
          name = "Firefox Developer Edition.app";
          source = "applications";
          group = "browsers";
          order = 320;
        }
        {
          name = "Safari.app";
          source = "applications";
          group = "browsers";
          order = 330;
        }
        {
          name = "Obsidian.app";
          source = "applications";
          group = "pkm";
          order = 410;
        }
        {
          name = "Notion.app";
          source = "applications";
          group = "pkm";
          order = 420;
        }
        {
          name = "Notion Calendar.app";
          source = "applications";
          group = "pkm";
          order = 430;
        }
        {
          name = "Logseq.app";
          source = "applications";
          group = "pkm";
          order = 440;
        }
        {
          name = "AppFlowy.app";
          source = "applications";
          group = "pkm";
          order = 450;
        }
        {
          name = "Zed.app";
          source = "hm";
          group = "editors";
          order = 510;
        }
        {
          name = "Bruno.app";
          source = "hm";
          group = "editors";
          order = 520;
        }
        {
          name = "WezTerm.app";
          source = "applications";
          group = "terminals";
          order = 610;
        }
        {
          name = "Ghostty.app";
          source = "applications";
          group = "terminals";
          order = 620;
        }
      ];
    };
  };

  # den.hosts.x86_64-linux.en-t65-1.users.john = { };
}
