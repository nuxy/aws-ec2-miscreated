#!/bin/sh
#
# EC2 instance Docker provision script.
#
# Copyright 2022, Marc S. Brooks (https://mbrooks.info)
# Licensed under the MIT license:
# http://www.opensource.org/licenses/mit-license.php
#
#  Notes:
#   - This script has been tested to work with RHEL & CentOS
#   - This script must be run as root

IP_ADDR=`curl http://169.254.169.254/latest/meta-data/public-ipv4`
HOSTNAME=`curl http://169.254.169.254/latest/meta-data/local-hostname`

# Install dependencies.
yum -y install https://s3.amazonaws.com/ec2-downloads-windows/SSMAgent/latest/linux_amd64/amazon-ssm-agent.rpm

amazon-linux-extras install docker

service docker start && chkconfig docker on

# Create 4GB swapfile (support t2.medium)
dd if=/dev/zero of=/swapfile bs=128M count=32

if [ -f /swapfile ]; then
    chmod 600 /swapfile
    mkswap /swapfile
    swapon -s
    echo "/swapfile swap swap defaults 0 0" >> /etc/fstab
fi

# Spoof public network (as systemd unit).
cat << EOF > /etc/systemd/system/spoof-network.service
[Unit]
Description=Miscreated network issue workaround.
After=network.target
After=network-online.target

[Service]
ExecStart=/bin/sh -c 'exec /sbin/ip a add $IP_ADDR/24 dev eth0 && echo "127.0.0.1 $HOSTNAME" >> /etc/hosts'
TimeoutSec=30

[Install]
WantedBy=multi-user.target
EOF

systemctl enable spoof-network
systemctl start spoof-network

# Resolve internal DNS
echo "nameserver  208.67.222.222" > /etc/resolv.conf

# Launch the game server.
CONTAINER_ID=`docker run -d --network host --restart always marcsbrooks/docker-miscreated-server:latest`

# Create game server (restart) cronjob.
echo "0 0 * * * /bin/docker exec $CONTAINER_ID /usr/sbin/service game-server restart > /dev/null" > /var/spool/cron/root
