# sinopia: instructions for the workshop

In fresco painting, the *sinopia* is the drawing traced on the wall before the painting covers it. In this repository:

- `docs/` is the sinopia: the user's description of the application, in plain words, tables, examples and sketches. It is the source of truth. The user may not know how to program.
- `project/` is the fresco: the code that brings the drawing to life.
- You are the workshop (*bottega*): you paint `project/` so that it matches `docs/`.

`./fresco.sh` calls you once per *giornata* (one change, painted, checked and set in one go). It tells you the giornata number and the base to compare against. It takes care of git: branches, commits, tags. **Never run git commands that change anything** (commit, add, checkout, switch, reset, restore, stash, merge, branch, tag, clean, rm, push). Reading git (diff, log, show, status) is fine.

## Your pages and the user's pages

The whole of `docs/` belongs to the user, except two pages that belong to you:

- `docs/QUESTIONS.md`: your open questions.
- `docs/DECISIONS.md`: your notebook of decisions.

Never create, change or delete any other file in `docs/`. `fresco.sh` puts back anything you touch there.

## Painting a giornata

1. **Read the new strokes.** Run the `git diff --cached <base> -- docs/` command given in the prompt. It shows everything the user changed since the last giornata, new and deleted files included. Binary files (images, spreadsheets, PDFs) only show up as changed: open them to see how.
2. **Study the whole drawing.** Read all of `docs/`, not just the changes, plus `docs/DECISIONS.md` and the current `project/`. A stroke only makes sense in its composition.
3. **Ask instead of guessing.** If the drawing is ambiguous, contradicts itself, or leaves out something you cannot reasonably decide on your own, do not paint. See "Questions" below.
4. **Paint.** Change `project/` until it does everything the drawing describes, and nothing it forbids. Keep the existing fresco where the drawing hasn't changed.
5. **Turn examples into tests.** See "The contract of project/" below. Run `project/test.sh` and keep painting until every example holds.
6. **Write down your decisions** in `docs/DECISIONS.md`. See "Decisions" below.
7. **Name the giornata.** Write a one-line title, at most 60 characters, to `.fresco/title`. Describe what changed for the user, in plain words, not in code terms: "Loans last three weeks", not "Update loan model".

Do not commit: `fresco.sh` runs the tests again and commits only if every example holds.

## The contract of project/

`project/` must always contain two executable scripts, written so they work from a fresh clone on macOS and Linux:

- `project/run.sh` starts the application so that the user can try it. If it needs dependencies, it installs them first, inside `project/` (a virtual environment, `node_modules`, and so on). When it starts a server, it prints the address to open.
- `project/test.sh` runs every example as an automated test. For each example it prints exactly one line, `PASS <example>` or `FAIL <example>`, where `<example>` is a short plain-language description of it. It exits with 0 only if every example passes. It also installs what it needs on its first run.

Tests come from the drawing. Every example in `docs/` (a concrete scene: "Anna has three books and tries to borrow a fourth: the app asks her to return one first") becomes at least one test. Rules stated with *must*, *never*, *always*, *at most* become tests too. Don't test what the drawing doesn't say.

`project/.gitignore` must exclude dependencies, build output and any data the application creates while the user tries it, so that trying the app never leaves stray files.

Choosing the tools: if the drawing names a language, framework or platform, use it. Otherwise choose the simplest robust stack that runs locally with few dependencies, and record the choice in `DECISIONS.md`.

## Questions

When you can't paint without guessing, write your questions in `docs/QUESTIONS.md` under a heading for this giornata, and paint nothing else:

```
## Giornata #15 · paused

1. lending.md says a member can borrow up to three books, but members.csv
   gives Marco a limit of five. Which one is right?
```

Each question must make sense on its own: say where the problem is, quote the strokes involved, and explain the choice the user has to make. Ask only what matters for this giornata.

`QUESTIONS.md` keeps only open questions. At the start of every giornata, check the questions already there. Remove those that the drawing now answers. If the user wrote an answer directly under a question, record that answer in `DECISIONS.md` as decided by the user, then remove the question. If questions remain open, the giornata pauses: `fresco.sh` sees any `## ` heading in `QUESTIONS.md` and stops. So use `## ` headings only for open questions.

## Decisions

`docs/DECISIONS.md` lists every significant choice the drawing didn't dictate: the stack, where data is stored, what happens at the edges, assumptions you made. Write each one in plain language for someone who doesn't program, and end it with the giornata that made it, for example `(giornata #14)`. Update or remove decisions that are no longer true.

The user may rewrite a decision. If a decision differs from what you remember, the user changed it: follow it, and change the fresco to match.

## Repainting

When the prompt says this is a repaint, `project/` is empty. Paint the whole application from the whole of `docs/` and `DECISIONS.md`, as if for the first time. The drawing may now ask for a different stack: follow the drawing.
