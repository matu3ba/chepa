# check paths
Fast checking of paths on conformance for shell coding and absence of antipatterns

alpha status with output and utf8 parts not yet being fully tested.

## use cases
- use case 1: check for ASCII control characters
- use case 2: check for bad practice file- and foldernames
- use case 3: check for `POSIX portable file name character set` and
  POSIX path length (will be split later)
- use case 4: check for a sane UTF8 subset without empty spaces
- goal: perf and simplicity for utf8
- goal: better alternative to `pathchk`
- reusable as library
* does not follow symlinks.
- non-goal: special case for locations or languages, see paths_are_complex.md
- potential followup project(s) or ideas for other people:
  * 1. utf8 simd validation
  * 2. language codes as list of allowed languages
  * 3. system to query unicode database + compute changes

## planned interfaces
1. write messages for safe inspection (default for cli, -l line count or no args)
   * only necessary allocs
   * sane default with configurability (what fits on screen)
   * developer may use memory intensive processes
2. only status codes (-c for check, 0 ok, positives ones generated from zig enum)
   * only necessary allocs
   * immediate exit on error
3. store messages in memory and flush at end (-s size, -f file)
   * write broken file paths with to user provided file
   * user provided max size in b,kb,mb [size means complexity]
4. API for use case 2+3 and configurable buffer or allocation size

## status
For now, `POSIX portable file name character set` is used to keep things simple
and will remain as another code path behind an additional cli flag.
Checking ASCII character works.
Eventually this work will be extended to utf8 and utf16 strings, which offer more
opportunity for bad practice filenames.

