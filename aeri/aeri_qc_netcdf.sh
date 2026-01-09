#!/usr/bin/env bash
set -euo pipefail

# Default settings
AERI_IMG="gitlab.ssec.wisc.edu:5555/aeri/aeri_armory"
INPUT_ROOT="/Users/benjaminriot/Dropbox/research/field_campaigns/ponex/scripts/aeri/temp"
OUTPUT_ROOT=""          # Will default to INPUT_ROOT if not specified
FORCE=0                 # 0: skip if exists, 1: overwrite
VERBOSE=1
AE_FOLDER=""            # optional: specific AE folder to process

usage() {
  cat <<EOF
Usage: $(basename "$0") [-i INPUT_ROOT] [-o OUTPUT_ROOT] [-f] [-q] [-a] [AE_FOLDER]

Loop over AEYYMMDD folders and:
  1) Run AERI QC (quality_control.py)
  2) Convert DMV files to netCDF (dmv_to_netcdf.py)

Options:
  -i INPUT_ROOT   Root directory with AEYYMMDD folders (default: /Users/benjaminriot/Dropbox/research/field_campaigns/ponex/scripts/aeri/temp)
  -o OUTPUT_ROOT  Root directory for outputs (default: same as INPUT_ROOT)
  -f              Force overwrite (pass -f to QC, delete existing .nc)
  -q              Quiet (less verbose)
  -a              Process all AE* folders found in INPUT_ROOT

Positional argument:
  AE_FOLDER       Optional path to specific AEYYMMDD folder to process.
                  If not provided, processes the most recent AE* folder in INPUT_ROOT (unless -a is used).
EOF
}

PROCESS_ALL=0
while getopts "i:o:fqha" opt; do
  case "$opt" in
    i) INPUT_ROOT="$OPTARG" ;;
    o) OUTPUT_ROOT="$OPTARG" ;;
    f) FORCE=1 ;;
    q) VERBOSE=0 ;;
    a) PROCESS_ALL=1 ;;
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

if [ ! -d "$INPUT_ROOT" ]; then
  echo "ERROR: INPUT_ROOT '$INPUT_ROOT' does not exist" >&2
  exit 1
fi

# Make sure OUTPUT_ROOT exists
mkdir -p "$OUTPUT_ROOT"

log() {
  if [ "$VERBOSE" -eq 1 ]; then
    echo "$@"
  fi
}

# Determine which AE folders to process
if [ -n "$AE_FOLDER" ]; then
  # Specific folder provided
  if [ ! -d "$AE_FOLDER" ]; then
    echo "ERROR: AE_FOLDER '$AE_FOLDER' does not exist" >&2
    exit 1
  fi
  AE_FOLDERS=("$AE_FOLDER")
elif [ "$PROCESS_ALL" -eq 1 ]; then
  # Process all AE* folders
  AE_FOLDERS=()
  while IFS= read -r folder; do
    AE_FOLDERS+=("$folder")
  done < <(find "$INPUT_ROOT" -maxdepth 1 -type d -name "AE*" | sort)

  if [ "${#AE_FOLDERS[@]}" -eq 0 ]; then
    echo "ERROR: No AE* folders found in '$INPUT_ROOT'" >&2
    exit 1
  fi
  log "Selected ${#AE_FOLDERS[@]} folders for processing."
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

# Loop over selected AEYYMMDD folders
for daydir in "${AE_FOLDERS[@]}"; do
  [ -d "$daydir" ] || continue
  daybase=$(basename "$daydir")
  # Place outputs inside an "output" subdirectory of each AE folder
  outdir="$daydir/output"
  mkdir -p "$outdir"

  # Convert to absolute paths for Docker volume mounts
  daydir_abs=$(cd "$daydir" && pwd)
  outdir_abs=$(cd "$outdir" && pwd)

  log "=== Processing $daybase ==="
  log "  Input:  $daydir_abs"
  log "  Output: $outdir_abs"

  # ---------- 1) QC: look for any *QC.nc in outdir ----------
  qc_exists=$(find "$outdir" -maxdepth 1 -type f -name "*QC.nc" | head -n 1 || true)

  if [ -n "$qc_exists" ] && [ "$FORCE" -eq 0 ]; then
    log "  QC: existing QC file found ($qc_exists) - skipping QC"
  else
    log "  QC: running quality_control.py (force=$FORCE)"
    # Build docker command and append -f only if FORCE=1 to avoid passing
    # an empty argument (which can trigger errors with set -u)
    DOCKER_CMD=("$AERI_IMG" quality_control.py "$daydir_abs" -o "$outdir_abs" -vv)
    if [ "$FORCE" -eq 1 ]; then
      DOCKER_CMD+=( -f )
    fi
    
    # Debug: show the exact docker command
    log "  Docker volume mounts:"
    log "    -v \"$daydir_abs\":\"$daydir_abs\""
    log "    -v \"$outdir_abs\":\"$outdir_abs\""

    if [ "$FORCE" -eq 1 ]; then
      docker run --rm \
        -v "$daydir_abs:$daydir_abs" \
        -v "$outdir_abs:$outdir_abs" \
        "$AERI_IMG" \
        quality_control.py "$daydir_abs" -o "$outdir_abs" -vv -f
    else
      docker run --rm \
        -v "$daydir_abs:$daydir_abs" \
        -v "$outdir_abs:$outdir_abs" \
        "$AERI_IMG" \
        quality_control.py "$daydir_abs" -o "$outdir_abs" -vv
    fi
  fi

  # ---------- 2) DMV → netCDF: look for any converted .nc in outdir ----------
  # Exclude QC output files (they are named *QC.nc) so we always run the
  # DMV->NetCDF conversion even if QC produced its own netCDF file.
  nc_exists=$(find "$outdir" -maxdepth 1 -type f -name "*.nc" ! -name "*QC.nc" | head -n 1 || true)

  if [ -n "$nc_exists" ] && [ "$FORCE" -eq 0 ]; then
    log "  NetCDF: existing .nc found ($nc_exists) - skipping conversion"
  else
    if [ "$FORCE" -eq 1 ]; then
      log "  NetCDF: FORCE enabled - deleting old .nc files in $outdir"
      find "$outdir" -maxdepth 1 -type f -name "*.nc" -delete || true
    fi

    log "  NetCDF: running dmv_to_netcdf.py"
    
    docker run --rm \
      -v "$daydir_abs:$daydir_abs" \
      -v "$outdir_abs:$outdir_abs" \
      "$AERI_IMG" \
      dmv_to_netcdf.py "$daydir_abs" -o "$outdir_abs" -vv
  fi

  log ""
done

log "All done."

