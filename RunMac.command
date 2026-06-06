#!/bin/sh
set -eu

app_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
jar_path="$app_dir/AlansStickfigures.jar"
log_dir="${HOME}/Library/Logs"
log_file="$log_dir/AlanBeckersStickfigures.log"
java_bin=""

show_error() {
  /usr/bin/osascript -e "display dialog \"$1\" buttons {\"OK\"} default button \"OK\" with icon caution"
}

if [ ! -f "$jar_path" ]; then
  show_error "AlansStickfigures.jar was not found next to RunMac.command."
  exit 1
fi

if [ -x /usr/libexec/java_home ]; then
  java_home=$(/usr/libexec/java_home 2>/dev/null || true)
  if [ -n "$java_home" ] && [ -x "$java_home/bin/java" ]; then
    java_bin="$java_home/bin/java"
  fi
fi

if [ -z "$java_bin" ] && command -v java >/dev/null 2>&1; then
  java_bin=$(command -v java)
fi

if [ -z "$java_bin" ] || ! "$java_bin" -version >/dev/null 2>&1; then
  show_error "Java is required to run Alan Beckers Stickfigures."
  exit 1
fi

mkdir -p "$log_dir"
cd "$app_dir"
nohup "$java_bin" -jar "$jar_path" >> "$log_file" 2>&1 &
