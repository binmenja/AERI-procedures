function quicklook_timeseries(root_dir, output_file)
% quicklook_timeseries - Create time-series plots of radiance in key spectral bands
%
% Inputs:
%   root_dir - Root directory containing AERI data files
%   output_file - Optional filename for saving the figure (e.g., 'timeseries.png')
%
% Creates time-series plots showing radiance evolution in:
%   - CO2 band center (~667 cm^-1)
%   - O3 band center (~1042 cm^-1)
%   - Window region (~990 cm^-1)
%   - H2O band center (~1595 cm^-1)

if nargin < 2 || isempty(output_file)
    % Generate default filename with timestamp
    output_file = 'timeseries_quicklook.png';
end

% Define spectral bands of interest (wavenumbers in cm^-1)
bands = struct();
bands.co2 = 667;      % CO2 15 μm band
bands.window = 990;   % Atmospheric window
bands.o3 = 1042;      % O3 9.6 μm band
bands.h2o = 1595;     % H2O 6.3 μm band

% Get all GEOMS files
aeri_files = dir(fullfile(root_dir, '**', 'groundbased_aeri_*.nc'));
if isempty(aeri_files)
    error('No GEOMS files found in %s', root_dir);
end
fprintf('Found %d GEOMS file(s)\n', length(aeri_files));

% Initialize storage
all_times = [];
all_rad_co2 = [];
all_rad_window = [];
all_rad_o3 = [];
all_rad_h2o = [];
all_flags = [];

% Process each file
for i = 1:length(aeri_files)
    try
        aeri_file = fullfile(aeri_files(i).folder, aeri_files(i).name);
        fprintf('Processing: %s\n', aeri_files(i).name);
        
        % Read AERI data from GEOMS file
        datetime_mjd2k = ncread(aeri_file, 'DATETIME');
        % Convert MJD2K to POSIX time
        posix_epoch_mjd2k = -10957.0; % 1970-01-01 in MJD2K
        aeri_seconds = (datetime_mjd2k - posix_epoch_mjd2k) * 86400.0;
        rad = ncread(aeri_file, 'RADIANCE.SKY');
        wnum = ncread(aeri_file, 'WAVENUMBER');
        
        % Read QC flags from GEOMS file
        qc_flags = zeros(length(aeri_seconds), 1);
        try
            % Read embedded QC flags from GEOMS file
            flag_details = ncread(aeri_file, 'FLAG.MEASUREMENT.QUALITY');
            % Check if ANY flag is raised for each timestamp
            any_flag_raised = any(flag_details > 0, 1); % 1 x n_times
            qc_flags = any_flag_raised(:); % Convert to column vector
            fprintf('  Found %d flagged observations (%.1f%%)\n', ...
                sum(qc_flags), (sum(qc_flags)/length(qc_flags))*100);
        catch ME
            warning('Could not read QC flags from GEOMS file: %s', ME.message);
        end
        
        % Extract radiance at specific wavenumbers
        [~, idx_co2] = min(abs(wnum - bands.co2));
        [~, idx_window] = min(abs(wnum - bands.window));
        [~, idx_o3] = min(abs(wnum - bands.o3));
        [~, idx_h2o] = min(abs(wnum - bands.h2o));
        
        rad_co2 = rad(idx_co2, :)';
        rad_window = rad(idx_window, :)';
        rad_o3 = rad(idx_o3, :)';
        rad_h2o = rad(idx_h2o, :)';
        
        % Append to arrays
        all_times = [all_times; aeri_seconds];
        all_rad_co2 = [all_rad_co2; rad_co2];
        all_rad_window = [all_rad_window; rad_window];
        all_rad_o3 = [all_rad_o3; rad_o3];
        all_rad_h2o = [all_rad_h2o; rad_h2o];
        all_flags = [all_flags; qc_flags];
        
    catch ME
        warning('Error processing %s: %s', aeri_files(i).name, ME.message);
    end
end

if isempty(all_times)
    error('No data was successfully processed');
end

% Convert to datetime
dt = datetime(all_times, 'ConvertFrom', 'posixtime', 'TimeZone', 'UTC');

% Create figure
fig = figure('Position', [100, 100, 1200, 900]);

% Plot CO2 band
subplot(4, 1, 1)
hold on
plot(dt, all_rad_co2, 'b.', 'MarkerSize', 4)
flagged_idx = all_flags > 0;
if any(flagged_idx)
    plot(dt(flagged_idx), all_rad_co2(flagged_idx), 'r.', 'MarkerSize', 4)
end
ylabel('Radiance (RU)')
title(sprintf('CO_2 Band (%.1f cm^{-1})', bands.co2))
legend('Valid', 'QC Flagged', 'Location', 'best')
grid on
box on
set(gca, 'XTickLabel', [],'fontSize', 15)

% Plot atmospheric window
subplot(4, 1, 2)
hold on
plot(dt, all_rad_window, 'b.', 'MarkerSize', 4)
if any(flagged_idx)
    plot(dt(flagged_idx), all_rad_window(flagged_idx), 'r.', 'MarkerSize', 4)
end
ylabel('Radiance (RU)')
title(sprintf('Atmospheric Window (%.1f cm^{-1})', bands.window))
legend('Valid', 'QC Flagged', 'Location', 'best')
grid on
box on
set(gca, 'XTickLabel', [],'fontSize', 15)

% Plot O3 band
subplot(4, 1, 3)
hold on
plot(dt, all_rad_o3, 'b.', 'MarkerSize', 4)
if any(flagged_idx)
    plot(dt(flagged_idx), all_rad_o3(flagged_idx), 'r.', 'MarkerSize', 4)
end
ylabel('Radiance (RU)')
title(sprintf('O_3 Band (%.1f cm^{-1})', bands.o3))
legend('Valid', 'QC Flagged', 'Location', 'best')
grid on
box on
set(gca, 'XTickLabel', [],'fontSize', 15)

% Plot H2O band
subplot(4, 1, 4)
hold on
plot(dt, all_rad_h2o, 'b.', 'MarkerSize', 4)
if any(flagged_idx)
    plot(dt(flagged_idx), all_rad_h2o(flagged_idx), 'r.', 'MarkerSize', 4)
end
ylabel('Radiance (RU)')
title(sprintf('H_2O Band (%.1f cm^{-1})', bands.h2o))
xlabel('Time (UTC)')
legend('Valid', 'QC Flagged', 'Location', 'best')
grid on
box on
set(gca, 'fontSize', 15)
datetick('x', 'HH:MM', 'keeplimits')



% Add overall title
sgtitle('AERI Radiance Time Series - Key Spectral Bands', 'FontSize', 15, 'FontWeight', 'bold')

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
fprintf('Figure saved to: %s\n', output_file);

fprintf('Quicklook time-series complete. Total observations: %d\n', length(all_times));
end
