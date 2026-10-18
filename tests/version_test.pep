# The semver package's versions: parsing what the spec allows and refusing
# what it does not, printing, and the spec's precedence rules (section 11).

import semver;

version(text: String): semver.Version {
    var result = semver.parse(text);
    if (result.is_err()) {
        print(result.error().message);
        panic("parse failed");
    }
    return result.value();
}

error_of(text: String): String {
    var result = semver.parse(text);
    expect_true(result.is_err());
    return result.is_err() ? result.error().message : "";
}

[Test]
parses_the_parts() {
    var v = version("1.20.300-rc.1+build.5");
    expect_equal(v.major, 1 as ulong);
    expect_equal(v.minor, 20 as ulong);
    expect_equal(v.patch, 300 as ulong);
    expect_equal(v.prerelease, "rc.1");
    expect_equal(v.build, "build.5");
    expect_true(v.is_prerelease());
    expect_false(version("1.0.0+build").is_prerelease());
    expect_equal(version("18446744073709551615.0.0").to_string(), "18446744073709551615.0.0");
}

# Valid versions from the test set of the spec's suggested regular
# expression (https://regex101.com/r/Ly7O1x/3/), less one whose numbers do
# not fit a ulong.
[Test]
parses_valid_versions() {
    var valid = [
        "0.0.4",
        "1.2.3",
        "10.20.30",
        "1.1.2-prerelease+meta",
        "1.1.2+meta",
        "1.1.2+meta-valid",
        "1.0.0-alpha",
        "1.0.0-beta",
        "1.0.0-alpha.beta",
        "1.0.0-alpha.beta.1",
        "1.0.0-alpha.1",
        "1.0.0-alpha0.valid",
        "1.0.0-alpha.0valid",
        "1.0.0-alpha-a.b-c-somethinglong+build.1-aef.1-its-okay",
        "1.0.0-rc.1+build.1",
        "2.0.0-rc.1+build.123",
        "1.2.3-beta",
        "10.2.3-DEV-SNAPSHOT",
        "1.2.3-SNAPSHOT-123",
        "1.0.0",
        "2.0.0",
        "1.1.7",
        "2.0.0+build.1848",
        "2.0.1-alpha.1227",
        "1.0.0-alpha+beta",
        "1.2.3----RC-SNAPSHOT.12.9.1--.12+788",
        "1.2.3----R-S.12.9.1--.12+meta",
        "1.2.3----RC-SNAPSHOT.12.9.1--.12",
        "1.0.0+0.build.1-rc.10000aaa-kk-0.1",
        "1.0.0-0A.is.legal",
        "1.0.0+001",
        "1.0.0-x-y-z.--",
    ];
    for (var text in valid) {
        var result = semver.parse(text);
        if (result.is_err()) {
            print(result.error().message);
        }
        expect_true(result.is_ok());
        expect_equal(result.value().to_string(), text);
    }
}

# Invalid versions from the same test set, and a few more.
[Test]
refuses_invalid_versions() {
    var invalid = [
        "1",
        "1.2",
        "1.2.3-0123",
        "1.2.3-0123.0123",
        "1.1.2+.123",
        "+invalid",
        "-invalid",
        "-invalid+invalid",
        "-invalid.01",
        "alpha",
        "alpha.beta",
        "alpha.beta.1",
        "alpha.1",
        "alpha+beta",
        "alpha_beta",
        "alpha.",
        "alpha..",
        "beta",
        "1.0.0-alpha_beta",
        "-alpha.",
        "1.0.0-alpha..",
        "1.0.0-alpha..1",
        "1.0.0-alpha...1",
        "01.1.1",
        "1.01.1",
        "1.1.01",
        "1.2.3.DEV",
        "1.2-SNAPSHOT",
        "1.2.31.2.3----RC-SNAPSHOT.12.09.1--..12+788",
        "1.2-RC-SNAPSHOT",
        "-1.0.3-gamma+b7718",
        "+justmeta",
        "9.8.7+meta+meta",
        "9.8.7-whatever+meta+meta",
        "99999999999999999999999.999999999999999999.99999999999999999----RC-SNAPSHOT.12.09.1--------------------------------..12",
        "",
        "v1.2.3",
        " 1.2.3",
        "1.2.3 ",
        "1.2.3-",
        "1.2.3+",
        "1.2.3-\u{E9}",
        "1.-2.3",
    ];
    for (var text in invalid) {
        var result = semver.parse(text);
        if (result.is_ok()) {
            print($"parsed '{text}'");
        }
        expect_true(result.is_err());
    }
}

