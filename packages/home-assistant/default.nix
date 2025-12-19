# Configuration for home-assistant packages
# Components need to be called within the Home Assistant Python package scope
{
  callPackage = pkgs: pkgs.home-assistant.python.pkgs.callPackage;
}
