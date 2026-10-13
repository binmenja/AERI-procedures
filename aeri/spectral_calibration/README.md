# AERI spectral calibration

This is the addition to the pipeline Jonathan Gero (UW-SSEC) provided to determine the AERI wavenumber scale after a **laser change**. It has to be redone every time the laser of an AERI is replaced. The scripts are the ones JG sent us after the AERI-125 laser change, run on 2025-02-12 at Gault; apart from the two files listed at the bottom they are unchanged.

## What it does

A clear-sky AERI spectrum, averaged over about an hour (but we can adjust this case-by-base), is compared to an LBLRTM calculation made from a radiosonde launched during that hour. The AERI wavenumber axis is stretched by a scale factor until the RMS difference with LBLRTM is smallest, in 730-740 cm-1 for ch1 (LW) and 2194-2200 cm-1 for ch2 (SW). The result is a new `originalLaserWavenumber` for each channel:

```
new originalLaserWavenumber = best fit scale factor x old originalLaserWavenumber
```

The new values are what go in the AERI configuration. For reference, AERI-125 on 2025-02-12 (values from JG):

```
Old AERI LW ch1 originalLaserWavenumber (cm-1): 15799.6973
Old AERI SW ch2 originalLaserWavenumber (cm-1): 15799.4414
AERI LW ch1 best fit scale factor: 1.000005 (5.1 ppm)
AERI SW ch2 best fit scale factor: 0.999999 (-1 ppm)
New AERI LW ch1 originalLaserWavenumber (cm-1): 15799.7771
New AERI SW ch2 originalLaserWavenumber (cm-1): 15799.4254
```

You then need to updates the values in 

```
c:\config\zfli.si1 and si2
```

## What you need

- A **clear-sky** day with a radiosonde launched next to the AERI. Clouds in the averaging window ruin the fit so select shorter period if needed, but ideally the radiosonde has not been through clouds.
- `YYMMDDC1.RNC`, `YYMMDDC2.RNC` and `YYMMDD.SUM` from the `AEYYMMDD` folder of that day.
- The sonde as a NetCDF file named `*sonde*YYYYMMDD*.nc` with the variables `HEIGHT_AGL`, `PRESSURE_INSITU`, `TEMPERATURE_INSITU` and `HUMIDITY.RELATIVE_INSITU` (the format of our Gault sondes).
- MATLAB.
- The AERI Armory Docker image (same as the processing pipeline) to convert the RNC/SUM files, see step 2.
- LBLRTM. We run it on Rorqual, see step 6. If not me doing it, you change the path etc.

## Layout

```
spectral_calibration/
  doit.m              top level script, run it section by section
  function tree.txt   which mfiles call which
  mfiles/             all functions
  input/aeri/         RNC, SUM and their .cdf versions
  input/sonde/        sonde file
  working/            intermediate files (parameters, mean spectra, tape5, tape27)
  output/             figures and the summary
  example_AERI-125_20250212/   JG's working/ and output/ from 2025-02-12, for comparison
```

## Procedure

Run `doit.m` one section at a time (each `%%` block), not in one go: several steps ask for input or need something done outside MATLAB.

**1. Copy the folder.** Copy `spectral_calibration/` somewhere outside the repo (e.g. `00.shared/procedures/`) and rename it `Spectral_Calibration_AERI-UNIT_YYYY-MM-DD`. In `doit.m`, set `DATE` (YYMMDD) and change the `cd` line to the new folder. Put the AERI files in `input/aeri/` and the sonde in `input/sonde/`.

**2. Convert to NetCDF.** The next steps need `YYMMDD.SUM.cdf`, `YYMMDDC1.RNC.cdf` and `YYMMDDC2.RNC.cdf` in `input/aeri/`. JG makes them with `dmv2cdf`, which calls SSEC's `dmvdump` with paths set for his computers, so it does not run on ours. Instead:

- Run the AERI Armory conversion on the day's `AEYYMMDD` folder (`aeri/aeri_qc_netcdf.sh`, or `run_aeri_pipeline.sh --no-geoms`). This gives `YYMMDD_sum.nc`, `YYMMDDC1_rnc.nc`, `YYMMDDC2_rnc.nc` in `AEYYMMDD/output/`.
- In `doit.m`, comment out the three `dmv2cdf` lines and uncomment `armory2cdf` with the path to that `output/` folder.

`armory2cdf` writes the three `.cdf` files with the names JG's scripts expect. The files do not have the same number of records as the `dmvdump` ones: `dmvdump` keeps empty records (`missingDataFlag` = 1, everything including `Time` set to NaN) and the Armory leaves them out. Each of SUM, C1 and C2 has its own empty records (for 2025-02-12: 160, 116 and 120 out of 3088), so the three Armory files do not line up record by record, which `AERImeanSpectraRNC` assumes. `armory2cdf` keeps the records present in all three. This gives the same result as `dmvdump`, where a record with an empty SUM `Time` can never be in the averaging window anyway.

