{
  rbn.system._.time.nixos =
    {
      host,
      inputs,
      lib,
      pkgs,
      ...
    }:
    let
      topology = lib.rbn.from-yaml "${inputs.self}/topology.yaml" { inherit pkgs; };
    in
    {
      time.timeZone = "America/New_York";

      networking.timeServers = [
        topology.networks.${host.datacenter}.lab.gateway
        "0.nixos.pool.ntp.org"
        "1.nixos.pool.ntp.org"
        "2.nixos.pool.ntp.org"
        "3.nixos.pool.ntp.org"
      ];

      services.chrony.enable = true;
    };
}
