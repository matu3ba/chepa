# check paths
Fast checking of paths on conformance for shell coding and absence of antipatterns

wip.

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

## planned interfaces
1. write messages for safe inspection (default for cli, -l line count or no args)
   * only necessary allocs
   * sane default with configurability (what fits on screen)
   * developer may use memory intensive processes
2. only status codes (-c for check, 0 ok, negative ones or positives ones?)
   * only necessary allocs
   * immediate exit on error
3. store messages in memory and flush at end (-s size, -f file)
   * write broken file paths with to user provided file
   * user provided max size in b,kb,mb [size means complexity]
4. API for use case 2+3 and configurable buffer or allocation size

## status
For now, `POSIX portable file name character set` is used to keep things simple
and will remain as another code path behind an additional cli flag.
Eventually this work will be extended to utf8 and utf16 strings, which offer more
opportunity for bad practice filenames.

## todos
- [x] use case 1
- [x] zig build
- [ ] test data
- [ ] perf: refactor error case once #489 lands or dont refactor once #84 is implemented
- [ ] use case 2
- [ ] use case 3
- [ ] test data
- [ ] utf8
- [ ] simd?
- [ ] utf16

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
