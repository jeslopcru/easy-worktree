# 🌳 easy-worktree

**`wt`: git worktrees without the typing.** One tiny zsh function to list, create, jump into and clean up your worktrees.

```
$ wt
   #  clean  changes      MR/PR        merged      branch            folder            why
*  0  main     1 changed  -            -           main              my-app
   1  safe     0 changed  !42 merged   yes         feat/login-page   feat-login-page
   2  safe     0 changed  -            no commits  docs/typo         docs-typo
   3  check    0 changed  !43 closed   no          fix/flaky-tests   fix-flaky-tests   3 commits not in origin/main, MR closed
   4  check    0 changed  !45 merged   squash?     feat/search       feat-search       MR merged, but 4 commits differ from origin/main (squash?)
   5  keep     0 changed  !44 opened   no          feat/dark-mode    feat-dark-mode    MR still open
   6  keep     2 changed  -            no          spike/parser      spike-parser      2 uncommitted files
   7  gone                -            -           old/spike         old-spike         folder deleted by hand — run wt prune
```

One table, everything you need: 🟢 **safe** to remove · 🟡 **check** first (commits not in the default branch) · 🔴 **keep** (uncommitted files or open MR/PR) · 🟣 **gone** (run `wt prune`) · `*` = you are here

## 🚀 Install

```bash
git clone https://github.com/jeslopcru/easy-worktree.git ~/.easy-worktree
echo '[ -f ~/.easy-worktree/wt.zsh ] && source ~/.easy-worktree/wt.zsh' >> ~/.zshrc
```

Open a new terminal and type `wt`. Needs **zsh** and **git**. Docker is optional. For MR/PR status: `glab` + `jq` (GitLab) or `gh` (GitHub).

To update: `git -C ~/.easy-worktree pull`

## 🧰 Commands

| Command | What it does |
|---|---|
| `wt` | 📋 List worktrees with uncommitted changes, MR/PR, and whether each is **safe** to remove (fetches origin first) |
| `wt new <branch> [base]` | 🏗️ Create a worktree and jump into it. Reuses the branch if it exists, otherwise creates it from `base` (default: current HEAD). Symlinks your `.env` files in |
| `wt cd <n\|name>` | 🐇 Jump into a worktree by number or any part of its name |
| `wt rm <n\|name> [-f] [-b\|-B]` | 🧹 Stop its Docker Compose project, then remove it. Refuses if there are uncommitted changes (unless `-f`). Keeps the branch, unless you add `-b` (delete it if merged) or `-B` (delete it anyway) |
| `wt prune` | 🍂 Forget worktrees whose folder you deleted by hand |
| `wt help` | 📖 Everything above, in your terminal |

Press **Tab** after `wt` to complete commands, worktree names and branches. ⌨️

## 🚦 How "clean" is decided

- 🟢 **safe**: nothing uncommitted, and every commit is already in origin's default branch (matched by content, so work that landed through another branch counts). `wt rm` it.
- 🟡 **check**: some commits aren't in the default branch. Look before removing. A squash-merged MR lands here too, because squashing rewrites the commits.
- 🔴 **keep**: uncommitted files, or the MR/PR is still open.

The **merged** column answers *is this branch's work in the default branch?*, even without an MR:

| merged | Meaning |
|---|---|
| ✅ `yes` | Every commit is in the default branch |
| ❌ `no` | Some commits aren't there (yet) |
| 🤔 `squash?` | The MR was merged, but the commits differ, probably a squash merge |
| 💤 `no commits` | The branch never got a commit of its own |

MR/PR comes from `glab` + `jq` (GitLab) or `gh` (GitHub). Without them the column shows `-` and the rest still works.

## 🔁 A typical day

```bash
wt new feat/login-page origin/main   # 🏗️ new house, fresh from main
# ...code, commit, push...
wt cd 0                              # 🏠 back to the main checkout
wt                                   # 🚦 merged yet? safe to remove?
wt rm login -b                       # 🧹 tidy up + delete the branch, if it's merged
```

## ⚙️ Config

| Variable | Default | Meaning |
|---|---|---|
| `WT_DIR` | `.claude/worktrees` | Where `wt new` puts worktrees, relative to the main checkout |

## 🤔 Worktrees in one minute

A worktree is an extra folder attached to the **same** repo. All of them share one `.git`: commits, branches and the stash. Each one has its own checked-out branch and its own uncommitted files. So you can run tests in one folder while you code in another, with no stashing and no branch switching.

Things to know:
- 🚫 A branch can be checked out in only one worktree at a time.
- 🎒 Ignored files (`.env`, `node_modules`, `.venv`) are not copied. `wt new` symlinks `.env` files for you.
- 🐳 Docker Compose names projects after the folder, so each worktree gets its own containers. `wt rm` and `wt prune` stop them so ports don't stay busy.
- 🔨 Don't `rm -rf` a worktree. Use `wt rm`. If you already did, run `wt prune`.

📚 Full docs, with diagrams and a version explained with animals: **[jeslopcru.github.io/easy-worktree](https://jeslopcru.github.io/easy-worktree/)**

## 😄 Joke

Why did the developer start using worktrees?

Because every time they ran `git stash`, their work went into hiding... and it never came back. 🫥

---

Made with 🌳 by [@jeslopcru](https://github.com/jeslopcru)
