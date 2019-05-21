#!/bin/bash

# Start both gRPC server and http server for health.
if [ "$1" = "startall" ]; then
  sudo ./server &
# Start just the gRPC server
elif [ "$1" = "start" ]; then
  sudo ./server --start_http=false &
# Bring down the server instance.
elif [ "$1" = "stop" ]; then
  sudo pkill -9 server
else
  echo "grpc_server.sh [startall|start|stop]"
fi
