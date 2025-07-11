# Raspberry Pi setup
Guide to setup a Raspberry PI device.

## Prepare the SD card
- Flash a SD card with RPi OS: [src](https://www.cyberciti.biz/faq/how-to-create-disk-image-on-mac-os-x-with-dd-command/)
```bash
diskutil
```
- Install [macports](https://www.macports.org/install.php)
- Add the credentials to the boot image, [src](https://raspberrypi.stackexchange.com/a/145010/22576)
- old: [src](https://www.raspberrypi.com/documentation/computers/configuration.html), [notes](https://desertbot.io/blog/headless-raspberry-pi-4-ssh-wifi-setup), [WPA](https://android.googlesource.com/platform/external/wpa_supplicant_8/+/master-soong/wpa_supplicant/wpa_supplicant.conf#662), [wifi pass](https://android.googlesource.com/platform/external/wpa_supplicant_8/+/master/wpa_supplicant/wpa_supplicant.conf#1243)
```bash
touch /Volumes/bootfs/ssh
# Setup username and password (just openssl on Linux)
brew install openssl
/opt/homebrew/opt/openssl/bin/openssl passwd -6 | sed -e 's/^/USERNAME:/;' > /Volumes/bootfs/openconf
# Hash your WiFi password
# sudo apt -y install wpa_passphrase
sudo port install wpa_passphrase
wpa_passphrase "cool-house5" # then enter password
# Fill in the password hash
vim /Volumes/bootfs/wpa_supplicant.conf


# TODO: replace with custom.toml
```
- Add WPA2/3 support: [ref](https://github.com/raspberrypi/linux/issues/4976)
    - `vim /Volumes/bootfs/cmdline.txt`
    - Append `brcmfmac.feature_disable=0x82000`
- Kernel configs
	- `vim /Volumes/bootfs/config.txt`
- Eject SD card and plug into Pi
- Power on Pi (LED [status codes](https://pimylifeup.com/raspberry-pi-red-green-lights))

## Configure the OS
- Log in
```bash
ssh-keygen -R raspberrypi.local
ssh pi@raspberrypi.local
ip addr
```
- Basic [Debian Linux setup](./debian.md)
- Disable GUI, autologin ([src](https://linuxhint.com/disable-gui-raspberry-pi/)), expand fs
```bash
sudo raspi-config
sudo reboot

# on Mac
ssh-keygen -R raspberrypi.local
ssh jdoe@SUBDOMAIN.janedoe.com
```

## Networking
- Record the MAC address, `ip addr`
- In pfSense, create a static DHCP lease
  - Go to Services >> DHCP Server >> LAN >> DHCP Static Mappings

- Add a DNS record
  - Update `unbound.conf`
  - Go to Services >> DNS Resolver >> Custom options, paste in config
