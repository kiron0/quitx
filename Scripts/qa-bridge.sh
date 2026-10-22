#!/usr/bin/env bash
set -u
cd "$(dirname "$0")/.."
dir=.qa
mkdir -p "$dir"
echo idle > "$dir/status"
echo "QA bridge watching $(pwd)/$dir/request (Ctrl-C to stop)"
while true; do
  if [ -f "$dir/request" ]; then
    req=$(head -n1 "$dir/request" | tr -d '\r')
    rm -f "$dir/request"
    cmd=${req%% *}
    arg=""
    [ "$req" != "$cmd" ] && arg=${req#* }
    if [ -n "$arg" ] && ! [[ "$arg" =~ ^[A-Za-z0-9_./]+$ ]]; then
      echo "rejected argument: $arg" > "$dir/rejected.log"
      continue
    fi
    case "$cmd" in
      test)
        echo "running $req" > "$dir/status"
        if [ -n "$arg" ]; then npm test -- --filter "$arg" > "$dir/test.log" 2>&1; else npm test > "$dir/test.log" 2>&1; fi
        echo $? > "$dir/test.exit" ;;
      build)
        echo "running build" > "$dir/status"
        npm run build > "$dir/build.log" 2>&1
        echo $? > "$dir/build.exit" ;;
      last-window)
        echo "running last-window" > "$dir/status"
        npm run test:last-window > "$dir/last-window.log" 2>&1
        echo $? > "$dir/last-window.exit" ;;
      *)
        echo "rejected command: $cmd" > "$dir/rejected.log"
        continue ;;
    esac
    echo "idle $(date +%s)" > "$dir/status"
    echo "finished: $req"
  fi
  sleep 1
done
