# sinopia

*The sinopia guides the fresco: write docs, get code.*

📜 [Read the story of sinopia (PDF)](https://github.com/Robin-Short/sinopia/releases/latest/download/sinopia.pdf)

In fresco painting, the *sinopia* is the drawing traced in red earth on the wall, underneath the painting. Here the sinopia is `docs/`, a plain-language description of your application, and the fresco is `project/`, its code. [Claude Code](https://claude.com/claude-code) is the workshop that paints one over the other.

You don't need to know how to code. Instead of chatting with an AI, you describe what you want in `docs/`. The description stays with your project, and the code always matches it.

## Getting started

Don't fork this repository: click **Use this template** to make your own copy. It can be private, and it has no ties to this one.

You need Git and **Claude Code in the terminal**: the `claude` command. The Claude desktop app alone doesn't install it, even though it has a Code section. Install it once with:

```
curl -fsSL https://claude.ai/install.sh | bash
```

then open a new terminal and run `claude` once to sign in. `claude --version` should now print a version number. Then:

1. Clone your new repository.
2. **Draw.** Describe your application in `docs/`. Start small: one page is enough.
3. **Paint.** Run `./fresco.sh`.
4. **Look.** Try the application with `cd project && ./run.sh`.
5. **Set or discard.** Run `./fresco.sh approve` to keep it, or `./fresco.sh discard` to throw it away.

Then draw again.

## How to draw

Write in `docs/` the way you would explain the application to a friend: what it is for, who uses it, what they can do, what must never happen. Use as many files as you like, with headings and lists, tables in CSV, sketches as images. There is no syntax to learn.

The strongest strokes are **examples**: concrete scenes such as *"Anna has three books and tries to borrow a fourth: the app asks her to return one first."* Every example becomes an automated test, and nothing is set until all of them pass.

If you care about the technology, say so in the drawing ("a website built with Django"). If you don't, the workshop chooses and writes its choice down.

## What happens when you paint

Each run of `./fresco.sh` is a *giornata*, the patch of fresh plaster a fresco painter could finish in one day.

1. The workshop reads what you changed in `docs/` since the last giornata, then the whole drawing.
2. The giornata gets its own branch (`giornata/N`), so the application you already have is never at risk.
3. The workshop paints `project/` and turns your examples into tests.
4. `fresco.sh` runs the tests itself. If some fail, the workshop keeps painting, up to two more attempts. If they still fail, nothing is set and the wall stays as it was.
5. When every example holds, the giornata is committed on its branch and waits for you.

While the workshop paints, one line keeps you posted: time spent, files touched so far, the last one. Painting a first giornata can take several minutes. Ctrl+C stops it, and the wall stays as it was.

```
$ ./fresco.sh

  sinopia    1 changed: lending.md
  plaster    new giornata #14, on its own branch
  painting   the workshop is at work (this takes a while; Ctrl+C stops it cleanly)
  painting   project/ updated, 7 files
  checking   12 of 12 examples hold
  ready      giornata #14 is waiting for your review: "Loans last three weeks"
```

## The workshop speaks back

The workshop writes on two pages of `docs/`, and only those two:

- **`QUESTIONS.md`.** When the drawing is ambiguous or contradicts itself, the workshop doesn't guess. It writes its questions here and paints nothing. Answer by changing the drawing, or right under the question, and run `./fresco.sh` again.
- **`DECISIONS.md`.** Every choice the drawing didn't make (the technology, where data is kept, what happens at the edges) is written here in plain words. Rewrite a decision you don't like, and the next giornata follows you.

Everything else in `docs/` is yours alone. If the workshop touches it, `fresco.sh` puts it back.

## Commands

| Command | What it does |
| --- | --- |
| `./fresco.sh` | Paints a new giornata from your new strokes. |
| `./fresco.sh approve` | Sets the giornata into the wall (merges it and tags it `giornata-N`). |
| `./fresco.sh discard` | Throws the giornata away. Your strokes stay in `docs/`. |
| `./fresco.sh history` | Lists every giornata. |
| `./fresco.sh back N` | Brings the wall back to giornata #N, as a new giornata. Nothing in between is lost. |
| `./fresco.sh repaint` | Empties `project/` and paints the whole fresco again from the drawing, for example on a new technology. |

## For the curious

- **The contract of `project/`.** It always contains `run.sh`, which starts the application, and `test.sh`, which runs every example and prints `PASS` or `FAIL` for each. The rules the workshop follows are in `CLAUDE.md`.
- **Permissions.** `fresco.sh` runs Claude Code without stopping to ask: it may edit files and run commands in this folder (to install dependencies and run tests), but not git commands that change history. `fresco.sh` handles git itself and checks afterwards that nothing slipped through. These rules guide the workshop; they aren't a sandbox. If that worries you, run sinopia in a container or a virtual machine.
- **Settings.** `FRESCO_RETRIES` sets how many extra attempts the workshop gets when examples fail (default 2).
- **Logs.** What the workshop said during each giornata is in `.fresco/giornata-N.log`, outside version control.
- **Leftovers.** When a giornata is stopped or discarded, `fresco.sh` cleans `project/` twice. The first pass deletes the files the workshop created, including its `.gitignore`. The second deletes what that `.gitignore` was hiding, such as freshly installed dependencies.
- **Discarding.** `discard` also undoes the edits made to `QUESTIONS.md` and `DECISIONS.md` during that giornata, including yours.
