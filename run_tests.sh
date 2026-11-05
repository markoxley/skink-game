#!/bin/bash
# run_tests.sh — module test harness for skink-game.
#
# Mirrors the compiler repo's run_tests.sh flow: for each *_test.skink
# file, generate a `main` that calls every `pub fn Test*`, compile it
# with the self-hosted compiler, and run it.
#
# Requires SKINK_HOME pointing at the skink repo (for std/ imports and
# the skink binary). Defaults to ../../skink relative to this script.
set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# IMPORTANT: run against the INSTALLED toolchain, not the repo tree —
# `mod/` imports resolve std/ via the package cache's walk-up to
# $HOME/.local/skink/std, and mixing that with a repo SKINK_HOME makes
# every std module register twice (duplicate declarations).
if [ -x "${SKINK:-}" ]; then
    SKINK_BIN="$SKINK"
elif [ -x "${SKINK_HOME:-}/bin/skink" ]; then
    SKINK_BIN="$SKINK_HOME/bin/skink"
elif command -v skink >/dev/null 2>&1; then
    SKINK_BIN="$(command -v skink)"
elif [ -x "$HOME/.local/skink/bin/skink" ]; then
    SKINK_BIN="$HOME/.local/skink/bin/skink"
else
    echo "skink binary not found (set SKINK_HOME or SKINK)"
    exit 1
fi
# Installed layout: SKINK_HOME points at the std/ dir itself.
SKINK_HOME="${SKINK_HOME:-$HOME/.local/skink/std}"
export SKINK_HOME

RESULTS_DIR="$(mktemp -d /tmp/redis_test_results.XXXXXX)"
trap 'rm -rf "$RESULTS_DIR"' EXIT

pass=0
fail=0
skip=0
compile_fail=0

test_files=$(find "$SCRIPT_DIR" -maxdepth 1 -type f -name '*_test*.skink' | sort)

for test_file in $test_files; do
    base=$(basename "$test_file" .skink)

    module_name=$(grep -m1 '^module ' "$test_file" | awk '{print $2}')
    if [ "$module_name" = "main" ]; then
        compile_output=$(SKINK_HOME="$SKINK_HOME" timeout 120 "$SKINK_BIN" -o "$RESULTS_DIR/${base}_bin" "$test_file" 2>&1)
        if [ $? -ne 0 ]; then
            compile_fail=$((compile_fail + 1))
            echo "FAIL $base (compile error)"
            echo "$compile_output" | head -5 | sed 's/^/  /'
            continue
        fi
        test_output=$(timeout 60 "$RESULTS_DIR/${base}_bin" 2>&1)
        if [ $? -eq 0 ]; then
            pass=$((pass + 1))
            echo "PASS $base (1 test)"
        else
            fail=$((fail + 1))
            echo "FAIL $base (runtime failure)"
            echo "$test_output" | head -10 | sed 's/^/  /'
        fi
        continue
    fi

    test_fns=$(grep -oP '^pub fn (Test\w+)' "$test_file" | sed 's/pub fn //')
    if [ -z "$test_fns" ]; then
        skip=$((skip + 1))
        echo "SKIP $base (no test functions)"
        continue
    fi

    main_file="$RESULTS_DIR/${base}_main.skink"
    {
        echo 'module main'
        echo 'import "std/testing"'
        echo "import \"${base}\""
        echo ''
        echo 'fn main() -> int {'
        echo '    passed := true'
        for fn in $test_fns; do
            echo '    {'
            echo '        testing.Reset()'
            echo "        ${module_name}.${fn}()"
            echo '        if testing.Failed() {'
            echo '            passed = false'
            echo '        }'
            echo '    }'
        done
        echo '    if passed {'
        echo '        return 0'
        echo '    }'
        echo '    return 1'
        echo '}'
    } > "$main_file"

    # Place the harness beside the tests so same-dir imports resolve.
    cp "$main_file" "$SCRIPT_DIR/.${base}_harness.skink"
    compile_output=$(SKINK_HOME="$SKINK_HOME" timeout 120 "$SKINK_BIN" -o "$RESULTS_DIR/${base}_bin" "$SCRIPT_DIR/.${base}_harness.skink" 2>&1)
    compile_rc=$?
    rm -f "$SCRIPT_DIR/.${base}_harness.skink"
    if [ $compile_rc -ne 0 ]; then
        compile_fail=$((compile_fail + 1))
        echo "FAIL $base (compile error)"
        echo "$compile_output" | head -8 | sed 's/^/  /'
        continue
    fi

    test_output=$(timeout 60 "$RESULTS_DIR/${base}_bin" 2>&1)
    if [ $? -eq 0 ]; then
        pass=$((pass + 1))
        echo "PASS $base ($(echo "$test_fns" | wc -w) tests)"
    else
        fail=$((fail + 1))
        echo "FAIL $base (runtime failure)"
        echo "$test_output" | head -10 | sed 's/^/  /'
    fi
done

# SDL2 backend smoke test — only when system SDL2 + a working (dummy)
# video driver are available. gmsdl_test is `module main` and lives in
# the sdl/ subpackage so the core tests don't need SDL2.
if command -v sdl2-config >/dev/null 2>&1 || pkg-config --exists sdl2 2>/dev/null; then
    sdl_compile=$(SKINK_HOME="$SKINK_HOME" timeout 120 "$SKINK_BIN" -o "$RESULTS_DIR/gmsdl_test_bin" "$SCRIPT_DIR/sdl/gmsdl_test.skink" 2>&1)
    if [ $? -ne 0 ]; then
        compile_fail=$((compile_fail + 1))
        echo "FAIL gmsdl_test (compile/link error)"
        echo "$sdl_compile" | head -5 | sed 's/^/  /'
    else
        if SDL_VIDEODRIVER=dummy timeout 60 "$RESULTS_DIR/gmsdl_test_bin" >/dev/null 2>&1; then
            pass=$((pass + 1))
            echo "PASS gmsdl_test (1 test)"
        else
            fail=$((fail + 1))
            echo "FAIL gmsdl_test (runtime failure)"
            SDL_VIDEODRIVER=dummy timeout 60 "$RESULTS_DIR/gmsdl_test_bin" 2>&1 | head -5 | sed 's/^/  /'
        fi
    fi
else
    skip=$((skip + 1))
    echo "SKIP gmsdl_test (no system SDL2)"
fi

echo ""
echo "Suites: $pass passed, $fail failed, $compile_fail compile errors, $skip skipped"
[ $fail -eq 0 ] && [ $compile_fail -eq 0 ]
