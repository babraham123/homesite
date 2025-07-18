# Podman setup
Initial setup to install Proxmox and configure it with the relevant scripts and services.

- Setup [Debian Linux](./debian.md)
- Make sure to do VM Host setup for [PVE1](./pve1.md) and [PVE2](./pve2.md).
- Review container security measures, for example [ref](https://www.panoptica.app/research/7-ways-to-escape-a-container)

## Install Podman
- Install dependencies
```bash
sudo su
apt install -y age jq python3-pip
pip3 install --break-system-packages jinjanator jinjanator-plugin-ansible passlib

YQ_VERSION=$(curl -s "https://api.github.com/repos/mikefarah/yq/releases/latest" | grep -Po '"tag_name": "v\K[0-9.]+')
wget "https://github.com/mikefarah/yq/releases/download/v${YQ_VERSION}/yq_linux_amd64.tar.gz" -O - | tar xz
mv yq_linux_amd64 /usr/bin/yq
./install-man-page.sh
rm yq* install-man-page.sh
```

- Install podman: [ref](https://podman.io/docs/installation#linux-distributions), [ref2](https://computingforgeeks.com/how-to-install-podman-on-debian/)
```bash
source /etc/os-release
curl -fsSL https://download.opensuse.org/repositories/home:/alvistack/Debian_$VERSION_ID/Release.key \
  | gpg --dearmor \
  | tee /etc/apt/trusted.gpg.d/alvistack.gpg > /dev/null
echo "deb http://downloadcontent.opensuse.org/repositories/home:/alvistack/Debian_$VERSION_ID/ /" \
  | tee /etc/apt/sources.list.d/alvistack.list > /dev/null

apt update
apt -y upgrade
apt -y install podman podman-netavark podman-aardvark-dns podman-compose libgpgme11-dev buildah libyajl2
```

- Enable container auto updating
```bash
systemctl enable --now podman-auto-update.timer
```

## Networking
- Account for conflicts between the podman network and the firewall, [bug](https://stackoverflow.com/questions/70870689/configure-ufw-for-podman-on-port-443)
```bash
ufw reset
# SSH, HTTP
ufw allow in from any to any port 22,80,443 proto tcp
# mDNS
ufw allow in from any to any port 5353 proto udp

cd /root/homelab-rendered
mkdir /etc/containers/systemd
cp src/$HOST/net.network /etc/containers/systemd
systemctl daemon-reload
systemctl start net-network
NET_IFACE=$(podman network inspect systemd-net | jq -r '.[0].network_interface')
# Use enp6s18 on secsvcs, enp6s18 on websvcs, enp6s18 on homesvcs
ufw route allow in on enp6s18 out on $NET_IFACE to any port 80,443 proto tcp

ufw enable
```

## Secrets
- On the VM host, update the SOPS/AGE secrets file if needed
- Configure secrets
```bash
sudo su
# Read secrets from age-encrypted file
mkdir -p /etc/opt/secrets
chmod 700 /etc/opt/secrets
cp /home/jdoe/.ssh/id_ed25519* /etc/opt/secrets
chmod 600 /etc/opt/secrets/*
cd /root/homelab-rendered
cp src/podman/*.sh /usr/local/bin
cp src/podman/containers.conf /etc/containers

echo "placeholder" > /root/placeholder.txt
podman secret rm --all
/usr/local/bin/list_secrets.sh | xargs -I% podman secret create "%" /root/placeholder.txt
podman secret ls
```

## mDNS
- Install dependencies and service
```bash
apt install -y build-essential
src/debian/install_svcs.sh mdns_repeater
```

## Monitoring
- Install Node Exporter
```bash
adduser node_exporter --system
groupadd node_exporter
usermod -a -G node_exporter node_exporter
cd /root/homelab-rendered
src/debian/install_svcs.sh node_exporter
```

- Allow access from metrics container to host in order to scrape node_exporter
```bash
# Use 10.10.0.7 on secsvcs, 10.11.0.7 on websvcs, 10.12.0.7 on homesvcs
ufw allow in from 10.10.0.7 to any port 9100 proto tcp
```
