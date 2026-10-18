## Version ranges and matching: `VersionRange`, `Comparison` and
## `parse_range`, which reads ranges the way Cargo does:
##
##     1.2, ^1.2     >=1.2.0, <2.0.0     (the leftmost nonzero part stays)
##     0.4, ^0.4     >=0.4.0, <0.5.0
##     ^0.0.3        >=0.0.3, <0.0.4
##     ~1.2          >=1.2.0, <1.3.0
##     ~1            >=1.0.0, <2.0.0
##     1.2.x, 1.2.*  >=1.2.0, <1.3.0
##     =1.2.3        exactly 1.2.3
##     =1.2          >=1.2.0, <1.3.0
##     >1.2          >=1.3.0
##     <=1.2         <1.3.0
##     >=1.0, <2     both comparisons
##     *             any release

import "version";

## One comparison of a range: `>=1.2.0`.
export struct Comparison {
    ## One of `>=`, `>`, `<=`, `<` and `=`.
    var operator: String = "=";
    ## The version compared with.
    var version: Version = Version();

    ## Creates `=0.0.0`.
    construct() {}

    ## Creates a comparison.
    ##
    ## @param operator one of `>=`, `>`, `<=`, `<` and `=`
    ## @param version the version compared with
    construct(operator: String, version: Version) {
        this.operator = operator;
        this.version = version;
    }

    ## Returns whether `candidate` passes the comparison, by precedence (so
    ## build metadata is ignored).
    ##
    ## @param candidate the version to test
    ## @returns true when `candidate` compares with `version` as `operator`
    ##   says
    matches(candidate: Version): bool {
        var order = candidate.compare(version);
        if (operator == ">=") {
            return order >= 0;
        }
        if (operator == ">") {
            return order > 0;
        }
        if (operator == "<=") {
            return order <= 0;
        }
        if (operator == "<") {
            return order < 0;
        }
        return order == 0;
    }

    ## Returns the comparison as text: `>=1.2.0`.
    ##
    ## @returns the operator followed by the version
    to_string(): String {
        return operator + version.to_string();
    }
}

## A version range: a version is in it when every comparison holds.
export struct VersionRange {
    ## The range as it was written.
    var text: String = "";
    ## The comparisons, all of which must hold; none for `*`.
    var comparisons: Array<Comparison> = __null;

    ## Creates the range `*`, which every release matches.
    construct() {
        comparisons = Array<Comparison>();
    }

    ## Returns whether `candidate` is in the range.
    ##
    ## A prerelease is in it only when a comparison names a prerelease of
    ## the same `major.minor.patch`, as Cargo and npm do, so `^1.2` never
    ## picks `1.3.0-beta` but `>=1.3.0-beta, <2` does.
    ##
    ## @param candidate the version to test
    ## @returns true when every comparison holds for `candidate`
    matches(candidate: Version): bool {
        if (candidate.is_prerelease() and !_names_prerelease_of(candidate)) {
            return false;
        }
        for (var comparison in comparisons) {
            if (!comparison.matches(candidate)) {
                return false;
            }
        }
        return true;
    }

    _names_prerelease_of(candidate: Version): bool {
        for (var comparison in comparisons) {
            var v = comparison.version;
            if (v.is_prerelease()
                and v.major == candidate.major
                and v.minor == candidate.minor
                and v.patch == candidate.patch) {
                return true;
            }
        }
        return false;
    }
}

# A partial version, `1`, `1.2` or `1.2.3`, with `x` or `*` allowed for a
# missing part: how many parts it gives, the version with the others 0, and
# whether it had a wildcard.
_partial(text: String): Result<(ulong, Version, bool)> {
    var numbers = Array<ulong>();
    var prerelease = "";
    var rest = text;
    var split = text.split_once("-");
    if (split.is_value()) {
        var (numbers_text, pre) = split.value();
        var error = _identifiers_error(pre, "prerelease", true);
        if (!error.is_empty) {
            return Result<(ulong, Version, bool)>.Err(error);
        }
        rest = numbers_text;
        prerelease = pre;
    }
    var parts = rest.split(".");
    if (parts.count > 3) {
        return Result<(ulong, Version, bool)>.Err($"'{text}' has more than three parts");
    }
    var names = ["major", "minor", "patch"];
    var wild = false;
    for (var i in 0..parts.count) {
        var part = parts[i];
        if (part == "x" or part == "X" or part == "*") {
            wild = true;
            continue;
        }
        if (wild) {
            return Result<(ulong, Version, bool)>.Err($"'{text}' has a number after a wildcard");
        }
        var error = _number_error(part, names[i]);
        if (!error.is_empty) {
            return Result<(ulong, Version, bool)>.Err(error);
        }
        numbers.append(ulong.parse(part).value());
    }
    if (wild and !prerelease.is_empty) {
        return Result<(ulong, Version, bool)>.Err($"'{text}' has a prerelease after a wildcard");
    }
    var version = Version(
        numbers.count > 0 ? numbers[0] : 0, numbers.count > 1 ? numbers[1] : 0, numbers.count > 2 ? numbers[2] : 0
    );
    version.prerelease = prerelease;
    return Result<(ulong, Version, bool)>.Ok((numbers.count, version, wild));
}

