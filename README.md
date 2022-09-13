# aws-ec2-miscreated

Run a [Miscreated](https://miscreatedgame.com) game server in a AWS [EC2](https://aws.amazon.com/ec2) instance.

## Dependencies

- [AWS CLI](https://aws.amazon.com/cli)

## AWS requirements

In order to successfully deploy your application you must have [set-up your AWS Config](https://docs.aws.amazon.com/config/latest/developerguide/gs-cli.html) and have [created an IAM user](https://docs.aws.amazon.com/IAM/latest/UserGuide/id_users_create.html) with the following [policies](https://docs.aws.amazon.com/IAM/latest/UserGuide/access_policies_manage.html):

- [IAMFullAccess](https://console.aws.amazon.com/iam/home#/policies/arn%3Aaws%3Aiam%3A%3Aaws%3Apolicy%2FIAMFullAccess)
- [AmazonEC2FullAccess](https://console.aws.amazon.com/iam/home#/policies/arn%3Aaws%3Aiam%3A%3Aaws%3Apolicy%2FAmazonEC2FullAccess)

WARNING: The policies above are provided to ensure a successful EC2 deployment.  It is recommended that you adjust these policies to meet the security requirements of your game server.  They should NOT be used in a Production environment.

## Performance concerns

A Miscreated server can currently use _up to 4GB of RAM_ when the game is fully loaded due to dynamic allocation of asset resources.  Furthermore, an _additional 30MB of RAM_ will be allocated for each concurrent player.  This should be considered when selecting the [AMI Instance Type](https://aws.amazon.com/ec2/instance-types) since resource usage determines cost.

## Launching the EC2 instance

    $ aws ec2 run-instances --image-id ami-05fa00d4c63e32376 --instance-type t2.medium --region us-east-1a --block-device-mappings file://block-device-mapping.json --user-data file://user-data.sh --associate-public-ip-address

## Managing the game server

The following command can be executed within the Docker container:

    $ service game-server {start|stop|restart}

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
