function quicklook_spectra(root_dir, time_selections, output_file, avg_window_minutes)
% quicklook_spectra - Plot radiance spectra with and without QC filtering
%
% Inputs:
%   root_dir - Root directory containing AERI data files
%   time_selections - Cell array of time strings in format 'yyyy-MM-dd HH:mm:ss'
%                     e.g., {'2024-04-08 12:00:00', '2024-04-08 18:30:00'}
%   output_file - Optional filename for saving the figure (e.g., 'spectra.png')
%   avg_window_minutes - Optional averaging window in minutes (default: 0 = single spectrum)
%                        If > 0, averages all spectra within ± this window

if nargin < 2 || isempty(time_selections)
    error('Please provide time_selections as cell array of datetime strings');
end

if nargin < 3 || isempty(output_file)
    output_file = 'spectra_quicklook.png';
end
if nargin < 4
    avg_window_minutes = 0;
end 

% Convert time selections to datetime
target_times = datetime(time_selections, 'InputFormat', 'yyyy-MM-dd HH:mm:ss', 'TimeZone', 'UTC');

% Get GEOMS files only
aeri_files = dir(fullfile(root_dir, '**', 'groundbased_aeri_*.nc'));
if isempty(aeri_files)
    error('No GEOMS files found in %s', root_dir);
end

fprintf('Found %d GEOMS file(s)\n', length(aeri_files));
fprintf('Searching for %d time(s)\n', length(target_times));

% Storage for found spectra
found_spectra = struct();
for t = 1:length(target_times)
    found_spectra(t).target_time = target_times(t);
    found_spectra(t).actual_time = NaT;
    found_spectra(t).wnum = [];
    found_spectra(t).rad_all = [];
    found_spectra(t).rad_filtered = [];
    found_spectra(t).std_all = [];
    found_spectra(t).std_filtered = [];
    found_spectra(t).bt_all = [];
    found_spectra(t).bt_filtered = [];
    found_spectra(t).bt_std_all = [];
    found_spectra(t).bt_std_filtered = [];
    found_spectra(t).n_spectra = 0;
    found_spectra(t).n_filtered = 0;
    found_spectra(t).flags_raised = {};
    found_spectra(t).found = false;
end

