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

[ -d /root/.build ] && exit 0

# Install dependencies.
yum -y install https://s3.amazonaws.com/ec2-downloads-windows/SSMAgent/latest/linux_amd64/amazon-ssm-agent.rpm
yum -y install git

amazon-linux-extras install docker

service docker start && chkconfig docker on

git clone --recurse-submodules https://github.com/nuxy/aws-ec2-miscreated.git /root/.build

# Launch the game server.
docker build -t steamcmd /root/.build/.docker-steamcmd-wine --build-arg APPID=302200 --build-arg RUNCMD="Bin64_dedicated/MiscreatedServer.exe +http_startserver +map islands +sv_maxplayers 10 -sv_port 27015 +sv_servername \"Miscreated\""

docker run -it -p 27015:27050 -p 27015:27050/udp steamcmd
