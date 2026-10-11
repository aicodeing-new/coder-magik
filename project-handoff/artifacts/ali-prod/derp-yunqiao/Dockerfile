FROM golang:1.26.5-bookworm AS builder
WORKDIR /build
COPY go.mod go.sum ./
RUN CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build -mod=readonly -trimpath -ldflags="-s -w" -o /out/derper tailscale.com/cmd/derper

FROM gcr.io/distroless/static-debian12:nonroot
COPY --from=builder /out/derper /usr/local/bin/derper
USER 65532:65532
EXPOSE 8080/tcp
ENTRYPOINT ["/usr/local/bin/derper"]
