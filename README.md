# aws-ec2-miscreated

Run a [Miscreated](https://miscreatedgame.com) game server in a AWS [EC2](https://aws.amazon.com/ec2) instance.

## Dependencies

- [AWS CLI](https://aws.amazon.com/cli)

### AWS requirements

In order to successfully deploy your application you must have [set-up your AWS Config](https://docs.aws.amazon.com/config/latest/developerguide/gs-cli.html) and have [created an IAM user](https://docs.aws.amazon.com/IAM/latest/UserGuide/id_users_create.html) with the following [policies](https://docs.aws.amazon.com/IAM/latest/UserGuide/access_policies_manage.html):

- [IAMFullAccess](https://console.aws.amazon.com/iam/home#/policies/arn%3Aaws%3Aiam%3A%3Aaws%3Apolicy%2FIAMFullAccess)
- [AmazonEC2FullAccess](https://console.aws.amazon.com/iam/home#/policies/arn%3Aaws%3Aiam%3A%3Aaws%3Apolicy%2FAmazonEC2FullAccess)

WARNING: The policies above are provided to ensure a successful EC2 deployment.  It is recommended that you adjust these policies to meet the security requirements of your game server.  They should NOT be used in a Production environment.

## Performance concerns

A Miscreated server can currently use _up to 4GB of RAM_ when the game is fully loaded due to dynamic allocation of asset resources.  Furthermore, an _additional 30MB of RAM_ will be allocated for each concurrent player.  This should be considered when selecting the [AMI Instance Type](https://aws.amazon.com/ec2/instance-types) since resource usage determines cost.

### Reducing operation costs

In order to meet the [game system requirements](#performance-concerns), while also being able to run a smaller EC2 instance type (currently `t3.small`), as part of the build process [I allocate 8GB of swap space](https://github.com/nuxy/aws-ec2-miscreated/blob/master/user-data.sh#L28) to the host OS.  Doing so allows me to reduce my hosting costs by 70%.. That said, I have created the chart below to be used as a guide in the EC2 instance selection process.

| Total users | Instance type | Volume (size/type) |
|-------------|---------------|--------------------|
| 1  to 10    | `t3.small`    | 30 GB / [gp2](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/ebs-volume-types.html#vol-type-ssd) |
| 11 to 50    | `t3.medium`   | 30 GB / gp2        |
| > 50        | `t3.large`    | 30 GB / gp2        |

## Launching the EC2 instance

    $ aws ec2 run-instances --image-id ami-05fa00d4c63e32376 --instance-type t3.small --region us-east-1a --block-device-mappings file://block-device-mapping.json --user-data file://user-data.sh --associate-public-ip-address

## Logging into your server

As part of the installation process an [SSM Agent](https://docs.aws.amazon.com/systems-manager/latest/userguide/prereqs-ssm-agent.html) is added which allows you to access your server using the [Amazon EC2 Console](https://docs.aws.amazon.com/systems-manager/latest/userguide/session-manager-working-with-sessions-start.html#start-ec2-console).  No SSH keys, port 22 routing necessary.

### Accessing the container

    $ docker exec -it <container-id> /bin/bash

## Game server defaults

The container comes with a vanilla installation of [Miscreated Dedicated Server](https://steamdb.info/app/302200) which is configured to support _up to 10 players_ and broadcasts the server name "Miscreated".  The server binds TCP/UDP ports 64090-64094 which needs to be opened using [EC2 Security Groups](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/working-with-security-groups.html#creating-security-group).  Furthermore, it also **exposes the RCON (remote control system) which is NOT password protected** and should either be disabled by removing the `+http_startserver` runtime option or restricted by setting `http_password` in your `hosting.cfg` file.

### Miscreated (Patch 1.18.x, >= v1.0.1.1126)

Due to [recent changes](https://twitter.com/miscreatedgame/status/1615515730929410050) in the network stack the following items **must be addressed** prior to starting the server:

1. You **must provide the external IP address** during runtime using `-sv_bind <ip-address>` or the server will fail to initialize.
2. You can no longer override `+sv_servername` in your `hosting.cfg` file since this will always use the runtime defined value.
3. If you are using Steam UGC content **you must omit** `-sv_bind <ip-address>` from runtime options.

To update these defaults you will need to [access the container](#accessing-the-container) and run the following command as root:

    $ echo -e "HEADLESS=yes\nRUNCMD=\"Bin64_dedicated/MiscreatedServer.exe -sv_bind <ip-address> +sv_maxplayers <max-players> +sv_servername '<server-name>' +http_startserver +http_password '<password>' +map islands\"" > /usr/games/.game-server

Once updated you just need to [restart the server](#managing-the-game-server) and you're good to go.

## Managing the game server

The following command can be executed within the Docker container:

    $ service game-server {start|stop|restart}

## Overriding game sources

In cases where you have an existing game set-up (e.g. configuration, database, workshops) follow the steps below:

### Copy the files to the container

    $ docker cp hosting.cfg <container-id>:/usr/games/Steam/steamapps/common/MiscreatedServer/hosting.cfg
    $ docker cp miscreated.db <container-id>:/usr/games/Steam/steamapps/common/MiscreatedServer/miscreated.db

### Update the file permissions

    $ docker -it <container-id> /bin/chown games:games /usr/games/Steam/steamapps/common/MiscreatedServer/*
    $ docker -it <container-id> /bin/chmod 666 /usr/games/Steam/steamapps/common/MiscreatedServer/miscreated.dd

### Restart the game server

    $ docker -it <container-id> /usr/sbin/service game-server restart

Mirroring that of the existing game directory, files that already exist will be overwritten.

## Restart requirements

Since the performance of the game engine degrades significantly as time goes by, the game server **forces a restart every 24 hours**.  However, due to a bug in the game engine this results with the server shutting down permanently.  In order to mitigate this a cronjob has been added to the host OS that restarts the server at 0:00 UTC.

To ensure both the host OS and game server are synchronized, you will need to define `schedule_shutdown_utc=0.0` in your _hosting.cfg_ or `+schedule_shutdown_utc 0.0` overriding the [game server defaults](#game-server-defaults).  Failure to do so will result in the server shutting down until the next scheduled restart.

## Troubleshooting

The most common issue you will face is with **Steam UGC** availability.  For example, in the `server.log` below:

```txt
<06:52:24> [STEAM] UGC content: XXXXXXXXXX
<06:52:24> [Game Version]: RELEASE DEDICATED SERVER
<06:52:25> [STEAM] Download request made for content id: XXXXXXXXXX
<06:52:25> [STEAM] Download failed for content id: XXXXXXXXXX, code: 15
<06:52:25> [STEAM] This server will be forced to restart in 60 seconds.
```

This is likely the result of **Steam Connection Managers** [degradation](https://steamstat.us).

## References

- [What is Amazon Linux 2023](https://docs.aws.amazon.com/linux/al2023/ug/what-is-amazon-linux.html)
- [Miscreated game server list](https://servers.miscreatedgame.com)

## Contributions

If you fix a bug, or have a code you want to contribute, please send a pull-request with your changes.

## Versioning

This package is maintained under the [Semantic Versioning](https://semver.org) guidelines.

## License and Warranty

This package is distributed in the hope that it will be useful, but without any warranty; without even the implied warranty of merchantability or fitness for a particular purpose.

_aws-ec2-miscreated_ is provided under the terms of the [MIT license](http://www.opensource.org/licenses/mit-license.php)

[AWS](https://aws.amazon.com) is a registered trademark of Amazon Web Services, Inc.

## Author

[Marc S. Brooks](https://github.com/nuxy)
