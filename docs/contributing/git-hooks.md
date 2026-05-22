# Git hooks (optional)

## Removing Cursor Agent from commit metadata (`cursoragent@cursor.com`)

Cursor can append **`Co-authored-by:`** trailers such as
**`Co-authored-by: Cursor <cursoragent@cursor.com>`**. GitHub shows these as commit co-authors. This
repo recommends **stripping those lines** so history only reflects **human** identities you choose
in **`git`** config.

### Future commits

1. **Enable this workspace’s hooks** (once per clone):

   ```bash
   git config core.hooksPath .githooks
   ```

2. In **Cursor / VS Code**, disable automated Git **co-author** / **generated commit message
   additions** tied to Cursor Agent if your build exposes that toggle (setting names vary by
   version).

The **`.githooks/commit-msg`** hook normalizes CRLF line endings then drops any
**`Co-authored-by:`** line that mentions **`cursoragent@cursor.com`**.

### Fixing history already on GitHub

If trailers already landed on **`origin`** (e.g. `origin/master`), you must **rewrite commits**
locally and **force-push** (coordinate with collaborators—everyone must **fetch** + **hard reset**
to the new tip).

Recorded helper (`tr` strips CR so patterns match reliably):

```bash
chmod +x scripts/strip-cursoragent-coauthor-msgfilter.sh
export FILTER_BRANCH_SQUELCH_WARNING=1
git filter-branch -f --msg-filter "$(pwd)/scripts/strip-cursoragent-coauthor-msgfilter.sh" master
git for-each-ref --format='%(refname)' refs/original/ | xargs -n 1 git update-ref -d   # optional cleanup
git push --force-with-lease origin master
```

Collaborators after a rewrite:

```bash
git fetch origin
git reset --hard origin/master
```

Hooks are **not** enabled automatically by Git—you must opt in with **`core.hooksPath`**.