% Search through files
for i = 1:length(aeri_files)
    try
        aeri_file = fullfile(aeri_files(i).folder, aeri_files(i).name);
        
        % Read from GEOMS file
        datetime_mjd2k = ncread(aeri_file, 'DATETIME');
        % Convert MJD2K to POSIX time
        posix_epoch_mjd2k = -10957.0; % 1970-01-01 in MJD2K
        aeri_seconds = (datetime_mjd2k - posix_epoch_mjd2k) * 86400.0;
        rad = ncread(aeri_file, 'RADIANCE.SKY');
        wnum = ncread(aeri_file, 'WAVENUMBER');
        
        % Convert to datetime
        dt = datetime(aeri_seconds, 'ConvertFrom', 'posixtime', 'TimeZone', 'UTC');
        
        % Read QC flags from GEOMS file - STORE INDIVIDUAL FLAG DATA
        qc_flags = false(length(aeri_seconds), 1);
        individual_flags = struct(); % Store each flag separately
        all_flag_names = {}; % Store actual flag names from file
        
        try
            flag_details = ncread(aeri_file, 'FLAG.MEASUREMENT.QUALITY');
            flag_names_raw = ncread(aeri_file, 'FLAG.NAMES');
            
            n_flags = size(flag_names_raw, 1);
            all_flag_names = cell(n_flags, 1);
            for k = 1:n_flags
                flag_name = strtrim(flag_names_raw(k, :));
                % Remove any non-alphanumeric characters except underscores for valid field names
                flag_name = regexprep(flag_name, '[^\w]', '');
                all_flag_names{k} = flag_name;
                % Store individual flag data
                individual_flags.(flag_name) = flag_details(k, :)' > 0;
            end
            
            % Check if ANY flag is raised for each timestamp
            qc_flags = any(flag_details > 0, 1)'; % Column vector
            
            fprintf('  File: %s - Found %d flagged observations (%.1f%%)\n', ...
                aeri_files(i).name, sum(qc_flags), (sum(qc_flags)/length(qc_flags))*100);
                
        catch ME
            warning('Could not read QC flags from GEOMS file: %s', ME.message);
        end
        
        % Check each target time
        for t = 1:length(target_times)
            if found_spectra(t).found
                continue; % Already found this one
            end
            
            % Find times within averaging window
            if avg_window_minutes > 0
                time_diff_minutes = abs(minutes(dt - target_times(t)));
                in_window = time_diff_minutes <= avg_window_minutes;
            else
                % Find closest time within 5 minutes
                time_diff_minutes = abs(minutes(dt - target_times(t)));
                [min_diff, idx] = min(time_diff_minutes);
                in_window = false(size(dt));
                if min_diff <= 5
                    in_window(idx) = true;
                end
            end
            
            if any(in_window)
                n_in_window = sum(in_window);
                found_spectra(t).wnum = wnum;
                found_spectra(t).n_spectra = n_in_window;
                
                % Average all spectra in window
                rad_window = rad(:, in_window);
                bt_window = rad_to_bt(wnum, rad_window);
                
                found_spectra(t).rad_all = mean(rad_window, 2);
                found_spectra(t).std_all = std(rad_window, 0, 2);
                found_spectra(t).bt_all = mean(bt_window, 2);
                found_spectra(t).bt_std_all = std(bt_window, 0, 2);
                
                % Average only non-flagged spectra
                unflagged_in_window = in_window & ~qc_flags;
                if any(unflagged_in_window)
                    rad_filt_window = rad(:, unflagged_in_window);
                    bt_filt_window = rad_to_bt(wnum, rad_filt_window);
                    
                    found_spectra(t).rad_filtered = mean(rad_filt_window, 2);
                    found_spectra(t).std_filtered = std(rad_filt_window, 0, 2);
                    found_spectra(t).bt_filtered = mean(bt_filt_window, 2);
                    found_spectra(t).bt_std_filtered = std(bt_filt_window, 0, 2);
                    found_spectra(t).n_filtered = sum(unflagged_in_window);
                else
                    found_spectra(t).rad_filtered = NaN(size(wnum));
                    found_spectra(t).std_filtered = NaN(size(wnum));
                    found_spectra(t).bt_filtered = NaN(size(wnum));
                    found_spectra(t).bt_std_filtered = NaN(size(wnum));
                    found_spectra(t).n_filtered = 0;
                end
                
                % Determine which flags were raised - FIXED VERSION
                flags_raised = {};
                if ~isempty(all_flag_names)
                    for k = 1:length(all_flag_names)
                        % Check if this flag was raised for ANY time in the window
                        if isfield(individual_flags, all_flag_names{k}) && ...
                           any(individual_flags.(all_flag_names{k})(in_window))
                            flags_raised{end+1} = all_flag_names{k};
                        end
                    end
                end
                found_spectra(t).flags_raised = flags_raised;
                
                % Record center time
                center_idx = find(in_window);
                found_spectra(t).actual_time = dt(center_idx(round(length(center_idx)/2)));
                
                found_spectra(t).found = true;
                if avg_window_minutes > 0
                    fprintf('Found %d spectra for %s (±%.1f min window, %d unflagged)\n', ...
                        n_in_window, datestr(target_times(t)), avg_window_minutes, sum(unflagged_in_window));
                else
                    fprintf('Found match for %s: actual time %s (diff: %.1f min)\n', ...
                        datestr(target_times(t)), datestr(found_spectra(t).actual_time), min(time_diff_minutes));
                end
                if ~isempty(flags_raised)
                    fprintf('  QC flags raised: %s\n', strjoin(flags_raised, ', '));
                end
            end
        end
        
    catch ME
        warning('Error processing %s: %s', aeri_files(i).name, ME.message);
    end
end

% Check if we found all requested times
n_found = sum([found_spectra.found]);
fprintf('\nFound %d out of %d requested times\n', n_found, length(target_times));

if n_found == 0
    error('No matching times found within 5 minutes of requested times');
end

% Create figure
n_times = length(target_times);
fig = figure('Position', [100, 100, 1400, 300*n_times]);

