# sinopia

This repository has two folders:

- `docs/` — a human-friendly description of the application, with no code. It is the source of truth.
- `project/` — the application code, which must faithfully implement what `docs/` describes.

The user never edits `project/` directly: they edit `docs/` and then run `./fresco.sh`.

## Sync procedure

When asked to sync:

1. Find what changed in `docs/` since the last commit: run `git add docs/` and then `git diff --cached -- docs/`. This shows the content of modified, new and deleted files alike. For binary files (images, spreadsheets, PDFs) the diff only says that they changed: open them to see how.
2. Read the whole of `docs/` for context, not only the changes.
3. Modify `project/` so that it matches the updated `docs/`. If `project/` is empty, build the application from scratch.
4. Do not edit `docs/`.
5. Commit everything (`docs/` and `project/`) in a single commit, with a message summarizing the change in plain language.

If there are no changes in `docs/`, do nothing and say so.
