#!/usr/bin/env bash
# Turns the changes made in docs/ into code in project/, then commits.
set -euo pipefail
cd "$(dirname "$0")"

claude -p "Sync project/ with docs/ following the procedure in CLAUDE.md." \
  --permission-mode acceptEdits \
  --allowedTools "Bash(git:*)"
