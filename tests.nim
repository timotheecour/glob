import future
import ospaths
from os import createDir, removeDir, getCurrentDir
from algorithm import sortedByIt

import unittest

import src/glob

template isEquiv (pattern, expected: string; forDos = false): bool =
  globToRegexString(pattern, forDos) == expected

template isMatchTest (pattern, input: string; forDos = false): bool =
  matches(input, pattern, forDos)

proc touchFile (path: string) =
  let (head, _) = path.splitPath
  head.createDir
  var f = open(path, fmWrite)
  f.write("")
  f.close

proc createStructure (dir: string, files: seq[string]): () -> void =
  dir.removeDir
  dir.createDir
  for file in files:
    touchFile(dir / file)

  result = () => removeDir(dir)

proc seqsEqual (seq1, seq2: seq[string]): bool =
  seq1.sortedByIt(it) == seq2.sortedByIt(it)

suite "globToRegex":
  test "produces equivalent regular expressions":
    check isEquiv("literal", r"^literal$")
    check isEquiv("*", r"^[^/]*$")
    check isEquiv("**", r"^(?:[^\/]*(?:\/|$))*$")
    check isEquiv("src/*.nim", r"^src/[^/]*\.nim$")
    check isEquiv("src/**/*.nim", r"^src/(?:[^\/]*(?:\/|$))*[^/]*\.nim$")
    check isEquiv("*.nim", r"^[^/]*\.nim$")

    check isEquiv(r"\{foo*", r"^\{foo[^/]*$")
    check isEquiv(r"*\}.html", r"^[^/]*}\.html$")
    check isEquiv(r"\[foo*", r"^\[foo[^/]*$")
    check isEquiv(r"*\].html", r"^[^/]*\]\.html$")

suite "procs accept both string & glob":
  test "matches":
    check "src/dir/foo.nim".matches("src/**/*.nim", false)
    check "src/dir/foo.nim".matches(glob("src/**/*.nim", false))

  test "listGlob":
    # listGlob uses `walkGlob` and therefore `walkGlobKinds` under the hood
    # so if it works, those underlying procs should also work

    let cleanup = createStructure("temp", @[
      "deep" / "dir" / "file.nim",
      "not_as" / "deep.jpg",
      "not_as" / "deep.nim",
      "shallow.nim"
    ])

    const expected = @[
      "temp" / "deep" / "dir" / "file.nim",
      "temp" / "not_as" / "deep.jpg",
      "temp" / "not_as" / "deep.nim",
      "temp" / "shallow.nim"
    ]

    check seqsEqual(listGlob("temp/**/*.{jpg,nim}"), expected)
    check seqsEqual(listGlob(glob("temp/**/*.{jpg,nim}")), expected)

    cleanup()

