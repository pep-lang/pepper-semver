# The semver package's ranges: what each operator means, prereleases,
# matching, and errors.

import semver;

range(text: String): semver.VersionRange {
    var result = semver.parse_range(text);
    if (result.is_err()) {
        print(result.error().message);
        panic("parse_range failed");
    }
    return result.value();
}

# The range's comparisons as text, joined by ", ".
comparisons(text: String): String {
    var parts = Array<String>();
    for (var comparison in range(text).comparisons) {
        parts.append(comparison.to_string());
    }
    return ", ".join(parts);
}

matches(range_text: String, version_text: String): bool {
    return range(range_text).matches(semver.parse(version_text).value());
}

[Test]
reads_each_operator() {
    expect_equal(comparisons("1.2"), ">=1.2.0, <2.0.0");
    expect_equal(comparisons("^1.2"), ">=1.2.0, <2.0.0");
    expect_equal(comparisons("^1"), ">=1.0.0, <2.0.0");
    expect_equal(comparisons("^1.2.3"), ">=1.2.3, <2.0.0");
    expect_equal(comparisons("^0.4"), ">=0.4.0, <0.5.0");
    expect_equal(comparisons("^0.4.2"), ">=0.4.2, <0.5.0");
    expect_equal(comparisons("^0.0.3"), ">=0.0.3, <0.0.4");
    expect_equal(comparisons("^0.0"), ">=0.0.0, <0.1.0");
    expect_equal(comparisons("^0"), ">=0.0.0, <1.0.0");
    expect_equal(comparisons("~1.2.3"), ">=1.2.3, <1.3.0");
    expect_equal(comparisons("~1.2"), ">=1.2.0, <1.3.0");
    expect_equal(comparisons("~1"), ">=1.0.0, <2.0.0");
    expect_equal(comparisons("1.2.x"), ">=1.2.0, <1.3.0");
    expect_equal(comparisons("1.2.*"), ">=1.2.0, <1.3.0");
    expect_equal(comparisons("1.X"), ">=1.0.0, <2.0.0");
    expect_equal(comparisons("=1.2.3"), "=1.2.3");
    expect_equal(comparisons("=1.2"), ">=1.2.0, <1.3.0");
    expect_equal(comparisons(">1.2.3"), ">1.2.3");
    expect_equal(comparisons(">1.2"), ">=1.3.0");
    expect_equal(comparisons(">=1.2"), ">=1.2.0");
    expect_equal(comparisons("<1.2"), "<1.2.0");
    expect_equal(comparisons("<=1.2"), "<1.3.0");
    expect_equal(comparisons("<=1.2.3"), "<=1.2.3");
    expect_equal(comparisons(">= 1.0, < 2"), ">=1.0.0, <2.0.0");
    expect_equal(comparisons("*"), "");
    expect_equal(range(" >=1, <2 ").text, " >=1, <2 ");
}

[Test]
matches_releases() {
    expect_true(matches("^1.2", "1.2.0"));
    expect_true(matches("^1.2", "1.99.7"));
    expect_false(matches("^1.2", "1.1.9"));
    expect_false(matches("^1.2", "2.0.0"));
    expect_true(matches("^0.4", "0.4.9"));
    expect_false(matches("^0.4", "0.5.0"));
    expect_true(matches("~1.2", "1.2.9"));
    expect_false(matches("~1.2", "1.3.0"));
    expect_true(matches("=1.2.3", "1.2.3"));
    expect_true(matches("=1.2.3", "1.2.3+build"));
    expect_false(matches("=1.2.3", "1.2.4"));
    expect_true(matches(">=1.0, <2", "1.0.0"));
    expect_false(matches(">=1.0, <2", "2.0.0"));
    expect_true(matches("*", "0.0.1"));
    expect_true(matches("*", "999.0.0"));
}

# A prerelease is in a range only when the range names a prerelease of the
# same release, and then by precedence.
[Test]
matches_prereleases_only_when_named() {
    expect_false(matches("^1.2", "1.3.0-beta"));
    expect_false(matches("*", "1.0.0-rc.1"));
    expect_false(matches("<2", "2.0.0-rc.1"));
    expect_true(matches("^1.3.0-beta", "1.3.0-beta"));
    expect_true(matches("^1.3.0-beta", "1.3.0-beta.2"));
    expect_true(matches("^1.3.0-beta", "1.3.0-rc.1"));
    expect_true(matches("^1.3.0-beta", "1.3.0"));
    expect_false(matches("^1.3.0-beta", "1.3.0-alpha"));
    expect_false(matches("^1.3.0-beta", "1.4.0-beta"));
    expect_true(matches(">=1.3.0-beta, <2", "1.3.0-beta.7"));
    expect_true(matches("=1.0.0-rc.1", "1.0.0-rc.1+build.3"));
}

[Test]
says_what_is_wrong_with_a_range() {
    var cases = [
        ("", "invalid version range '': it has an empty part"),
        (">=1,", "invalid version range '>=1,': it has an empty part"),
        (">=", "invalid version range '>=': the major version is empty"),
        (">*", "invalid version range '>*': '>' needs a version"),
        ("1.2.3.4", "invalid version range '1.2.3.4': '1.2.3.4' has more than three parts"),
        ("1.x.3", "invalid version range '1.x.3': '1.x.3' has a number after a wildcard"),
        ("^01.2", "invalid version range '^01.2': the major version '01' has a leading zero"),
        ("~1.a", "invalid version range '~1.a': the minor version 'a' is not a number"),
        ("1.2.3-01", "invalid version range '1.2.3-01': the prerelease identifier '01' has a leading zero"),
        ("1.x-beta", "invalid version range '1.x-beta': '1.x-beta' has a prerelease after a wildcard"),
    ];
    for (var (text, message) in cases) {
        var result = semver.parse_range(text);
        expect_true(result.is_err());
        if (result.is_err()) {
            expect_equal(result.error().message, message);
        }
    }
}
