# AERI procedures

This repository contains small utilities and pipeline wrappers used to process AERI (Atmospheric Emitted Radiance Interferometer) data. The scripts live under the `aeri/` directory and are intended to be run locally (shell scripts) and from MATLAB. These scripts were made ahead of the PONEX field campaign to facilitate processing and enable quicklooks.

## Prerequisites

### Docker

The processing scripts rely on a Docker image containing the AERI processing tools. You need Docker installed on your system.

#### Installing Docker

**macOS:**
```bash
# Install via Homebrew
brew install --cask docker

# Or download Docker Desktop from:
# https://www.docker.com/products/docker-desktop
```

**Linux:**
```bash
# Ubuntu/Debian
sudo apt-get update
sudo apt-get install docker.io
sudo systemctl start docker
sudo systemctl enable docker

# Add your user to the docker group to run without sudo
sudo usermod -aG docker $USER
# Log out and back in for this to take effect
```

**Windows:**
Download and install Docker Desktop from https://www.docker.com/products/docker-desktop

#### Pulling the AERI Docker Image

The scripts use the image `gitlab.ssec.wisc.edu:5555/aeri/aeri_armory`. Pull it before running:

```bash
docker pull gitlab.ssec.wisc.edu:5555/aeri/aeri_armory
```

### MATLAB

The GEOMS conversion step requires MATLAB. Ensure MATLAB is installed and accessible from the terminal:

```bash
which matlab
# Should return the path to MATLAB executable
```

## Files of interest

- `aeri/aeri_qc_netcdf.sh` — Run AERI QC and convert DMV files to netCDF

  - Processes AEYYMMDD folders. If no folder is specified, automatically processes the most recent AE* folder in the input root.
  - For each day it runs two steps inside a Docker image:
    1. `quality_control.py` to generate QC output (produces `*QC.nc`).
    2. `dmv_to_netcdf.py` to convert DMV files to `.nc` files.
  - Key options: `-i INPUT_ROOT`, `-o OUTPUT_ROOT`, `-f` (force overwrite), `-q` (quiet).
  - Optional positional argument: path to a specific AE folder to process.

- `aeri/aeri_cal_val.sh` — Run calibration/blackbody (cal_val.py) over day folders

  - Processes AEYYMMDD folders. If no folder is specified, automatically processes the most recent AE* folder in the input root.
  - Runs `cal_val.py` inside the Docker image and produces calibration outputs (e.g. files named `bbcal_*`) in each day's `output/` folder.
  - Key options: `-i INPUT_ROOT`, `-o OUTPUT_ROOT`, `-f` (force), `-r "START END"` (record range), `-s` (separate records), `-q` (quiet).
  - Optional positional argument: path to a specific AE folder to process.

- `aeri/run_aeri_pipeline.sh` — Complete pipeline wrapper (recommended)

  - Bash script that runs the full pipeline: QC/netCDF conversion, optional calibration, and GEOMS conversion.
  - Automatically calls `run_aeri_pipeline.m` via MATLAB.
  - Key options: `-i INPUT_ROOT`, `-o OUTPUT_ROOT`, `-c` (include calibration), `-f` (force overwrite), `--no-geoms` (skip GEOMS conversion).

- `aeri/run_aeri_pipeline.m` — MATLAB wrapper

  - Called by `run_aeri_pipeline.sh` or can be used directly in MATLAB.
  - Runs the shell scripts and then calls `processDailyAERIdata_GEOMS.m` for GEOMS conversion.

- `aeri/processDailyAERIdata_GEOMS.m` — GEOMS netCDF conversion

  - Converts AERI netCDF files to GEOMS-compliant format.
  - Automatically detects location from lat/lon coordinates in files.
  - Supported locations: Gault, NRC, Burnside, Inuvik, Radar.

## Key configuration

