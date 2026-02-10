# Configuration for home-assistant packages
# Components need to be called within the Home Assistant Python package scope
# `platforms` is checked before callPackage runs, preventing abort on missing deps
{
  callPackage = pkgs: pkgs.home-assistant.python.pkgs.callPackage;
  platforms = lib: lib.platforms.linux;
}
