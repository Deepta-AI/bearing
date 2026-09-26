FROM golang:1.26 AS build
WORKDIR /src
# go.sum is committed (make setup writes it); the glob keeps a first build
# working before it exists, at the cost of an unpinned resolution.
COPY go.mod go.sum* ./
RUN if [ -f go.sum ]; then go mod download; else echo "lockfile: no go.sum committed, resolving unpinned (run go mod tidy and commit go.sum)"; fi
COPY . .
RUN CGO_ENABLED=0 go build -ldflags="-s -w" -o /out/api ./cmd/api

FROM gcr.io/distroless/static-debian12:nonroot
COPY --from=build /out/api /api
USER nonroot
EXPOSE 8080
ENTRYPOINT ["/api"]
