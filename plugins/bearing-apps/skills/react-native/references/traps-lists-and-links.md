# react-native: traps in paginated lists, deep links and sessions

Read when the task touches useInfiniteQuery, deep links, sign in or sign out.

- `getNextPageParam` returns `undefined` when the cursor is null; the list
  calls `fetchNextPage` from `onEndReached` only when `hasNextPage &&
  !isFetchingNextPage` (it fires several times per scroll).
- A failed next page sets `isError` while `data` still holds the pages
  already loaded. Check `data` before `isError`, show the page error as a
  footer with retry (`isFetchNextPageError`), and never replace 60 loaded
  rows with a full-screen error.
- Refetch on focus refetches every loaded page in sequence: a customer 20
  pages deep makes 20 requests on each return to the app. Set `maxPages`,
  or a `staleTime` with a reason, on long histories.
- Keys come from the item id; flatten pages once (`select` or `useMemo`).

- A signed-out customer who opens a link must land on that target after
  sign in. The gate passes the path it blocked (`usePathname` plus params)
  to sign in as a `next` param; sign in accepts `next` only as an in-app
  path (one leading `/`, no `//`, no scheme, not an auth route, ideally
  matched against the routes that may be linked) and `router.replace`s to
  it, else to home.
- A cold-start deep link has no screen under it: export `unstable_settings
  = { initialRouteName: '(tabs)' }` from the group layout so Back returns
  to the tabs instead of closing the app.
- Sign out clears the query cache (`queryClient.clear()`, and any persisted
  cache). Otherwise the next person to sign in on a shared phone sees the
  previous customer's data until the refetch lands.
