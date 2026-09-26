# Breaking changes checklist (manual diff)

Read the old and the new spec side by side. Every item is a yes or no
per operation; count the yeses as breaking. `oasdiff breaking` covers
the same list when installed.

## Breaking

- A path or an operation removed or renamed.
- A required request parameter or body field added.
- A request field removed (clients still send it: harmless) is not
  breaking; a request field retyped is.
- A response field removed, renamed, retyped, or made nullable when it
  was not.
- A response status code removed, or a success code changed (200 to 201).
- An enum narrowed (a value removed) in a response; an enum widened in
  a request.
- A string pattern tightened, a max length lowered, a min raised, in a
  request.
- Authentication scheme changed or a scope added to an operation.
- Pagination shape changed (page to cursor) or a default page size
  lowered.
- Content type removed from `requestBody` or `responses`.
- A header the client must send added; a header the client relied on
  removed.
- Error envelope shape changed.

## Not breaking

- A new path or operation.
- An optional request field or parameter added.
- A response field added.
- An enum widened in a response.
- A constraint loosened in a request.
- A new optional header.
- Documentation, examples, descriptions.

## Count line

`operations compared: N, breaking: B, non-breaking: C (manual)`
