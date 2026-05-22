# Git hooks (optional)

## Dropping `Co-authored-by: Cursor <cursoragent@cursor.com>`

Historic commits on `origin` were rewritten without that trailer. After a rewrite, collaborators may need:

```bash
git fetch origin
git reset --hard origin/master
```

Enable this repo’s **commit-msg** hook (run once per clone):

```bash
git config core.hooksPath .githooks
```

Hooks are **not** auto-enabled by Git for security—you must opt in.

Also check **Cursor → Settings** for options that attach a Git co-author on commits.
