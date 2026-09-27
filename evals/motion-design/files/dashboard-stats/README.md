# Tally dashboard

The merchant dashboard: today's revenue, orders, conversion and refund
rate, refreshed every 30 seconds. Plain ES modules, no build step, no
dependencies.

    make check    # node --test
    make serve    # python3 -m http.server 8080, then open http://localhost:8080

Design notes live in docs/design/DESIGN.md; the design tokens in
src/styles/tokens.css are the source of truth for colour, spacing and
motion.
