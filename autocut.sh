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
  ____ ___ __  __  ___  _   _           __  __ ____  ____   ___  ____  
 / ___|_ _|  \/  |/ _ \| \ | |         |  \/  / ___||  _ \ / _ \/ ___| 
 \___ \| || |\/| | | | |  \| |  _____  | |\/| \___ \| | | | | | \___ \ 
  ___) | || |  | | |_| | |\  | |_____| | |  | |___) | |_| | |_| |___) |
 |____/___|_|  |_|\___/|_| \_|         |_|  |_|____/|____/ \___/|____/  

     Auto Video Splitter by simon-msdos
EOF
  echo -e "${RESET}"
}

# ─── Self-install ───────────────────────────────
SELF_NAME="autocut"
VERSION="1.1.0"

show_help() {
  echo -e "${CYAN}AutoCut - Universal Video Splitter${RESET}"
  echo "Usage: autocut [options] /path/to/file_or_folder chunk_time"
  echo "Options:"
  echo "  -h, --help           Show this help message"
  echo "  -v, --version        Show version"
  echo "  --uninstall          Remove autocut from system"
  echo "  -o, --output DIR     Custom output directory"
  echo "  -f, --format EXT     Output format (default: original)"
  echo "  -p, --parallel N     Parallel jobs (default: 1)"
  echo "  --dry-run            Show what would be done, don't process"
  echo "  --log FILE           Log actions to FILE"
  echo "  --skip-existing      Skip existing output files"
  echo "  --audio-only         Extract audio only"
  echo
  echo "Chunk time formats: 9m30s, 570, 00:09:30"
}

uninstall_self() {
  sudo rm -f /usr/local/bin/$SELF_NAME
  echo -e "${GREEN}✅ Uninstalled autocut from /usr/local/bin${RESET}"
  exit 0
}

