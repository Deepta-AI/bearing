FROM golang:1.25 AS build
WORKDIR /src
COPY . .
RUN CGO_ENABLED=0 go build -o /out/web ./cmd/web \
 && CGO_ENABLED=0 go build -o /out/worker ./cmd/worker

FROM gcr.io/distroless/static
COPY --from=build /out/ /bin/
ENTRYPOINT ["/bin/web"]
