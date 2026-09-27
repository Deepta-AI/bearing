# tallyq

A small Go library for counting events in a sliding time window, with a
checksum on each snapshot so a restored counter can be verified.

    go get git.larkspur.dev/larkspur/tallyq

## Use

    w := tallyq.NewWindow(time.Minute, 60)
    w.Add(time.Now(), 1)
    fmt.Println(w.Sum(time.Now()))

`cmd/tallyq` reads timestamps on stdin and prints the per-minute count.

## Licence

Proprietary. Internal use only. See LICENSE.