# The version after part `part` (0 major, 1 minor, 2 patch) of `v` is
# bumped and the later parts zeroed: the upper bound of a caret or tilde
# range.
_bump(v: Version, part: ulong): Version {
    if (part == 0) {
        return Version(v.major + 1, 0, 0);
    }
    if (part == 1) {
        return Version(v.major, v.minor + 1, 0);
    }
    return Version(v.major, v.minor, v.patch + 1);
}

## Parses a range: comparisons separated by commas, each an operator
## (`^`, `~`, `=`, `>`, `>=`, `<`, `<=`, or none, which means `^`) and a
## partial version (`1`, `1.2`, `1.2.3`, `1.2.x`, `1.2.3-rc.1`), or `*`
## (see the top of this page for what each means).
##
## @param text the range
## @returns the range, or an error saying what is wrong
## @example
##     var range = semver.parse_range(">=1.0, <2").value();
##     assert(range.matches(semver.parse("1.8.0").value()), "in range");
##     assert(!range.matches(semver.parse("2.0.0").value()), "the bound is excluded");
export parse_range(text: String): Result<VersionRange> {
    var range = VersionRange();
    range.text = text;
    for (var raw in text.split(",")) {
        var piece = raw.trim();
        if (piece.is_empty) {
            return Result<VersionRange>.Err($"invalid version range '{text}': it has an empty part");
        }
        if (piece == "*" or piece == "x" or piece == "X") {
            continue;
        }
        var operator = "^";
        for (var candidate in [">=", "<=", ">", "<", "=", "^", "~"]) {
            if (piece.starts_with(candidate)) {
                operator = candidate;
                piece = piece.substr(candidate.length, piece.length).trim();
                break;
            }
        }
        var parsed = _partial(piece);
        if (parsed.is_err()) {
            return Result<VersionRange>.Err($"invalid version range '{text}': {parsed.error().message}");
        }
        var (given, version, wild) = parsed.value();
        if (wild and operator == "^") {
            # `1.2.x` is every 1.2 version, like `=1.2`.
            operator = "=";
        }
        if (given == 0) {
            if (operator == "^" or operator == "~" or operator == "=") {
                continue;
            }
            return Result<VersionRange>.Err($"invalid version range '{text}': '{operator}' needs a version");
        }
        if (operator == "^") {
            # Up to the leftmost nonzero part given; with only zeros, the
            # last part given.
            ulong keep = given - 1;
            if (version.major != 0) {
                keep = 0;
            } else if (version.minor != 0 and given > 1) {
                keep = 1;
            } else if (given > 2) {
                keep = 2;
            }
            range.comparisons.append(Comparison(">=", version));
            range.comparisons.append(Comparison("<", _bump(version, keep)));
            continue;
        }
        if (operator == "~") {
            range.comparisons.append(Comparison(">=", version));
            range.comparisons.append(Comparison("<", _bump(version, given == 1 ? 0 : 1)));
            continue;
        }
        if (given == 3) {
            range.comparisons.append(Comparison(operator, version));
            continue;
        }
        # A partial version stands for every version it starts.
        if (operator == "=") {
            range.comparisons.append(Comparison(">=", version));
            range.comparisons.append(Comparison("<", _bump(version, given - 1)));
        } else if (operator == ">") {
            range.comparisons.append(Comparison(">=", _bump(version, given - 1)));
        } else if (operator == "<=") {
            range.comparisons.append(Comparison("<", _bump(version, given - 1)));
        } else {
            range.comparisons.append(Comparison(operator, version));
        }
    }
    return Result<VersionRange>.Ok(range);
}