- **Docker image**: Scripts use `gitlab.ssec.wisc.edu:5555/aeri/aeri_armory` (configurable via `AERI_IMG` variable).
- **Data structure**: Each day's data should be in a folder named `AEYYMMDD/` (e.g., `AE240408/`). Outputs are written to an `output/` subdirectory under each AE folder.
- **Location detection**: The GEOMS conversion automatically detects instrument location from the latitude/longitude metadata in the netCDF files (tolerance: 0.1°).

## Usage Examples

### Complete Pipeline (Recommended)

**Basic usage - process most recent folder:**
```bash
cd aeri/
./run_aeri_pipeline.sh -i ../aeri_proc
```

**With calibration:**
```bash
./run_aeri_pipeline.sh -i ../aeri_proc -c
```

**Force overwrite existing files:**
```bash
./run_aeri_pipeline.sh -i ../aeri_proc -f
```

**With calibration and force overwrite:**
```bash
./run_aeri_pipeline.sh -i ../aeri_proc -c -f
```

**Custom output directory:**
```bash
./run_aeri_pipeline.sh -i ../aeri_proc -o /path/to/output
```

**Skip GEOMS conversion:**
```bash
./run_aeri_pipeline.sh -i ../aeri_proc --no-geoms
```

### Individual Scripts

**1) QC and netCDF conversion only:**
```bash
cd aeri/
# Process most recent AE folder
./aeri_qc_netcdf.sh -i ../aeri_proc

# Process specific folder
./aeri_qc_netcdf.sh -i ../aeri_proc ../aeri_proc/AE240408

# Force overwrite
./aeri_qc_netcdf.sh -i ../aeri_proc -f
```

**2) Calibration/blackbody processing:**
```bash
# Process most recent AE folder
./aeri_cal_val.sh -i ../aeri_proc

# Process specific folder
./aeri_cal_val.sh -i ../aeri_proc ../aeri_proc/AE240408

# With record range and separate plots
./aeri_cal_val.sh -i ../aeri_proc -r "1 10" -s
```

**3) GEOMS conversion (from MATLAB):**
```matlab
% Process all AE folders in directory
processDailyAERIdata_GEOMS('../aeri_proc', false, true)
% arguments: root_dir, mat (save .mat), nc (save GEOMS netCDF)

% Or use the full pipeline wrapper
run_aeri_pipeline('../aeri_proc', '../aeri_proc', false, false, true)
% arguments: inputRoot, outputRoot, doCalVal, force, doGEOMS
```

## Expected Output Structure

After processing, each AEYYMMDD folder will contain an `output/` subdirectory with:

```
AE240408/
├── [raw AERI files...]
└── output/
    ├── 20240408QC.nc              # QC output
    ├── 240408B1_cxs.nc            # Converted netCDF files
    ├── 240408B2_cxs.nc
    ├── 240408C1_rnc.nc
    ├── 240408C2_rnc.nc
    ├── 240408_sum.nc
    ├── bbcal_*.png                # Calibration plots (if -c used)
    └── groundbased_aeri_mcgill125_radar_20240408t000000z_20240408t235959z_001.nc  # GEOMS file
```

## Contact / debugging

If a script fails, run it with verbose mode (omit `-q`) to see the docker command and outputs. Check that:
- The Docker image `gitlab.ssec.wisc.edu:5555/aeri/aeri_armory` is accessible
- Volume mounts point to the correct host paths
- Input folders follow the `AEYYMMDD` naming convention
- MATLAB is accessible from the terminal for GEOMS conversion

Common issues:
- **Docker permission errors**: Add your user to the docker group (Linux) or ensure Docker Desktop is running (macOS/Windows)
- **MATLAB not found**: Add MATLAB to your PATH or specify the full path in the scripts
- **Location not detected**: Verify lat/lon in netCDF files are correct and within 0.1° of known sites. You can add a site manually with a tolerance in the processDailyAERIdata_GEOMS function. 

## License

This project is licensed under the MIT License - see the `LICENSE` file for details.
