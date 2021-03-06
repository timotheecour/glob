<a name="v0.7.0"></a>
### [`v0.7.0`](https://github.com/citycide/glob/compare/v0.6.0...v0.7.0) (2018-07-04)


###### FEATURES

* normalize returned paths to current os style ([`966e8cf`](https://github.com/citycide/glob/commit/966e8cfdf1bc0f98640dad9b7c8b0615eb2d009d))
* remove `$` to improve inspection & debugging ([`c897d6b`](https://github.com/citycide/glob/commit/c897d6b8d9c2de818ac0cf7567b33e437b5f5ac2))

###### BUG FIXES

* handle absolute paths correctly ([`1753cb8`](https://github.com/citycide/glob/commit/1753cb81f6f184ab40ba11dd2e75024d2617c900))

---

<a name="v0.6.0"></a>
### [`v0.6.0`](https://github.com/citycide/glob/compare/v0.5.0...v0.6.0) (2018-06-06)

This release has the potential to _greatly_ improve performance. `glob` will no
longer traverse into directories or over files that have no hope of matching the
given pattern. A simple example is that a shallow pattern like `*.nim` can only
match files with a `.nim` extension in the current directory &mdash; so `glob`
should never enter a subdirectory or consider files with any other extension.
This is now the case!

TL;DR when using shallow patterns in roots of huge directory structures, users
should see huge performance gains.

###### PERFORMANCE

* optimize walk iterator ([`1a57121`](https://github.com/citycide/glob/commit/1a57121e3810d78c913c9d3a37f36a7ed03cace0))

---

<a name="v0.5.0"></a>
### [`v0.5.0`](https://github.com/citycide/glob/compare/v0.4.0...v0.5.0) (2018-05-30)

This release brings a number of API improvements, the most significant of which
is that procs/iterators like `listGlob` that previously only accepted string
patterns now also accept pre-constructed `Glob` objects:

```nim
import glob
const matcher = glob("src/**/*.nim")

# the following are now equivalent:
listGlob(matcher)
listGlob("src/**/*.nim")
```

This makes globs more reusable and can reduce the number of created objects.

An internal proc named `splitPattern` is now exposed publicly:

```nim
import glob

echo splitPattern("src/dir/**/*.{png,svg}")
# -> (base: "src/dir", magic: "**/*.{png.svg}")
```

The full feature update list is below, and all of these have been documented on
the [full docs site](https://citycide.github.io/glob/).

###### FEATURES

* `walkGlobKinds`, `walkGlob`, & `listGlob` now also accept
a preconstructed `Glob` object instead of a string
* the internal `splitPattern` proc is now publicly exported,
which allows users to split string glob patterns into their
"magic" & "non-magic" (base) parts
* `Glob` objects now contain their `base` & `magic` path segments
* `hasMagic` now checks for extended glob features like pattern
matches

---

<a name="v0.4.0"></a>
### [`v0.4.0`](https://github.com/citycide/glob/compare/v0.3.1...v0.4.0) (2018-05-23)

While it's a fairly small release, almost the entire glob parser was actually rewritten for this
release to make supporting [extended pattern matches](https://citycide.github.io/glob/#syntax-extended-pattern-matching)
easier and to generally make it simpler. :tada:

###### FEATURES

* add extended pattern matching ([`a7cf070`](https://github.com/citycide/glob/commit/a7cf0708335459c2acf969182f2a1cdf6bb37d7f))

---

<a name="v0.3.1"></a>
### [`v0.3.1`](https://github.com/citycide/glob/compare/v0.3.0...v0.3.1) (2018-05-22)


###### BUG FIXES

* correctly handle patterns in cwd ([`ee12839`](https://github.com/citycide/glob/commit/ee12839bc3e13b886f0df9bc75da52e1993437c5))

---

<a name="v0.3.0"></a>
### [`v0.3.0`](https://github.com/citycide/glob/compare/v0.2.0...v0.3.0) (2018-05-22)

###### FEATURES

* allow matching `]` in character class ([`991553b`](https://github.com/citycide/glob/commit/991553b8de6dc32015e7976348eb0660a255d93d))

###### BUG FIXES

* error correctly on invalid character escapes ([`2ae42eb`](https://github.com/citycide/glob/commit/2ae42eb9b357e70a3780b6b8516e9150cfb8c683))

---

<a name="v0.2.0"></a>
### [`v0.2.0`](https://github.com/citycide/glob/compare/v0.1.0...v0.2.0) (2018-05-22)


###### FEATURES

* support posix character classes ([`a8a8fc6`](https://github.com/citycide/glob/commit/a8a8fc623a7d8c353a54c1482a7a1915f1ea53e1))

---

<a name="v0.1.0"></a>
### `v0.1.0` (2018-05-20)

Initial release.
