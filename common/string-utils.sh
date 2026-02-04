#!/bin/bash

# @arg1 - separtor string; @arg2.... - strings to be joined
function joinByString() {
  local separator="$1"
  shift
  local first="$1"
  shift
  # For each positional parameter, replace the beginning of the parameter with the value of $separator"
  printf "%s" "$first" "${@/#/$separator}"
}

##########################
####   UNIT TESTING   ####
##########################

if [[ $1 == "test" ]]; then
# set -x
    joinByChar '@' bibi mimi fifi
    echo
    joinByString '-fi-' lili gigi io
    echo
    joinByString '---' "hello world" "this is a test" "Bash is fun"
    echo
    joinByString ' ' "one" "two" "three" "four"
    echo
    joinByString '@' "apple" "banana" "cherry"
    echo
fi