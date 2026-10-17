# nextjs: traps in server action files, bound arguments, redirects and forms

Read when you write or review a "use server" file, bind an argument, redirect from an action, or build a form.

- Every exported function in a `"use server"` file is a POST endpoint,
  callable from any browser with any arguments, whether or not a form uses
  it. A helper such as `removeInvoices(orgId, ids)` exported beside the
  actions is an open door; keep helpers unexported or in a `server-only`
  module.
- `action.bind(null, orgId)` in a server component does not make `orgId`
  trusted: the bound value travels through the browser, and the action is
  an endpoint any client can call with any first argument. Hidden inputs
  are the same. Neither carries authority; read the tenant from the
  session inside the action.
- `redirect()` and `notFound()` work by throwing. A `try` around
  `requireSession()` or around code that redirects turns "signed out" into
  a generic error message; keep them outside the `try` or call
  `unstable_rethrow(e)` first in the `catch`.
- React 19 resets an uncontrolled form when its action settles, so a
  failed save wipes what the user typed and shows the old `defaultValue`.
  Return the submitted values in the error state and render them as the
  defaults (key the form on the state so they apply).
