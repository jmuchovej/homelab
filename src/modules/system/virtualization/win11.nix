{ inputs, lib, ... }:
let
  inherit (lib)
    recursiveUpdate
    optionalAttrs
    makeBinPath
    ;

  # Deterministic UUID from a seed string (md5 -> 8-4-4-4-12), so the domain
  # and network keep a stable identity across rebuilds without random state.
  mk-uuid =
    s:
    let
      h = builtins.hashString "md5" s;
      sub = a: b: builtins.substring a b h;
    in
    "${sub 0 8}-${sub 8 4}-${sub 12 4}-${sub 16 4}-${sub 20 12}";

  # Nix has no hex parser; PCI bus/slot/function are hex in `lspci` output.
  hex-digit =
    c:
    {
      "0" = 0;
      "1" = 1;
      "2" = 2;
      "3" = 3;
      "4" = 4;
      "5" = 5;
      "6" = 6;
      "7" = 7;
      "8" = 8;
      "9" = 9;
      "a" = 10;
      "b" = 11;
      "c" = 12;
      "d" = 13;
      "e" = 14;
      "f" = 15;
    }
    .${c};
  hex-to-int =
    s: lib.foldl' (acc: c: acc * 16 + hex-digit c) 0 (lib.stringToCharacters (lib.toLower s));
