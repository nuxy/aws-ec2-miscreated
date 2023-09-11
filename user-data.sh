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

# Network device (Linux 1/2: eth0 | Linux 2023: ens5)
NET_DEV="eth0"

IP_ADDR=`curl http://169.254.169.254/latest/meta-data/public-ipv4`
HOSTNAME=`curl http://169.254.169.254/latest/meta-data/local-hostname`

# Install dependencies.
yum -y install https://s3.amazonaws.com/ec2-downloads-windows/SSMAgent/latest/linux_amd64/amazon-ssm-agent.rpm
yum -y install docker

if [ "$NET_DEV" = "ens5" ]; then
  yum -y install cronie cronie-anacron

  systemctl enable crond.service
  systemctl start crond.service
fi

service docker start && chkconfig docker on

# Create 8GB swapfile (support t3.medium)
dd if=/dev/zero of=/swapfile bs=128M count=64

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
ExecStart=/bin/sh -c '/sbin/ip a add $IP_ADDR/24 dev $NET_DEV && echo "$IP_ADDR $HOSTNAME" >> /etc/hosts'
TimeoutSec=30

[Install]
WantedBy=multi-user.target
EOF

systemctl enable spoof-network

# Launch the game server.
CONTAINER_ID=`docker run -d --network host --restart always marcsbrooks/docker-miscreated-server:latest`

#
# Miscreated (Patch 1.18.x) workarounds.
#

# Set IP address (non-UGC default).
RUNCMD="Bin64_dedicated/MiscreatedServer.exe -sv_bind $IP_ADDR +sv_servername 'Miscreated' +sv_maxplayers $MAX_PLAYERS +http_startserver +map islands"
echo -e "HEADLESS=yes\nRUNCMD=\"$RUNCMD\"" > /tmp/.game-server

docker cp /tmp/.game-server $CONTAINER_ID:/usr/games && rm -f /tmp/.game-server

# Create game server cron tasks.
cat << EOF > /var/spool/cron/root
CONTAINER_ID=$CONTAINER_ID

# Restart the server.
0 0 * * * /bin/docker restart \$CONTAINER_ID > /dev/null

# Keep-alive process.
* * * * * if [[ ! \$(pgrep -f Miscreated) ]]; then /bin/docker restart \$CONTAINER_ID > /dev/null; fi
EOF

# Restart the instance.
shutdown -r now
