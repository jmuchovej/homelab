{
  __findFile,
  den,
  inputs,
  lib,
  rbn-policies,
  ...
}:
let
  inherit (rbn-policies) when-desktop;
  profile = {
    fullname = "John Muchovej";
    username = "john";
    email = "git@jmuchovej.com";
  };

  read-key = name: lib.trim (builtins.readFile (./. + "/${name}.pub"));
  mk-forge = host: forge: forge // { signing-key = read-key host; };
  ## Forge identities, keyed by the directory under `~/Documents/src`. The
  ## signing key is read from `<key>.pub` beside this file, so adding a forge
  ## means dropping in one more public key — the name cannot drift.
  forges = lib.mapAttrs mk-forge {
    "github.com" = {
      host = "github.com";
      short = "github";
      email = "5000729+jmuchovej@users.noreply.github.com";
    };
    "gitlab.com" = {
      host = "gitlab.com";
      short = "gitlab";
      email = "880641-jmuchovej@users.noreply.gitlab.com";
    };
    "sr.ht" = {
      host = "git.sr.ht";
      short = "sr.ht";
      email = "sr.ht.b4i3k@passmail.com";
    };
    "tangled.org" = {
      host = "tangled.org";
      short = "tangled";
      email = "did:plc:wjsziyvr5xuqyzykxp7eydg7";
    };
    "git.yale.edu" = {
      host = "git.yale.edu";
      short = "yale";
      email = "john.muchovej@yale.edu";
    };
    "github.mit.edu" = {
      host = "github.mit.edu";
      short = "mit";
      email = "muchovej@mit.edu";
    };
  };
in
{
  den.homes = {
    aarch64-linux.john.includes = [ den.aspects.john ];

    x86_64-linux.john.includes = [ den.aspects.john ];
    x86_64-linux.jpm268.includes = [
      den.aspects.john
      {
        name = "jpm268/sops-as-john";
        hm = { lib, ... }: {
          sops.defaultSopsFile = lib.mkForce "${inputs.self}/secrets/users/john.sops.yaml";
        };
      }
    ];
  };

  den.aspects.john = _: {
    includes =
      with den.batteries;
      with den.aspects;
      [
        define-user
        (user-shell "zsh")

        primary-user
        tools.nix-trusted-user
        <rbn/system/dock>
        <rbn/system/homebrew>
        <rbn/system/interface>

        <rbn/suite/common>
        <rbn/suite/development>

        <rbn/programs/terminal/bacon>
        <rbn/programs/terminal/topgrade>

        # Shells
        <rbn/shells/nushell>

        # Editors
        <rbn/programs/editors/helix>
        <rbn/programs/editors/micro>
        <rbn/programs/security/proton>
        (<rbn/programs/editors/default-editor> "nvim")

        # Development
        <rbn/programs/development/data/csv>
        <rbn/programs/development/data/json>
        <rbn/programs/development/data/xml>
        <rbn/programs/development/data/yaml>
        <rbn/programs/development/languages/go>
        <rbn/programs/development/languages/python>
        <rbn/programs/development/languages/typescript>
        <rbn/programs/development/languages/markdown>
        <rbn/programs/development/languages/nix>
        <rbn/programs/development/languages/rust>
        <rbn/programs/development/languages/julia>
        <rbn/programs/development/languages/lua>
        <rbn/programs/development/languages/typst>
        <rbn/programs/development/languages/rlang>
        <rbn/programs/development/toolchains/astro>
        <rbn/programs/development/toolchains/nuxt>
        <rbn/programs/development/toolchains/tauri>
        <rbn/programs/development/toolchains/android>
        <rbn/programs/development/toolchains/apple>
        <rbn/programs/development/languages/opentofu>

        (when-desktop "waypoints" <rbn/programs/documents/waypoints>)

        <rbn/services/ssh-agent>
        <rbn/programs/ai-tools>
        <rbn/programs/ai-tools/gemini>
        <rbn/programs/ai-tools/claude>
        <rbn/programs/ai-tools/mcp>
      ];

    hm = _: {
      programs.ssh.settings = {
        "Host git*" = {
          IdentitiesOnly = true;
          IdentityFile = "~/.ssh/1p-%h.pub";
        };
      };
    };

    provides.da-n1x = {
      includes = [
        <rbn/programs/editors/zed>

        <rbn/programs/browsers/brave>
        <rbn/programs/media/spotify>

        <rbn/programs/social/beeper>

        <rbn/programs/emulators/ghostty>
        <rbn/programs/emulators/wezterm>

        <rbn/programs/databases/beekeeper>
        <rbn/programs/databases/dbeaver>

        <rbn/programs/desktop/superwhisper>
        <rbn/programs/desktop/utils/raycast>

        <rbn/programs/terminal/k9s>
        <rbn/programs/development/containers/orbstack>

        <rbn/programs/creative/3d-modeling>
        <rbn/programs/creative/design>
        <rbn/programs/documents/obsidian>
        <rbn/programs/documents/logseq>
        <rbn/programs/documents/appflowy>
        <rbn/programs/documents/notion>
        <rbn/programs/documents/anytype>
        <rbn/programs/social/zoom>
        <rbn/programs/social/zulip>
        <rbn/programs/media/ferium>
        <rbn/programs/desktop/openconnect>
        <rbn/programs/desktop/setapp>
        <rbn/programs/toolchains/api/bruno>
        <rbn/programs/toolchains/api/postman>

        <rbn/programs/desktop/utils/alt-tab>
        <rbn/programs/desktop/utils/appcleaner>
        <rbn/programs/desktop/utils/bartender>
        <rbn/programs/desktop/utils/blueutil>
        <rbn/programs/desktop/utils/monitorcontrol>
        <rbn/programs/desktop/utils/switchaudio>
        <rbn/programs/desktop/utils/stats>
      ];
    };
  };

  # den.hosts.x86_64-linux.da-vcx-1.users.john = { };
  # den.hosts.x86_64-linux.da-vcx-2.users.john = { };
  # den.hosts.x86_64-linux.da-vcx-3.users.john = { };
  den.hosts.aarch64-darwin.da-n1x.users.john = {
    inherit (profile) fullname username email;
    inherit forges;

    dock = {
      system.order = 100;
      system.apps = [
        "System Settings"
        "Activity Monitor"
        "1Password"
      ];
      communication.order = 200;
      communication.apps = [
        "Messages"
        "Beeper Desktop"
      ];
      media.order = 250;
      media.apps = [ "Spotify" ];
      browsers.order = 300;
      browsers.apps = [
        "Brave Browser"
        # "Firefox Developer Edition"
        "Safari"
      ];
      pkm.order = 400;
      pkm.apps = [
        "Obsidian"
        "Notion"
        "Notion Calendar"
        "Logseq"
        "AppFlowy"
      ];
      development.order = 500;
      development.apps = [
        "Claude"
        {
        }
        "Zed"
        "Delta"
        "Ghostty"
      ];
    };
  };

  # den.hosts.x86_64-linux.en-t65-1.users.john = { };
}
