IMAGE ?= registry.example.com/harbor/lab-intake
VERSION ?= $(shell git describe --tags --always)

.PHONY: run check build push

run:
	node src/server.js

check:
	node --test test/*.test.js

build:
	docker build -t $(IMAGE):$(VERSION) .

push: build
	docker push $(IMAGE):$(VERSION)

# Deploy targets (deploy, rollback) live in the shared platform makefile.
-include make/deploy.mk
