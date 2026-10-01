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
  wt                   list all worktrees: changes, MR/PR, and whether each one
                       is safe to remove (fetches origin first)
  wt new <branch> [base]
                       create a worktree and jump into it
                       (existing branch → checks it out; new branch → created from
                       [base], default: current HEAD; .env files are symlinked in)
                       lives in $WT_DIR (default: .claude/worktrees)
  wt cd <n|name>       jump the terminal into a worktree
  wt rm <n|name> [-f] [-b]
                       remove a worktree (stops its docker compose first)
                       -f  also discard uncommitted changes
                       -b  also delete its branch (prints how to undo)
  wt prune             forget worktrees whose folder was deleted by hand
                       (stops their docker compose; never touches existing
                       folders, branches or commits)
  wt help              show this help

<n|name>  the number shown by 'wt', or any part of the worktree path
          (e.g. 'wt cd login' → .../feat-login-page)
          press TAB to complete commands, worktree names and branches

READING THE LIST
  *        the worktree you are in right now
  #        number to use with wt cd / wt rm (0 = main checkout, never removed)
  clean    safe   no uncommitted files, every commit already in origin's
                  default branch → wt rm it
           check  has commits not in the default branch: look before removing
                  (a squash-merged MR also lands here)
           keep   uncommitted files, or its MR/PR is still open
           gone   folder was deleted by hand → wt prune
  changes  uncommitted files (yellow) or clean (green)
  MR/PR    read with glab + jq (GitLab) or gh (GitHub); '-' if none or not installed
  merged   yes         every commit is in the default branch
           no          some commits are not (yet) in the default branch
           squash?     MR merged but commits differ (squash merge?)
           no commits  branch has no commits of its own (never started)
  why      the reason, when it is not safe

REMOVING
  - refuses if the worktree has uncommitted changes; add -f to discard them
  - runs 'docker compose -p <folder> down -v' first, so its containers and
    volumes don't keep ports busy
  - the branch is kept unless you pass -b
  - remote branches on GitLab/GitHub are never touched

EXAMPLES
  wt                   what do I have, and what can I clean up?
  wt new feat/login-page origin/main
                       start a new task from the latest main
  wt cd 3              work in worktree 3
  wt cd 0              back to the main checkout
  wt rm login          clean up a finished worktree
  wt rm login -b       ...and delete its branch
EOF
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

_wt_base() {
  git symbolic-ref -q --short refs/remotes/origin/HEAD 2>/dev/null && return
  local b
  for b in origin/main origin/master; do
    git rev-parse -q --verify "$b" >/dev/null && { print -- $b; return; }
  done
  return 1
}

_wt_mr() {
  if [[ $(git remote get-url origin 2>/dev/null) == *github.com* ]]; then
    (( $+commands[gh] )) || return
    gh pr list --head "$1" --state all --limit 1 --json number,state \
      --jq '.[0] | select(.) | "#\(.number) \(.state | ascii_downcase)"' 2>/dev/null
  else
    (( $+commands[glab] && $+commands[jq] )) || return
    glab mr list --source-branch "$1" --all -F json 2>/dev/null | jq -r '.[0] | select(.) | "!\(.iid) \(.state)"'
  fi
}

_wt_merged() {
  local ahead=$1 unique=$2 mr=$3
  (( ahead == 0 ))       && { print "no commits"; return; }
  (( unique == 0 ))      && { print "yes"; return; }
  [[ $mr == *\ merged ]] && { print "squash?"; return; }
  print "no"
}

_wt_verdict() {
  local dirty=$1 unique=$2 mr=$3 base=$4
  (( dirty > 0 ))           && { print "keep|$dirty uncommitted files"; return; }
  [[ $mr == *\ opened || $mr == *\ open ]] && { print "keep|MR still open"; return; }
  (( unique == 0 ))         && { print "safe|everything is in $base"; return; }
  [[ $mr == *\ merged ]]    && { print "check|MR merged, but $unique commits differ from $base (squash?)"; return; }
  print "check|$unique commits not in $base${mr:+, MR ${mr#* }}"
}

_wt_rows() {
  git worktree list --porcelain | awk '
    /^worktree /{ if (p) print p "\t" b; p = substr($0, 10); b = "" }
    /^branch /  { b = substr($0, 19) }
    END         { if (p) print p "\t" b }'
}

_wt_lookups() {
  local b
  ( git fetch -q origin 2>/dev/null ) &
  for b in "$@"; do ( print -r -- "$b"$'\t'"$(_wt_mr "$b")" ) & done
  wait
}

