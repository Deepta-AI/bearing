# Queuewell kiosk

Self check-in for outpatient clinics. A patient types the six character
booking code from their SMS and the last two digits of their birth year;
the kiosk marks them arrived and tells them where to wait.

## Hardware

Every clinic has the same kiosk: a 21.5 inch touchscreen mounted in
portrait, 1080 x 1920, running Chromium in kiosk mode at 100% zoom. It
stands in the waiting room at arm's length (about 60 cm) and the screen
can be read by people queuing behind the patient. Many patients are
elderly; some use it with a walking stick in one hand.

The kiosks sit on the clinic's network, which lets them reach the
Queuewell server and nothing else: no internet access, so every asset
the screens use is served by the kiosk server from static/.

The kiosk runs one light theme. There is no dark mode: the rooms are
lit and glare is the problem (docs/adr/0005-kiosk-accessibility.md).

## Run

    make run      # http://localhost:8080
    make check    # go vet and go test

## Layout

- cmd/kiosk: the server
- internal/kiosk: handlers and the display rules
- templates: the three kiosk screens (html/template)
- static/css: tokens.css (the design tokens) and kiosk.css
- docs/design/flows/kiosk-checkin: screens and copy