plot_idx = 1;
for t = 1:length(target_times)
    if ~found_spectra(t).found
        fprintf('Warning: No data found for %s\n', datestr(target_times(t)));
        continue;
    end
    
    wnum = found_spectra(t).wnum;
    rad_all = found_spectra(t).rad_all;
    rad_filtered = found_spectra(t).rad_filtered;
    std_all = found_spectra(t).std_all;
    std_filtered = found_spectra(t).std_filtered;
    actual_time = found_spectra(t).actual_time;
    n_spectra = found_spectra(t).n_spectra;
    n_filtered = found_spectra(t).n_filtered;
    flags_raised = found_spectra(t).flags_raised;
    
    % Top panel: All data
    subplot(n_times, 2, plot_idx)
    if avg_window_minutes > 0 && n_spectra > 1
        % Plot mean with shaded standard deviation
        hold on
        fill([wnum; flipud(wnum)], [rad_all + std_all; flipud(rad_all - std_all)], ...
            'b', 'FaceAlpha', 0.2, 'EdgeColor', 'none')
        plot(wnum, rad_all, 'b-', 'LineWidth', 1.5)
        hold off
        title_str = sprintf('All Data (n=%d) - %s UTC', n_spectra, datestr(actual_time, 'yyyy-mm-dd HH:MM:SS'));
    else
        plot(wnum, rad_all, 'b-', 'LineWidth', 1)
        title_str = sprintf('All Data - %s UTC', datestr(actual_time, 'yyyy-mm-dd HH:MM:SS'));
    end
    xlabel('Wavenumber (cm^{-1})')
    ylabel('Radiance (RU)')
    title(title_str)
    grid on
    xlim([min(wnum), max(wnum)])
    
    % Bottom panel: QC filtered
    subplot(n_times, 2, plot_idx + 1)
    if all(isnan(rad_filtered)) || n_filtered == 0
        text(0.5, 0.5, {'ALL DATA QC FLAGGED', sprintf('Flags: %s', strjoin(flags_raised, ', '))}, ...
            'HorizontalAlignment', 'center', 'FontSize', 12, 'Color', 'r', ...
            'Units', 'normalized')
        xlabel('Wavenumber (cm^{-1})')
        ylabel('Radiance (RU)')
        xlim([min(wnum), max(wnum)])
    else
        if avg_window_minutes > 0 && n_filtered > 1
            % Plot mean with shaded standard deviation
            hold on
            fill([wnum; flipud(wnum)], [rad_filtered + std_filtered; flipud(rad_filtered - std_filtered)], ...
                'g', 'FaceAlpha', 0.2, 'EdgeColor', 'none')
            plot(wnum, rad_filtered, 'g-', 'LineWidth', 1.5)
            hold off
            title_str = sprintf('QC Filtered (n=%d/%d) - %s UTC', n_filtered, n_spectra, datestr(actual_time, 'yyyy-mm-dd HH:MM:SS'));
        else
            plot(wnum, rad_filtered, 'g-', 'LineWidth', 1)
            title_str = sprintf('QC Filtered - %s UTC', datestr(actual_time, 'yyyy-mm-dd HH:MM:SS'));
        end
        xlabel('Wavenumber (cm^{-1})')
        ylabel('Radiance (RU)')
        title(title_str)
        grid on
        xlim([min(wnum), max(wnum)])
        
        % Add text annotation with flags if any were raised
        if ~isempty(flags_raised)
            text(0.02, 0.98, sprintf('Flags raised: %s', strjoin(flags_raised, ', ')), ...
                'Units', 'normalized', 'VerticalAlignment', 'top', ...
                'FontSize', 8, 'Color', 'r', 'Interpreter', 'none')
        end
    end
    
    plot_idx = plot_idx + 2;
end

sgtitle('AERI Radiance Spectra: Unfiltered vs QC Filtered', 'FontSize', 20, 'FontWeight', 'bold');

% Save figure to output folder
[filepath, name, ext] = fileparts(output_file);
if isempty(filepath)
    % Find output folder in root_dir
    output_dir = dir(fullfile(root_dir, '**', 'output'));
    if ~isempty(output_dir)
        output_file = fullfile(output_dir(1).folder, output_dir(1).name, [name, ext]);
    end
end
saveas(fig, output_file)
fprintf('Radiance figure saved to: %s\n', output_file);

[filepath, name, ext] = fileparts(output_file);

