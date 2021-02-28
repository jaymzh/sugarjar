#!/bin/bash

sudo dnf install fedora-packager fedora-review rubygems-devel -y
sudo usermod -a -G mock vagrant
newgrp