suite "regex matching":
  test "basic":
    check isMatchTest("literal", "literal")
    check isMatchTest("literal", "lateral").not
    check isMatchTest("foo.nim", "foo.nim")
    check isMatchTest("foo.nim", "bar.nim").not
    check isMatchTest("src/foo.nim", "src/foo.nim")
    check isMatchTest("src/foo.nim", "foo.nim").not

  test "wildcards (single character)":
    check isMatchTest("?oo.html", "foo.html")
    check isMatchTest("??o.html", "foo.html")
    check isMatchTest("???.html", "foo.html")
    check isMatchTest("???.htm?", "foo.html")
    check isMatchTest("foo.???", "foo.html").not

  test "wildcards & globstars":
    check isMatchTest("*", "matches_anything")
    check isMatchTest("*", "matches_anything/but_not_this").not
    check isMatchTest("**", "matches_anything/even_this")

    check isMatchTest("src/*.nim", "src/foo.nim")
    check isMatchTest("src/*.nim", "src/bar.nim")
    check isMatchTest("src/*.nim", "src/foo/deep.nim").not
    check isMatchTest("src/*.nim", "src/foo/deep/deeper/dir/file.nim").not

    check isMatchTest("f*", "foo.html")
    check isMatchTest("*.html", "foo.html")
    check isMatchTest("foo.html*", "foo.html")
    check isMatchTest("*foo.html", "foo.html")
    check isMatchTest("*foo.html*", "foo.html")
    check isMatchTest("*.htm", "foo.html").not
    check isMatchTest("f.*", "foo.html").not

    check isMatchTest("src/**/*.nim", "foo.nim").not
    check isMatchTest("src/**/*.nim", "src/foo.nim")
    check isMatchTest("src/**/*.nim", "src/foo/deep.nim")
    check isMatchTest("src/**/*.nim", "src/foo/deep/deeper/dir/file.nim")

  test "brace expansion":
    check isMatchTest("src/file.{nim,js}", "src/file.nim")
    check isMatchTest("src/file.{nim,js}", "src/file.js")
    check isMatchTest("src/file.{nim,js}", "src/file.java").not
    check isMatchTest("src/file.{nim,js}", "src/file.rs").not

    expect GlobSyntaxError: discard globToRegexString("jell{o,y")
    expect GlobSyntaxError: discard globToRegexString("*.{nims,{.nim}}")

  test "bracket expressions":
    check isMatchTest("[f]oo.html", "foo.html")
    check isMatchTest("[e-g]oo.html", "foo.html")
    check isMatchTest("[abcde-g]oo.html", "foo.html")
    check isMatchTest("[abcdefx-z]oo.html", "foo.html")
    check isMatchTest("[!a]oo.html", "foo.html")
    check isMatchTest("[!a-e]oo.html", "foo.html")
    check isMatchTest("foo[-a-z]bar", "foo-bar")
    check isMatchTest("foo[!-]html", "foo.html")
    check isMatchTest("[f]oo.{[h]tml,class}", "foo.html")
    check isMatchTest("foo.{[a-z]tml,class}", "foo.html")
    check isMatchTest("foo.{[!a-e]tml,.class}", "foo.html")
    check isMatchTest("[]]", "]")

    expect GlobSyntaxError: discard globToRegexString("[]")
    expect GlobSyntaxError: discard globToRegexString("*[a-z")
    expect GlobSyntaxError: discard globToRegexString("*[a--z]")
    expect GlobSyntaxError: discard globToRegexString("*[a--]")

    test "character classes (posix)":
      expect GlobSyntaxError: discard globToRegexString("[[:alnum:")
      expect GlobSyntaxError: discard globToRegexString("[[:alnum:]")
      expect GlobSyntaxError: discard globToRegexString("[[:shoop:]]")

      test "alnum":
        check isMatchTest("[[:alnum:]].html", "a.html")
        check isMatchTest("[[:alnum:]].html", "1.html")
        check isMatchTest("[[:alnum:]].html", "_.html").not
        check isMatchTest("[[:alnum:]].html", "=.html").not

      test "alpha":
        check isMatchTest("[[:alpha:]].html", "a.html")
        check isMatchTest("[[:alpha:]].html", "1.html").not
        check isMatchTest("[[:alpha:]].html", "_.html").not
        check isMatchTest("[[:alpha:]].html", "=.html").not

      test "digit":
        check isMatchTest("[[:digit:]].html", "0.html")
        check isMatchTest("[[:digit:]].html", "1.html")
        check isMatchTest("[[:digit:]].html", "_.html").not
        check isMatchTest("[[:digit:]].html", "=.html").not

      test "upper":
        check isMatchTest("[[:upper:]].nim", "A.nim")
        check isMatchTest("[[:upper:]].nim", "Z.nim")
        check isMatchTest("[[:upper:]].nim", "z.nim").not
        check isMatchTest("[[:upper:]].nim", "_.nim").not
        check isMatchTest("[[:upper:]].nim", "0.nim").not

      test "lower":
        check isMatchTest("[[:lower:]].nim", "a.nim")
        check isMatchTest("[[:lower:]].nim", "z.nim")
        check isMatchTest("[[:lower:]].nim", "Z.nim").not
        check isMatchTest("[[:lower:]].nim", "_.nim").not
        check isMatchTest("[[:lower:]].nim", "0.nim").not

      test "xdigit":
        check isMatchTest("[[:xdigit:]][[:xdigit:]]", "0A")
        check isMatchTest("[[:xdigit:]][[:xdigit:]]", "0a")
        check isMatchTest("[[:xdigit:]][[:xdigit:]]", "0_").not
        check isMatchTest("[[:xdigit:]][[:xdigit:]]", "+a").not

      test "blank":
        check isMatchTest("[[:blank:]]", " ")
        check isMatchTest("[[:blank:]]", "\t")
        check isMatchTest("[[:blank:]]", "  ").not
        check isMatchTest("[[:blank:]]", "+ ").not

      test "punct":
        check isMatchTest("[[:punct:]]", "=")
        check isMatchTest("[[:punct:]]", "*")
        check isMatchTest("[[:punct:]]", "}")
        check isMatchTest("[[:punct:]][[:punct:]]", "%(")
        check isMatchTest("[[:punct:]][[:punct:]][[:punct:]]", "*^#")
        check isMatchTest("[[:punct:]]", "a").not
        check isMatchTest("[[:punct:]]", "A").not

      test "space":
        check isMatchTest("[[:space:]]", "\v")
        check isMatchTest("[[:space:]]", "\f")
        check isMatchTest("[[:space:]]", "s").not
        check isMatchTest("[[:space:]]", "=").not

      test "ascii":
        check isMatchTest("[[:ascii:]]", "\x00")
        check isMatchTest("[[:ascii:]]", "\x7F")
        check isMatchTest("[[:ascii:]]", "£").not
        check isMatchTest("[[:ascii:]]", "©").not

      test "cntrl":
        check isMatchTest("[[:cntrl:]]", "\x1F")
        check isMatchTest("[[:cntrl:]]", "\x00")
        check isMatchTest("[[:cntrl:]]", "+").not
        check isMatchTest("[[:cntrl:]]", "A").not

      test "print":
        check isMatchTest("[[:print:]]", "\x20")
        check isMatchTest("[[:print:]]", "\x7E")
        check isMatchTest("[[:print:]]", " ")
        check isMatchTest("[[:print:]]", "\t").not
        check isMatchTest("[[:print:]]", "\v").not

      test "graph":
        check isMatchTest("[[:graph:]]", "\x7E")
        check isMatchTest("[[:graph:]]", "\x21")
        check isMatchTest("[[:graph:]]", "\t").not
        check isMatchTest("[[:graph:]]", "\v").not

  test "medium complexity":
    let pattern = "src/**/*.{nim,js}"
    check isMatchTest(pattern, "src/file.nim")
    check isMatchTest(pattern, "src/file.js")
    check isMatchTest(pattern, "src/deep/file.nim")
    check isMatchTest(pattern, "src/deep/deeper/dir/file.nim")
    check isMatchTest(pattern, "src/deep/deeper/dir/file.js")
    check isMatchTest(pattern, "file.java").not
    check isMatchTest(pattern, "file.nim").not
    check isMatchTest(pattern, "file.js").not

  test "high complexity":
    let pattern = "src/**/[A-Z]???[!_].{png,jpg}"
    check isMatchTest(pattern, "src/res/A001a.png")
    check isMatchTest(pattern, "src/res/D403b.jpg")
    check isMatchTest(pattern, "src/res/D403_.jpg").not
    check isMatchTest(pattern, "src/res/a403.jpg").not
    check isMatchTest(pattern, "src/res/A001a.gif").not

  test "special character escapes":
    check isMatchTest("\\{foo*", "{foo}.html")
    check isMatchTest("*\\}.html", "{foo}.html")
    check isMatchTest("\\[foo*", "[foo].html")
    check isMatchTest("*\\].html", "[foo].html")

    expect GlobSyntaxError: discard globToRegexString(r"foo\")

  test "extended (?)":
    check isMatchTest("?(fo[!qp]|qux)bar.nim", "foobar.nim")
    check isMatchTest("?(fo[!qp]|qux)bar.nim", "quxbar.nim")
    check isMatchTest("?(fo[!qp]|qux)bar.nim", "bar.nim")
    check isMatchTest("?(fo[!qp]|qux)bar.nim", "fopbar.nim").not

  test "extended (*)":
    check isMatchTest("*(foo|ba[rt]).nim", "foo.nim")
    check isMatchTest("*(foo|ba[rt]).nim", "bat.nim")
    check isMatchTest("*(foo|ba[rt]).nim", "foobat.nim")
    check isMatchTest("*(foo|ba[rt]).nim", "baz.nim").not
    check isMatchTest("*(foo|ba[rt]).nim", "fun.nim").not

  test "extended (!) - currently unsupported":
    # currently unsupported in regex implementation
    expect GlobSyntaxError: discard globToRegexString("!(boo).txt")

    # check isMatchTest("!(boo).nim", "foo.nim")
    # check isMatchTest("!(foo|baz)bar.nim", "buzbar.nim")
    # check isMatchTest("!bar.nim", "!bar.nim")
    # check isMatchTest("!({foo,bar})baz.nim", "notbaz.nim")
    # check isMatchTest("!({foo,bar})baz.nim", "foobaz.nim").not

  test "extended (+)":
    check isMatchTest("+foo.nim", "+foo.nim")
    check isMatchTest("+(foo).nim", "foo.nim")
    check isMatchTest("+(foo).nim", "foofoo.nim")
    check isMatchTest("+(foo).nim", "fop.nim").not
    check isMatchTest("+(foo).nim", ".nim").not

  test "extended (@)":
    check isMatchTest("@foo.nim", "@foo.nim")
    check isMatchTest("@(foo).nim", "foo.nim")
    check isMatchTest("@(foo).nim", "foofoo.nim").not
    check isMatchTest("@(1|2).nim", "1.nim")
    check isMatchTest("@(1|2).nim", "12.nim").not

suite "pattern walking / listing":
  test "yields expected files":
    let cleanup = createStructure("temp", @[
      "deep" / "dir" / "file.nim",
      "not_as" / "deep.jpg",
      "not_as" / "deep.nim",
      "shallow.nim"
    ])

    test "basic":
      check seqsEqual(listGlob("temp"), @[
        "temp" / "deep" / "dir" / "file.nim",
        "temp" / "not_as" / "deep.jpg",
        "temp" / "not_as" / "deep.nim",
        "temp" / "shallow.nim"
      ])

      check seqsEqual(listGlob("temp/**/*.{nim,jpg}"), @[
        "temp" / "deep" / "dir" / "file.nim",
        "temp" / "not_as" / "deep.jpg",
        "temp" / "not_as" / "deep.nim",
        "temp" / "shallow.nim"
      ])

      check seqsEqual(listGlob("temp/*.nim"), @[
        "temp" / "shallow.nim"
      ])

      check seqsEqual(listGlob("temp/**/*.nim"), @[
        "temp" / "deep" / "dir" / "file.nim",
        "temp" / "not_as" / "deep.nim",
        "temp" / "shallow.nim"
      ])

    test "`includeDirs` adds matching directories to the results":
      check seqsEqual(listGlob("temp/**", includeDirs = true), @[
        "temp" / "deep",
        "temp" / "deep" / "dir",
        "temp" / "deep" / "dir" / "file.nim",
        "temp" / "not_as",
        "temp" / "not_as" / "deep.jpg",
        "temp" / "not_as" / "deep.nim",
        "temp" / "shallow.nim"
      ])

    test "directories are expanded by default":
      check seqsEqual(listGlob("temp"), @[
        "temp" / "deep" / "dir" / "file.nim",
        "temp" / "not_as" / "deep.jpg",
        "temp" / "not_as" / "deep.nim",
        "temp" / "shallow.nim"
      ])

    test "`relative = false` makes returned paths absolute":
      check seqsEqual(listGlob("temp/*.nim", relative = false), @[
        getCurrentDir() / "temp" / "shallow.nim"
      ])

    cleanup()

suite "utility procs":
  test "glob":
    let patternString = "src/**/*.nim"
    let g = glob("src/**/*.nim", false)
    check g.pattern == patternString
    check g.base == "src"
    check g.magic == "**/*.nim"
    check g.regexStr == r"^src/(?:[^\/]*(?:\/|$))*[^/]*\.nim$"
    check "src/foo.nim".contains(g.regex)
    check "src/dir/foo.nim".contains(g.regex)

    test "absolute paths (unix)":
      let patternString = "/home/cc/dev/nim/**/*.nim"
      let g = glob(patternString, false)
      check g.pattern == patternString
      check g.base == "/home/cc/dev/nim"
      check g.magic == "**/*.nim"
      check g.regexStr == "^/home/cc/dev/nim/(?:[^\\/]*(?:\\/|$))*[^/]*\\.nim$"

    test "absolute paths (windows)":
      let patternString = "C:/Users/cc/dev/nim/**/*.nim"
      let g = glob(patternString, true)
      check g.pattern == patternString
      check g.base == "C:/Users/cc/dev/nim"
      check g.magic == "**/*.nim"
      check g.regexStr == r"^C:\\Users\\cc\\dev\\nim\\(?:[^\\]*(?:\\|$))*[^\\]*\.nim$"

  test "hasMagic":
    check "".hasMagic.not
    check "literal-match.html".hasMagic.not
    check "*".hasMagic
    check "**".hasMagic
    check "**/*.nim".hasMagic
    check "[!f]oo.nim".hasMagic
    check "foo.{nim,js}".hasMagic
    check "?(a|b).nim".hasMagic
    check "*(a|b).nim".hasMagic
    check "!(a|b).nim".hasMagic
    check "+(a|b).nim".hasMagic
    check "@(a|b).nim".hasMagic

  test "splitPattern":
    check "".splitPattern == ("", "")
    check "*".splitPattern == ("", "*")
    check "**/*.nim".splitPattern == ("", "**/*.nim")
    check "literal-match.html".splitPattern == ("", "literal-match.html")
    check "src/deep/dir/[[:digit:]]*.{png,svg}".splitPattern == ("src/deep/dir", "[[:digit:]]*.{png,svg}")
