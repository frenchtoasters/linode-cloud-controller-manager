PLATFORM ?= linux/amd64
REGISTRY_NAME = index.docker.io/linode
IMAGE_NAME = linode-cloud-controller-manager
IMAGE_VERSION ?= canary
IMAGE_TAG=$(REGISTRY_NAME)/$(IMAGE_NAME):$(IMAGE_VERSION)
REV=$(shell git describe --long --tags --dirty)

export GO111MODULE=on

.PHONY: all
all: build

.PHONY: clean
clean:
	go clean .
	rm -r dist/*

.PHONY: codegen
codegen:
	go generate ./...

.PHONY: lint
lint:
	docker run --rm -v "$(shell pwd):/var/work:ro" -w /var/work \
		golangci/golangci-lint:v1.44.0 golangci-lint run -v --timeout=5m

.PHONY: fmt
fmt:
	go fmt ./...

.PHONY: test
# we say code is not worth testing unless it's formatted
test: fmt codegen
	go test -v -cover ./cloud/... $(TEST_ARGS)

.PHONY: build-linux
build-linux: codegen
	echo "cross compiling linode-cloud-controller-manager for linux/amd64" && \
		GOOS=linux GOARCH=amd64 \
		CGO_ENABLED=0 \
		go build -o dist/linode-cloud-controller-manager-linux-amd64 .

.PHONY: build
build: codegen
	echo "compiling linode-cloud-controller-manager" && \
		CGO_ENABLED=0 \
		go build -o dist/linode-cloud-controller-manager .

.PHONY: imgname
# print the Docker image name that will be used
# useful for subsequently defining it on the shell
imgname:
	echo IMG=${IMG}

.PHONY: docker-build
docker-build:
	DOCKER_BUILDKIT=1 docker build --platform=$(PLATFORM) --progress=plain -t $(IMAGE_TAG) --build-arg REV=$(REV) -f Dockerfile .

.PHONY: docker-push
# must run the docker build before pushing the image
docker-push:
	echo "[reminder] Did you run `make docker-build`?"
	docker push ${IMG}

.PHONY: run
# run the ccm locally, really only makes sense on linux anyway
run: build
	dist/linode-cloud-controller-manager \
		--logtostderr=true \
		--stderrthreshold=INFO \
		--kubeconfig=${KUBECONFIG}

.PHONY: run-debug
# run the ccm locally, really only makes sense on linux anyway
run-debug: build
	dist/linode-cloud-controller-manager \
		--logtostderr=true \
		--stderrthreshold=INFO \
		--kubeconfig=${KUBECONFIG} \
		--linodego-debug


