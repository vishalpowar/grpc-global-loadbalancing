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

// Package main implements a client for Greeter service.
package main

import (
	"context"
	"log"
	"os"
	"time"
	"flag"
	"strings"
	"html/template"
	"net/http"

	"google.golang.org/grpc"
	pb "google.golang.org/grpc/examples/helloworld/helloworld"
)

const (
	defaultName = "world"
)

type HostServer struct {
	HostName string
	Count int
}

type Continent struct {
	Name string
	Hosts []HostServer
}

type Row struct {
	Continents []Continent
	Time string
}

type TodoPageData struct {
	PageTitle string
	Rows []Row
}

func parse_response(response string) (string, string) {
	msgpart := strings.Split(response, " ");
	results := strings.Split(msgpart[1], "-");
	return results[0], msgpart[1]
}

var gRows []Row
var pRows []Row

func main() {
	address := flag.String("server", "localhost:5000", "a string")
	flag.Parse()

	// Start a simple Web server which returns rpc stats.
	go func() {
		name, err := os.Hostname();
		if err != nil {
			name = "Foobar"
		}
		tmpl := template.Must(template.ParseFiles("layout.html"))
		http.HandleFunc("/", func(w http.ResponseWriter, r *http.Request) {
			data := TodoPageData{
				PageTitle: "Request from :" + name,
				Rows: gRows,
			}
			tmpl.Execute(w, data)
		})
		log.Fatal(http.ListenAndServe(":80", nil))
	}()

	// Set up a connection to the server.
	conn, err := grpc.Dial(*address, grpc.WithInsecure())
	if err != nil {
		log.Fatalf("did not connect: %v", err)
	}
	defer conn.Close()
	c := pb.NewGreeterClient(conn)

	// Once started run forever
	for {
		var c_map = map[string]map[string]int{
			"us" : make(map[string]int),
			"asia" : make(map[string]int),
		}

		for i := 0; i < 50; i++ {
			/// Contact the server and print out its response.
			name := defaultName
			ctx, cancel := context.WithTimeout(context.Background(), time.Second)
			defer cancel()
			r, err := c.SayHello(ctx, &pb.HelloRequest{Name: name})
			if err != nil {
				log.Fatalf("could not greet: %v", err)
			}
			log.Printf("Greeting [%d]: %s", i, r.Message)
			continent, host := parse_response(r.Message)
			//log.Printf("\t %s %s", continent, host)
			val := c_map[continent]
			hval := val[host] + 1
			val[host ] = hval
		}

		var r Row
		for k, v := range c_map {
			continent := Continent {Name : k, Hosts : []HostServer{} }
			log.Printf("continent:%s \n", k)
			for k, v := range v {
				host := HostServer {HostName : k, Count : v}
				continent.Hosts = append(continent.Hosts, host)
				log.Printf("host:%s rpc: %d\n", k, v)
			}
			r.Continents = append(r.Continents, continent)
		}
		r.Time = time.Now().Format("2006.01.02 15:04:05")
		gRows = append(gRows, r)
		pRows = append(pRows, r)
		pRows = append(pRows, gRows...)
		gRows = pRows
		pRows = nil
	}
}
