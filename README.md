# sinopia

*The sinopia guides the fresco: write docs, get code.*

In fresco painting, the *sinopia* is the preparatory drawing traced on the wall, underneath the painting. Here the sinopia is `docs/`, a plain-language description of your application, and the fresco is `project/`, its code.

You don't need to know how to code. Instead of chatting with an AI, you describe what you want in `docs/`, and [Claude Code](https://claude.com/claude-code) paints it.

## Getting started

Don't fork this repository: click **Use this template** to create your own (it can be private).

Then:

1. Install and log in to [Claude Code](https://claude.com/claude-code).
2. Clone your new repository.
3. Describe your application in `docs/`: add sections, change definitions, add data. Any human-friendly format works.
4. Run `./fresco.sh`.

Claude Code reads what changed in `docs/`, updates `project/` accordingly, and commits both.

## Structure

```
CLAUDE.md   instructions for Claude Code
fresco.sh   paints the fresco: turns docs into code
docs/       your description of the application
project/    the generated code
```
