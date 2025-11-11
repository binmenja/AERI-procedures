# AERI procedures

This repository contains small utilities and pipeline wrappers used to process AERI (Atmospheric Emitted Radiance Interferometer) data for the PONEX field campaign. The scripts live under the `aeri/` directory and are intended to be run locally (shell scripts) and from MATLAB.

## Files of interest

- `aeri/aeri_qc_netcdf.sh` — Run AERI QC and convert DMV files to netCDF

  - Loops over day-folders named like `AEYYMMDD/` under the input root.
  - For each day it runs two steps inside a Docker image (configured by `AERI_IMG`):
    1. `quality_control.py` to generate QC output (produces `*QC.nc`).
    2. `dmv_to_netcdf.py` to convert DMV files to `.nc` files (excluding QC files).
  - Key options: `-i INPUT_ROOT`, `-o OUTPUT_ROOT`, `-f` (force overwrite), `-q` (quiet).

- `aeri/aeri_cal_val.sh` — Run calibration/blackbody (cal_val.py) over day folders

  - Loops over the same `AE*` day folders and runs `cal_val.py` inside the same Docker image.
  - Produces calibration outputs (e.g. files named `bbcal_*`) in each day's `output/` folder.
  - Key options: `-i INPUT_ROOT`, `-o OUTPUT_ROOT`, `-f` (force), `-r "START END"` (record range), `-s` (separate records), `-q` (quiet).

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

1) From the shell (process all days, force overwrite):

```bash
cd /path/to/scripts/aeri
./aeri_qc_netcdf.sh -i ./temp -o ./temp -f
./aeri_cal_val.sh -i ./temp -o ./temp -f
```

2) From MATLAB (run QC + netCDF; optionally do cal/BB):

```matlab
% run only QC/netCDF
run_aeri_pipeline('/path/to/scripts/aeri/temp','/path/to/output', false, false)

% run QC/netCDF and cal/BB, forcing overwrite
run_aeri_pipeline('/path/to/scripts/aeri/temp','/path/to/output', true, true)
```

## Notes & recommendations

- Repository naming: the repo has been renamed to `AERI-procedures` (use hyphenated names for URL-safety). You can still display the human-readable title in the README and the repo description.
- Avoid spaces in folder or repo names used in URLs or scripts.
- If you have large previously-committed files in `aeri/temp/` that need pruning from history, use `git filter-repo` or BFG to rewrite history (this is irreversible; back up first).
- If Docker is unavailable, the scripts can be adapted to run the Python tools directly in your environment; ensure the required Python packages and scripts are on PATH.

## Contact / debugging

- If a script fails, run it with `-q` omitted (verbose mode) to see the docker command and outputs. Check that the Docker image referenced by `AERI_IMG` is accessible and that the volume mounts point to the correct host paths.

## License

This project is licensed under the MIT License - see the `LICENSE` file for details.
