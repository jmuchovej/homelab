{ writeShellScriptBin, gum, ... }:
writeShellScriptBin  "install" ''
  host=$1
  addr=$2
  ${gum}/bin/gum style \
    --border normal \
    --margin "1" \
    --padding "1 2" \
    --border-foreground 212 \
    "✨ Joining the Rebellion ✨"
  echo "This script will wipe the remote system!"
  ${gum}/bin/gum confirm "Cancel?" && exit

  echo
  echo "🔥 kexec into the NixOS installer..."
  ssh root@$addr \
    -o StrictHostKeyChecking=no \
    -o UserKnownHostsFile=/dev/null \
    'curl -L https://github.com/nix-community/nixos-images/releases/download/nixos-unstable/nixos-kexec-installer-noninteractive-x86_64-linux.tar.gz | tar -xzf- -C /root'
  ssh root@$addr -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null '/root/kexec/run'

  echo
  echo "⏰ Waiting for host \`$host\` to come online..."
  while true; do ping -c1 $addr > /dev/null && break; done

  echo
  echo "📥 Grabbing hardware config..."
  ssh root@$addr -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null 'nixos-generate-config --show-hardware-config --root /mnt' > systems/x86_64-linux/$host/hardware-configuration.nix

  echo
  echo "✅ Installing..."
  nix run github:nix-community/nixos-anywhere -- --flake .#$host --target-host root@$addr --build-on-remote

  echo
  echo "🚀 Done! 🚀"
''
