#!/usr/bin/env bash
# fresco.sh: paints your sinopia (docs/) into a fresco (project/), one giornata at a time.
#
#   ./fresco.sh              paint a new giornata from the strokes you added to docs/
#   ./fresco.sh approve      set the giornata you just reviewed into the wall
#   ./fresco.sh discard      throw the giornata away (your strokes stay in docs/)
#   ./fresco.sh history      list every giornata
#   ./fresco.sh back N       bring the wall back to giornata #N (nothing is lost)
#   ./fresco.sh repaint      paint the whole fresco again on an empty wall
#
# Written for bash 3.2 (macOS) and later.
set -euo pipefail
cd "$(dirname "$0")"

RETRIES="${FRESCO_RETRIES:-2}"          # extra attempts when examples don't hold
CLAUDE="${FRESCO_CLAUDE:-claude}"       # the workshop
STATE=".fresco"                         # local, git-ignored: logs, title, wall name
EMPTY_TREE="$(git hash-object -t tree /dev/null)"

# What the workshop may do. It runs commands in this folder (installing
# dependencies, running tests), but it never touches git history: this
# script does that, and checks afterwards that nothing slipped through.
ALLOW=("Bash" "Read" "Edit" "Write" "Glob" "Grep")
DENY=("Bash(git commit *)" "Bash(git push *)" "Bash(git switch *)" "Bash(git checkout *)"
      "Bash(git reset *)" "Bash(git restore *)" "Bash(git rebase *)" "Bash(git merge *)"
      "Bash(git tag *)" "Bash(git branch *)" "Bash(git stash *)" "Bash(git clean *)"
      "Bash(git rm *)" "Bash(git add *)")

say()  { printf '  %-9s  %s\n' "$1" "$2"; }
die()  { printf '\nfresco: %s\n\n' "$1" >&2; exit 1; }
here() { git symbolic-ref --short -q HEAD || true; }
last_giornata() { git tag -l 'giornata-*' | sed 's/^giornata-//' | grep -E '^[0-9]+$' | sort -n | tail -n 1 || true; }
wall() { cat "$STATE/wall" 2>/dev/null || echo main; }
is_own() { [ "$1" = docs/QUESTIONS.md ] || [ "$1" = docs/DECISIONS.md ]; }

# Put one path back as it is in a tree (or remove it if the tree doesn't have it).
put_back() { # tree path
  if git cat-file -e "$1:$2" 2>/dev/null; then
    git restore --source="$1" --staged --worktree -- "$2"
  else
    git rm -q --cached --ignore-unmatch -- "$2" >/dev/null; rm -f -- "$2"
  fi
}

# Undo whatever the workshop painted in project/ during this giornata.
scrape_project() {
  git restore --source=HEAD --staged --worktree -- project 2>/dev/null || true
  mkdir -p project
  git clean -fdq -- project; git clean -fdq -- project   # twice: see README, "Leftovers"
}

# Leave the giornata branch and return to the wall, keeping the user's strokes.
leave_branch() { # n
  git switch -q "$(wall)"
  git branch -q -D "giornata/$1"
  git reset -q
}

workshop() { # n base mode feedback
  local prompt
  prompt="You are the workshop. Paint giornata #$1, following CLAUDE.md.
The drawing as it was at the last giornata is $2.
See the new strokes with: git diff --cached $2 -- docs/"
  if [ "$3" = repaint ]; then
    prompt="$prompt
This is a repaint: project/ has been emptied. Paint the whole application again from the whole of docs/, as if for the first time."
  fi
  if [ -n "$4" ]; then
    prompt="$prompt

This is another attempt at the same giornata. $4"
  fi
  # exec: the background job *is* the workshop, so Ctrl+C can stop it for real
  exec "$CLAUDE" -p "$prompt" --permission-mode acceptEdits \
    --allowedTools "${ALLOW[@]}" --disallowedTools "${DENY[@]}"
}

