# AWS ECR Login

This script and container aid in loging into AWS EC2 Container Registries (ECR) and updating the .dockercfg files on a host.

## Script Usage
```
./ecr-login.sh [options]
    -r|--region        If not provided, the region will be looked up via AWS metadata (optional on EC2-only).
    -g|--registries    The AWS account IDs to use for the login. Space separated. (Ex: "123456789101, 98765432101")
    -f|--file-location Where the dockercfg should be saved.
    -i|--interval      How often to loop and refresh credentials (optional - default is 21600 - 6 hours).
```

The script can be run from within a Docker container or stand-alone on either AWS infrastructure or traditional servers. When run in a container, you must mount the host path where you wish the `.dockercfg` file to be written.

### Docker Container
```
$ docker pull adobeplatform/aws-ecr-login
$ docker run --name aws-ecr-login -v /home/core:/home/core:rw -e "REGION=us-east-1" -e "REGISTRIES=12345678901" -e "FILE_LOCATION=/home/core/.dockercfg" -e "INTERVAL=21600"
```

### Usage on AWS Infrastructure
Running on AWS means that the region can be determined automatically via the AWS metadata service and does not need to be provided via the command line.

### Usage on Traditional Servers
Running on traditional servers means that the region must be provided. Failure to provide the region will result in the script hanging as it attempts to contact the (unavailable) AWS metadata service.

```
$ ./ecr-login.sh --region us-east-1 --registries 12345678901 --file-location /home/core/.dockercfg --interval 21600
```
