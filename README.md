# pepper-semver

[Semantic Versioning 2.0.0](https://semver.org) for
[Pepper](https://github.com/justinboswell/pepper) (issue
justinboswell/pepper#986): parse versions, order them by the spec's
precedence, and match them against ranges such as `^1.2`, `~1.2` and
`>=1.0, <2`. It starts from the version code of `pep-package`, so other
tools can share one implementation.

One module, **`semver`**:

- **`semver.parse(text)`** reads a version (`1.2.3`, `1.2.3-rc.1`,
  `1.2.3-rc.1+build.5`) into a **`Version`** with `major`, `minor`,
  `patch`, `prerelease` and `build`, or an error saying what is wrong.
  It is strict: exactly three numbers with no leading zeros, and
  prerelease and build identifiers that are not empty and hold only ASCII
  letters, digits and `-` (prerelease numbers with no leading zero). No
  `v` prefix: drop a tag's `v` first.
- **`Version.compare(other)`** and the operators `<`, `<=`, `>`, `>=`, `==`
  and `!=` follow the spec's precedence (section 11): numbers numerically,
  a prerelease before its release, prerelease identifiers numerically or
  in ASCII order with numbers first and a longer list after its prefix.
  Build metadata is ignored, so `1.0.0+a == 1.0.0+b`; `to_string()` keeps
  it. Sort with `versions.sort((a, b) => a.compare(b))`.
- **`semver.parse_range(text)`** reads a **`VersionRange`** the way Cargo
  does, and **`VersionRange.matches(version)`** tests a version against
  it. A range is comparisons separated by commas, all of which must hold:

  | Range | Means |
  | --- | --- |
  | `1.2`, `^1.2` | `>=1.2.0, <2.0.0` (the leftmost nonzero part stays) |
  | `^0.4` | `>=0.4.0, <0.5.0` |
  | `^0.0.3` | `>=0.0.3, <0.0.4` |
  | `~1.2` | `>=1.2.0, <1.3.0` |
  | `~1` | `>=1.0.0, <2.0.0` |
  | `1.2.x`, `1.2.*` | `>=1.2.0, <1.3.0` |
  | `=1.2.3` | exactly `1.2.3` |
  | `=1.2` | `>=1.2.0, <1.3.0` |
  | `>1.2`, `<=1.2` | `>=1.3.0`, `<1.3.0` |
  | `>=1.0, <2` | both comparisons |
  | `*` | any release |

  A prerelease matches only a range that names a prerelease of the same
  `major.minor.patch`, as in Cargo and npm: `^1.2` never picks
  `1.3.0-beta`, but `^1.3.0-beta` and `>=1.3.0-beta, <2` do.

```pepper
import semver;

main(): int {
    var parsed = semver.parse("1.4.0-rc.1+build.7");
    if (parsed.is_err()) {
        print(parsed.error().message);   # invalid version '...': ...
        return 1;
    }
    var candidate = parsed.value();
    print(candidate.prerelease);                            # rc.1
    print(candidate < semver.parse("1.4.0").value());       # true

    var range = semver.parse_range("^1.2").value();
    print(range.matches(semver.parse("1.9.3").value()));    # true
    print(range.matches(candidate));                        # false: not named
    return 0;
}
```

## Limits

- `major`, `minor` and `patch` are `ulong`s, so a version with a larger
  number is an error (`the major version '...' is too large`). Prerelease
  numbers have no limit.
- Ranges are Cargo's: no npm hyphen ranges (`1.2 - 1.4`) or `||`.
- `Version` has `compare` and the comparison operators but does not yet
  declare the runtime's `Comparable` trait, which is newer than the
  0.9.4 toolchain this package builds with.

## Using it

This repository is a package: `pep.toml` marks its root, and its root
`module.pep` is the `semver` module. Add it to a project under the name
`semver`:

```sh
pepper package add justinboswell/pepper-semver --name semver
```

which writes

```toml
[dependencies]
semver = { github = "justinboswell/pepper-semver" }
```

Without a project, put a folder named `semver` that holds (or links to)
this repository on the import path: `pepper build -I packages main.pep`.

## Tests

```sh
tests/run.sh path/to/pepper
```

runs the `[Test]` functions in `tests/` with `pepper test`: versions
(`version_test.pep`), with the valid and invalid versions of the test set
for the spec's suggested regular expression and each of the spec's
precedence rules, and ranges (`range_test.pep`).
