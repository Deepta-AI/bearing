# fleet-agent

Collects disk counters and CPU count from a Linux host and ships them to the
fleet collector every 30 seconds.

    make check     # vet, test, build (vendored, offline)
    ./bin/fleet-agent -endpoint https://collector.example.org/v1/metrics

Release 0.9.0 is due to go to a customer next week. See docs/distribution.md
for what the release tarball contains.