[Test]
says_what_is_wrong_with_a_version() {
    expect_equal(error_of("1.2"), "invalid version '1.2': expected 'major.minor.patch'");
    expect_equal(error_of("01.2.3"), "invalid version '01.2.3': the major version '01' has a leading zero");
    expect_equal(error_of("1.x.3"), "invalid version '1.x.3': the minor version 'x' is not a number");
    expect_equal(error_of("1.2."), "invalid version '1.2.': the patch version is empty");
    expect_equal(
        error_of("18446744073709551616.0.0"),
        "invalid version '18446744073709551616.0.0': the major version '18446744073709551616' is too large"
    );
    expect_equal(error_of("1.2.3-01"), "invalid version '1.2.3-01': the prerelease identifier '01' has a leading zero");
    expect_equal(error_of("1.2.3-a..b"), "invalid version '1.2.3-a..b': the prerelease 'a..b' has an empty identifier");
    expect_equal(
        error_of("1.2.3+a_b"),
        "invalid version '1.2.3+a_b': the build metadata identifier 'a_b' may hold only ASCII letters, digits and '-'"
    );
}

[Test]
prints_what_it_parsed() {
    expect_equal(semver.Version(1, 2, 3).to_string(), "1.2.3");
    var v = semver.Version(1, 0, 0);
    v.build = "sha.5114f85";
    expect_equal(v.to_string(), "1.0.0+sha.5114f85");
    v.prerelease = "beta";
    expect_equal(v.to_string(), "1.0.0-beta+sha.5114f85");
}

# Each version sorts strictly before the next.
expect_ascending(texts: Array<String>) {
    for (var i in 1..texts.count) {
        var a = version(texts[i - 1]);
        var b = version(texts[i]);
        if (!(a < b)) {
            print($"'{texts[i - 1]}' does not sort before '{texts[i]}'");
        }
        expect_equal(a.compare(b), -1);
        expect_equal(b.compare(a), 1);
        expect_true(a < b and a <= b and b > a and b >= a and a != b);
        expect_false(a == b or a > b or b < a);
    }
}

# Spec 11.2: major, minor and patch compare numerically.
[Test]
orders_by_the_numbers() {
    expect_ascending(["1.0.0", "2.0.0", "2.1.0", "2.1.1"]);
    expect_ascending(["1.9.0", "1.10.0", "1.11.0"]);
    expect_ascending(["0.0.9", "0.0.10", "0.1.0", "1.0.0", "10.0.0"]);
}

# Spec 11.3: a prerelease has lower precedence than its release.
[Test]
orders_a_prerelease_before_its_release() {
    expect_ascending(["1.0.0-alpha", "1.0.0"]);
    expect_ascending(["0.9.9", "1.0.0-0", "1.0.0"]);
    expect_ascending(["1.0.0", "1.0.1-alpha", "1.0.1"]);
}

# Spec 11.4: the spec's own example, then each of its rules on prerelease
# identifiers.
[Test]
orders_prereleases_by_their_identifiers() {
    expect_ascending(
        [
            "1.0.0-alpha",
            "1.0.0-alpha.1",
            "1.0.0-alpha.beta",
            "1.0.0-beta",
            "1.0.0-beta.2",
            "1.0.0-beta.11",
            "1.0.0-rc.1",
            "1.0.0",
        ]
    );
    # 11.4.1: numeric identifiers numerically, at any length.
    expect_ascending(["1.0.0-2", "1.0.0-10", "1.0.0-99999999999999999999", "1.0.0-100000000000000000000"]);
    # 11.4.2: alphanumeric identifiers in ASCII order.
    expect_ascending(["1.0.0-A", "1.0.0-B", "1.0.0-a", "1.0.0-a-", "1.0.0-ab", "1.0.0-b"]);
    expect_ascending(["1.0.0--", "1.0.0-0a", "1.0.0-a0"]);
    # 11.4.3: numeric identifiers before alphanumeric ones.
    expect_ascending(["1.0.0-999", "1.0.0--1", "1.0.0-0a", "1.0.0-a"]);
    # 11.4.4: a longer set after its prefix.
    expect_ascending(["1.0.0-a", "1.0.0-a.0", "1.0.0-a.0.0", "1.0.0-a.1"]);
}

# Spec 10: build metadata does not change precedence.
[Test]
ignores_build_metadata() {
    var plain = version("1.0.0");
    for (var text in ["1.0.0+20130313144700", "1.0.0+exp.sha.5114f85", "1.0.0+21AF26D3----117B344092BD"]) {
        var built = version(text);
        expect_equal(built.compare(plain), 0);
        expect_true(built == plain and built <= plain and built >= plain);
        expect_false(built != plain or built < plain or built > plain);
    }
    expect_true(version("1.0.0-beta+a") == version("1.0.0-beta+b"));
    expect_ascending(["1.0.0-beta+zzz", "1.0.0+aaa"]);
}

[Test]
sorts_with_compare() {
    var versions = Array<semver.Version>();
    for (var text in ["1.0.0", "1.0.0-rc.1", "0.1.0", "1.0.0-beta.11", "1.0.0-beta.2", "1.0.0-alpha", "2.0.0"]) {
        versions.append(version(text));
    }
    versions.sort((a, b) => a.compare(b));
    var sorted = Array<String>();
    for (var v in versions) {
        sorted.append(v.to_string());
    }
    expect_equal(", ".join(sorted), "0.1.0, 1.0.0-alpha, 1.0.0-beta.2, 1.0.0-beta.11, 1.0.0-rc.1, 1.0.0, 2.0.0");
}
