function run_aeri_pipeline(inputRoot, outputRoot, doCalVal, force, doGEOMS)
% run_aeri_pipeline("/Users/benjaminriot/Dropbox/research/field_campaigns/ponex/scripts/aeri/temp", "/data/aeri_output", true, false, true)
%
% Inputs:
%   inputRoot  - Root directory with AEYYMMDD folders
%   outputRoot - Output directory (default: same as inputRoot)
%   doCalVal   - Run calibration/blackbody processing (default: false)
%   force      - Force overwrite existing files (default: false)
%   doGEOMS    - Run GEOMS netCDF conversion (default: true)

if nargin < 1 || isempty(inputRoot), inputRoot = "/Users/benjaminriot/Dropbox/research/field_campaigns/ponex/scripts/aeri/temp"; end
if nargin < 2 || isempty(outputRoot), outputRoot = inputRoot; end
if nargin < 3 || isempty(doCalVal),   doCalVal   = false;      end
if nargin < 4 || isempty(force),      force      = false;     end
if nargin < 5 || isempty(doGEOMS),    doGEOMS    = true;      end

forceFlag = "";
if force
    forceFlag = "-f";
end

qc_cmd = sprintf('./aeri_qc_netcdf.sh -i "%s" -o "%s" %s', ...
                 inputRoot, outputRoot, forceFlag);
fprintf('Running QC + netCDF:\n  %s\n', qc_cmd);
[status, msg] = system(qc_cmd);
if status ~= 0
    error('QC/netCDF script failed:\n%s', msg);
end

if doCalVal
    cal_cmd = sprintf('./aeri_cal_val.sh -i "%s" -o "%s" %s', ...
                      inputRoot, outputRoot, forceFlag);
    fprintf('Running cal/BB:\n  %s\n', cal_cmd);
    [status, msg] = system(cal_cmd);
    if status ~= 0
        error('Cal/BB script failed:\n%s', msg);
    end
end

if doGEOMS
    fprintf('Running GEOMS netCDF conversion:\n');
    fprintf('  processDailyAERIdata_GEOMS(''%s'', false, true)\n', outputRoot);
    try
        processDailyAERIdata_GEOMS(outputRoot, false, true);
        fprintf('GEOMS conversion complete.\n');
    catch ME
        warning('GEOMS conversion failed:\n%s', ME.message);
    end
end

fprintf('AERI pipeline finished.\n');
end

