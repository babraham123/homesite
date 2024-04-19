# Render and install website files

## Install tools
- Basics
```bash
sudo su
cd /root
apt install -y fd-find python3-pip git
pip3 install --break-system-packages mkdocs-material jinjanator

# installs nvm, node and npm
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.7/install.sh | bash
nvm install 20
node -v
npm -v
```

- Install yq
```bash
YQ_VERSION=$(curl -s "https://api.github.com/repos/mikefarah/yq/releases/latest" | grep -Po '"tag_name": "v\K[0-9.]+')
wget "https://github.com/mikefarah/yq/releases/download/v${YQ_VERSION}/yq_linux_amd64.tar.gz" -O - | tar xz
mv yq_linux_amd64 /usr/bin/yq
./install-man-page.sh
rm -f yq* install-man-page.sh
```

- Install sass
```bash
SA_VERSION=$(curl -s "https://api.github.com/repos/sass/dart-sass/releases/latest" | grep -Po '"tag_name": "\K[0-9.]+')
wget "https://github.com/sass/dart-sass/releases/download/${SA_VERSION}/dart-sass-${SA_VERSION}-linux-x64.tar.gz" -O - | tar xz
mv dart-sass/sass /usr/bin
mv dart-sass/src /usr/bin
rm -rf dart-sass
```

## Render source
```bash
git clone {{ webrepo }} homesite
cd homesite
# Fill in personal details based on vars.template.yml
vim vars.yml
tools/update_src.sh
```
