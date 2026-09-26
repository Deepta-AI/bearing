FROM golang:1.25 AS build
WORKDIR /src
COPY go.mod ./
COPY . .
RUN CGO_ENABLED=0 go build -o /out/pricing-api ./cmd/api

FROM gcr.io/distroless/static-debian12
COPY --from=build /out/pricing-api /pricing-api
EXPOSE 8080
ENTRYPOINT ["/pricing-api"]
