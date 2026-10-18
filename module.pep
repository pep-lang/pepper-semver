## Semantic Versioning 2.0.0 (<https://semver.org>): parse versions, order
## them by the spec's precedence, and match them against ranges such as
## `^1.2`, `~1.2` and `>=1.0, <2`.
##
## Bring it in with `import semver`. Parsing is strict and safe for
## untrusted text: anything the spec does not allow is an error saying what
## is wrong.
##
## - `Version`, `parse`: one version and its order
## - `VersionRange`, `Comparison`, `parse_range`: ranges and matching
##
## @example
##     import semver;
##
##     main(): int {
##         var version = semver.parse("1.4.0-rc.1+build.7").value();
##         assert(version < semver.parse("1.4.0").value(), "a prerelease sorts first");
##         var range = semver.parse_range("^1.2").value();
##         assert(range.matches(semver.parse("1.9.3").value()), "in the range");
##         assert(!range.matches(version), "a prerelease must be named");
##         return 0;
##     }

# This file only gathers the module's public API from its other files.

import "range";
import "version";

export Version;
export parse;
export Comparison;
export VersionRange;
export parse_range;