fig_bt = figure('Position', [150, 150, 1400, 300*n_times]);

plot_idx = 1;
for t = 1:length(target_times)
    if ~found_spectra(t).found
        continue;
    end
    
    wnum = found_spectra(t).wnum;
    bt_all = found_spectra(t).bt_all;
    bt_filtered = found_spectra(t).bt_filtered;
    bt_std_all = found_spectra(t).bt_std_all;
    bt_std_filtered = found_spectra(t).bt_std_filtered;
    actual_time = found_spectra(t).actual_time;
    n_spectra = found_spectra(t).n_spectra;
    n_filtered = found_spectra(t).n_filtered;
    flags_raised = found_spectra(t).flags_raised;
    
    % Top panel: All data (BT)
    subplot(n_times, 2, plot_idx)
    if avg_window_minutes > 0 && n_spectra > 1
        % Plot mean with shaded standard deviation
        hold on
        fill([wnum; flipud(wnum)], [bt_all + bt_std_all; flipud(bt_all - bt_std_all)], ...
            'b', 'FaceAlpha', 0.2, 'EdgeColor', 'none')
        plot(wnum, bt_all, 'b-', 'LineWidth', 1.5)
        hold off
        title_str = sprintf('All Data (n=%d) - %s UTC', n_spectra, datestr(actual_time, 'yyyy-mm-dd HH:MM:SS'));
    else
        plot(wnum, bt_all, 'b-', 'LineWidth', 1)
        title_str = sprintf('All Data - %s UTC', datestr(actual_time, 'yyyy-mm-dd HH:MM:SS'));
    end
    xlabel('Wavenumber (cm^{-1})')
    ylabel('Brightness Temp (K)')
    title(title_str)
    grid on
    xlim([min(wnum), max(wnum)])
    
    % Bottom panel: QC filtered (BT)
    subplot(n_times, 2, plot_idx + 1)
    if all(isnan(bt_filtered)) || n_filtered == 0
        text(0.5, 0.5, {'ALL DATA QC FLAGGED', sprintf('Flags: %s', strjoin(flags_raised, ', '))}, ...
            'HorizontalAlignment', 'center', 'FontSize', 12, 'Color', 'r', ...
            'Units', 'normalized')
        xlabel('Wavenumber (cm^{-1})')
        ylabel('Brightness Temp (K)')
        xlim([min(wnum), max(wnum)])
    else
        if avg_window_minutes > 0 && n_filtered > 1
            % Plot mean with shaded standard deviation
            hold on
            fill([wnum; flipud(wnum)], [bt_filtered + bt_std_filtered; flipud(bt_filtered - bt_std_filtered)], ...
                'g', 'FaceAlpha', 0.2, 'EdgeColor', 'none')
            plot(wnum, bt_filtered, 'g-', 'LineWidth', 1.5)
            hold off
            title_str = sprintf('QC Filtered (n=%d/%d) - %s UTC', n_filtered, n_spectra, datestr(actual_time, 'yyyy-mm-dd HH:MM:SS'));
        else
            plot(wnum, bt_filtered, 'g-', 'LineWidth', 1)
            title_str = sprintf('QC Filtered - %s UTC', datestr(actual_time, 'yyyy-mm-dd HH:MM:SS'));
        end
        xlabel('Wavenumber (cm^{-1})')
        ylabel('Brightness Temp (K)')
        title(title_str)
        grid on
        xlim([min(wnum), max(wnum)])
        
        % Add text annotation with flags if any were raised
        if ~isempty(flags_raised)
            text(0.02, 0.98, sprintf('Flags raised: %s', strjoin(flags_raised, ', ')), ...
                'Units', 'normalized', 'VerticalAlignment', 'top', ...
                'FontSize', 8, 'Color', 'r', 'Interpreter', 'none')
        end
    end
    
    plot_idx = plot_idx + 2;
end

sgtitle('AERI Brightness Temperature: Unfiltered vs QC Filtered', 'FontSize', 20, 'FontWeight', 'bold');

% Save BT figure
output_file_bt = fullfile(filepath, [name, '_bt', ext]);
saveas(fig_bt, output_file_bt)
fprintf('BT figure saved to: %s\n', output_file_bt);

fprintf('Quicklook spectra complete.\n');
end