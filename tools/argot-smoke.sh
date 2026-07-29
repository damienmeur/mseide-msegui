#!/usr/bin/env bash
#
# argot smoke check — proves the fitted voice model still catches things.
#
# Two independent checks:
#   1. custom rule fixtures      — argot rules test
#   2. foreign-dependency catch  — injects `fphttpclient` (a standard FPC unit
#                                  that appears in none of this repo's 879
#                                  familiar imports) into a primary-source
#                                  kernel file, then always reverts it
#
# Re-run this after any change to argot.toml, after a refit, or whenever a
# finding looks wrong. Exit 0 = argot is catching what it should.
#
# A silent argot is indistinguishable from a clean repo until it matters —
# that is what this script exists to disambiguate. If check 2 fails, do NOT
# conclude the tool is weak: run `argot inspect --format json` and read
# .verdict and .reasons[].signal first (a mis-scope is far more likely).

set -uo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TARGET="lib/common/kernel/msedatamodules.pas"
cd "$REPO" || exit 2

command -v argot >/dev/null 2>&1 || { echo "argot is not on PATH" >&2; exit 2; }
[ -f .argot/scorer-config.json ] || { echo "repo is not fitted — run 'argot init'" >&2; exit 2; }

fail=0

echo "=== 1/2  custom rule fixtures ==="
if argot rules test; then
  echo "PASS: custom rule fixtures green"
else
  echo "FAIL: custom rule fixtures red"
  fail=1
fi
echo

echo "=== 2/2  foreign-dependency catch ==="
if ! git diff --quiet -- "$TARGET"; then
  echo "SKIP: $TARGET already has uncommitted changes" >&2
  exit 2
fi

cleanup() { git checkout -- "$TARGET" 2>/dev/null || true; }
trap cleanup EXIT INT TERM

python3 - "$TARGET" <<'PY' || { echo "fixture failed to apply" >&2; exit 2; }
import sys, pathlib
p = pathlib.Path(sys.argv[1])
src = original = p.read_text()

src = src.replace("implementation\nuses\n sysutils;",
                  "implementation\nuses\n sysutils,fphttpclient;", 1)
if src == original:
    raise SystemExit("could not patch the implementation uses clause")

before = src
src = src.replace(
    "type\n tmsecomponent1 = class(tmsecomponent);\n",
    "type\n tmsecomponent1 = class(tmsecomponent);\n"
    "\n"
    "function fetchmoduledescriptor(const aurl: string): string;\n"
    "var\n"
    " client: tfphttpclient;\n"
    "begin\n"
    " client:= tfphttpclient.create(nil);\n"
    " try\n"
    "  result:= client.get(aurl);\n"
    " finally\n"
    "  client.free;\n"
    " end;\n"
    "end;\n", 1)
if src == before:
    raise SystemExit("could not insert the fixture function")

p.write_text(src)
PY

argot check
rc=$?

if [ "$rc" -ne 0 ]; then
  echo "PASS: argot flagged the foreign dependency (exit $rc)"
else
  echo "FAIL: argot did not fire on a dependency used nowhere in this repo."
  echo "      Run 'argot inspect --format json' before concluding anything:"
  echo "        .verdict == 'not_recommended'          -> scope is wrong, fix argot.toml [exclude]"
  echo "        .reasons[].signal                      -> relay it verbatim"
  fail=1
fi

echo
[ "$fail" -eq 0 ] && echo "smoke check: PASS" || echo "smoke check: FAIL"
exit "$fail"
