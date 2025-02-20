#!/bin/bash

sudo dnf install fedora-packager fedora-review rubygems-devel \
    rubygem-rspec rubygem-gem2rpm git vim -y
sudo usermod -a -G mock vagrant
newgrp
echo 'jaymzh' > ~vagrant/.fedora.upn
mkdir ~vagrant/bin
cat > ~vagrant/bin/krb <<EOF
#!/bin/bash

kinit jaymzh@FEDORAPROJECT.ORG
EOF
chmod +x ~vagrant/bin/krb

cat > ~vagrant/.gitconfig <<EOF
[user]
	name = Phil Dibowitz
	email = phil@ipom.com
EOF

cat >> ~vagrant/.bashrc <<'EOF'
source /usr/share/git-core/contrib/completion/git-prompt.sh
export PS1="[\u@\h\$(__git_ps1) \W]\$ "
export EDITOR=vim
EOF
