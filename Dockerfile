FROM golang:1.18-alpine AS builder
ARG REV

RUN mkdir -p /go/src/github.com/linode/linode-cloud-controller-manager/
WORKDIR /go/src/github.com/linode/linode-cloud-controller-manager/

COPY go.mod .
COPY go.sum .

COPY main.go .
COPY cloud ./cloud
COPY sentry ./sentry

RUN go mod download
RUN GOOS=linux GOARCH=amd64 CGO_ENABLED=0 go build -a -ldflags '-X main.vendorVersion='${REV}' -extldflags "-static"' -o /bin/linode-cloud-controller-manager-linux-amd64 .

FROM alpine:latest

RUN apk update && apk add ca-certificates && rm -rf /var/cache/apk/*

COPY --from=builder /bin/linode-cloud-controller-manager-linux-amd64 .

ENTRYPOINT ["/linode-cloud-controller-manager-linux-amd64"]
