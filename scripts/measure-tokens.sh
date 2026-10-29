#!/usr/bin/env sh
# measure-tokens.sh — baseline CLI-output size for the token-reduction axis.
#
# Client-neutral. No dependency on any AI client. It measures the raw output
# size (bytes + an estimated token count) of a fixed list of representative,
# READ-ONLY commands this repo runs often, so the effect of a CLI-output
# compressor (e.g. rtk, see docs/optional-tooling.md) can be quantified
# before/after with the same list.
#
# Token estimate: bytes / 4 (a coarse, well-known heuristic — NOT a tokenizer).
# For the authoritative, real savings a compressor delivered to an agent, read
# that tool's own counter instead; for rtk that is `rtk stats`.
#
# Usage:
#   sh scripts/measure-tokens.sh              # default command set
#   sh scripts/measure-tokens.sh -f cmds.txt  # one shell command per line
#
# Exit status is always 0 unless a bad flag is given; a failing measured
# command is reported inline and does not abort the run.

set -u

CMD_FILE=""
while [ $# -gt 0 ]; do
    case "$1" in
        -f|--file) CMD_FILE="${2:-}"; shift 2 ;;
        -h|--help) sed -n '2,20p' "$0"; exit 0 ;;
        *) echo "unknown argument: $1" >&2; exit 2 ;;
    esac
done

# Representative, read-only commands. Keep them side-effect free.
default_cmds() {
    cat <<'CMDS'
git status
git log --stat -5
ls -laR skills
find skills -type f
grep -rn "ACTION REQUIRED" skills
CMDS
}

if [ -n "$CMD_FILE" ]; then
    [ -f "$CMD_FILE" ] || { echo "no such file: $CMD_FILE" >&2; exit 2; }
    CMDS_SRC=$(cat "$CMD_FILE")
else
    CMDS_SRC=$(default_cmds)
fi

printf '%-34s %12s %12s\n' "command" "bytes" "~tokens"
printf '%-34s %12s %12s\n' "-------" "-----" "-------"

TOTAL_BYTES=0
# Read command lines without a subshell so the totals survive the loop.
OLDIFS=$IFS
IFS='
'
for CMD in $CMDS_SRC; do
    [ -n "$CMD" ] || continue
    case "$CMD" in \#*) continue ;; esac
    # Capture combined output; a non-zero exit is reported, not fatal.
    OUT=$(eval "$CMD" 2>&1); RC=$?
    BYTES=$(printf '%s' "$OUT" | wc -c | tr -d ' ')
    TOKENS=$((BYTES / 4))
    TOTAL_BYTES=$((TOTAL_BYTES + BYTES))
    LABEL=$CMD
    [ "$RC" -eq 0 ] || LABEL="$CMD [rc=$RC]"
    printf '%-34.34s %12s %12s\n' "$LABEL" "$BYTES" "$TOKENS"
done
IFS=$OLDIFS

printf '%-34s %12s %12s\n' "-------" "-----" "-------"
printf '%-34s %12s %12s\n' "TOTAL (raw baseline)" "$TOTAL_BYTES" "$((TOTAL_BYTES / 4))"

echo
if command -v rtk >/dev/null 2>&1; then
    echo "rtk detected: $(rtk --version 2>/dev/null | head -1)"
    echo "  -> run \`rtk stats\` for the authoritative tokens-saved counter."
    echo "  -> re-run this script after enabling the rtk hook to compare the"
    echo "     raw baseline above against the compressed command stream."
else
    echo "rtk not installed. The numbers above are the raw baseline."
    echo "See docs/optional-tooling.md to install a CLI-output compressor,"
    echo "then re-run this script to measure the reduction."
fi
