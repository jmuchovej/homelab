{ inputs, ... }:
{
  flake.lib = {
    # keep-sorted start block=yes newline_separated=yes
    file = import ./file.nix {
      inherit inputs;
      self = ../.;
    };
    module = import ./module.nix { inherit inputs; };
    overlay = import ./overlay.nix { inherit inputs; };
    system = {
      # System configuration builders
      homes = import ./system/mk-homes.nix { inherit inputs; };
      macos = import ./system/mk-macos.nix { inherit inputs; };
      nixos = import ./system/mk-nixos.nix { inherit inputs; };

      # Common utilities used by system builders
      common = import ./system/common.nix { inherit inputs; };
    };
    # keep-sorted end
  };

  # override-meta =
  #   meta: package:
  #   package.overrideAttrs (_: {
  #     inherit meta;
  #   });
}
