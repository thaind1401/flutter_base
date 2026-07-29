#!/bin/sh
# Formats a Dart file immediately after Claude edits it, at this repo's page
# width — because the width is 120 and every tool's default is 80.
#
# Without this, a session's worth of edits lands at the wrong width and the
# failure surfaces minutes later as a red `make fmt-check`, in CI, in a diff
# that is now large enough that nobody can see which change caused it. One
# `dart format` per edit is the cheapest possible place to catch it.
#
# Wired from .claude/settings.json as a PostToolUse hook on Edit|Write. Claude
# Code passes the tool call as JSON on stdin; the path we want is
# `.tool_input.file_path`.
#
# Always exits 0. A formatter that can block an edit is a formatter that will
# eventually block the wrong edit, and this is a convenience, not a gate —
# `make fmt-check` in the pre-push hook and in CI is the gate.
#
# To turn it off, delete the "hooks" block from .claude/settings.json.

file=$(jq -r '.tool_input.file_path // empty' 2>/dev/null)

[ -n "$file" ] || exit 0
[ -f "$file" ] || exit 0

case "$file" in
	# Generated output carries the generator's own style, and reformatting it
	# only makes the next build_runner run produce a spurious diff.
	*.g.dart | *.config.dart | *.module.dart | */generated/*) exit 0 ;;
	*.dart) ;;
	*) exit 0 ;;
esac

# Prefer the FVM-pinned SDK so the formatter matches the one CI runs; fall back
# to whatever `dart` is on PATH rather than silently doing nothing on a machine
# without FVM.
if command -v fvm >/dev/null 2>&1; then
	fvm dart format --page-width=120 "$file" >/dev/null 2>&1
elif command -v dart >/dev/null 2>&1; then
	dart format --page-width=120 "$file" >/dev/null 2>&1
fi

exit 0
