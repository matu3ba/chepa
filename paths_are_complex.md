Windows
for now skipped
https://docs.microsoft.com/en-us/windows/win32/fileio/maximum-file-path-limitation?tabs=cmd
* Windows API (with some exceptions discussed in the following paragraphs):
  "D:\some 256-character path string<NUL>" (in total 260 characters)
* Windows 10, Version 1607, and later: removed MAX_PATH limitations
  - as of now, Windows an opt-in is required to to enable it
* maximum path of 32,767 characters is approximate, because the "\\?\"
  prefix may be expanded to a longer string by the system at run time,
  and this expansion applies to the total length.
* Windows applications use the UTF-16 implementation of Unicode.
older character sets that are native to Windows Me/98/95: Code Pages
assume: for sanity use UTF-16 encoded characters

Linux
https://lwn.net/Articles/649115/
Internally, Linux permits to use any byte sequence for file name,
except for null byte 0 and forward slash '/'
(which is used as directory separator).
https://unix.stackexchange.com/a/2092
It depends on how you mount the file system, just take a look at mount
options for different file systems in man mount. For example iso9660,
vfat and fat have iocharset and utf8 options.
On top of that the user can overwrite localization settings
https://unix.stackexchange.com/a/87763 ie to encode filenames in
different ways
assume: for sanity use utf8 encoded characters

NOTE: Only the Kernel information about filepaths are reliable,
since the path representation is depending on the user-overridable locale.
