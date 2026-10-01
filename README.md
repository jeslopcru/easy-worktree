# 🌳 easy-worktree

**`wt`: git worktrees without the typing.** One tiny zsh function to list, create, jump into and clean up your worktrees.

```
$ wt
   0    1 changed  main                     ~/code/my-app
*  1    0 changed  feat/login-page          ~/code/my-app/.claude/worktrees/feat-login-page
   2    3 changed  fix/flaky-tests          ~/code/my-app/.claude/worktrees/fix-flaky-tests
   3  folder gone                           ~/code/my-app/.claude/worktrees/old-spike  (stale — wt prune)
```

🟡 yellow = uncommitted changes · 🟢 green = clean · 🔴 red = folder deleted by hand · **bold `*`** = you are here

## 🚀 Install

```bash
git clone https://github.com/jeslopcru/easy-worktree.git ~/.easy-worktree
echo '[ -f ~/.easy-worktree/wt.zsh ] && source ~/.easy-worktree/wt.zsh' >> ~/.zshrc
```

Open a new terminal and type `wt`. Needs **zsh** and **git**. Docker is optional.

To update: `git -C ~/.easy-worktree pull`

## 🧰 Commands

| Command | What it does |
|---|---|
| `wt` | 📋 List worktrees: number, changed files, branch, path |
| `wt new <branch> [base]` | 🏗️ Create a worktree and jump into it. Reuses the branch if it exists, otherwise creates it from `base` (default: current HEAD). Symlinks your `.env` files in |
| `wt cd <n\|name>` | 🐇 Jump into a worktree by number or any part of its name |
| `wt rm <n\|name> [-f]` | 🧹 Stop its Docker Compose project, then remove it. Refuses if there are uncommitted changes (unless `-f`). Keeps the branch |
| `wt prune` | 🍂 Forget worktrees whose folder you deleted by hand |
| `wt help` | 📖 Everything above, in your terminal |

Press **Tab** after `wt` to complete commands, worktree names and branches. ⌨️

## 🔁 A typical day

```bash
wt new feat/login-page origin/main   # 🏗️ new house, fresh from main
# ...code, commit, push...
wt cd 0                              # 🏠 back to the main checkout
wt rm login                          # 🧹 tidy up when it's merged
git branch -D feat/login-page        # ✂️ trim the branch
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

📚 Full docs, with diagrams and a version explained with animals: **[easy-worktree docs](https://claude.ai/artifact/M3FYmmG6kEp19Kh3N7NYcL)**

## 😄 Joke

Why did the developer start using worktrees?

Because every time they ran `git stash`, their work went into hiding... and it never came back. 🫥

---

Made with 🌳 by [@jeslopcru](https://github.com/jeslopcru)
