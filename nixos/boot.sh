set -e
set -x

nix-channel --remove nixos
nix-channel --add $NIXOS_CHANNEL nixos
nix-channel --update

# Assuming a single disk (/dev/sda).
MB="1048576"
DISK_SIZE=`fdisk -l | grep ^Disk | grep -v loop | awk -F" "  '{ print $5 }'`
DISK_SIZE=$(($DISK_SIZE / $MB))

# Create partitions.
if [ -z "$SWAP" ]; then
  echo "n
p
1


a
w
" | fdisk /dev/sda
else
  PRIMARY_SIZE=$(($DISK_SIZE - $SWAP))
  echo "n
p
1

+${PRIMARY_SIZE}M
a
n
p
2


w
" | fdisk /dev/sda
  mkswap -L swap /dev/sda2
  swapon /dev/sda2
fi

mkfs.ext4 -j -L nixos /dev/sda1
mount LABEL=nixos /mnt

# Generate hardware config.
nixos-generate-config --root /mnt

# Download configuration.
curl http://$HTTP_IP:$HTTP_PORT/configuration.nix > /mnt/etc/nixos/configuration.nix
curl http://$HTTP_IP:$HTTP_PORT/guest.nix > /mnt/etc/nixos/guest.nix
curl http://$HTTP_IP:$HTTP_PORT/graphical.nix > /mnt/etc/nixos/graphical.nix
curl http://$HTTP_IP:$HTTP_PORT/users.nix > /mnt/etc/nixos/users.nix
curl http://$HTTP_IP:$HTTP_PORT/vagrant-hostname.nix > /mnt/etc/nixos/vagrant-hostname.nix
curl http://$HTTP_IP:$HTTP_PORT/vagrant-network.nix > /mnt/etc/nixos/vagrant-network.nix

if [ -z "$GRAPHICAL" ]; then
  sed -i '/graphical\.nix/d' /mnt/etc/nixos/configuration.nix
fi

if [ -z "$ROOT_PASSWORD" ]; then
  nixos-install
else
  echo -e "$ROOT_PASSWORD\n$ROOT_PASSWORD" | nixos-install
fi

printf "%s nixos" "$NIXOS_CHANNEL" > /mnt/root/.nix-channels

sleep 2
reboot -f
