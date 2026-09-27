FROM golang:1.25 AS build
ARG GIT_SHA=dev
WORKDIR /src
COPY . .
RUN CGO_ENABLED=0 go build -tags pgx -ldflags "-X main.version=${GIT_SHA}" -o /out/orders-api ./cmd/api

FROM gcr.io/distroless/static
COPY --from=build /out/orders-api /orders-api
EXPOSE 8080
ENTRYPOINT ["/orders-api"]