# After each run: undo commits or branch moves, and give the user's pages back.
guard() { # n start snapshot
  [ "$(here)" = "giornata/$1" ] || die "the workshop left branch giornata/$1. Nothing was set; check 'git status'."
  if [ "$(git rev-parse HEAD)" != "$2" ]; then
    git reset -q --soft "$2"; say note "the workshop tried to commit by itself: undone"
  fi
  { git diff --name-only "$3" -- docs; git ls-files --others --exclude-standard -- docs; } | sort -u |
  while IFS= read -r f; do
    if [ -n "$f" ] && ! is_own "$f"; then put_back "$3" "$f"; say note "the workshop changed $f, which is yours: put back"; fi
  done
}

# One line, rewritten every few seconds while the workshop paints:
#   painting   3 min 12 s · 6 files · last: app/style.css
progress() { # pid
  [ -t 1 ] || return 0
  local t0 now el files last line cols
  t0="$(date +%s)"; cols="$(tput cols 2>/dev/null || echo 80)"
  while kill -0 "$1" 2>/dev/null; do
    now="$(date +%s)"; el=$(( now - t0 ))
    if [ "$el" -ge 60 ]; then el="$(( el / 60 )) min $(( el % 60 )) s"; else el="$el s"; fi
    files="$(git status --porcelain --untracked-files=all -- project | wc -l | tr -d ' ' || true)"
    line="$el · $files files"
    if [ "$files" -gt 0 ]; then
      last="$(git ls-files -m -o --exclude-standard -z -- project | xargs -0 ls -t 2>/dev/null | head -n 1 | sed 's#^project/##' || true)"
      [ -z "$last" ] || line="$line · last: $last"
    fi
    [ "${#line}" -le $(( cols - 16 )) ] || line="${line:0:$(( cols - 17 ))}…"
    printf '\r  %-9s  %s\033[K' painting "$line"
    sleep 3
  done
  printf '\r\033[K'
}

# Ctrl+C while the workshop paints: stop it, and leave the wall as it was.
interrupted() {
  trap - INT TERM
  [ -z "${CUR_PID:-}" ] || { kill "$CUR_PID" 2>/dev/null || true; wait "$CUR_PID" 2>/dev/null || true; }
  printf '\r\033[K'
  abandon "$CUR_N" "$CUR_SNAP" "stopped by you"
}

run_tests() {
  [ -x project/test.sh ] || { FEEDBACK="project/test.sh is missing or not executable. Create it as CLAUDE.md describes."; return 1; }
  local rc
  set +e; ( cd project && ./test.sh ) >"$STATE/test.out" 2>&1; rc=$?; set -e
  PASSED="$(grep -c '^PASS' "$STATE/test.out" || true)"
  FAILED="$(grep -c '^FAIL' "$STATE/test.out" || true)"
  if [ "$rc" -eq 0 ] && [ "$FAILED" -eq 0 ] && [ "$PASSED" -gt 0 ]; then return 0; fi
  if [ "$PASSED" -eq 0 ] && [ "$FAILED" -eq 0 ]; then
    FEEDBACK="project/test.sh printed no PASS or FAIL lines. Every example must print one, as CLAUDE.md describes."
  else
    FEEDBACK="These examples do not hold yet. Output of project/test.sh:
$(tail -n 60 "$STATE/test.out")"
  fi
  return 1
}

abandon() { # n snapshot reason
  scrape_project
  put_back "$2" docs/QUESTIONS.md; put_back "$2" docs/DECISIONS.md
  leave_branch "$1"
  say stopped "giornata #$1: $3"
  if [ -f "$STATE/test.out" ] && grep -q '^FAIL' "$STATE/test.out"; then
    grep '^FAIL' "$STATE/test.out" | head -n 8 | sed 's/^/             /'
  fi
  printf '\n  Nothing was set: the wall is exactly as it was, your strokes are still in docs/.\n'
  printf '  The workshop'"'"'s notes are in %s\n\n' "$STATE/giornata-$1.log"
  exit 1
}

