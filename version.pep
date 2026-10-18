## One version, `major.minor.patch` with an optional prerelease and build
## metadata (`1.0.0-beta.2+exp.sha.5114f85`), and its order: `Version` and
## `parse`.

## A version: `major.minor.patch`, with an optional prerelease after `-`
## and optional build metadata after `+`.
##
## Versions order by the spec's precedence (section 11): `compare` and the
## operators `<`, `<=`, `>`, `>=`, `==` and `!=` all follow it, so build
## metadata is ignored (`1.0.0+a == 1.0.0+b`) and a prerelease sorts before
## its release (`1.0.0-rc.1 < 1.0.0`). `to_string()` keeps the build.
##
## @example
##     var versions = [semver.parse("1.10.0").value(), semver.parse("1.9.0").value()];
##     versions.sort((a, b) => a.compare(b));   # 1.9.0, 1.10.0
export struct Version {
    ## The major version: incompatible API changes.
    var major: ulong = 0;
    ## The minor version: compatible additions.
    var minor: ulong = 0;
    ## The patch version: compatible fixes.
    var patch: ulong = 0;
    ## The prerelease identifiers joined by `.` (`alpha.1`), without the
    ## `-`; empty for a release.
    var prerelease: String = "";
    ## The build metadata identifiers joined by `.` (`exp.sha.5114f85`),
    ## without the `+`; empty when there is none.
    var build: String = "";

    ## Creates `0.0.0`.
    construct() {}

    ## Creates a release version.
    ##
    ## @param major the major version
    ## @param minor the minor version
    ## @param patch the patch version
    construct(major: ulong, minor: ulong, patch: ulong) {
        this.major = major;
        this.minor = minor;
        this.patch = patch;
    }

    ## Returns whether this is a prerelease (`1.0.0-alpha`).
    ##
    ## @returns true when `prerelease` is not empty
    is_prerelease(): bool {
        return !prerelease.is_empty;
    }

    ## Returns the version as the spec writes it: `1.2.3`, `1.2.3-rc.1`,
    ## `1.2.3-rc.1+build.5`.
    ##
    ## @returns the version's text, which `parse` reads back
    to_string(): String {
        var text = $"{major}.{minor}.{patch}";
        if (!prerelease.is_empty) {
            text = text + "-" + prerelease;
        }
        if (!build.is_empty) {
            text = text + "+" + build;
        }
        return text;
    }

    ## Returns the order of this version and `other` by the spec's
    ## precedence: major, minor and patch numerically; then a release after
    ## any of its prereleases; then the prerelease identifiers left to
    ## right, numeric ones numerically and below alphanumeric ones, which
    ## compare in ASCII order, and a longer list after its prefix. Build
    ## metadata is ignored.
    ##
    ## @param other the version to compare with
    ## @returns -1, 0 or 1 as this version sorts before, with or after
    ##   `other`
    compare(other: Version): int {
        if (major != other.major) {
            return major < other.major ? -1 : 1;
        }
        if (minor != other.minor) {
            return minor < other.minor ? -1 : 1;
        }
        if (patch != other.patch) {
            return patch < other.patch ? -1 : 1;
        }
        if (prerelease == other.prerelease) {
            return 0;
        }
        if (prerelease.is_empty) {
            return 1;
        }
        if (other.prerelease.is_empty) {
            return -1;
        }
        var mine = prerelease.split(".");
        var theirs = other.prerelease.split(".");
        var shared = mine.count < theirs.count ? mine.count : theirs.count;
        for (var i in 0..shared) {
            var order = _compare_identifiers(mine[i], theirs[i]);
            if (order != 0) {
                return order;
            }
        }
        if (mine.count == theirs.count) {
            return 0;
        }
        return mine.count < theirs.count ? -1 : 1;
    }

    ## Returns whether this version has the same precedence as `other`,
    ## ignoring build metadata.
    ##
    ## @param other the version to compare with
    ## @returns true when `compare(other) == 0`
    ==(other: Version): bool {
        return compare(other) == 0;
    }

    ## Returns whether this version's precedence differs from `other`'s.
    ##
    ## @param other the version to compare with
    ## @returns true when `compare(other) != 0`
    !=(other: Version): bool {
        return compare(other) != 0;
    }

    ## Returns whether this version sorts before `other`.
    ##
    ## @param other the version to compare with
    ## @returns true when `compare(other) < 0`
    <(other: Version): bool {
        return compare(other) < 0;
    }

    ## Returns whether this version sorts before or with `other`.
    ##
    ## @param other the version to compare with
    ## @returns true when `compare(other) <= 0`
    <=(other: Version): bool {
        return compare(other) <= 0;
    }

