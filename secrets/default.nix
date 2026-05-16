{ lib, ... }:
let
  inherit (lib)
    hasSuffix
    removeSuffix
    fileContents
    filterAttrs
    mapAttrs
    mapAttrs'
    nameValuePair
    optionalAttrs
    pipe
    ;

  # Discover entries by their `<name>.sops.yaml` files in `dir`, then look up
  # colocated `<name>.pub` (SSH, optional) and `<name>.pub.age` (age, optional)
  # siblings. Returns `{}` for missing/empty directories so callers don't need
  # to guard.
  read-dir =
    dir:
    if !builtins.pathExists dir then
      { }
    else
      pipe (builtins.readDir dir) [
        (filterAttrs (n: _: hasSuffix ".sops.yaml" n))
        (mapAttrs' (
          file: _:
          let
            name = removeSuffix ".sops.yaml" file;
            ssh-file = dir + "/${name}.pub";
            age-file = dir + "/${name}.pub.age";
          in
          nameValuePair name (
            optionalAttrs (builtins.pathExists ssh-file) {
              ssh = fileContents ssh-file;
            }
            // optionalAttrs (builtins.pathExists age-file) {
              age = fileContents age-file;
            }
          )
        ))
      ];

  systems = read-dir ./systems;
  users = read-dir ./homes;

  # Flat views — only include entries that have the relevant key, so callers
  # iterating these can't trip on missing files.
  ssh-of = attrs: mapAttrs (_: v: v.ssh) (filterAttrs (_: v: v ? ssh) attrs);
  age-of = attrs: mapAttrs (_: v: v.age) (filterAttrs (_: v: v ? age) attrs);
in
{
  inherit systems users;

  systems-ssh = ssh-of systems;
  systems-age = age-of systems;

  users-ssh = ssh-of users;
  users-age = age-of users;
}