**3. Write parameters** (`writeParamsAuto`). Reads the date from the SUM file and asks for the rest. Answer with single quotes: site (`'GAULT'`), AERI unit (`'125'`), sonde launch time in UTC (`'120639'`). Writes the `.txt` files in `working/`.

**4. Mean AERI spectra** (`AERImeanSpectraRNC`). Shows a brightness temperature time series with the sonde time, then asks for the start and end of the averaging window in UTC hours (e.g. `11.8` and `12.8`). Pick at least one hour of clear, stable sky around the launch. Saves the mean ch1/ch2 spectra to `working/` and the plots to `output/`.

**5. TAPE5** (`makeTape5_McGill`). Reads the sonde, interpolates to 100 pressure levels and writes one TAPE5 per channel to `working/`. **Edit these in `makeTape5_McGill.m` for every new calibration:**

- `CO2`: current CO2 in ppmv (427 for 2025-02-12), from <https://gml.noaa.gov/ccgg/trends/>
- `atmflag`: model atmosphere used for what the sonde does not give (ozone and other gases, levels above the sonde top). 5 = subarctic winter (used for February at Gault), 2 = midlatitude summer, 3 = midlatitude winter

Check the sonde plot in `output/` before going further. If the sonde was not launched at the AERI, `doit.m` lists what to change by hand in the TAPE5 files.

**6. LBLRTM.** LBLRTM has to go through Slurm. In `doit.m` comment out `writeLBLRTM_zsh;` and uncomment `writeLBLRTM_rorqual;`. This writes `working/lblrtm_job.sh` (the Slurm job) and `working/runLBLRTM.sh`. From a terminal in the calibration folder run

```bash
bash working/runLBLRTM.sh
```

It asks for the MFA once, creates the run folder on scratch, copies the TAPE5 files and job script, submits the job and waits for it to end (`sbatch --wait`), prints the job log, and copies the two `tape27_*` files back to `working/`. If the job fails it prints the log and stops. The same commands are in `working/runLBLRTM.txt` to run by hand step by step.

The job uses the LBLRTM already installed in the my user project space (`~/links/projects/rrg-yihuang-ad/binmenja/models/LBLRTM`, `lblrtm_v12.17_linux_gnu_dbl` with its `TAPE3`, `FSCDXS`, `xs` and the MT_CKD continuum file `data/absco-ref_wv-mt-ckd.nc`, which v12.13 and later need) and runs in `~/links/scratch/spectral_calibration/` under the `rrg-yihuang-ad` allocation. These are set at the top of `mfiles/writeLBLRTM_rorqual.m`; change them there if needed.

`writeLBLRTM_zsh.m` and `writeLBLRTMremote.m` are JG's versions for SSEC's "armada" server and are left for reference.

**7. Spectral calibration** (`AERI_LBLRTM_Spectral_Calibration_RNC`). Reads the mean spectra and the tape27 files, does the fit and writes `output/AERI-UNIT_YYYYMMDD_spectral_cal_summary.txt` with the new laser wavenumbers. The tape27 headers do not need to be edited (the 27 header lines are skipped when reading). Look at the `spectral_cal_ch1/ch2` figures: the RMS curve should have a clear minimum inside the scanned range (+/-100 ppm). If the minimum is at the edge, something is wrong (clouds, sonde, wrong window).

**8. Save.** `writeSAVE` writes the command to copy everything to SSEC's armada and only works there. For us, keep the whole folder in `00.shared/procedures/` and send the summary to JG.

## Checked

The 2025-02-12 case was rerun on 2026-10-12 with JG's tape27 files (LBLRTM not rerun), twice: once from JG's `.cdf` files and once from the raw RNC/SUM files through the AERI Armory and `armory2cdf`. Both times the TAPE5 files and mean spectra are identical to JG's and the summary gives the same scale factors and laser wavenumbers. JG's outputs are in `example_AERI-125_20250212/`. Only thing I found is that when I run LBLRTM myself I get slightly different numbers despite the same TAPE5. I believe this is due to version differences; JG confirmed on 2026-10-12.

## Not from JG

- `mfiles/rh2e.m`: called by `rh2dp.m` but missing from the files JG sent. I wrote what should be the same in `rh2mr.m`/`e2mr.m`. It only affects the dew point in the sonde plot anyways, not the TAPE5.
- `mfiles/armory2cdf.m`: replaces `dmv2cdf` using the AERI Armory netCDF files.
- `mfiles/writeLBLRTM_rorqual.m`: Rorqual version of `writeLBLRTM_zsh.m`.
- Two commented lines in `doit.m` to call them.

## Notes

The tape5 writer here provides the AERI FWHM directly in the TAPE5. I personally prefer to perform the convolution myself with the exact AERI sinc since LBLRTM's TAPE5 does not accept enough digits. Should matter little in those bands though, but I might want to adjust it in the future. 