    ## Returns whether this version sorts after `other`.
    ##
    ## @param other the version to compare with
    ## @returns true when `compare(other) > 0`
    >(other: Version): bool {
        return compare(other) > 0;
    }

    ## Returns whether this version sorts after or with `other`.
    ##
    ## @param other the version to compare with
    ## @returns true when `compare(other) >= 0`
    >=(other: Version): bool {
        return compare(other) >= 0;
    }
}

# The order of two prerelease identifiers: numeric ones by value (by length
# first, since neither has a leading zero, so any length works), numeric
# before alphanumeric, alphanumeric ones in ASCII order.
_compare_identifiers(a: String, b: String): int {
    var a_numeric = _is_numeric(a);
    var b_numeric = _is_numeric(b);
    if (a_numeric != b_numeric) {
        return a_numeric ? -1 : 1;
    }
    if (a_numeric and a.length != b.length) {
        return a.length < b.length ? -1 : 1;
    }
    var order = a.compare(b);
    if (order == 0) {
        return 0;
    }
    return order < 0 ? -1 : 1;
}

_is_numeric(text: String): bool {
    if (text.is_empty) {
        return false;
    }
    for (var b in text.bytes()) {
        if (!(b as byte).is_digit()) {
            return false;
        }
    }
    return true;
}

# Why `text` is not a numeric identifier (digits, no leading zero) that
# fits a ulong, or empty when it is one.
_number_error(text: String, what: String): String {
    if (text.is_empty) {
        return $"the {what} version is empty";
    }
    if (!_is_numeric(text)) {
        return $"the {what} version '{text}' is not a number";
    }
    if (text.length > 1 and text.starts_with("0")) {
        return $"the {what} version '{text}' has a leading zero";
    }
    if (ulong.parse(text).is_empty()) {
        return $"the {what} version '{text}' is too large";
    }
    return "";
}

# Why the dot-separated identifiers `text` break the spec, or empty when
# they do not: each is non-empty and only ASCII letters, digits and `-`,
# and in a prerelease a numeric one has no leading zero.
_identifiers_error(text: String, what: String, prerelease: bool): String {
    for (var identifier in text.split(".")) {
        if (identifier.is_empty) {
            return $"the {what} '{text}' has an empty identifier";
        }
        for (var b in identifier.bytes()) {
            var c = b as byte;
            if (!c.is_alphanumeric() and c != '-') {
                return $"the {what} identifier '{identifier}' may hold only ASCII letters, digits and '-'";
            }
        }
        if (prerelease and _is_numeric(identifier) and identifier.length > 1 and identifier.starts_with("0")) {
            return $"the {what} identifier '{identifier}' has a leading zero";
        }
    }
    return "";
}

## Parses a version as the spec writes it: `1.2.3`, `1.2.3-rc.1`,
## `1.2.3+build.5`, `1.2.3-rc.1+build.5`.
##
## It is strict: exactly three numbers with no leading zeros, no `v`
## prefix, no spaces, and prerelease and build identifiers that are not
## empty and hold only ASCII letters, digits and `-` (and in a prerelease,
## numbers with no leading zero). A tag such as `v1.2.3` is parsed after
## dropping its `v`.
##
## @param text the version
## @returns the version, or an error saying what is wrong
## @example
##     var version = semver.parse("1.0.0-alpha.1").value();
##     assert(version.prerelease == "alpha.1", "the prerelease");
##     assert(semver.parse("1.2").is_err(), "three numbers");
export parse(text: String): Result<Version> {
    var rest = text;
    var version = Version();
    var with_build = rest.split_once("+");
    if (with_build.is_value()) {
        var (head, build) = with_build.value();
        var error = _identifiers_error(build, "build metadata", false);
        if (!error.is_empty) {
            return Result<Version>.Err($"invalid version '{text}': {error}");
        }
        rest = head;
        version.build = build;
    }
    var with_prerelease = rest.split_once("-");
    if (with_prerelease.is_value()) {
        var (head, prerelease) = with_prerelease.value();
        var error = _identifiers_error(prerelease, "prerelease", true);
        if (!error.is_empty) {
            return Result<Version>.Err($"invalid version '{text}': {error}");
        }
        rest = head;
        version.prerelease = prerelease;
    }
    var parts = rest.split(".");
    if (parts.count != 3) {
        return Result<Version>.Err($"invalid version '{text}': expected 'major.minor.patch'");
    }
    var names = ["major", "minor", "patch"];
    for (var i in 0..3) {
        var error = _number_error(parts[i], names[i]);
        if (!error.is_empty) {
            return Result<Version>.Err($"invalid version '{text}': {error}");
        }
    }
    version.major = ulong.parse(parts[0]).value();
    version.minor = ulong.parse(parts[1]).value();
    version.patch = ulong.parse(parts[2]).value();
    return Result<Version>.Ok(version);
}
