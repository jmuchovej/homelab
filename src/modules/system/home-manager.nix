{ inputs, lib, ... }:
{
  flake-file.inputs.home-manager = {
    url = lib.mkDefault "github:nix-community/home-manager";
    inputs.nixpkgs.follows = "nixpkgs";
  };

  den.default = {
    nixos.imports = [
      inputs.home-manager.nixosModules.home-manager
    ];
    darwin.imports = [
      inputs.home-manager.darwinModules.home-manager
    ];
    homeManager =
      { lib, ... }:
      {
        home.stateVersion = lib.mkDefault "25.11";
        home.sessionPath = [ "$HOME/.local/bin" ];
      };
  };

  den.schema.user.classes = lib.mkDefault [ "homeManager" ];

  # ── Host schema: HM collection options ─────────────────────────────
  den.schema.host =
    { lib, ... }:
    let
      inherit (lib) mkOption;
      inherit (lib.types) attrs;
    in
    {
      # Named `hm` rather than `home` to avoid colliding with den's
      # fx-pipeline `home` context binding (host.home is implicitly passed
      # as the `home` arg to home-scoped parametric aspects).
      options.hm = {
        file = mkOption {
          type = attrs;
          default = { };
          description = "Files managed by home-manager's home.file.";
        };
        config-file = mkOption {
          type = attrs;
          default = { };
          description = "Files managed by home-manager's xdg.configFile.";
        };
        extra-options = mkOption {
          type = attrs;
          default = { };
          description = "Options to pass directly to home-manager.";
        };
      };
    };

  # ── HM wiring aspect ──────────────────────────────────────────────
  rbn.system._.home-manager = {
    os =
      { host, lib, ... }:
      let
        username = host.primary-user.name;
      in
      {
        home-manager = {
          backupFileExtension = "hm.bak";
          useUserPackages = true;
          useGlobalPkgs = true;
          verbose = true;
        };

        home-manager.users.${username} = host.hm.extra-options // {
          home.file = host.hm.file;
          xdg.enable = true;
          xdg.configFile = host.hm.config-file;
        };
      };

    # NixOS: wire HM for primary user
    nixos =
      { host, lib, ... }:
      let
        username = host.primary-user.name;
      in
      {
        users.users.${username}.home = lib.mkDefault (/. + "/home/${username}");
      };

    # Darwin: wire HM for primary user
    darwin =
      { host, lib, ... }:
      let
        username = host.primary-user.name;
      in
      {
        users.users.${username}.home = lib.mkDefault (/. + "/Users/${username}");
      };
  };
}
