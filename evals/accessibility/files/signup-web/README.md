# Tallyfield web

Server-rendered web front end for Tallyfield: public signup, sign-in and the
admin reports page. Plain Node (22+), no npm dependencies, no client framework
(see docs/adr/0002-server-rendered-no-dependencies.md).

## Run

    make run      # http://localhost:3000/signup
    make check    # unit tests (node --test)

## Layout

- src/server.js: routes and form handling
- src/views/: HTML templates (layout, signup, welcome, reports)
- src/validate.js: signup validation
- public/: styles.css and signup.js (progressive enhancement only)
- docs/design/: tokens and copy from design
