function run_aeri_pipeline(inputRoot, outputRoot, doCalVal, force, doGEOMS, processAll, doQuicklook, doDebugTemp)
% run_aeri_pipeline("/Users/benjaminriot/Dropbox/research/field_campaigns/ponex/scripts/aeri/temp", "/data/aeri_output", true, false, true, false, true, false)
%
% Inputs:
%   inputRoot  - Root directory with AEYYMMDD folders
%   outputRoot - Output directory (default: same as inputRoot)
%   doCalVal   - Run calibration/blackbody processing (default: false)
%   force      - Force overwrite existing files (default: false)
%   doGEOMS    - Run GEOMS netCDF conversion (default: true)
%   processAll - Process all AE* folders (default: false)
%   doQuicklook - Run quicklook generation (default: false)
%   doDebugTemp - Add engineering temperatures to NetCDF (default: false)

if nargin < 1 || isempty(inputRoot), inputRoot = "/Users/benjaminriot/Dropbox/research/field_campaigns/ponex/scripts/aeri/temp"; end
if nargin < 2 || isempty(outputRoot), outputRoot = inputRoot; end
if nargin < 3 || isempty(doCalVal),   doCalVal   = false;      end
if nargin < 4 || isempty(force),      force      = false;     end
if nargin < 5 || isempty(doGEOMS),    doGEOMS    = true;      end
if nargin < 6 || isempty(processAll), processAll = false;     end
if nargin < 7 || isempty(doQuicklook), doQuicklook = false;   end
if nargin < 8 || isempty(doDebugTemp), doDebugTemp = false;   end

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

allFlag = "";
if processAll
    allFlag = "-a";
end

qc_cmd = sprintf('./aeri_qc_netcdf.sh -i "%s" -o "%s" %s %s', ...
                 inputRoot, outputRoot, forceFlag, allFlag);
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
    cal_cmd = sprintf('./aeri_cal_val.sh -i "%s" -o "%s" %s %s', ...
                      inputRoot, outputRoot, forceFlag, allFlag);
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
    fprintf('  processDailyAERIdata_GEOMS(''%s'', false, true, %d)\n', outputRoot, doDebugTemp);
    try
        processDailyAERIdata_GEOMS(outputRoot, false, true, doDebugTemp);
        fprintf('GEOMS conversion complete.\n');
    catch ME
        warning('GEOMS conversion failed:\n%s', ME.message);
    end
end

if doQuicklook
    fprintf('Generating quicklook plots...\n');
    try
        % 1. Timeseries Plot
        figure_output = 'quicklook_timeseries.png';
        try
            quicklook_timeseries(outputRoot, figure_output);
            fprintf('Timeseries generated (check subfolders)\n');
        catch ME
            warning('Timeseries generation failed: %s', ME.message);
        end

        % 2. Spectra Plots at 16 & 23 UTC
        fprintf('Searching for data to generate spectra plots (16 & 23 UTC)...\n');
        geoms_files = dir(fullfile(outputRoot, '**', 'groundbased_aeri_*.nc'));
        processed_keys = {};
        
        for i = 1:length(geoms_files)
            fname = geoms_files(i).name;
            fpath = geoms_files(i).folder;
            
            % Extract date YYYYMMDD from filename
            % Pattern: ..._20251229t...
            tokens = regexp(fname, '_(\d{8})t', 'tokens');
            if isempty(tokens), continue; end
            date_str = tokens{1}{1}; % e.g., '20251229'
            
            % Check if we already processed this Date+Folder
            key = fullfile(fpath, date_str);
            if any(strcmp(processed_keys, key))
                continue;
            end
            processed_keys{end+1} = key;
            
            % Format date strings
            yyyy = date_str(1:4);
            mm = date_str(5:6);
            dd = date_str(7:8);
            
            target_times = {};
            
            % Read time info from file to see what is available
            try
                time_mjd2k = ncread(fullfile(fpath, fname), 'DATETIME');
                % MJD2K to POSIX
                % epoch -10957.0 is 1970-01-01
                time_posix = (time_mjd2k - (-10957.0)) * 86400;
                dt_array = datetime(time_posix, 'ConvertFrom', 'posixtime', 'TimeZone', 'UTC');
                
                % spectra quicklook times
                desired_hours = [16, 23];
                for h = desired_hours
                    t_check = datetime(str2double(yyyy), str2double(mm), str2double(dd), h, 0, 0, 'TimeZone', 'UTC');
                    % Check if we have data within +/- 2 hours of this time
                    if any(abs(dt_array - t_check) < hours(2))
                        target_times{end+1} = datestr(t_check, 'yyyy-mm-dd HH:MM:SS');
                    end
                end
                
                % If no desired times overlap, pick two available times (e.g. 1/3 and 2/3 through the day)
                if isempty(target_times) && ~isempty(dt_array)
                    idx1 = floor(length(dt_array) * 0.33);
                    idx2 = floor(length(dt_array) * 0.66);
                    if idx1 > 0, target_times{end+1} = datestr(dt_array(max(1,idx1)), 'yyyy-mm-dd HH:MM:SS'); end
                    if idx2 > 0, target_times{end+1} = datestr(dt_array(idx2), 'yyyy-mm-dd HH:MM:SS'); end
                    fprintf('  Note: Requested times (16/23 UTC) not found. Plotting available times instead.\n');
                end
            catch
                 % Fallback to original requested times if check fails
                 target_times = {
                    sprintf('%s-%s-%s 16:00:00', yyyy, mm, dd), ...
                    sprintf('%s-%s-%s 23:00:00', yyyy, mm, dd)
                };
            end
            
            if isempty(target_times)
                 fprintf('  Skipping spectra plot: No suitable times found in file.\n');
                 continue;
            end
            
            spectra_output = fullfile(fpath, sprintf('quicklook_spectra_%s.png', date_str));
            
            fprintf('  Generating spectra - Date: %s-%s-%s in %s\n', yyyy, mm, dd, fpath);
            try
                % quicklook_timeseries(fpath, figure_output);
                % Call with 30-min averaging window
                quicklook_spectra(fpath, target_times, spectra_output, 30);
            catch ME
                warning('  Spectra generation failed for %s: %s', date_str, ME.message);
            end
        end
        
    catch ME
        warning('Quicklook generation failed:\n%s', ME.message);
    end
end

fprintf('AERI pipeline finished.\n');
end

