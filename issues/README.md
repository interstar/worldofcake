# Issues

Bugs and to-dos for the World of Cake framework, one Markdown file per issue. They are
ordinary files in the repo: they are read and edited with any editor, found
with grep, and committed with the change that fixes them.

## Format

A file is named `NNNN-short-slug.md`, with the issue's number padded to four
digits (`0008-goldenpond-crashes-in-rack.md`). It starts with YAML front
matter, then the description, then any comments:

```markdown
---
id: 8
title: "after 10 minutes, the goldenpond VCV Rack module crashes"
status: open
labels: [goldenpond vcv]
created: 2026-10-17
---

What happens, how to reproduce it, what should happen, and where the cause
is (or what to look at).

## Comments

### 2026-10-18 14:02

Later findings, a fix, or why it was closed.
```

| Field | Meaning |
|---|---|
| `id` | the number in the file name |
| `title` | one line, in double quotes |
| `status` | `open` or `closed` |
| `labels` | any of the labels below, or `[]` |
| `created`, `closed` | dates, `YYYY-MM-DD`; `closed` only once closed |
| `git-bug` | for issues 1–7 only: the id they had in git-bug, used in older notes |

Labels: `front-end` (parsing, typing, IR), `parser`, `interpreter`,
`haxe-target`, `smalltalk-target`, `cpp-target`, `docs`. A backend-specific
issue is labelled by its target.

## Working with issues

- **New issue:** copy the format, take the next number, set `status: open`.
- **Comment:** add a dated `###` heading under `## Comments`.
- **Close:** set `status: closed`, add `closed:`, and add a comment saying
  how it was fixed (or why it is not a bug). Commit it with the fix.
- **Refer to an issue** by its number and file, e.g. "issue 8
  (`issues/0008-if-branches-of-sum-variants.md`)".

Listing, from `wchnt-lang/`:

```bash
grep -l "^status: open" issues/[0-9]*.md
```

```bash
grep -l "cpp-target" issues/[0-9]*.md
```

```bash
grep -h "^title:" $(grep -l "^status: open" issues/[0-9]*.md)
```

## History


