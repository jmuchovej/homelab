_: {
  rbn.programs._.browsers._.firefox = {
    homeManager =
      {
        config,
        lib,
        pkgs,
        ...
      }:
      let
        inherit (pkgs.stdenv) isLinux;

        extensions = with config.nur.repos.rycee.firefox-addons; [
          onepassword-password-manager
          ublock-origin
        ];

        policies = {
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
        };

        search = {
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

            "NixOS Wiki" = {
              urls = [ { template = "https://wiki.nixos.org/w/index.php?search={searchTerms}"; } ];
              iconUpdateURL = "https://wiki.nixos.org/favicon.png";
              updateInterval = 24 * 60 * 60 * 1000;
              definedAliases = [ "@nw" ];
            };
          };
        };

        inherit (config.home) username;
      in
      {
        rebellion.dock.entries = [
          {
            name = "Firefox Developer Edition.app";
            source = "applications";
            group = "browsers";
            order = 320;
          }
        ];

        programs.firefox = {
          enable = true;
          package = if isLinux then pkgs.firefox-devedition else null;

          inherit policies;

          profiles = {
            "dev-edition-default" = {
              id = 0;
              path = username;
            };

            ${username} = {
              inherit extensions search;
              name = username;
              id = 1;

              settings = {
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
              };
            };
          };
        };
      };

    darwin =
      { host, lib, ... }:
      lib.mkIf host.homebrew.enable {
        homebrew.casks = [ "firefox@developer-edition" ];
      };
  };
}
