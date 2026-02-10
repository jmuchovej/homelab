{ lib, pkgs, ... }@args:
lib.rebellion.mk-desktop-module args {
  name = "desktop.firefox";
  options =
    { config, pkgs, ... }:
    with lib.types;
    let
      default-extensions = with config.nur.repos.rycee.firefox-addons; [
        # angular-devtools
        # auto-tab-discard
        # bitwarden
        # # NOTE: annoying new page and permissions
        # # bypass-paywalls-clean
        # darkreader
        # firefox-color
        # firenvim
        onepassword-password-manager
        # react-devtools
        # reduxdevtools
        # sidebery
        # sponsorblock
        # stylus
        ublock-origin
        # user-agent-string-switcher
      ];

      default-policies = {
        CaptivePortal = false;
        DisableFirefoxStudies = true;
        DisableFormHistory = true;
        DisablePocket = true;
        DisableTelemetry = true;
        DisplayBookmarksToolbar = true;
        DontCheckDefaultBrowser = true;
        FirefoxHome = {
          Pocket = false;
          Snippets = false;
        };
        PasswordManagerEnabled = false;
        # PromptForDownloadLocation = true;
        UserMessaging = {
          ExtensionRecommendations = false;
          SkipOnboarding = true;
        };
        ExtensionSettings = {
          "ebay@search.mozilla.org".installation_mode = "blocked";
          "amazondotcom@search.mozilla.org".installation_mode = "blocked";
          "bing@search.mozilla.org".installation_mode = "blocked";
          "ddg@search.mozilla.org".installation_mode = "blocked";
          "wikipedia@search.mozilla.org".installation_mode = "blocked";

          "frankerfacez@frankerfacez.com" = {
            installation_mode = "force_installed";
            install_url = "https://cdn.frankerfacez.com/script/frankerfacez-4.0-an+fx.xpi";
          };
        };
        Preferences = { };
      };

      default-search = {
        default = "DuckDuckGo";
        privateDefault = "DuckDuckGo";
        force = true;

        engines = {
          "Nix Packages" = {
            urls = [
              {
                template = "https://search.nixos.org/packages";
                params = [
                  {
                    name = "type";
                    value = "packages";
                  }
                  {
                    name = "query";
                    value = "{searchTerms}";
                  }
                ];
              }
            ];
            icon = "${pkgs.nixos-icons}/share/icons/hicolor/scalable/desktop/nix-snowflake.svg";
            definedAliases = [ "@np" ];
          };

          "NixOS Options" = {
            urls = [
              {
                template = "https://search.nixos.org/options";
                params = [
                  {
                    name = "channel";
                    value = "unstable";
                  }
                  {
                    name = "query";
                    value = "{searchTerms}";
                  }
                ];
              }
            ];
            icon = "${pkgs.nixos-icons}/share/icons/hicolor/scalable/desktop/nix-snowflake.svg";
            definedAliases = [ "@no" ];
          };

          "Searchix" = {
            urls = [
              {
                template = "https://searchix.alanpearce.eu/all/search/";
                params = [
                  {
                    name = "query";
                    value = "{searchTerms}";
                  }
                ];
              }
            ];
            icon = "${pkgs.nixos-icons}/share/icons/hicolor/scalable/desktop/nix-snowflake.svg";
            definedAliases = [ "@sx" ];
          };

          "NüschtOS" = {
            urls = [
              {
                template = "https://search.nüschtos.de";
                params = [
                  {
                    name = "query";
                    value = "{searchTerms}";
                  }
                ];
              }
            ];
            icon = "${pkgs.nixos-icons}/share/icons/hicolor/scalable/desktop/nix-snowflake.svg";
            definedAliases = [ "@nos" ];
          };

          "NixOS Wiki" = {
            urls = [ { template = "https://wiki.nixos.org/w/index.php?search={searchTerms}"; } ];
            iconUpdateURL = "https://wiki.nixos.org/favicon.png";
            updateInterval = 24 * 60 * 60 * 1000;
            definedAliases = [ "@nw" ];
          };
        };
      };
    in
    {
      extensions = mkOption {
        type = listOf package;
        default = default-extensions;
        description = "Extensions to install";
      };
      extra-config = mkOption {
        type = str;
        default = "";
        description = "Extra configuration for the user profile JS file.";
      };
      gpu-acceleration = mkEnableOption "Enable GPU acceleration.";
      hardware-decoding = mkEnableOption "Enable hardware video decoding.";
      policies = mkOption {
        type = attrs;
        default = default-policies;
        description = "Policies to apply to Firefox.";
      };
      search = mkOption {
        type = attrs;
        default = default-search;
        description = "Search configuration";
      };
      settings = mkOption {
        type = attrs;
        default = { };
        description = "Settings to apply to the profile.";
      };
      userChrome = mkOption {
        type = str;
        default = "";
        description = "Extra configuration for the user chrome CSS file.";
      };
    };
  config =
    {
      cfg,
      config,
      lib,
      pkgs,
      ...
    }:
    let
      inherit (lib) mkMerge optionalAttrs;
      inherit (pkgs.stdenv) isLinux;
    in
    {
      # home.file = (mkMerge [
      #   {
      #     "${firefoxPath}/chrome/img" = {
      #       recursive = true;
      #       source    = cleanSourceWith { src = cleanSource ./chrome/img/.; };
      #     };
      #   }
      # ]);

      programs.firefox = {
        enable = true;
        package = if isLinux then pkgs.firefox-devedition else null;

        inherit (cfg) policies;

        profiles = {
          "dev-edition-default" = {
            id = 0;
            path = "${config.rebellion.user.name}";
          };

          ${config.rebellion.user.name} = {
            inherit (cfg) extraConfig extensions search;
            inherit (config.rebellion.user) name;

            id = 1;

            settings = mkMerge [
              cfg.settings
              {
                "accessibility.typeaheadfind.enablesound" = false;
                "accessibility.typeaheadfind.flashBar" = 0;
                "browser.aboutConfig.showWarning" = false;
                "browser.aboutwelcome.enabled" = false;
                "browser.bookmarks.autoExportHTML" = true;
                "browser.bookmarks.showMobileBookmarks" = true;
                "browser.meta_refresh_when_inactive.disabled" = true;
                "browser.newtabpage.activity-stream.default.sites" = "";
                "browser.newtabpage.activity-stream.showSponsored" = false;
                "browser.newtabpage.activity-stream.showSponsoredTopSites" = false;
                "browser.search.hiddenOneOffs" = "Google,Amazon.com,Bing,DuckDuckGo,eBay,Wikipedia (en)";
                "browser.search.suggest.enabled" = false;
                "browser.sessionstore.warnOnQuit" = true;
                "browser.shell.checkDefaultBrowser" = false;
                "browser.ssb.enabled" = true;
                "browser.startup.homepage.abouthome_cache.enabled" = true;
                "browser.startup.page" = 3;
                "browser.urlbar.keepPanelOpenDuringImeComposition" = true;
                "browser.urlbar.suggest.quicksuggest.sponsored" = false;
                "devtools.chrome.enabled" = true;
                "devtools.debugger.remote-enabled" = true;
                "dom.storage.next_gen" = true;
                "dom.forms.autocomplete.formautofill" = true;
                "extensions.htmlaboutaddons.recommendations.enabled" = false;
                "extensions.formautofill.addresses.enabled" = false;
                "extensions.formautofill.creditCards.enabled" = false;
                "general.autoScroll" = false;
                "general.smoothScroll.msdPhysics.enabled" = true;
                "geo.enabled" = false;
                "geo.provider.use_corelocation" = false;
                "geo.provider.use_geoclue" = false;
                "geo.provider.use_gpsd" = false;
                "gfx.font_rendering.directwrite.bold_simulation" = 2;
                "gfx.font_rendering.cleartype_params.enhanced_contrast" = 25;
                "gfx.font_rendering.cleartype_params.force_gdi_classic_for_families" = "";
                "intl.accept_languages" = "en-US,en";
                "media.eme.enabled" = true;
                "media.videocontrols.picture-in-picture.video-toggle.enabled" = false;
                "toolkit.legacyUserProfileCustomizations.stylesheets" = true;
                "font.name.monospace.x-western" = "MonaspiceKr Nerd Font";
                "font.name.sans-serif.x-western" = "MonaspiceNe Nerd Font";
                "font.name.serif.x-western" = "MonaspiceNe Nerd Font";
                "signon.autofillForms" = false;
                "signon.firefoxRelay.feature" = "disabled";
                "signon.generation.enabled" = false;
                "signon.management.page.breach-alerts.enabled" = false;
                "xpinstall.signatures.required" = false;
              }
              (optionalAttrs cfg.gpu-acceleration {
                "dom.webgpu.enabled" = true;
                "gfx.webrender.all" = true;
                "layers.gpu-process.enabled" = true;
                "layers.mlgpu.enabled" = true;
              })
              (optionalAttrs cfg.hardware-decoding {
                "media.ffmpeg.vaapi.enabled" = true;
                "media.gpu-process-decoder" = true;
                "media.hardware-video-decoding.enabled" = true;
              })
            ];

            # TODO: support alternative theme loading
            # userChrome =
            #   builtins.readFile ./chrome/userChrome.css
            #   + ''
            #     ${cfg.userChrome}
            #   '';
          };
        };
      };
    };
}
