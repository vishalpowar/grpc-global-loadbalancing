/*
 *
 * Copyright 2015 gRPC authors.
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 *
 */

//go:generate protoc -I ../helloworld --go_out=plugins=grpc:../helloworld ../helloworld/helloworld.proto

// Package main implements a server for Greeter service.
package main

import (
	"context"
	"net"
	"os"
	"flag"
	"fmt"
	"log"
	"net/http"

	"google.golang.org/grpc"
	pb "google.golang.org/grpc/examples/helloworld/helloworld"
)

// server is used to implement helloworld.GreeterServer.
type server struct{}

// SayHello implements helloworld.GreeterServer
func (s *server) SayHello(ctx context.Context, in *pb.HelloRequest) (*pb.HelloReply, error) {
	log.Printf("Received: %v", in.Name)
	name, err := os.Hostname();
	if err != nil {
		name = "Foobar"
	}
	return &pb.HelloReply{Message: "Hello " + name}, nil
}

// Repond to http request with hostname
func handler(w http.ResponseWriter, r *http.Request) {
	name, err := os.Hostname();
	if err != nil {
		name = "Foobar"
	}
	fmt.Fprintf(w, "Hi, I am %s!", name)
}

func main() {
	port := flag.String("port", ":5000", "a string")
	start_http := flag.Bool("start_http", true, "a bool")
	flag.Parse()

	if *start_http {
		go func() {
			log.Printf("\nStarting http server")
			// Start a simple Web server which returns Hostname.
			http.HandleFunc("/", handler)
			log.Fatal(http.ListenAndServe(":80", nil))
		}()
	}

	// Create gRPC server on passed port.
	log.Printf("\nStarting gRPC server")
	lis, err := net.Listen("tcp", *port)
	if err != nil {
		log.Fatalf("failed to listen: %v", err)
	}
	s := grpc.NewServer()
	pb.RegisterGreeterServer(s, &server{})
	if err := s.Serve(lis); err != nil {
		log.Fatalf("failed to serve: %v", err)
	}
}
