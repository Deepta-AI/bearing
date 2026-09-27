# linkd

The short-link service behind the marketing team's printed QR codes and
campaign emails. One binary, one JSON file of links.

    make build
    ./linkd -addr :8080 -data /var/lib/linkd/links.json

The form in `web/` is served by the marketing site's nginx; partners also
call the API directly from their own tools. See `docs/api.md`.

Branches merge to `main` by merge request; run `make check` before pushing.
