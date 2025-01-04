# Render and install website files

## Install tools
- Basics
```bash
brew install fd yq yamllint
pip3 install jinjanator jinjanator-plugin-ansible passlib mkdocs
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
ssh-copy-id {{ username }}@websvcs.{{ site.url }}
git clone {{ webrepo }} homesite
cd homesite
# Fill in personal details based on vars.template.yml
vim vars.yml
tools/deploy_src.sh
```
