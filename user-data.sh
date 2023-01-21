#!/bin/sh
#
# EC2 instance Docker provision script.
#
# Copyright 2022-2023, Marc S. Brooks (https://mbrooks.info)
# Licensed under the MIT license:
# http://www.opensource.org/licenses/mit-license.php
#
#  Notes:
#   - This script has been tested to work with RHEL & CentOS
#   - This script must be run as root

# Concurrent player total.
MAX_PLAYERS=10

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
ExecStart=/bin/sh -c 'exec /sbin/ip a add $IP_ADDR/24 dev eth0 && echo "$IP_ADDR $HOSTNAME" >> /etc/hosts'
TimeoutSec=30

[Install]
WantedBy=multi-user.target
EOF

systemctl enable spoof-network
systemctl start spoof-network

# Launch the game server.
CONTAINER_ID=`docker run -d --network host --restart always marcsbrooks/docker-miscreated-server:latest`

# Miscreated (Patch 1.18.1) workaround.
RUNCMD="Bin64_dedicated/MiscreatedServer.exe -sv_bind $IP_ADDR +sv_servername 'Miscreated' +sv_maxplayers $MAX_PLAYERS +http_startserver +map islands"
echo -e "HEADLESS=yes\nRUNCMD=\"$RUNCMD\"" > /tmp/.game-server

docker cp /tmp/.game-server $CONTAINER_ID:/usr/games

rm -f /tmp/.game-server

# Create game server (restart) cronjob.
echo "0 0 * * * /bin/docker exec $CONTAINER_ID /usr/sbin/service game-server restart > /dev/null" > /var/spool/cron/root
