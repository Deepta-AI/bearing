.PHONY: check deploy config-apply

check:
	pytest -q -p no:cacheprovider

# CI only. Rolls production out to an existing release tag.
deploy:
	@test -n "$(TAG)" || { echo "usage: make deploy TAG=vX.Y.Z"; exit 2; }
	./scripts/deploy.sh $(TAG)

# CI only. Pushes config/production.env to the running pods.
config-apply:
	./scripts/config-apply.sh config/production.env
