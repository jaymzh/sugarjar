#!/bin/bash

sudo dnf install fedora-packager fedora-review rubygems-devel \
    rubygem-rspec rubygem-gem2rpm -y
sudo usermod -a -G mock vagrant
newgrp
echo 'jaymzh' > ~vagrant/.fedora.upn
mkdir ~vagrant/bin
cat > ~vagrant/bin/krb <<EOF
#!/bin/bash

kinit jaymzh@FEDORAPROJECT.ORG
EOF
chmod +x ~vagrant/bin/krb
