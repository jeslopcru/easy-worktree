_wt_paths() { git worktree list --porcelain | awk '/^worktree /{sub(/^worktree /,""); print}'; }

_wt_resolve() {
  local match
  if [[ $1 == <-> ]]; then
    match=$(_wt_paths | sed -n "$(( $1 + 1 ))p")
  else
    match=$(_wt_paths | command grep -- "/$1$")
    [[ -n $match ]] || match=$(_wt_paths | command grep -- "$1")
    [[ $(print -l -- $match | wc -l) -gt 1 ]] && { echo "ambiguous: '$1' matches several worktrees, use its number:" >&2; print -l -- $match >&2; return 1; }
  fi
  [[ -n $match ]] || { echo "no worktree matches '$1' — run 'wt' to see the list" >&2; return 1; }
  print -- $match
}

_wt_help() {
  cat <<'EOF'
wt — see, switch and remove git worktrees

USAGE
  wt                   list all worktrees of this repo
  wt new <branch> [base]
                       create a worktree and jump into it
                       (existing branch → checks it out; new branch → created from
                       [base], default: current HEAD; .env files are symlinked in)
                       lives in $WT_DIR (default: .claude/worktrees)
  wt cd <n|name>       jump the terminal into a worktree
  wt rm <n|name> [-f]  remove a worktree (stops its docker compose first)
  wt prune             forget worktrees whose folder was deleted by hand
                       (stops their docker compose; never touches existing
                       folders, branches or commits)
  wt help              show this help

<n|name>  the number shown by 'wt', or any part of the worktree path
          (e.g. 'wt cd login' → .../feat-login-page)
          press TAB to complete commands, worktree names and branches

READING THE LIST
  *  bold line     the worktree you are in right now
  yellow           has uncommitted changes (the number = changed files)
  green            clean
  red "folder gone" the folder was deleted by hand — run 'wt prune'
  0                always the main checkout (cannot be removed)

REMOVING
  - refuses if the worktree has uncommitted changes; add -f to discard them
  - runs 'docker compose -p <folder> down -v' first, so its containers and
    volumes don't keep ports busy
  - the branch is kept; delete it yourself with: git branch -D <branch>

EXAMPLES
  wt                   what do I have?
  wt new feat/login-page origin/main
                       start a new task from the latest main
  wt cd 3              work in worktree 3
  wt cd 0              back to the main checkout
  wt rm login          clean up a finished worktree
EOF
}

_wt_list() {
  local i=0 d n mark bold color current reset=$'\e[0m'
  current=$(git rev-parse --show-toplevel)
  _wt_paths | while read -r d; do
    [[ ${d:A} == ${current:A} ]] && { mark='*'; bold=$'\e[1m'; } || { mark=' '; bold=''; }
    if [[ ! -d $d ]]; then
      printf '%s %2d  \e[31m%-62s%s %s  (stale — wt prune)\n' "$mark" $i "folder gone" "$reset" "${d/#$HOME/~}"
      (( i++ )); continue
    fi
    n=$(git -C "$d" status -s 2>/dev/null | wc -l | tr -d ' ')
    (( n > 0 )) && color=$'\e[33m' || color=$'\e[32m'
    printf '%s%s %2d  %s%3s changed  %-50s%s%s %s%s\n' "$bold" "$mark" $i "$color" $n \
      "$(git -C "$d" branch --show-current 2>/dev/null)" "$reset" "$bold" "${d/#$HOME/~}" "$reset"
    (( i++ ))
  done
}

_wt_new() {
  local branch=$1 base=${2:-HEAD} main dir f
  main=$(_wt_paths | head -1)
  dir="$main/${WT_DIR:-.claude/worktrees}/${branch//\//-}"
  if git show-ref --verify --quiet "refs/heads/$branch"; then
    git worktree add "$dir" "$branch" || return 1
  else
    git worktree add -b "$branch" "$dir" "$base" || return 1
  fi
  for f in "$main"/.env*(N) "$main"/*/.env*(N); do
    [[ -f $f && ! -e $dir/${f#$main/} ]] && ln -s "$f" "$dir/${f#$main/}"
  done
  cd "$dir" && echo "created $dir — you are now in it"
}

_wt_prune() {
  local d stale=()
  for d in ${(f)"$(_wt_paths)"}; do [[ -d $d ]] || stale+=$d; done
  (( ${#stale} )) || { echo "nothing to prune — every worktree folder exists"; return; }
  for d in $stale; do
    echo "pruning ${d/#$HOME/~}"
    docker compose -p "${${d:t}:l}" down -v 2>/dev/null
  done
  git worktree prune && echo "done — branches kept"
}

_wt_rm() {
  local target force=()
  [[ $2 == -f ]] && force=(--force)
  target=$(_wt_resolve "$1") || return 1
  [[ $target == $(_wt_paths | head -1) ]] && { echo "refusing to remove the main worktree" >&2; return 1; }
  [[ $PWD == $target* ]] && cd "$(_wt_paths | head -1)"
  docker compose -p "${${target:t}:l}" down -v 2>/dev/null
  git worktree remove $force "$target" && echo "removed $target (branch kept)"
}

wt() {
  case $1 in
    help|-h|--help) _wt_help; return ;;
  esac
  git rev-parse --git-dir >/dev/null 2>&1 || { echo "not in a git repo — cd into one first (wt help)" >&2; return 1; }
  case $1 in
    ""|ls) _wt_list ;;
    cd)    [[ -n $2 ]] || { echo "which one? wt cd <n|name>" >&2; return 1; }
           local target; target=$(_wt_resolve "$2") && cd "$target" ;;
    new)   [[ -n $2 ]] || { echo "which branch? wt new <branch> [base]" >&2; return 1; }
           _wt_new "$2" "$3" ;;
    prune) _wt_prune ;;
    rm)    [[ -n $2 ]] || { echo "which one? wt rm <n|name> [-f]" >&2; return 1; }
           _wt_rm "$2" "$3" ;;
    *)     echo "unknown command '$1'" >&2; _wt_help >&2; return 1 ;;
  esac
}

_wt_complete() {
  local -a cmds names
  cmds=(
    'ls:list all worktrees'
    'new:create a worktree and jump into it'
    'cd:jump into a worktree'
    'rm:remove a worktree'
    'prune:forget worktrees whose folder was deleted'
    'help:show help'
  )
  if (( CURRENT == 2 )); then
    _describe 'wt command' cmds
    return
  fi
  local d i=0
  for d in ${(f)"$(_wt_paths 2>/dev/null)"}; do
    [[ $words[2] == rm && $i == 0 ]] || names+=("${d:t}:$(git -C "$d" branch --show-current 2>/dev/null)")
    (( i++ ))
  done
  case $words[2] in
    cd|rm) (( CURRENT == 3 )) && _describe 'worktree' names
           [[ $words[2] == rm && CURRENT -eq 4 ]] && compadd -- -f ;;
    new)   (( CURRENT == 3 )) && compadd -- ${(f)"$(git for-each-ref --format='%(refname:short)' refs/heads 2>/dev/null)"}
           (( CURRENT == 4 )) && compadd -- ${(f)"$(git for-each-ref --format='%(refname:short)' refs/heads refs/remotes 2>/dev/null)"} ;;
  esac
}
(( $+functions[compdef] )) && compdef _wt_complete wt
