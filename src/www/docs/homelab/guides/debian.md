# Debian Linux setup
Initial setup for any Debian Linux instance. Configures the shell, ssh access and useful utilities.

- First do the basic [VM setup](./vm.md) if it's a VM running on Proxmox.

## OS
[Vid](https://www.youtube.com/watch?v=XEoO1FgIel4)
- If running, temporarily stop the vm_watchdog service on PVE1.
- Use graphical install, run through the options.
  - Leave name blank, username: jdoe
  - Partition disks: Guided - use entire disk
  - All files in one partition
  - If not a desktop VM, make sure to uncheck the GUI packages.
- Go to Hardware >> CD/DVD Drive >> Remove
- Go to Console
  - If desktop VM, open Terminal app. Otherwise login as root.
```bash
apt install -y ssh sudo
usermod -aG sudo jdoe
```

## Packages
- SSH in
```bash
ssh jdoe@HOSTNAME.janedoe.com
sudo su
```
- Fix deb repository, [src](https://it42.cc/2019/10/14/fix-proxmox-repository-is-not-signed/) 
	- `nano /etc/apt/sources.list`
	- add `contrib non-free non-free-firmware` to all Debian sources
- Install basics
```bash
apt update && apt upgrade
apt install -y zsh vim iproute2 git less curl wget zip unzip ethtool jq unattended-upgrades ufw
chsh -s /bin/zsh

# enable firewall
ufw allow ssh
ufw enable
```
- Configure updates
	- `vim /etc/apt/apt.conf.d/50unattended-upgrades`
  - Uncomment `-updates`

## SSH
- Set timezone
  - `timedatectl set-timezone America/Los_Angeles`
- Change hostname
	- `hostnamectl set-hostname SUBDOMAIN`
	- `vim /etc/hosts`, add `127.0.1.1    SUBDOMAIN.janedoe.com    SUBDOMAIN`
- Lock down SSH
	- `vim /etc/ssh/sshd_config`
```
PermitRootLogin no
```
- Generate SSH key, set correct SUBDOMAIN
```bash
exit
cd ~
ssh-keygen -t ed25519 -C "jdoe@SUBDOMAIN.janedoe.com"
eval "$(ssh-agent -s)"
ssh-add ~/.ssh/id_ed25519
```

## ZSH
- Install tools, [src](https://gist.github.com/sinadarvi/7b7178cb3cf9a605ab04700cae05287a)
```bash
sh -c "$(curl -fsSL https://raw.github.com/robbyrussell/oh-my-zsh/master/tools/install.sh)"

sudo apt install -y fonts-powerline fontconfig
git clone https://github.com/zsh-users/zsh-autosuggestions $ZSH_CUSTOM/plugins/zsh-autosuggestions
git clone https://github.com/zsh-users/zsh-syntax-highlighting.git $ZSH_CUSTOM/plugins/zsh-syntax-highlighting
git clone --depth=1 https://github.com/romkatv/powerlevel10k.git $ZSH_CUSTOM/themes/powerlevel10k

mkdir -p ~/.local/share/fonts
cd ~/.local/share/fonts
wget https://github.com/ryanoasis/nerd-fonts/releases/latest/download/Meslo.zip
unzip Meslo.zip
rm Meslo.zip
fc-cache -fv
cd ~
wget -O .vimrc https://raw.githubusercontent.com/amix/vimrc/master/vimrcs/basic.vim
echo 'export EDITOR="vim"' >> ~/.zshrc
```
- `vim ~/.zshrc`
```
...
ZSH_THEME="powerlevel10k/powerlevel10k"
...
plugins=(zsh-autosuggestions zsh-syntax-highlighting git)
```
- Copy files from source repo, under `src/debian`
  - `vim ~/.oh-my-zsh/custom/aliases.zsh`
  - `vim ~/.oh-my-zsh/custom/functions.zsh`
  - `sudo vim /root/.zshrc`

- Logout and log back in. Configure oh-my-zsh
	- Answers: `yyyy211n1311111y1y`

## Homelab Repo
- Install the homelab source code
```bash
exit
# From your local device
ssh-copy-id jdoe@SUBDOMAIN.janedoe.com
tools/render_src.sh /tmp/homelab-rendered
tools/upload_src.sh SUBDOMAIN /tmp/homelab-rendered
```
