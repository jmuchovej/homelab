{
  lib,
  den,
  __findFile,
  ...
}:
{
  # Host schema config — read by aspects via `host.*`
  den.hosts.x86_64-linux.da-vcx-1 = {
    s3 = {
      buckets = [
        "volsync"
        "postgres"
        "authentik"
      ];
      data-dir = [ "/impulse/s3" ];
    };
    local-llms.ollama.models = [
      "all-minilm"
      "codegemma"
      "codellama"
      "cogito"
      "deepseek-coder"
      "deepseek-r1"
      "deepseek-v3"
      "deepseek-v3.1"
      "devstral"
      "devstral-2"
      "dolphin3"
      "falcon3"
      "gemma"
      "gemma2"
      "gemma3"
      "gpt-oss"
      "llama3"
      "llama3.1"
      "llama3.2"
      "llama3.2-vision"
      "llama3.3"
      "llama4"
      "llava"
      "magistral"
      "ministral-3"
      "mistral"
      "mixtral"
      "mxbai-embed-large"
      "nemotron-3-nano"
      "nomic-embed-text"
      "olmo-3"
      "olmo2"
      "phi"
      "phi3"
      "phi3.5"
      "phi4-reasoning"
      "qwen"
      "qwen2"
      "qwen2.5"
      "qwen2.5-coder"
      "qwen2.5vl"
      "qwen3"
      "qwen3-embedding"
      "qwen3-vl"
      "qwq"
      "embeddinggemma"
    ];
    authentik.enable = true;
    tailscale.enable = true;
    containers.enable = true;

    nfs.mounts = [
      {
        server = "10.69.10.1";
        remote = "/impulse/home";
        local = "/home";
      }
      {
        server = "10.69.10.1";
        remote = "/impulse/media";
        local = "/srv/media";
      }
    ];

    persistence = {
      device = "/dev/disk/by-id/nvme-Patriot_M.2_P300_256GB_P300IBBB23122507026";
      extra-directories = [ ];
      extra-files = [ ];
    };
  };

  den.aspects.da-vcx-1 = {
    includes = [

      # Suites
      <rbn/suite/server>
      <rbn/system/boot/graphical>

      # Hardware
      <rbn/system/hardware/cpu/intel>
      <rbn/system/hardware/gpu/nvidia>
      <rbn/system/hardware/storage/btrfs>
      <rbn/system/hardware/storage/zfs>
      <rbn/system/hardware/storage/zfs/managed>

      # Virtualization
      # <rbn/system/virtualization>
      # (<rbn/system/virtualization/win11> {
      #   vhd = "/warp/vms/win11.qcow2";
      #   vcpus = 8;
      #   memory = 32; # GiB
      #   gpu = "0000:01:00.0"; # RTX 3090 — VGA .0 + HDMI-audio .1
      # })

      # Security
      <rbn/system/security/sudo>

      # Networking (base via suite-common, dns/manager selected here)
      <rbn/system/networking/dns/dnsmasq>
      <rbn/system/networking/manager/networkmanager>

      # Services
      <rbn/services/nfs>
      <rbn/services/kubernetes>
      <rbn/services/kubernetes/nvidia>
      # <rbn/services/authentik>
      # <rbn/services/syncthing>
      <rbn/services/avahi>
      <rbn/services/cloudflared>
      # <rbn/services/redis>
      <rbn/services/ldap>
      # <rbn/services/chroma>
      # <rbn/services/n8n>
      # <rbn/services/media>
      # <rbn/services/immich>
      # <rbn/services/homebox>
      # <rbn/services/spliit>
      # <rbn/services/home-assistant>
      <rbn/services/postgres>
      # <rbn/services/proton-vpn>
      # <rbn/services/qbittorrent>
      # <rbn/services/s3>
      # <rbn/services/split-pro>
      # <rbn/services/arr>
      # <rbn/services/local-llms/ollama>
      # <rbn/services/local-llms/open-webui>

      <rbn/services/zerotier>
    ];

    provides.to-users = {
      includes = with den.aspects; [
        (facter ./facter.json)
      ];
    };

    nixos = {
      networking.hostId = "fe4ccbf4";

      boot.zfs.extraPools = [
        "warp"
      ];
      system.stateVersion = "24.11";
    };
  };
}