## todos
- [x] use case 1
- [x] zig build
- [x] test base perf: 10000 folders each with 0 or 10 subfolders
- [x] test control sequences: add such folders (fix #10920 to have nicer solution)
- [x] test bad patterns: add such folders
- [x] cli `-outfile`
- [x] use case 2
- [x] use case 3
- [x] refactor -c and -outfile to separate functions
- [x] replace hacky buildTest.sh with proper status code tests
- [x] finish integration tests with generated file (zig build inttest)
- [x] perf bench: cmds to invoke hyperfine with other contestors
- [x] utf8: std.unicode interpret as unicode literals
- [x] test data
- [ ] unicode test data
- [ ] capture output of stdout: wait for testing IPC+output capture to be less annoying
      (https://github.com/ziglang/zig/pull/11138 and follow-up PRs)
- [ ] unicode test data
- [ ] parallelize running in multiple processes
- [ ] other cli option to validate paths as utf8 with zigstr (complex)
- [ ] simd?
- [ ] utf16
- [ ] perf: refactor error case once #489 lands or dont refactor once #84 is implemented

## obsoletion plan
1. Ideally this library would be obsoleted by shells defaulting to
have separate IPC channels like named pipes instead for ASCII control sequences.
Or at least to provide standard IPC for the most commonly used programs
to disable and enable all ASCII control sequences.
This prevents commands like `cat` or `ls` leading to ASCII control
sequence execution.
2. Further more, it would be great if Kernels would not accepting filenames
with ASCII control sequences and bad practice filenames like, but not limited to,
newlines, leading dashes, commas, leading and trailing emptyspaces etc.
3. Empty spaces should be removed from filenames, if Kernel communities think,
that working in the shell should be simple.
Alternatively, shells must define a fast alternative program interface that does
not rely on spaces for command separation.


## notes
Example for bad practice file- and foldernames are
  ' filename', 'filename ', '~filename', '-filename', 'f1 -f2'

The `POSIX portable file name character set` consists of
  ABCDEFGHIJKLMNOPQRSTUVWXYZ
  abcdefghijklmnopqrstuvwxyz
  0123456789._-

Unfortunately path delimitors need to be special cased:
(1) unix requires `/` to be used for root directories
(2) windows requires `\` and `:` to be used for `C:\\path\\..`

Control characters (`0x1-0x31,0x7f`) may get escaped by the library or
operating system, which would look like:
```txt
d_\u{b}  d_\r     d_\u{4}  d_\u{8}   d_\u{11}  d_\u{15}  d_\u{19}  d_\u{1d}
d_\n     d_\u{1}  d_\u{5}  d_\u{e}   d_\u{12}  d_\u{16}  d_\u{1a}  d_\u{1e}
d_\t     d_\u{2}  d_\u{6}  d_\u{f}   d_\u{13}  d_\u{17}  d_\u{1b}  d_\u{7f}
d_\u{c}  d_\u{3}  d_\u{7}  d_\u{10}  d_\u{14}  d_\u{18}  d_\u{1c}
```
`0x0` should crash the file/folder generation command.

Problems for storing problems for user-inspection and usage in tools
* file/directory may have `'` or `\n`
* reading line-wise or between delimiters does not work
* reading between characters does not work
* custom encoding to handle all case :(
* special case of `\n`
  - return in status code or user message
  - cli text in offending line + `HERE` for easy search
* process spawning with cli input and paths with control characters likely breaks

#### utf8 whitespace characters
```txt
taken from https://en.wikipedia.org/wiki/Whitespace_character#Unicode
0x9     U+0009  character tabulation          b'\t'
0xa     U+000A  line feed                     b'\n'
0xb     U+000B  line tabulation               b'\x0b'
0xc     U+000C  form feed                     b'\x0c'
0xd     U+000D  carriage return               b'\r'
0x20    U+0020  space                         b' '
----
0x85    U+0085  next line                     b'\xc2\x85'
0xa0    U+00A0  no-break space                b'\xc2\xa0'
----
0x1680  U+1680  ogham space mark              b'\xe1\x9a\x80'
0x180e  U+180E  mongolian vowel separator     b'\xe1\xa0\x8e'
0x2000  U+2000  en quad                       b'\xe2\x80\x80'
0x2001  U+2001  em quad                       b'\xe2\x80\x81'
0x2002  U+2002  en space                      b'\xe2\x80\x82'
0x2003  U+2003  em space                      b'\xe2\x80\x83'
0x2004  U+2004  three-per-em space            b'\xe2\x80\x84'
0x2005  U+2005  four-per-em space             b'\xe2\x80\x85'
0x2006  U+2006  six-per-em space              b'\xe2\x80\x86'
0x2007  U+2007  figure space                  b'\xe2\x80\x87'
0x2008  U+2008  punctuation space             b'\xe2\x80\x88'
0x2009  U+2009  thin space                    b'\xe2\x80\x89'
0x200a  U+200A  hair space                    b'\xe2\x80\x8a'
0x200b  U+200B  zero width space              b'\xe2\x80\x8b'
0x200c  U+200C  zero width non-joiner         b'\xe2\x80\x8c'
0x200d  U+200D  zero width joiner             b'\xe2\x80\x8d'
0x2028  U+2028  line separator                b'\xe2\x80\xa8'
0x2029  U+2029  paragraph separator           b'\xe2\x80\xa9'
0x202f  U+202F  narrow no-break space         b'\xe2\x80\xaf'
0x205f  U+205F  medium mathematical space     b'\xe2\x81\x9f'
0x2060  U+2060  word joiner                   b'\xe2\x81\xa0'
0x3000  U+3000  ideographic space             b'\xe3\x80\x80'
0xfeff  U+FEFF  zero width non-breaking space b'\xef\xbb\xbf'
```

#### checked utf8 non-language specific control characters
```txt
https://en.wiktionary.org/wiki/Appendix:Control_characters
0 not being representable in filepaths
1-31 from Ascii
127 del
128-159 from extended Ascii
173 soft hyphen
other control characters are language specific and/or utf8 deprecated characters
TODO clarify, if 8206 bidirectional text is used in filepaths, 8234 Left-to-Right Embedding
```
Note, that 128-159 have no fully specified semantics but are mostly understood as
C1 controls with Alias names by ISO/IEC 6429:1992.
See https://www.unicode.org/charts/PDF/U0080.pdf and the specification for details.

#### utf8 deprecated characters
```txt
https://en.wikipedia.org/wiki/Unicode_character_property#Deprecated
https://www.unicode.org/Public/15.0.0/ucd/PropList-15.0.0d2.txt
0149          ; Deprecated # L&       LATIN SMALL LETTER N PRECEDED BY APOSTROPHE
0673          ; Deprecated # Lo       ARABIC LETTER ALEF WITH WAVY HAMZA BELOW
0F77          ; Deprecated # Mn       TIBETAN VOWEL SIGN VOCALIC RR
0F79          ; Deprecated # Mn       TIBETAN VOWEL SIGN VOCALIC LL
17A3..17A4    ; Deprecated # Lo   [2] KHMER INDEPENDENT VOWEL QAQ..KHMER INDEPENDENT VOWEL QAA
206A..206F    ; Deprecated # Cf   [6] INHIBIT SYMMETRIC SWAPPING..NOMINAL DIGIT SHAPES
2329          ; Deprecated # Ps       LEFT-POINTING ANGLE BRACKET
232A          ; Deprecated # Pe       RIGHT-POINTING ANGLE BRACKET
E0001         ; Deprecated # Cf       LANGUAGE TAG
```

#### comparison of (non-fully optimized) unicode decoding
created via lib/std/unicode/throughput_test.zig:
short ASCII strings
  count:    84 MiB/s [3]
short Unicode strings
  count:   126 MiB/s [3]
pure ASCII strings
  count:  1770 MiB/s [80]
pure Unicode strings
  count:   370 MiB/s [80]
mixed ASCII/Unicode strings
  count:   522 MiB/s [224]
