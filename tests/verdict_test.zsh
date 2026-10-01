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
merged() {
  local got=$(_wt_merged $1 $2 "$3")
  [[ $got == $4 ]] && print "ok    merged=$4  ← ahead=$1 unique=$2 mr='$3'" || { print "FAIL  want merged=$4, got $got"; (( fails++ )); }
}
merged 0 0 ""           "no commits"
merged 2 0 ""           yes
merged 2 0 "!7 merged"  yes
merged 2 2 "!7 merged"  "squash?"
merged 2 2 "!7 closed"  no
merged 2 1 ""           no
exit $fails
