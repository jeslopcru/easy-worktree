#!/usr/bin/env zsh
source ${0:A:h}/../wt.zsh
fails=0
check() {
  local got=$(_wt_verdict $1 $2 "$3" origin/main)
  [[ ${got%%|*} == $4 ]] && print "ok    $4  ← dirty=$1 unique=$2 mr='$3'" || { print "FAIL  want $4, got $got"; (( fails++ )); }
}
check 0 0 ""            safe
check 0 0 "!7 merged"   safe
check 3 0 ""            keep
check 0 0 "!7 opened"   keep
check 0 0 "#7 open"     keep
check 0 2 "!7 merged"   check
check 0 2 "!7 closed"   check
check 0 2 ""            check
exit $fails
