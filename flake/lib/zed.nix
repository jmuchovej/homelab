_: {
  # Create a standardized Traefik service configuration
  # Returns router and service config that should be assigned to dynamicConfigOptions.http
  # Usage in modules: services.traefik.dynamicConfigOptions.http = lib.rebellion.traefik.mk-service { ... };
  mkzed-settings =
    {
      extensions ? [ ],
      packages ? [ ],
      settings ? { },
    }:
    {
      inherit extensions;
      extraPackages = packages;
      userSettings = settings;
    };
}
