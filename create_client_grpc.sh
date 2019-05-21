#!/bin/bash
DEP_PREFIX=new-grpc
SERVICE_CIDR="10.10.10.20"

# create the template
echo "++++++++++ Creating template " ${DEP_PREFIX}-client-vm-template
gcloud beta compute instance-templates create ${DEP_PREFIX}-client-vm-template \
   --scopes=https://www.googleapis.com/auth/cloud-platform \
   --tags=http-td-tag,http-server,https-server \
   --image-family=debian-9 \
   --image-project=debian-cloud \
   --metadata=startup-script="#! /bin/bash
# Add a system user to run Envoy binaries. Login is disabled for this user
sudo adduser --system --disabled-login envoy
# Download and extract the Traffic Director tar.gz file
sudo wget -P /home/envoy https://storage.googleapis.com/traffic-director/beta/traffic-director-beta.tar.gz
sudo tar -xzf /home/envoy/traffic-director-beta.tar.gz -C /home/envoy
sudo cat << END > /home/envoy/traffic-director-beta/sidecar.env
ENVOY_USER=envoy
# Exclude the proxy user from redirection so that traffic doesn't loop back
# to the proxy
EXCLUDE_ENVOY_USER_FROM_INTERCEPT='true'
VPC_NETWORK_NAME=''
SERVICE_CIDR='${SERVICE_CIDR}'
ENVOY_PORT='15001'
LOG_DIR='/var/log/envoy/'
LOG_LEVEL='info'
XDS_SERVER_CERT='/etc/ssl/certs/ca-certificates.crt'
END
sudo apt-get update -y
sudo apt-get install apt-transport-https ca-certificates curl gnupg2 software-properties-common -y
sudo curl -fsSL https://download.docker.com/linux/debian/gpg | sudo apt-key add -
sudo add-apt-repository 'deb [arch=amd64] https://download.docker.com/linux/debian stretch stable' -y
sudo apt-get update -y
sudo apt-get install docker-ce -y
sudo /home/envoy/traffic-director-beta/pull_envoy.sh
sudo /home/envoy/traffic-director-beta/run.sh
echo '<!doctype html><html><body><h1>'\`/bin/hostname\`'</h1></body></html>' | sudo tee /var/www/html/index.html"

# Create the Clients
echo "++++++++++ Creating Clients " ${DEP_PREFIX}-client-asia-south ${DEP_PREFIX}-client-us-west
gcloud compute instances create ${DEP_PREFIX}-client-asia-south \
  --source-instance-template ${DEP_PREFIX}-client-vm-template \
  --zone asia-south1-a

gcloud compute instances create ${DEP_PREFIX}-client-us-west \
  --source-instance-template ${DEP_PREFIX}-client-vm-template \
  --zone us-west1-b
