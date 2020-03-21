#! /bin/bash
#                             _
#  _ __ _   _ _ __         __| |
# | '__| | | | '_ \ _____ / _` |
# | |  | |_| | | | |_____| (_| |
# |_|   \__,_|_| |_|      \__,_|
#
# © 2020 Navaz Alani
# Contact : nalani@uwaterloo.ca

about="
run-d is a program which takes a command string and
a list of files (provided as a listing).
It watches the file(s) passed for changes and re-runs
the given command whenever a change is recorded.

It is intended to be used during development.
"

# temporary files
tmpDir=/tmp/run-d
reloadF=$tmpDir/reload

# tmpDirInit creates the required temporary files in the
# system /tmp directory.
tmpDirInit() {
  [ ! -d $tmpDir ] && mkdir $tmpDir
  touch $reloadF
}

# tmpDirClean cleans up files created in the /tmp directory.
tmpDirClean() {
  rm -rf $tmpDir $reloadF
}

# DList is a collection of PIDs of tasks processes which
# need to be killed before the program exits.
DList=()

# _hash_ generates a hex digest of the given file using
# a local installation of openssl.
_hash_() {
  openssl dgst -hex "$1" | awk '{ print $2 }'
}

# fileMonitorD is a daemon which reloads when the service
# when a change to the file is detected.
# It checks every second, by default.
fileMonitorD() {
  file=$1
  [ -z "$file" ] && echo "run-d: error- filename not provided" && return 1
  [ ! -f "$file" ] && echo "run-d: error- file '$file' does not exist; ignoring..." &&
    return 1

  hashA=$(_hash_ "$file")
  while true; do
    hashB=$(_hash_ "$file")
    if [[ $hashA != "$hashB" ]]; then
      echo "run-d: info- change in file $1"
      echo "true" >$reloadF
      hashA=$hashB
    fi
    sleep 0.25
  done
}

# evaluateD is a daemon responding to service reload requests from
# fileMonitorDaemons.
# It checks every second, by default.
evaluateD() {
  cmd=$1
  eval "$cmd" &
  cmdPid=$!

  while true; do
    reloadCond=$(cat $reloadF)
    if [[ $reloadCond == "true" ]]; then
      echo "run-d: info- re-running..."
      if ps -p $cmdPid >/dev/null; then
        kill $cmdPid
      fi
      eval "$cmd" &
      cmdPid=$!
      echo "" >$reloadF
    fi
    sleep 1
  done
}

# run-d is the entry point, allowing specification of command
# and files to monitor. Run `run-d -h` for more.
run-d() {
  DList=()
  tmpDirInit

  cmd=$1
  usage="usage: super [command] -f [files...]"
  if [[ $cmd == "-h" || $cmd == "-help" || $# -lt 3 ]]; then
    echo "$usage"
    echo "$about"
    return
  fi

  # spawn evaluation daemon
  echo "run-d: dispatched update handler"
  evaluateD "$cmd" &
  DList+=($!)

  # spawn a daemon to watch each file
  if [[ $2 == "-f" ]]; then
    for i in $(seq 3 $#); do
      echo "run-d: dispatched daemon for $(eval echo \${$i})"
      fileMonitorD "$(eval echo \${$i})" &
      DList+=($!)
    done
  else
    echo "run-d: error unknown file specification '$2'"
    return 1
  fi

  wait
}

# trap and handle SIGINT
trap ctrl_c SIGINT
function ctrl_c() {
  # kill remaining daemons
  for pid in "${DList[@]}"; do
    kill "$pid"
  done

  tmpDirClean
  trap - SIGINT
}