in
{
  flake-file.inputs.nixvirt.url = "github:AshleyYakeley/NixVirt";

  # Parametric Windows 11 KVM guest with optional NVIDIA GPU passthrough.
  #
  #   includes = [
  #     (<rbn/system/virtualization/win11> {
  #       vhd = "/warp/vms/win11.qcow2";
  #       gpu = "0000:01:00.0";          # null => plain VM, no passthrough, no hook
  #     })
  #   ];
  #
  # When `gpu` is set the guest gets the GPU's VGA + audio functions as
  # `managed='no'` hostdevs, and a libvirt qemu hook gates VM start on GPU
  # availability — refusing to start if a CUDA workload holds the card —
  # then dynamically rebinds the GPU from `nvidia` to `vfio-pci`, returning
  # it to `nvidia` when the guest stops. `active = false` keeps the GPU with
  # the host driver until you explicitly `virsh start`.
  rbn.system._.virtualization._.win11.__functor =
    _self:
    {
      name ? "win11",
      vcpus ? 8,
      memory ? 32, # GiB
      vhd, # absolute path to the (mutable) disk image
      nvram ? "/var/lib/libvirt/nvram/${name}.nvram",
      install-virtio ? true,
      gpu ? null, # e.g. "0000:01:00.0"; null => no passthrough + no hook
    }:
    { class, ... }:
    if class != "nixos" then
      { }
    else
      {
        nixos =
          {
            host,
            pkgs,
            ...
          }:
          let
            nixvirt = inputs.nixvirt.lib;

            # ── GPU PCI address (only forced when gpu != null) ──────────
            addr = builtins.match "([0-9a-fA-F]+):([0-9a-fA-F]+):([0-9a-fA-F]+)\\.([0-9a-fA-F]+)" gpu;
            pci = {
              domain = hex-to-int (builtins.elemAt addr 0);
              bus = hex-to-int (builtins.elemAt addr 1);
              slot = hex-to-int (builtins.elemAt addr 2);
              function = hex-to-int (builtins.elemAt addr 3);
            };
            # Same bus:device, audio is function .1; sysfs path for the hook.
            aud-str = "${builtins.elemAt addr 0}:${builtins.elemAt addr 1}:${builtins.elemAt addr 2}.1";

            mk-hostdev = fn: {
              mode = "subsystem";
              type = "pci";
              managed = false; # our hook does the bind/unbind, not libvirt
              source.address = {
                inherit (pci) domain bus slot;
                function = fn;
              };
            };

            base = nixvirt.domain.templates.windows {
              inherit name;
              uuid = mk-uuid "domain-${name}";
              memory = {
                count = memory;
                unit = "GiB";
              };
              storage_vol = vhd;
              nvram_path = nvram;
              install_virtio = install-virtio;
            };

            domain = recursiveUpdate base (
              {
                vcpu = {
                  placement = "static";
                  count = vcpus;
                };
                cpu = {
                  mode = "host-passthrough";
                  check = "none";
                };
              }
              // optionalAttrs (gpu != null) {
                devices.hostdev = [
                  (mk-hostdev pci.function)
                  (mk-hostdev (pci.function + 1))
                ];
              }
            );

            # ── GPU gate + dynamic bind hook (only when gpu != null) ────
            gpu-hook = pkgs.writeShellScript "libvirt-gpu-gate-${name}" ''
              export PATH=${
                makeBinPath [
                  pkgs.kmod
                  pkgs.coreutils
                  pkgs.gnugrep
                ]
              }:/run/current-system/sw/bin

              guest="$1"; op="$2"; subop="$3"
              [ "$guest" = "${name}" ] || exit 0

              vga="${gpu}"
              aud="${aud-str}"
              short="$(echo "$vga" | cut -d: -f2-)"

              case "$op/$subop" in
                prepare/begin)
                  # Friendly pre-check (authoritative gate is the rmmod below).
                  if command -v nvidia-smi >/dev/null 2>&1; then
                    if nvidia-smi --query-compute-apps=gpu_bus_id --format=csv,noheader 2>/dev/null \
                         | grep -qi "$short"; then
                      echo "gpu-gate: $vga has active compute work; refusing to start ${name}" >&2
                      exit 1
                    fi
                  fi
                  # Full nvidia unload only succeeds if nothing holds the GPU.
                  if ! modprobe -r nvidia_drm nvidia_uvm nvidia_modeset nvidia 2>/dev/null; then
                    echo "gpu-gate: cannot release nvidia driver (GPU in use); refusing to start ${name}" >&2
                    exit 1
                  fi
                  modprobe vfio-pci 2>/dev/null || true
                  # Release the HDMI-audio function from snd_hda_intel first.
                  if [ -e "/sys/bus/pci/devices/$aud/driver" ]; then
                    echo "$aud" > "/sys/bus/pci/devices/$aud/driver/unbind" 2>/dev/null || true
                  fi
                  for d in "$vga" "$aud"; do
                    echo vfio-pci > "/sys/bus/pci/devices/$d/driver_override"
                    echo "$d" > /sys/bus/pci/drivers_probe 2>/dev/null || true
                  done
                  ;;
                release/end)
                  for d in "$vga" "$aud"; do
                    if [ -e "/sys/bus/pci/devices/$d/driver" ]; then
                      echo "$d" > "/sys/bus/pci/devices/$d/driver/unbind" 2>/dev/null || true
                    fi
                    echo > "/sys/bus/pci/devices/$d/driver_override" 2>/dev/null || true
                  done
                  modprobe nvidia nvidia_modeset nvidia_uvm nvidia_drm 2>/dev/null || true
                  for d in "$vga" "$aud"; do
                    echo "$d" > /sys/bus/pci/drivers_probe 2>/dev/null || true
                  done
                  ;;
              esac
              exit 0
            '';
          in
          {
            # `imports` is a special module key — it must stay top-level and
            # cannot be wrapped in mkMerge/mkIf. GPU-only settings below use
            # inline mkIf instead.
            imports = [ inputs.nixvirt.nixosModules.default ];

            virtualisation.libvirt = {
              enable = true;
              swtpm.enable = true;
              connections."qemu:///system" = {
                domains = [
                  {
                    definition = nixvirt.domain.writeXML domain;
                    active = false; # never autostart -> GPU stays with nvidia/CUDA
                  }
                ];
                networks = [
                  {
                    definition = nixvirt.network.writeXML (
                      nixvirt.network.templates.bridge {
                        uuid = mk-uuid "net-${name}-default";
                        subnet_byte = 122;
                      }
                    );
                    active = true;
                  }
                ];
              };
            };

            environment.systemPackages = with pkgs; [
              virt-manager
              virtiofsd
            ];

            users.users.${host.primary-user.name}.extraGroups = [
              "libvirtd"
              "kvm"
            ];

            # ── GPU-passthrough-only settings ──────────────────────────
            boot.kernelParams = lib.mkIf (gpu != null) [
              "intel_iommu=on"
              "iommu=pt"
            ];
            virtualisation.libvirtd.hooks.qemu = lib.mkIf (gpu != null) {
              "gpu-gate-${name}" = gpu-hook;
            };
          };
      };
}
