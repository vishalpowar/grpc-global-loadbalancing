# gRP global loadbalancing
Sample scripts and steps to demonstrate global load balancing of gRPC server using envoy sidecar proxy.

## Background
The steps and scripts in this project setup GCE environment for gRPC service and clients. The example here uses Traffic Director (GCP) as load balancer, but istio can also be configured to provide the same functionality.

**NOTE: As time passes the scripts and the steps mentioned here will get stale. Please refer to actual GCP documentation for update steps and commands to configured GCE and Traffic Director (GCP).**

### Sample gRPC application 
The sample gRPC application creates gRPC service on the passed port (defaults to :5000), and optionally starts a http service to report the health of the service (running on port :80). The gRPC service can be configured to run on :80 in which case there is no need to start the http service.

The sample gRPC service returns the hostname of the server.

### Sample gRPC client 
The gRPC client accumulates the rpc status and reports for every 50 requests, the number of requests that were directed to a region(Continent) and the endpoint within that continent.
   
This will enable us to see how the requests from the clients, move from one region to another in case of failures.

## Setting up global loadbalancing

### Step 1: Create GCP project, and setup environment
Create GCP project (assuming project name as 'kubecon-2019' for subsequent steps).

As we will be running scripts to setup the configuration, enable the [gcloud command line](https://cloud.google.com/sdk/docs/#linux).

### Step 2: Enable support for Traffic Director API
Run the following command to enable Traffic Director for the project.
```
gcloud services enable trafficdirector.googleapis.com
```

### Step 3: Create VMs on two continents US and Asia
Run the script to create two VMs each on continents US and Asia.

```
./create_mig_grpc.sh
```

Check the GCP console to verify if the VMs for the servers are created. Also, check traffic director configuration and verify if two managed instance groups are created for the service.

**NOTE: The servers/endpoints will show up as unhealthy as we have not yet deployed the gRPC service on them.**

### Step 4: Build and deploy gRPC service on each VM
The greeter_server needs to be built locally before it can be deployed on the servers.

```
$ go build -o server helloworld/greeter_server/main.go
```

Copy over the 'server' binary and the grpc_server.sh script to each of the server VMs.

```
gcloud compute scp server <server-name>:~ --zone <server-zone>
gcloud compute scp grpc_server.sh <server-name>:~ --zone <server-zone>
```

SSH into each of the servers and start the service.

```
$gcloud compute --project "<project-id>" ssh --zone "<zone>" "<server-name>"
```

The server can be started by running the following command.

```
$ ./grpc_server.sh startall
```

Verify the traffic director configuration to see if both the managed instance groups are now healthy.

### Step 5: Create VMs for clients
Run the script to create one VMs each on continents US and Asia.
```
./create_client_grpc.sh
```
Check the GCP console to verify if the VMs for the clients are created.

### Step 6: Build and deploy gRPC clients on client VMs
The greeter client needs to be built locally before it can be deployed on the client VMs.

```
$ go build -o main_client helloworld/greeter_client/main.go
```

Copy over the 'main_client' binary, 'layout.html' (for rendering results) and start_client.sh to each of the client VMs.

```
gcloud compute scp main_client <client-name>:~ --zone <client-zone>
gcloud compute scp start_client.sh <client-name>:~ --zone <client-zone>
gcloud compute scp helloworld/greeter_client/layout.html <client-name>:~ --zone <client-zone>
```

### Step 7: Test the global loadbalancing 

Run the grpc_client on each of the client VMs, and check their results which are reported by the http server on those VMs.
```
$ ./start_client.sh
```
**NOTE: Find the external IP address of the client VM and use that ip address in the browser to see results.**

You can also bring down the gRPC servers on one or more servers to see its impact on the client by running.

```
$ ./grpc_server.sh stop
```

