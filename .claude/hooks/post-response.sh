#!/bin/bash
# Claude Code Stop hook: runs unit tests + a dev build, and if both pass,
# commits and pushes. Always exits 0 so it never blocks Claude from
# finishing a turn (see .claude/settings.json, which also runs this async).

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
LOG_FILE="$SCRIPT_DIR/post-response.log"

cd "$PROJECT_ROOT" || exit 0

{
	echo "=== $(date) ==="

	if ! make test; then
		echo "make test failed - skipping build/commit/push."
		echo
		exit 0
	fi

	if ! make dev; then
		echo "make dev failed - skipping commit/push."
		echo
		exit 0
	fi

	if [ -z "$(git status --porcelain)" ]; then
		echo "No changes to commit."
		echo
		exit 0
	fi

	git add -A
	if git commit -m "Automated commit: tests and dev build passed"; then
		if git remote get-url origin >/dev/null 2>&1; then
			if git push; then
				echo "Pushed to origin."
			else
				echo "git push failed (check upstream/auth) - commit was made locally."
			fi
		else
			echo "No 'origin' remote configured - commit was made locally, not pushed."
		fi
	else
		echo "git commit failed."
	fi
	echo
} >>"$LOG_FILE" 2>&1

exit 0
