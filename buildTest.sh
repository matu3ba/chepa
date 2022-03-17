#!/usr/bin/env sh
zig build

# check
./zig-out/bin/chepa -c ./zig-out/
test $? -eq 0 || (echo "ok, but found error"; exit 0);
./zig-out/bin/chepa -c ./test_folders/bad_patterns/
test $? -eq 1 || (echo "bad_patterns, found error"; exit 0);
./zig-out/bin/chepa -c ./test_folders/control_sequences/
test $? -eq 1 || (echo "bad_patterns, found error"; exit 0);

# shell output
./zig-out/bin/chepa ./zig-out/
test $? -eq 0 || (echo "ok, but found error"; exit 0);

./zig-out/bin/chepa ./test_folders/bad_patterns/
test $? -eq 1 || (echo "bad_patterns, found error"; exit 0);
./zig-out/bin/chepa ./zig-out/ ./test_folders/bad_patterns/
test $? -eq 1 || (echo "bad_patterns, found error"; exit 0);
./zig-out/bin/chepa ./zig-out/ ./test_folders/bad_patterns/
test $? -eq 1 || (echo "bad_patterns, found error"; exit 0);
./zig-out/bin/chepa ./test_folders/bad_patterns/ ./zig-out/
test $? -eq 1 || (echo "bad_patterns, found error"; exit 0);

./zig-out/bin/chepa ./test_folders/control_sequences/
test $? -eq 2 || (echo "control_sequences, found error"; exit 0);
./zig-out/bin/chepa ./zig-out/ ./test_folders/bad_patterns/ ./test_folders/control_sequences/
test $? -eq 2 || (echo "control_sequences, found error"; exit 0);
./zig-out/bin/chepa ./zig-out/ ./test_folders/control_sequences/ ./test_folders/bad_patterns/
test $? -eq 2 || (echo "control_sequences, found error"; exit 0);
./zig-out/bin/chepa ./test_folders/bad_patterns/ ./test_folders/control_sequences/ ./zig-out/
test $? -eq 2 || (echo "control_sequences, found error"; exit 0);
./zig-out/bin/chepa ./test_folders/bad_patterns/ ./zig-out/ ./test_folders/control_sequences/
test $? -eq 2 || (echo "control_sequences, found error"; exit 0);

#TODO capture output

# file output
#TODO
