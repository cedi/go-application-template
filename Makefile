VERSION=`git describe --tags`
BUILD=`date +%FT%T%z`
COMMIT=`git rev-parse HEAD`

# Setup the -ldflags option for go build here, interpolate the variable values
LDFLAGS=-X main.version=${VERSION} \
	-X main.date=${BUILD} \
	-X main.commit=${COMMIT} \
	-X main.builtBy=Makefile

LDFLAGS_BUILD=-ldflags "${LDFLAGS}"
LDFLAGS_RELEASE=-ldflags "-s -w ${LDFLAGS}"

OUTPUT_OBJ=-o build/main

MAIN_GO=./main.go

.PHONY: all
all: tidy analyze build install

.PHONY: build
build: build_dir 
	go build ${LDFLAGS_BUILD} ${OUTPUT_OBJ} ${MAIN_GO}

.PHONY: release
release: clean build_dir analyze
	go build ${LDFLAGS_RELEASE} ${OUTPUT_OBJ} ${MAIN_GO}

.PHONY: test
test: build_dir tidy analyze
	go test -covermode=count -coverprofile=./build/profile.out ./...
	if [ -f ./build/profile.out ]; then go tool cover -func=./build/profile.out; fi

.PHONY: bench
bench: build_dir
	go test -o=./build/bench.test -bench=. -benchmem .
	go test -o=./build/bench.test -cpuprofile=./build/cpuprofile.out .
	go test -o=./build/bench.test -memprofile=./build/memprofile.out .
	go test -o=./build/bench.test -blockprofile=./build/blockprofile.out .
	go test -o=./build/bench.test -mutexprofile=./build/mutexprofile.out ./.

.PHONY: trace
trace: build_dir
	go test -trace=./build/trace.out .
	if [ -f ./build/trace.out ]; then go tool trace ./build/trace.out; fi

.PHONY: test_all
test_all: test
	go test all

.PHONY: install
install:
	cp ./build/cmap ${GOPATH}/bin/

.PHONY: clean
clean:
	rm -rf ./build
	go clean -cache

.PHONY: analyze
analyze: fmt vet lint cyclo

.PHONY: fmt
fmt:
	gofmt -w -s -d .

.PHONY: vet
vet: lint cyclo
	go vet ./...

.PHONY: tidy
tidy:
	go mod tidy
	go mod verify

.PHONY: lint
lint:
	golint ./...

.PHONY: cyclo
cyclo:
	gocyclo -avg -over 15 -ignore "_test|Godeps|vendor/" -total .

.PHONY: build_dir
build_dir:
	mkdir -p ./build/