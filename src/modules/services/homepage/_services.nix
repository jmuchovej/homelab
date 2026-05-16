[
  {
    external = [
      {
        Tandoor = {
          icon = "tandoor.png";
          href = "{{HOMEPAGE_VAR_TANDOOR_EXT_URL}}";
          description = "";
          widget = {
            type = "tandoor";
            url = "{{HOMEPAGE_VAR_TANDOOR_INT_URL}}";
            key = "{{HOMEPAGE_VAR_TANDOOR_API_KEY}}";
          };
        };
      }
    ];
  }
  {
    media = [
      {
        Plex = {
          icon = "plex.png";
          href = "{{HOMEPAGE_VAR_PLEX_EXT_URL}}";
          description = "media management";
          widget = {
            type = "plex";
            url = "{{HOMEPAGE_VAR_PLEX_INT_URL}}";
            key = "{{HOMEPAGE_VAR_PLEX_API_KEY}}";
          };
        };
      }

      {
        Radarr = {
          icon = "radarr.png";
          href = "{{HOMEPAGE_VAR_RADARR_EXT_URL}}";
          description = "movies management";
          widget = {
            type = "radarr";
            url = "{{HOMEPAGE_VAR_RADARR_INT_URL}}";
            key = "{{HOMEPAGE_VAR_RADARR_API_KEY}}";
          };
        };
      }
      {
        Sonarr = {
          icon = "sonarr.png";
          href = "{{HOMEPAGE_VAR_SONARR_EXT_URL}}";
          description = "series management";
          widget = {
            type = "sonarr";
            url = "{{HOMEPAGE_VAR_SONARR_INT_URL}}";
            key = "{{HOMEPAGE_VAR_SONARR_API_KEY}}";
          };
        };
      }
      {
        Lidarr = {
          icon = "lidarr.png";
          href = "{{HOMEPAGE_VAR_LIDARR_EXT_URL}}";
          description = "music management";
          widget = {
            type = "lidarr";
            url = "{{HOMEPAGE_VAR_LIDARR_INT_URL}}";
            key = "{{HOMEPAGE_VAR_LIDARR_API_KEY}}";
          };
        };
      }
      {
        Readarr = {
          icon = "readarr.png";
          href = "{{HOMEPAGE_VAR_READARR_EXT_URL}}";
          description = "book management";
          widget = {
            type = "readarr";
            url = "{{HOMEPAGE_VAR_READARR_INT_URL}}";
            key = "{{HOMEPAGE_VAR_READARR_API_KEY}}";
          };
        };
      }
      {
        Prowlarr = {
          icon = "prowlarr.png";
          href = "{{HOMEPAGE_VAR_PROWLARR_EXT_URL}}";
          description = "index management";
          widget = {
            type = "prowlarr";
            url = "{{HOMEPAGE_VAR_PROWLARR_INT_URL}}";
            key = "{{HOMEPAGE_VAR_PROWLARR_API_KEY}}";
          };
        };
      }
    ];
  }
]
