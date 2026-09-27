OVERLAYS := dev qa prod

.PHONY: check vet test kustomize

check: vet test kustomize
	@echo "check: passed"

vet:
	GOTOOLCHAIN=local go vet ./...

test:
	GOTOOLCHAIN=local go test ./...

kustomize:
	@n=0; for o in $(OVERLAYS); do \
	  c=$$(kubectl kustomize infra/k8s/overlays/$$o | grep -c '^kind:') || { echo "kustomize: $$o renders nothing" >&2; exit 1; }; \
	  echo "kustomize: $$o $$c resources"; n=$$((n+1)); done; \
	[ "$$n" -gt 0 ] || { echo "kustomize: 0 overlays checked" >&2; exit 1; }; echo "kustomize: $$n overlays"
