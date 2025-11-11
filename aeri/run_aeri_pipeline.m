function run_aeri_pipeline(inputRoot, outputRoot, doCalVal, force)
% run_aeri_pipeline("/Users/benjaminriot/Dropbox/research/field_campaigns/ponex/scripts/aeri/temp", "/data/aeri_output", true, false)

if nargin < 1 || isempty(inputRoot), inputRoot = "/Users/benjaminriot/Dropbox/research/field_campaigns/ponex/scripts/aeri/temp"; end
if nargin < 2 || isempty(outputRoot), outputRoot = inputRoot; end
if nargin < 3 || isempty(doCalVal),   doCalVal   = false;      end
if nargin < 4 || isempty(force),      force      = false;     end

forceFlag = "";
if force
    forceFlag = "-f";
end

% NOTE: script name changed to match repository (aeri_qc_netcdf.sh)
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

fprintf('AERI pipeline finished.\n');
end

