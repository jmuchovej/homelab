# Shell for bootstrapping flake-enabled nix and home-manager
# You can enter it through 'nix develop' or (legacy) 'nix-shell'
{
  pkgs ? (import ./nixpkgs.nix) { }
  , sops-import-keys-hook, sops-init-gpg-key
  , deploy-rs
  , ...
}:
{
  default = pkgs.mkShell {
    sopsPGPKeyDirs = [ "./secrets/keys" ];
    # Enable experimental features without having to specify the argument
    NIX_CONFIG = "experimental-features = nix-command flakes";
    # nativeBuildInputs = [ pkgs.nix pkgs.home-manager pkgs.git ];
    nativeBuildInputs = [
      pkgs.nix pkgs.git pkgs.vim
      pkgs.home-manager
      pkgs.go-task
      pkgs.sops pkgs.ssh-to-age pkgs.ssh-to-pgp
      sops-import-keys-hook sops-init-gpg-key
      pkgs.deploy-rs
      pkgs.nixpkgs-fmt
    ];
  };
}
