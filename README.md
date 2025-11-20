# AERI procedures

This repository contains small utilities and pipeline wrappers used to process AERI (Atmospheric Emitted Radiance Interferometer) data. The scripts live under the `aeri/` directory and are intended to be run locally (shell scripts) and from MATLAB. These scripts were made ahead of the PONEX field campaign to facilitate processing and enable quicklooks. 

## Files of interest

- `aeri/aeri_qc_netcdf.sh` — Run AERI QC and convert DMV files to netCDF

  - Processes AEYYMMDD folders. If no folder is specified, automatically processes the most recent AE* folder in the input root.
  - For each day it runs two steps inside a Docker image (configured by `AERI_IMG`):
    1. `quality_control.py` to generate QC output (produces `*QC.nc`).
    2. `dmv_to_netcdf.py` to convert DMV files to `.nc` files (excluding QC files).
  - Key options: `-i INPUT_ROOT`, `-o OUTPUT_ROOT`, `-f` (force overwrite), `-q` (quiet).
  - Optional positional argument: path to a specific AE folder to process.
  - Usage: `./aeri_qc_netcdf.sh [-i INPUT_ROOT] [-o OUTPUT_ROOT] [-f] [-q] [AE_FOLDER]`

- `aeri/aeri_cal_val.sh` — Run calibration/blackbody (cal_val.py) over day folders

  - Processes AEYYMMDD folders. If no folder is specified, automatically processes the most recent AE* folder in the input root.
  - Runs `cal_val.py` inside the Docker image and produces calibration outputs (e.g. files named `bbcal_*`) in each day's `output/` folder.
  - Key options: `-i INPUT_ROOT`, `-o OUTPUT_ROOT`, `-f` (force), `-r "START END"` (record range), `-s` (separate records), `-q` (quiet).
  - Optional positional argument: path to a specific AE folder to process.
  - Usage: `./aeri_cal_val.sh [-i INPUT_ROOT] [-o OUTPUT_ROOT] [-f] [-r "START END"] [-s] [-q] [AE_FOLDER]`

- `aeri/run_aeri_pipeline.m` — MATLAB wrapper to run the shell pipeline

  - Convenience function to run the QC/netCDF step and optionally the cal/BB step from MATLAB.
  - Usage example:

    ```matlab
    run_aeri_pipeline('/path/to/aeri/temp','/path/to/output', true, false)
    % arguments: inputRoot, outputRoot, doCalVal (true/false), force (true/false)
    ```

## Key configuration

- Docker image: both shell scripts use the `AERI_IMG` variable (default in the scripts: `gitlab.ssec.wisc.edu:5555/aeri/aeri_armory`). The Docker image must contain `quality_control.py`, `dmv_to_netcdf.py` and `cal_val.py` tools.
- Default input/output root: the scripts default to `aeri/temp/` in this repository. Each day is expected to be in a folder named `AEYYMMDD/` inside that root; outputs are written into an `output/` subdirectory under each day folder.
- The `aeri/temp/` directory is intentionally excluded from git (see `.gitignore`) because it holds derived/large data files.

## Example workflows

1) From the shell (process the most recent AE folder):

```bash
cd /path/to/scripts/aeri
./aeri_qc_netcdf.sh -i ./temp -o ./temp
./aeri_cal_val.sh -i ./temp -o ./temp
```

Or process a specific AE folder:

```bash
./aeri_qc_netcdf.sh -i ./temp -o ./temp /path/to/AE240408
./aeri_cal_val.sh -i ./temp -o ./temp /path/to/AE240408
```

Or use relative paths (the scripts convert them to absolute paths for Docker):

```bash
./aeri_qc_netcdf.sh -i "." -o "output"
./aeri_cal_val.sh -i "." -o "output"
```

2) From MATLAB (run QC + netCDF; optionally do cal/BB):

```matlab
% run only QC/netCDF
run_aeri_pipeline('/path/to/scripts/aeri/temp','/path/to/output', false, false)

% run QC/netCDF and cal/BB, forcing overwrite
run_aeri_pipeline('/path/to/scripts/aeri/temp','/path/to/output', true, true)
```

## Contact / debugging

- If a script fails, run it with `-q` omitted (verbose mode) to see the docker command and outputs. Check that the Docker image referenced by `AERI_IMG` is accessible and that the volume mounts point to the correct host paths.

## License

This project is licensed under the MIT License - see the `LICENSE` file for details.
