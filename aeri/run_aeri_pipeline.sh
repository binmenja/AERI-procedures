#!/usr/bin/env bash
set -euo pipefail

# Wrapper script to run the full AERI pipeline from terminal
# Calls run_aeri_pipeline.m with appropriate parameters

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INPUT_ROOT="${SCRIPT_DIR}/temp"
OUTPUT_ROOT=""  # Will default to INPUT_ROOT if not specified
DO_CALVAL="false"
FORCE="false"
DO_GEOMS="true"
PROCESS_ALL="false"
DO_QUICKLOOK="false"
DEBUG_TEMP="false"

usage() {
  cat <<EOF
Usage: $(basename "$0") [-i INPUT_ROOT] [-o OUTPUT_ROOT] [-c] [-f] [--no-geoms] [-a] [-p] [-d]

Run full AERI pipeline via MATLAB:
  1. QC and DMV->NetCDF conversion (aeri_qc_netcdf.sh)
  2. Calibration/blackbody processing (optional, aeri_cal_val.sh)
  3. GEOMS netCDF conversion (processDailyAERIdata_GEOMS.m)
  4. Quicklook generation (optional, quicklook_timeseries.m)

Options:
  -i INPUT_ROOT   Root directory with AEYYMMDD folders (default: ${SCRIPT_DIR}/temp)
  -o OUTPUT_ROOT  Output directory (default: same as INPUT_ROOT)
  -c              Run calibration/blackbody processing
  -f              Force overwrite existing files
  --no-geoms      Skip GEOMS netCDF conversion
  -a              Process all AE* folders in INPUT_ROOT (default: processes most recent only)
  -p              Generate quicklook plots
  -d              Include engineering temperature variables in NetCDF
  -h              Show this help message

Examples:
  $(basename "$0")                    # Process with defaults (most recent folder)
  $(basename "$0") -c -a              # Include calibration, process all folders
  $(basename "$0") -i ./data -f -p    # Custom input, force overwrite, with plots
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    -i)
      INPUT_ROOT="$2"
      shift 2
      ;;
    -o)
      OUTPUT_ROOT="$2"
      shift 2
      ;;
    -c)
      DO_CALVAL="true"
      shift
      ;;
    -f)
      FORCE="true"
      shift
      ;;
    --no-geoms)
      DO_GEOMS="false"
      shift
      ;;
    -a)
      PROCESS_ALL="true"
      shift
      ;;
    -p|--quicklook)
      DO_QUICKLOOK="true"
      shift
      ;;
    -d|--debug-temp)
      DEBUG_TEMP="true"
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "ERROR: Unknown option: $1" >&2
      usage
      exit 1
      ;;
  esac
done

# If output not specified, default to input
if [ -z "$OUTPUT_ROOT" ]; then
  OUTPUT_ROOT="$INPUT_ROOT"
fi

# Check if MATLAB is available
if ! command -v matlab &> /dev/null; then
  echo "ERROR: MATLAB not found in PATH" >&2
  echo "Please ensure MATLAB is installed and accessible from terminal" >&2
  exit 1
fi

# Convert paths for Windows if running in Git Bash/MSYS
# Detect if we're on Windows (Git Bash shows MSYS or MINGW in uname)
if [[ "$(uname -s)" =~ ^(MSYS|MINGW) ]]; then
  # Convert /c/Users/... to C:/Users/...
  SCRIPT_DIR_WIN=$(cygpath -w "$SCRIPT_DIR" 2>/dev/null || echo "$SCRIPT_DIR" | sed 's|^/\([a-z]\)/|\1:/|')
  INPUT_ROOT_WIN=$(cygpath -w "$INPUT_ROOT" 2>/dev/null || echo "$INPUT_ROOT" | sed 's|^/\([a-z]\)/|\1:/|')
  OUTPUT_ROOT_WIN=$(cygpath -w "$OUTPUT_ROOT" 2>/dev/null || echo "$OUTPUT_ROOT" | sed 's|^/\([a-z]\)/|\1:/|')
  # Use forward slashes for MATLAB (works on all platforms)
  SCRIPT_DIR_WIN="${SCRIPT_DIR_WIN//\\//}"
  INPUT_ROOT_WIN="${INPUT_ROOT_WIN//\\//}"
  OUTPUT_ROOT_WIN="${OUTPUT_ROOT_WIN//\\//}"
else
  # On Linux/Mac, use paths as-is
  SCRIPT_DIR_WIN="$SCRIPT_DIR"
  INPUT_ROOT_WIN="$INPUT_ROOT"
  OUTPUT_ROOT_WIN="$OUTPUT_ROOT"
fi

# Build MATLAB command
MATLAB_CMD="cd('${SCRIPT_DIR_WIN}'); run_aeri_pipeline('${INPUT_ROOT_WIN}', '${OUTPUT_ROOT_WIN}', ${DO_CALVAL}, ${FORCE}, ${DO_GEOMS}, ${PROCESS_ALL}, ${DO_QUICKLOOK}, ${DEBUG_TEMP}); exit"

echo "========================================="
echo "Running AERI Pipeline"
echo "========================================="
echo "Input:       ${INPUT_ROOT_WIN}"
echo "Output:      ${OUTPUT_ROOT_WIN}"
echo "CalVal:      ${DO_CALVAL}"
echo "Force:       ${FORCE}"
echo "GEOMS:       ${DO_GEOMS}"
echo "Process All: ${PROCESS_ALL}"
echo "Quicklook:   ${DO_QUICKLOOK}"
echo "Debug Temp:  ${DEBUG_TEMP}"
echo "========================================="
echo ""

# Run MATLAB in batch mode
matlab -batch "${MATLAB_CMD}"

echo ""
echo "========================================="
echo "Pipeline complete!"
echo "========================================="
