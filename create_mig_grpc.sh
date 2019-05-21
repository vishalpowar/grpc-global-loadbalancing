#!/bin/bash
# set the VIP
VIP=10.10.10.20
DEP_PREFIX=auto-grpc-
GRPC_PORT=5000

# create the template
echo "++++++++++ Creating template " ${DEP_PREFIX}td-vm-template
gcloud beta compute instance-templates create ${DEP_PREFIX}td-vm-template \
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
SERVICE_CIDR='*'
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

# Create the MIG
echo "++++++++++ Creating MIG " ${DEP_PREFIX}td-vm-mig-us-central1
gcloud beta compute instance-groups managed create us-central-auto \
    --zone us-central1-a --size=2 --template=${DEP_PREFIX}td-vm-template

gcloud beta compute instance-groups managed create asia-south-auto \
    --zone asia-south1-a --size=2 --template=${DEP_PREFIX}td-vm-template

gcloud compute instance-groups set-named-ports asia-south-auto \
  --zone asia-south1-a --named-ports=${DEP_PREFIX}port:${GRPC_PORT}

gcloud compute instance-groups set-named-ports us-central-auto \
  --zone us-central1-a --named-ports=${DEP_PREFIX}port:${GRPC_PORT}

# Create health check
echo "++++++++++ Creating Health Check " ${DEP_PREFIX}td-vm-health-check
gcloud beta compute health-checks create http ${DEP_PREFIX}td-vm-health-check

# Create backend service
echo "++++++++++ Creating Backend Service " ${DEP_PREFIX}td-vm-service
gcloud beta compute backend-services create ${DEP_PREFIX}td-vm-service \
    --global \
    --load-balancing-scheme=INTERNAL_SELF_MANAGED \
    --protocol=HTTP2 \
    --port-name=${DEP_PREFIX}port \
    --health-checks ${DEP_PREFIX}td-vm-health-check

gcloud beta compute backend-services add-backend ${DEP_PREFIX}td-vm-service \
    --instance-group us-central-auto \
    --instance-group-zone us-central1-a \
    --global

gcloud beta compute backend-services add-backend ${DEP_PREFIX}td-vm-service \
    --instance-group asia-south-auto \
    --instance-group-zone asia-south1-a \
    --global

# Create routing rules
echo "++++++++++ Creating Routing Rules " ${DEP_PREFIX}td-vm-url-map
gcloud beta compute url-maps create ${DEP_PREFIX}td-vm-url-map \
   --default-service ${DEP_PREFIX}td-vm-service

# Create target proxy
echo "Creating target proxy " ${DEP_PREFIX}td-vm-proxy
gcloud beta compute target-http-proxies create ${DEP_PREFIX}td-vm-proxy \
   --url-map ${DEP_PREFIX}td-vm-url-map

# Create forwarding rule for grpc
echo "Creating forwarding rule " ${DEP_PREFIX}td-vm-forwarding-rule
gcloud beta compute forwarding-rules create ${DEP_PREFIX}td-vm-forwarding-rule \
   --global \
   --load-balancing-scheme=INTERNAL_SELF_MANAGED \
   --address=${VIP} --address-region=us-central1 \
   --target-http-proxy=${DEP_PREFIX}td-vm-proxy \
   --ports ${GRPC_PORT} \
   --network default

# Setup the port
gcloud beta compute firewall-rules create rule80 --allow=tcp:80
