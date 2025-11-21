#!/usr/bin/env bash
set -euo pipefail

AERI_IMG="gitlab.ssec.wisc.edu:5555/aeri/aeri_armory"
INPUT_ROOT="/Users/benjaminriot/Dropbox/research/field_campaigns/ponex/scripts/aeri/temp"
OUTPUT_ROOT=""          # Will default to INPUT_ROOT if not specified
FORCE=0
VERBOSE=1
RECORD_RANGE=""
SEPARATE=1
AE_FOLDER=""            # optional: specific AE folder to process

usage() {
  cat <<EOF
Usage: $(basename "$0") [-i INPUT_ROOT] [-o OUTPUT_ROOT] [-f] [-r \"START END\"] [-s] [-q] [AE_FOLDER]

Run cal_val.py over AEYYMMDD folders (AERI calibration / 3rd BB step).

Options:
  -i INPUT_ROOT           Root directory with AEYYMMDD folders (default: /Users/benjaminriot/Dropbox/research/field_campaigns/ponex/scripts/aeri/temp)
  -o OUTPUT_ROOT          Root directory for outputs (default: same as INPUT_ROOT)
  -f                      Force overwrite (delete existing bbcal_* in outdir)
  -r \"START END\"          Record range for cal_val.py (optional)
  -s                      Separate: plot each record individually (passes -s to cal_val.py)
  -q                      Quiet

Positional argument:
  AE_FOLDER               Optional path to specific AEYYMMDD folder to process.
                          If not provided, processes the most recent AE* folder in INPUT_ROOT.
EOF
}

while getopts "i:o:fr:qhs" opt; do
  case "$opt" in
    i) INPUT_ROOT="$OPTARG" ;;
    o) OUTPUT_ROOT="$OPTARG" ;;
    f) FORCE=1 ;;
    r) RECORD_RANGE="$OPTARG" ;;
    q) VERBOSE=0 ;;
    s) SEPARATE=1 ;;
    h) usage; exit 0 ;;
    *) usage; exit 1 ;;
  esac
done

shift $((OPTIND - 1))
if [ $# -gt 0 ]; then
  AE_FOLDER="$1"
fi

# If output not specified, default to input
if [ -z "$OUTPUT_ROOT" ]; then
  OUTPUT_ROOT="$INPUT_ROOT"
fi

usage() {
  cat <<EOF
Usage: $(basename "$0") [-i INPUT_ROOT] [-o OUTPUT_ROOT] [-f] [-r \"START END\"] [-s] [-q]

Run cal_val.py over AEYYMMDD folders (AERI calibration / 3rd BB step).

Options:
  -i INPUT_ROOT           Root directory with AEYYMMDD folders (default: /Users/benjaminriot/Dropbox/research/field_campaigns/ponex/scripts/aeri/temp)
  -o OUTPUT_ROOT          Root directory for outputs (default: same as INPUT_ROOT)
  -f                      Force overwrite (delete existing bbcal_* in outdir)
  -r "START END"          Record range for cal_val.py (optional)
  -s                      Separate: plot each record individually (passes -s to cal_val.py)
  -q                      Quiet
EOF
}

while getopts "i:o:fr:qhs" opt; do
  case "$opt" in
    i) INPUT_ROOT="$OPTARG" ;;
    o) OUTPUT_ROOT="$OPTARG" ;;
    f) FORCE=1 ;;
    r) RECORD_RANGE="$OPTARG" ;;
    q) VERBOSE=0 ;;
    s) SEPARATE=1 ;;
    h) usage; exit 0 ;;
    *) usage; exit 1 ;;
  esac
done

# If OUTPUT_ROOT not explicitly set, default to INPUT_ROOT
if [ "$OUTPUT_ROOT" = "/Users/benjaminriot/Dropbox/research/field_campaigns/ponex/scripts/aeri/temp" ] && [ "$INPUT_ROOT" != "/Users/benjaminriot/Dropbox/research/field_campaigns/ponex/scripts/aeri/temp" ]; then
  OUTPUT_ROOT="$INPUT_ROOT"
fi

[ -d "$INPUT_ROOT" ] || { echo "ERROR: INPUT_ROOT '$INPUT_ROOT' missing"; exit 1; }
mkdir -p "$OUTPUT_ROOT"

log() {
  [ "$VERBOSE" -eq 1 ] && echo "$@"
}

# Build extra args for cal_val once, outside the loop
CALVAL_EXTRA_ARGS=()
if [ -n "$RECORD_RANGE" ]; then
  CALVAL_EXTRA_ARGS+=( -r "$RECORD_RANGE" )
fi
if [ "$SEPARATE" -eq 1 ]; then
  CALVAL_EXTRA_ARGS+=( -s )
fi

# Determine which AE folders to process
if [ -n "$AE_FOLDER" ]; then
  # Specific folder provided
  if [ ! -d "$AE_FOLDER" ]; then
    echo "ERROR: AE_FOLDER '$AE_FOLDER' does not exist" >&2
    exit 1
  fi
  AE_FOLDERS=("$AE_FOLDER")
