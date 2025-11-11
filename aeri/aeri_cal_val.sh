#!/usr/bin/env bash
set -euo pipefail

AERI_IMG="gitlab.ssec.wisc.edu:5555/aeri/aeri_armory"
INPUT_ROOT="/Users/benjaminriot/Dropbox/research/field_campaigns/ponex/scripts/aeri/temp"
OUTPUT_ROOT="/Users/benjaminriot/Dropbox/research/field_campaigns/ponex/scripts/aeri/temp"
FORCE=0
VERBOSE=1
RECORD_RANGE=""
SEPARATE=1

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

for daydir in "$INPUT_ROOT"/AE*; do
  [ -d "$daydir" ] || continue
  daybase=$(basename "$daydir")
  # Use an "output" subdirectory inside each AEYYYYMMDD folder, per request
  outdir="$daydir/output"
  mkdir -p "$outdir"

  log "=== Cal/BB for $daybase ==="
  log "  Input:  $daydir"
  log "  Output: $outdir"

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
  DOCKER_CMD=("$AERI_IMG" cal_val.py "$daydir" -o "$outdir" -vv)
  if [ ${#CALVAL_EXTRA_ARGS[@]} -gt 0 ]; then
    DOCKER_CMD+=("${CALVAL_EXTRA_ARGS[@]}")
  fi

  docker run --rm \
    -v "$daydir":"$daydir" \
    -v "$outdir":"$outdir" \
    "${DOCKER_CMD[@]}"

  log ""
done

log "Cal/BB done."
