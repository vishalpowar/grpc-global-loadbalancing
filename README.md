# gRP global loadbalancing
Sample scripts and steps to demonstrate global load balancing of gRPC server using envoy sidecar proxy.

## Background
The steps and scripts in this project setup GCE environment for gRPC service and clients. The example here uses Traffic Director (GCP) as load balancer, but istio can also be configured to provide the same functionality.

NOTE: As time passes the scripts and the steps mentioned here will get stale. Please refer to actual GCP documentation for update steps and commands to configured GCE and Traffic Director (GCP).

## Sample gRPC application 
The sample gRPC application creates gRPC service on the passed port (defaults to :5000), and optionally starts a http service to report the health of the service (running on port :80). The gRPC service can be configured to run on :80 in which case there is no need to start the http service.

The sample gRPC service returns the hostname of the server.

### gRPC client 
The gRPC client accumulates the rpc status and reports the following for every 50 consecutive requests.

-- Region (which served the request)
   + -- Hosts (which served the request)
   
This will enable us to see how the requests from the clients, move from one region to another in case of failures.