_wt_list() {
  local -a rows branches; rows=(${(f)"$(_wt_rows)"})
  local -A mcolors=(yes $'\e[32m' no $'\e[33m' 'squash?' $'\e[33m' 'no commits' $'\e[2m')
  local -A mrs colors=(safe $'\e[32m' check $'\e[33m' keep $'\e[31m' main $'\e[2m' gone $'\e[35m')
  local line d b base main current i=0 n unique ahead merged v reason mark wb=6 wf=6 reset=$'\e[0m' dim=$'\e[2m'
  for line in $rows; do
    b=${line#*$'\t'}; d=${line%%$'\t'*}
    [[ -n $b ]] && branches+=$b
    (( ${#b} > wb )) && wb=${#b}; (( ${#d:t} > wf )) && wf=${#d:t}
  done
  for line in ${(f)"$(_wt_lookups $branches)"}; do mrs[${line%%$'\t'*}]=${line#*$'\t'}; done
  main=${rows[1]%%$'\t'*}
  base=$(_wt_base) || base=$(git -C "$main" branch --show-current)
  current=$(git rev-parse --show-toplevel)
  printf "$dim  %2s  %-5s  %-11s  %-11s  %-10s  %-${wb}s  %-${wf}s  %s$reset\n" '#' 'clean' 'changes' 'MR/PR' 'merged' 'branch' 'folder' 'why'
  for line in $rows; do
    d=${line%%$'\t'*}; b=${line#*$'\t'}
    mark=' '; [[ ${d:A} == ${current:A} ]] && mark='*'
    if [[ ! -d $d ]]; then
      v=gone; n=; merged=; reason="folder deleted by hand — run wt prune"
    else
      n=$(git -C "$d" status -s 2>/dev/null | wc -l | tr -d ' ')
      if [[ $d == $main ]]; then
        v=main; merged=; reason=
      else
        unique=$(git cherry "$base" "${b:-$(git -C "$d" rev-parse HEAD)}" 2>/dev/null | command grep -c '^+')
        ahead=$(git rev-list --count "$base..${b:-$(git -C "$d" rev-parse HEAD)}" 2>/dev/null)
        merged=$(_wt_merged ${ahead:-0} $unique "${mrs[$b]}")
        IFS='|' read -r v reason <<< "$(_wt_verdict $n $unique "${mrs[$b]}" $base)"
      fi
    fi
    [[ $v == safe ]] && reason=
    printf "\e[1m%s$reset %2d  %s%-5s$reset  %s%11s$reset  %-11s  %s%-10s$reset  \e[1m%-${wb}s$reset  $dim%-${wf}s$reset  %s%s$reset\n" \
      "$mark" $i "${colors[$v]}" $v "$( [[ $n == 0 ]] && print $'\e[32m' || print $'\e[33m' )" "${n/#%-/}${n:+ changed}" \
      "${mrs[$b]:--}" "${mcolors[$merged]}" "${merged:--}" "${b:-(detached)}" "${d:t}" "${colors[$v]}" "$reason"
    (( i++ ))
  done
}

_wt_rm() {
  local name target branch base unique sha force=() del= opt
  for opt in "$@"; do
    case $opt in
      -f) force=(--force) ;;
      -b) del=1 ;;
      -*) echo "unknown option '$opt' — use -f or -b" >&2; return 1 ;;
      *)  name=$opt ;;
    esac
  done
  target=$(_wt_resolve "$name") || return 1
  [[ $target == $(_wt_paths | head -1) ]] && { echo "refusing to remove the main worktree" >&2; return 1; }
  branch=$(git -C "$target" branch --show-current 2>/dev/null)
  [[ $PWD == $target* ]] && cd "$(_wt_paths | head -1)"
  docker compose -p "${${target:t}:l}" down -v 2>/dev/null
  git worktree remove $force "$target" || return 1
  echo "removed $target"
  if [[ -z $del || -z $branch ]]; then
    echo "branch ${branch:-?} kept (add -b to delete it too)"
    return
  fi
  base=$(_wt_base) || base=$(git -C "$(_wt_paths | head -1)" branch --show-current)
  unique=$(git cherry "$base" "$branch" 2>/dev/null | command grep -c '^+')
  sha=$(git rev-parse --short "$branch")
  git branch -D "$branch" >/dev/null || return 1
  echo "deleted branch $branch (was $sha)"
  (( unique == 0 )) || echo "⚠ it had $unique commits not in $base — undo with: git branch $branch $sha" >&2
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
    rm)    [[ -n $2 ]] || { echo "which one? wt rm <n|name> [-f] [-b]" >&2; return 1; }
           shift; _wt_rm "$@" ;;
    *)     echo "unknown command '$1'" >&2; _wt_help >&2; return 1 ;;
  esac
}

_wt_complete() {
  local -a cmds names
  cmds=(
    'ls:list worktrees with MR status and what is safe to remove'
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
           [[ $words[2] == rm && CURRENT -ge 4 ]] && compadd -- -f -b ;;
    new)   (( CURRENT == 3 )) && compadd -- ${(f)"$(git for-each-ref --format='%(refname:short)' refs/heads 2>/dev/null)"}
           (( CURRENT == 4 )) && compadd -- ${(f)"$(git for-each-ref --format='%(refname:short)' refs/heads refs/remotes 2>/dev/null)"} ;;
  esac
}
(( $+functions[compdef] )) && compdef _wt_complete wt
