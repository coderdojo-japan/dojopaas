#!/usr/bin/env bash

# @sacloud-once

set -ex

apt-get update -y
apt-get upgrade -y
apt-get install ansible -y

sed -i -e "s/PermitRootLogin prohibit-password/PermitRootLogin no/" /etc/ssh/sshd_config
sed -i -e "s/#PasswordAuthentication yes/PasswordAuthentication no/" /etc/ssh/sshd_config

service ssh restart