else
  # No folder provided: find the most recent AE* folder in INPUT_ROOT
  # Sort by name (AEYYMMDD format sorts chronologically) and take the last one
  LAST_AE=""
  while IFS= read -r folder; do
    LAST_AE="$folder"
  done < <(find "$INPUT_ROOT" -maxdepth 1 -type d -name "AE*" | sort)
  
  if [ -z "$LAST_AE" ]; then
    echo "ERROR: No AE* folders found in '$INPUT_ROOT'" >&2
    exit 1
  fi
  AE_FOLDERS=("$LAST_AE")
  log "Auto-selected most recent folder: $(basename "${AE_FOLDERS[0]}")"
fi

for daydir in "${AE_FOLDERS[@]}"; do
  [ -d "$daydir" ] || continue
  daybase=$(basename "$daydir")
  # Use an "output" subdirectory inside each AEYYYYMMDD folder, per request
  outdir="$daydir/output"
  mkdir -p "$outdir"

  # Convert to absolute paths for Docker volume mounts
  daydir_abs=$(cd "$daydir" && pwd)
  outdir_abs=$(cd "$outdir" && pwd)
  
  # On Windows (Git Bash), convert paths to Windows format for Docker
  # Docker on Windows expects C:/Users/... not /c/Users/...
  if [[ "$(uname -s)" =~ ^(MSYS|MINGW) ]]; then
    # Use cygpath if available, otherwise use sed
    if command -v cygpath &> /dev/null; then
      daydir_abs=$(cygpath -w "$daydir_abs")
      outdir_abs=$(cygpath -w "$outdir_abs")
    else
      daydir_abs=$(echo "$daydir_abs" | sed 's|^/\([a-z]\)/|\U\1:/|')
      outdir_abs=$(echo "$outdir_abs" | sed 's|^/\([a-z]\)/|\U\1:/|')
    fi
    # Use forward slashes (Docker accepts both on Windows)
    daydir_abs="${daydir_abs//\\//}"
    outdir_abs="${outdir_abs//\\//}"
  fi

  log "=== Cal/BB for $daybase ==="
  log "  Input:  $daydir_abs"
  log "  Output: $outdir_abs"

  # Look for any bbcal_* file as a signal that cal_val already ran
  bb_exists=$(find "$outdir" -maxdepth 1 -type f -name "bbcal_*" | head -n 1 || true)

  if [ -n "$bb_exists" ] && [ "$FORCE" -eq 0 ]; then
    log "  cal_val: existing bbcal_* found ($bb_exists) - skipping"
    continue
  fi

  if [ "$FORCE" -eq 1 ]; then
    log "  cal_val: FORCE enabled - deleting old bbcal_* in $outdir"
    find "$outdir" -maxdepth 1 -type f -name "bbcal_*" -delete || true
  fi

  # Print what will be run; avoid passing an empty positional argument to cal_val.py
  if [ ${#CALVAL_EXTRA_ARGS[@]} -gt 0 ]; then
    log "  cal_val: running cal_val.py ${CALVAL_EXTRA_ARGS[*]}"
  else
    log "  cal_val: running cal_val.py (no extra args)"
  fi

  # Build docker command array and append extra args only if present to avoid
  # injecting an empty string argument which confuses cal_val.py's arg parser.
  
  # On Windows, use /c/path format and bypass entrypoint
  if [[ "$(uname -s)" =~ ^(MSYS|MINGW) ]]; then
    daydir_mount=$(echo "$daydir_abs" | sed 's|^\([A-Z]\):|/\L\1|')
    outdir_mount=$(echo "$outdir_abs" | sed 's|^\([A-Z]\):|/\L\1|')
    
    DOCKER_CMD=(cal_val.py "$daydir_mount" -o "$outdir_mount" -vv)
    if [ ${#CALVAL_EXTRA_ARGS[@]} -gt 0 ]; then
      DOCKER_CMD+=("${CALVAL_EXTRA_ARGS[@]}")
    fi
    
    docker run --rm \
      --entrypoint //aeri_armory_env/bin/python3 \
      -v "$daydir_mount:$daydir_mount" \
      -v "$outdir_mount:$outdir_mount" \
      "$AERI_IMG" \
      "${DOCKER_CMD[@]}"
  else
    DOCKER_CMD=("$AERI_IMG" cal_val.py "$daydir_abs" -o "$outdir_abs" -vv)
    if [ ${#CALVAL_EXTRA_ARGS[@]} -gt 0 ]; then
      DOCKER_CMD+=("${CALVAL_EXTRA_ARGS[@]}")
    fi
    
    docker run --rm \
      -v "$daydir_abs:$daydir_abs" \
      -v "$outdir_abs:$outdir_abs" \
      "${DOCKER_CMD[@]}"
  fi

  log ""
done

log "Cal/BB done."
