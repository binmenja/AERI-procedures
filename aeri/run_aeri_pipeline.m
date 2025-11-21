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

% Detect if we're on Windows
isWindows = ispc;

% On Windows, we need to call bash explicitly to run .sh scripts
if isWindows
    % Find bash executable (usually in Git installation)
    bash_paths = {
        'C:\Program Files\Git\bin\bash.exe'
        'C:\Program Files (x86)\Git\bin\bash.exe'
    };
    bash_exe = '';
    for i = 1:length(bash_paths)
        if isfile(bash_paths{i})
            bash_exe = bash_paths{i};
            break;
        end
    end
    if isempty(bash_exe)
        % Try to find bash in PATH
        [status, result] = system('where bash');
        if status == 0
            bash_exe = strtrim(result);
            % Take first line if multiple results
            bash_exe = strsplit(bash_exe, newline);
            bash_exe = bash_exe{1};
        else
            error('Git Bash not found. Please install Git for Windows from https://git-scm.com/download/win');
        end
    end
    shellPrefix = sprintf('"%s" -c ', bash_exe);
else
    shellPrefix = '';
end

forceFlag = "";
if force
    forceFlag = "-f";
end

qc_cmd = sprintf('./aeri_qc_netcdf.sh -i "%s" -o "%s" %s', ...
                 inputRoot, outputRoot, forceFlag);
fprintf('Running QC + netCDF:\n  %s\n', qc_cmd);
if isWindows
    full_cmd = sprintf('%s"%s"', shellPrefix, qc_cmd);
else
    full_cmd = qc_cmd;
end
[status, msg] = system(full_cmd);
if status ~= 0
    error('QC/netCDF script failed:\n%s', msg);
end

if doCalVal
    cal_cmd = sprintf('./aeri_cal_val.sh -i "%s" -o "%s" %s', ...
                      inputRoot, outputRoot, forceFlag);
    fprintf('Running cal/BB:\n  %s\n', cal_cmd);
    if isWindows
        full_cmd = sprintf('%s"%s"', shellPrefix, cal_cmd);
    else
        full_cmd = cal_cmd;
    end
    [status, msg] = system(full_cmd);
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