# ─── Time Parser ────────────────────────────────
parse_time_to_seconds() {
  local time="$1"
  if [[ "$time" =~ ^([0-9]+):([0-9]{2}):([0-9]{2})$ ]]; then
    echo $((10#${BASH_REMATCH[1]}*3600 + 10#${BASH_REMATCH[2]}*60 + 10#${BASH_REMATCH[3]}))
  elif [[ "$time" =~ ^[0-9]+$ ]]; then
    echo "$time"
  else
    local total=0
    [[ "$time" =~ ([0-9]+)h ]] && total=$((total + ${BASH_REMATCH[1]} * 3600))
    [[ "$time" =~ ([0-9]+)m ]] && total=$((total + ${BASH_REMATCH[1]} * 60))
    [[ "$time" =~ ([0-9]+)s ]] && total=$((total + ${BASH_REMATCH[1]}))
    echo "$total"
  fi
}

log_msg() {
  [[ -n "$LOG_FILE" ]] && echo "$1" >> "$LOG_FILE"
}

progress_bar() {
  local current=$1 total=$2
  local percent=$(( 100 * current / total ))
  local bar=$(printf "%-${percent}s" "#" | tr ' ' '#')
  printf "\rProgress: [%-100s] %d%%" "$bar" "$percent"
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

main() {
  banner
  install_self

  # --- Defaults ---
  OUTPUT_DIR=""
  OUTPUT_FORMAT=""
  PARALLEL=1
  DRY_RUN=0
  LOG_FILE=""
  SKIP_EXISTING=0
  AUDIO_ONLY=0

  # --- Parse args ---
  POSITIONAL=()
  while [[ $# -gt 0 ]]; do
    case "$1" in
      -h|--help) show_help; exit 0 ;;
      -v|--version) echo "$VERSION"; exit 0 ;;
      --uninstall) uninstall_self ;;
      -o|--output) OUTPUT_DIR="$2"; shift 2 ;;
      -f|--format) OUTPUT_FORMAT="$2"; shift 2 ;;
      -p|--parallel) PARALLEL="$2"; shift 2 ;;
      --dry-run) DRY_RUN=1; shift ;;
      --log) LOG_FILE="$2"; shift 2 ;;
      --skip-existing) SKIP_EXISTING=1; shift ;;
      --audio-only) AUDIO_ONLY=1; shift ;;
      --) shift; break ;;
      -*) echo "Unknown option $1"; show_help; exit 1 ;;
      *) POSITIONAL+=("$1"); shift ;;
    esac
  done
  set -- "${POSITIONAL[@]}"

  if [[ $# -lt 2 ]]; then
    show_help
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

  if [[ -z "$OUTPUT_DIR" ]]; then
    if [[ -d "$INPUT_PATH" ]]; then
      OUTPUT_DIR="$INPUT_PATH/output"
    else
      OUTPUT_DIR="$(dirname "$INPUT_PATH")/output"
    fi
  fi
  mkdir -p "$OUTPUT_DIR"

  if [[ -d "$INPUT_PATH" ]]; then
    FILES=("$INPUT_PATH"/*)
  elif [[ -f "$INPUT_PATH" ]]; then
    FILES=("$INPUT_PATH")
  else
    echo -e "${RED}❌ Not a valid file or folder: $INPUT_PATH${RESET}"
    exit 1
  fi

  echo -e "${CYAN}🗂️ Output directory:${RESET} $OUTPUT_DIR"
  echo -e "${CYAN}⏳ Chunk size:${RESET} $CHUNK_TIME (${CHUNK_SECONDS} seconds)"

  # --- Parallel processing ---
  semaphores=()
  process_file() {
    local input_file="$1"
    [[ -f "$input_file" ]] || return
    filename=$(basename -- "$input_file")
    base="${filename%.*}"
    ext="${filename##*.}"
    out_ext="${OUTPUT_FORMAT:-$ext}"

    log_msg "Processing: $filename"
    echo -e "${CYAN}🎞️  Processing: $filename${RESET}"

    duration=$(ffprobe -v error -show_entries format=duration \
      -of default=noprint_wrappers=1:nokey=1 "$input_file")
    duration=${duration%.*}

    if [[ -z "$duration" || "$duration" -eq 0 ]]; then
      echo -e "${YELLOW}⚠️ Could not determine duration. Skipping: $filename${RESET}"
      log_msg "Could not determine duration: $filename"
      return
    fi

    part=1
    start=0

    while (( start < duration )); do
      output_file="$OUTPUT_DIR/${base}_part${part}.${out_ext}"
      if [[ -f "$output_file" ]]; then
        if [[ "$SKIP_EXISTING" -eq 1 ]]; then
          echo -e "${YELLOW}⚠️ Skipping existing: $output_file${RESET}"
          log_msg "Skipped existing: $output_file"
          start=$((start + CHUNK_SECONDS))
          part=$((part + 1))
          continue
        fi
        read -rp "File '$output_file' already exists. Overwrite? [y/N] " answer
        [[ "$answer" != "y" && "$answer" != "Y" ]] && break
      fi

      if [[ "$DRY_RUN" -eq 1 ]]; then
        echo "Would create: $output_file"
        log_msg "Dry run: $output_file"
      else
        if [[ "$AUDIO_ONLY" -eq 1 ]]; then
          ffmpeg -hide_banner -loglevel error -ss "$start" -i "$input_file" -t "$CHUNK_SECONDS" \
            -vn -acodec copy "$output_file"
        else
          ffmpeg -hide_banner -loglevel error -ss "$start" -i "$input_file" -t "$CHUNK_SECONDS" \
            -vf "scale=trunc(iw/2)*2:trunc(ih/2)*2" \
            -c:v libx264 -preset fast -crf 23 -c:a aac -b:a 128k "$output_file"
        fi
        if [[ $? -eq 0 ]]; then
          echo -e "${GREEN}  ✔️ Created: $output_file${RESET}"
          log_msg "Created: $output_file"
        else
          echo -e "${RED}  ❌ Failed to create part $part of $filename${RESET}"
          log_msg "Failed: $output_file"
          break
        fi
      fi

      # Progress bar
      progress_bar $((start + CHUNK_SECONDS)) $duration

      start=$((start + CHUNK_SECONDS))
      part=$((part + 1))
    done
    echo
  }

  export -f process_file
  export OUTPUT_DIR OUTPUT_FORMAT CHUNK_SECONDS SKIP_EXISTING DRY_RUN AUDIO_ONLY LOG_FILE

  if [[ "$PARALLEL" -gt 1 ]]; then
    printf "%s\n" "${FILES[@]}" | xargs -n1 -P"$PARALLEL" bash -c 'process_file "$0"' 
  else
    for input_file in "${FILES[@]}"; do
      process_file "$input_file"
    done
  fi

  echo -e "${GREEN}🎉 All done! Video slicing complete. Created by simon-msdos${RESET}"
}

main "$@"
