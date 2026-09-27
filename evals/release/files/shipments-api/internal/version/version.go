// Package version reports the running build's version at GET /version.
package version

// Version is the release version. Keep it equal to the VERSION file at the
// repository root; TestVersionMatchesFile fails when they drift.
const Version = "1.4.0"
