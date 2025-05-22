#!/bin/bash

# ===============================================
#  AutoCut - Universal Video Splitter
#  Author: simon-msdos
#  License: MIT
# ===============================================

# ─── Colors ─────────────────────────────────────
GREEN='\033[0;32m'
CYAN='\033[0;36m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
RESET='\033[0m'

# ─── Banner ─────────────────────────────────────
banner() {
  echo -e "${CYAN}"
  cat << "EOF"
    ___        __            __           __     
   /   | _____/ /_____  ____/ /___ ______/ /__  __
  / /| |/ ___/ __/ __ \/ __  / __ `/ ___/ / _ \/ /
 / ___ / /__/ /_/ /_/ / /_/ / /_/ / /__/ /  __/ / 
/_/  |_\___/\__/\____/\__,_/\__,_/\___/_/\___/_/  

     Auto Video Splitter by simon-msdos
EOF
  echo -e "${RESET}"
}

# ─── Self-install ───────────────────────────────
SELF_NAME="autocut"

install_self() {
  if [[ "$(basename "$0")" != "$SELF_NAME" ]]; then
    echo -e "${YELLOW}⚙️ Installing autocut globally...${RESET}"
    chmod +x "$0"
    sudo cp "$0" /usr/local/bin/$SELF_NAME
    echo -e "${GREEN}✅ Installed as system-wide command: $SELF_NAME${RESET}"
    echo -e "ℹ️ Now run: ${CYAN}$SELF_NAME /path/to/file_or_folder 9m30s${RESET}"
    exit 0
  fi
}

# ─── Time Parser ────────────────────────────────
parse_time_to_seconds() {
  local time="$1"
  local total=0
  [[ "$time" =~ ([0-9]+)h ]] && total=$((total + ${BASH_REMATCH[1]} * 3600))
  [[ "$time" =~ ([0-9]+)m ]] && total=$((total + ${BASH_REMATCH[1]} * 60))
  [[ "$time" =~ ([0-9]+)s ]] && total=$((total + ${BASH_REMATCH[1]}))
  echo "$total"
}

# ─── Dependency Check ───────────────────────────
check_ffmpeg() {
  if ! command -v ffmpeg >/dev/null 2>&1 || ! command -v ffprobe >/dev/null 2>&1; then
    echo -e "${YELLOW}⚙️ ffmpeg/ffprobe not found. Installing...${RESET}"
    if [ -f /etc/debian_version ]; then
      sudo apt update && sudo apt install -y ffmpeg
    elif [[ "$(uname)" == "Darwin" ]]; then
      if ! command -v brew >/dev/null 2>&1; then
        echo -e "${RED}❌ Homebrew not found. Install from https://brew.sh${RESET}"
        exit 1
      fi
      brew install ffmpeg
    else
      echo -e "${RED}❌ Unsupported OS. Install ffmpeg manually.${RESET}"
      exit 1
    fi
  fi
}

# ─── Main Function ──────────────────────────────
main() {
  banner
  install_self

  if [[ $# -lt 2 ]]; then
    echo -e "${YELLOW}Usage:${RESET} autocut /path/to/file_or_folder 9m30s"
    exit 1
  fi

  local INPUT_PATH="$1"
  local CHUNK_TIME="$2"
  local CHUNK_SECONDS

  if [[ ! -e "$INPUT_PATH" ]]; then
    echo -e "${RED}❌ File or folder not found: $INPUT_PATH${RESET}"
    exit 1
  fi

  CHUNK_SECONDS=$(parse_time_to_seconds "$CHUNK_TIME")
  if [[ "$CHUNK_SECONDS" -le 0 ]]; then
    echo -e "${RED}❌ Invalid chunk time format: $CHUNK_TIME${RESET}"
    exit 1
  fi

  check_ffmpeg

  # Detect input type
  if [[ -d "$INPUT_PATH" ]]; then
    OUTPUT_DIR="$INPUT_PATH/output"
    mkdir -p "$OUTPUT_DIR"
    FILES=("$INPUT_PATH"/*)
  elif [[ -f "$INPUT_PATH" ]]; then
    OUTPUT_DIR="$(dirname "$INPUT_PATH")/output"
    mkdir -p "$OUTPUT_DIR"
    FILES=("$INPUT_PATH")
  else
    echo -e "${RED}❌ Not a valid file or folder: $INPUT_PATH${RESET}"
    exit 1
  fi

  echo -e "${CYAN}🗂️ Output directory:${RESET} $OUTPUT_DIR"
  echo -e "${CYAN}⏳ Chunk size:${RESET} $CHUNK_TIME (${CHUNK_SECONDS} seconds)"

  # Process each file
  for input_file in "${FILES[@]}"; do
    [[ -f "$input_file" ]] || continue
    filename=$(basename -- "$input_file")
    base="${filename%.*}"

    echo -e "${CYAN}🎞️  Processing: $filename${RESET}"

    duration=$(ffprobe -v error -show_entries format=duration \
      -of default=noprint_wrappers=1:nokey=1 "$input_file")
    duration=${duration%.*}

    if [[ -z "$duration" || "$duration" -eq 0 ]]; then
      echo -e "${YELLOW}⚠️ Could not determine duration. Skipping: $filename${RESET}"
      continue
    fi

    part=1
    start=0

    while (( start < duration )); do
      output_file="$OUTPUT_DIR/${base}_part${part}.mp4"
      if [[ -f "$output_file" ]]; then
        read -rp "File '$output_file' already exists. Overwrite? [y/N] " answer
        [[ "$answer" != "y" && "$answer" != "Y" ]] && break
      fi

      ffmpeg -hide_banner -loglevel error -ss "$start" -i "$input_file" -t "$CHUNK_SECONDS" \
        -vf "scale=trunc(iw/2)*2:trunc(ih/2)*2" \
        -c:v libx264 -preset fast -crf 23 -c:a aac -b:a 128k "$output_file"

      if [[ $? -eq 0 ]]; then
        echo -e "${GREEN}  ✔️ Created: $output_file${RESET}"
      else
        echo -e "${RED}  ❌ Failed to create part $part of $filename${RESET}"
        break
      fi

      start=$((start + CHUNK_SECONDS))
      part=$((part + 1))
    done
  done

  echo -e "${GREEN}🎉 All done! Video slicing complete. Created by simon-msdos${RESET}"
}

main "$@"