paint() { # mode
  local mode="$1" b; b="$(here)"
  case "$b" in
    giornata/*) die "giornata #${b#giornata/} is still waiting for your review. Try it, then run ./fresco.sh approve or ./fresco.sh discard." ;;
    "") die "git is not on a branch. Switch back to your wall first (git switch main)." ;;
  esac
  command -v "$CLAUDE" >/dev/null 2>&1 || die "the claude command was not found. sinopia needs Claude Code in the terminal
(the Claude desktop app alone doesn't install it). Install it with:

    curl -fsSL https://claude.ai/install.sh | bash

then open a new terminal, run 'claude' once to sign in, and run ./fresco.sh again."
  local outside; outside="$(git status --porcelain --untracked-files=all -- . ':(exclude)docs')"
  [ -z "$outside" ] || die "there are changes outside docs/:
$outside
The workshop is the only one who paints project/. Undo these changes, or commit them yourself."

  mkdir -p "$STATE"; echo "$b" > "$STATE/wall"
  local last base n; last="$(last_giornata)"; n=$(( ${last:-0} + 1 ))
  if [ -n "$last" ]; then base="giornata-$last"; else base="$EMPTY_TREE"; fi

  git add -A -- docs
  if [ -z "$(git ls-files -- docs | grep -v -e '^docs/QUESTIONS.md$' -e '^docs/DECISIONS.md$' -e '\.gitkeep$' || true)" ]; then
    git reset -q; die "the sinopia is empty: describe your application in docs/ first."
  fi
  local strokes; strokes="$(git diff --cached --name-only "$base" -- docs | grep -v '\.gitkeep$' || true)"
  if [ -z "$strokes" ] && [ "$mode" = paint ]; then
    git reset -q; say sinopia "no new strokes since the last giornata: nothing to paint"; exit 0
  fi

  echo
  if [ -n "$strokes" ]; then
    # show the user's own pages first; the workshop's pages only if nothing else changed
    local shown count names
    shown="$(printf '%s\n' "$strokes" | grep -v -e '^docs/QUESTIONS.md$' -e '^docs/DECISIONS.md$' || true)"
    [ -n "$shown" ] || shown="$strokes"
    count="$(printf '%s\n' "$shown" | wc -l | tr -d ' ')"
    names="$(printf '%s\n' "$shown" | sed 's#^docs/##' | head -n 3 | paste -sd, - | sed 's/,/, /g')"
    [ "$count" -le 3 ] || names="$names and $(( count - 3 )) more"
    say sinopia "$count changed: $names"
  else
    say sinopia "no new strokes: repainting the whole drawing"
  fi

  local snapshot start log; snapshot="$(git write-tree)"
  git switch -q -c "giornata/$n"
  start="$(git rev-parse HEAD)"; log="$STATE/giornata-$n.log"
  rm -f "$STATE/title" "$STATE/test.out"; : > "$log"
  say plaster "new giornata #$n, on its own branch"
  if [ "$mode" = repaint ]; then
    git rm -r -q --ignore-unmatch -- project >/dev/null; rm -rf project; mkdir -p project
  fi

  local attempt=0; FEEDBACK=""
  say painting "the workshop is at work (this takes a while; Ctrl+C stops it cleanly)"
  CUR_N="$n"; CUR_SNAP="$snapshot"
  trap interrupted INT TERM
  while :; do
    workshop "$n" "$base" "$mode" "$FEEDBACK" >>"$log" 2>&1 &
    CUR_PID=$!
    progress "$CUR_PID"
    local rc=0; wait "$CUR_PID" || rc=$?
    CUR_PID=""
    if [ "$rc" -ne 0 ]; then
      tail -n 5 "$log" | sed 's/^/             /'
      abandon "$n" "$snapshot" "the workshop stopped with an error"
    fi
    guard "$n" "$start" "$snapshot"
    if [ -f docs/QUESTIONS.md ] && grep -q '^## ' docs/QUESTIONS.md; then
      scrape_project; put_back "$snapshot" docs/DECISIONS.md
      leave_branch "$n"
      say paused "the workshop has questions before it can paint: see docs/QUESTIONS.md"
      printf '\n  Answer by changing your drawing, or write the answer right under each question,\n  then run ./fresco.sh again.\n\n'
      exit 2
    fi
    if run_tests; then break; fi
    attempt=$(( attempt + 1 ))
    [ "$attempt" -le "$RETRIES" ] || abandon "$n" "$snapshot" "the examples still don't hold after $attempt attempts"
    say painting "not right yet: the workshop keeps painting (attempt $(( attempt + 1 )))"
    printf '\n--- attempt %s ---\n' "$(( attempt + 1 ))" >>"$log"
  done

  local title files
  title="$(head -n 1 "$STATE/title" 2>/dev/null | cut -c1-72 || true)"; [ -n "$title" ] || title="giornata #$n"
  git add -A
  files="$(git diff --cached --name-only HEAD -- project | wc -l | tr -d ' ')"
  git commit -q -m "giornata #$n: $title"
  if [ "$files" -eq 1 ]; then files="1 file"; else files="$files files"; fi
  say painting "project/ updated, $files"
  say checking "$PASSED of $PASSED examples hold"
  say ready "giornata #$n is waiting for your review: \"$title\""
  cat <<EOF

  Try it:   (cd project && ./run.sh)
  Then:     ./fresco.sh approve    to set it into the wall
            ./fresco.sh discard    to throw it away (your strokes stay in docs/)

EOF
}

approve() {
  local b n; b="$(here)"
  case "$b" in giornata/*) n="${b#giornata/}" ;; *) die "no giornata is waiting for review." ;; esac
  local dirty; dirty="$(git status --porcelain --untracked-files=all)"
  [ -z "$dirty" ] || die "the giornata has changes nobody painted:
$dirty
Files your app creates while you try it should be listed in project/.gitignore. Remove them, then approve again."
  git switch -q "$(wall)"
  git merge -q --ff-only "$b" 2>/dev/null || git merge -q --no-ff -m "giornata #$n" "$b"
  git tag "giornata-$n"
  git branch -q -d "$b"
  echo; say set "giornata #$n is now part of the wall"; echo
}

discard() {
  local b n; b="$(here)"
  case "$b" in giornata/*) n="${b#giornata/}" ;; *) die "no giornata is waiting for review." ;; esac
  git switch -q -f "$(wall)"
  git clean -fdq -- project
  git restore --source="$b" --worktree -- docs          # your strokes come back, unpainted
  put_back HEAD docs/QUESTIONS.md; put_back HEAD docs/DECISIONS.md; git reset -q
  git branch -q -D "$b"
  echo; say discarded "giornata #$n: the wall is exactly as it was"
  printf '  Your strokes are still in docs/, ready to be changed and painted again.\n\n'
}

history() {
  local n found=""
  echo
  for n in $(git tag -l 'giornata-*' | sed 's/^giornata-//' | grep -E '^[0-9]+$' | sort -n); do
    found=1
    printf '  #%-4s %s  %s\n' "$n" "$(git log -1 --format=%cs "giornata-$n")" \
      "$(git log -1 --format=%s "giornata-$n" | sed 's/^giornata #[0-9]*: //')"
  done
  [ -n "$found" ] || echo "  No giornate yet."
  case "$(here)" in giornata/*) printf '  #%-4s waiting for your review\n' "$(here | sed 's#giornata/##')" ;; esac
  echo
}

back() { # N
  local target="${1:-}"
  printf '%s' "$target" | grep -Eq '^[0-9]+$' || die "usage: ./fresco.sh back N   (see ./fresco.sh history)"
  case "$(here)" in giornata/*) die "approve or discard the giornata in progress first." ;; esac
  [ -z "$(git status --porcelain --untracked-files=all)" ] || die "the wall has strokes that aren't painted yet. Paint them, or undo them, first."
  git rev-parse -q --verify "refs/tags/giornata-$target" >/dev/null || die "there is no giornata #$target (see ./fresco.sh history)."
  local last n; last="$(last_giornata)"; n=$(( last + 1 ))
  git restore --source="giornata-$target" --staged --worktree -- docs project
  if git diff --cached --quiet; then die "the wall already looks exactly like giornata #$target."; fi
  git commit -q -m "giornata #$n: back to giornata #$target"
  git tag "giornata-$n"
  echo; say set "giornata #$n brings the wall back to giornata #$target"
  printf '  Nothing in between is lost: see ./fresco.sh history.\n\n'
}

case "${1:-paint}" in
  paint)    paint paint ;;
  repaint)  paint repaint ;;
  approve)  approve ;;
  discard)  discard ;;
  history)  history ;;
  back)     back "${2:-}" ;;
  help|-h|--help) sed -n '2,10p' "$0" | sed 's/^# \{0,1\}//' ;;
  *) die "unknown command '$1'. Try ./fresco.sh help" ;;
esac
