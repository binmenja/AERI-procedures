function plot_aeri_outputs(output_root)
% plot_aeri_outputs - Groups AERI data by date and plots availability, QC, and midnight spectra.
% Fixed: Final removal of non-MATLAB ternary operators.

if nargin < 1 || isempty(output_root), error('Please provide output_root directory'); end

% 1. Setup Filters
all_folders = dir(fullfile(output_root, 'AE*'));
all_folders = all_folders([all_folders.isdir]);
if isempty(all_folders), error('No AE folders found.'); end

raw_names = {all_folders.name};
date_strings = cellfun(@(x) regexp(x, '\d+', 'match', 'once'), raw_names, 'UniformOutput', false);
folder_dates = datetime(date_strings, 'InputFormat', 'yyyyMMdd');
if any(isnat(folder_dates)), folder_dates(isnat(folder_dates)) = datetime(date_strings(isnat(folder_dates)), 'InputFormat', 'yyMMdd'); end

start_filter = datetime(2025, 12, 1);
end_filter = datetime(2026, 1, 21);
full_range = start_filter:end_filter;

% Midnight window (UTC)
mid_start = posixtime(datetime('2026-01-19 23:55:00'));
mid_end   = posixtime(datetime('2026-01-20 00:05:00'));

% 2. Process Data
all_corrected_times = [];
all_exists = [];
all_qc_matrix = []; 
flag_names = {};
trouble_dates = datetime.empty;
midnight_rad = [];
midnight_time = [];
wavenumbers = [];

fprintf('Processing Dec-Jan data (Correcting syntax)...\n');
for i = 1:length(all_folders)
    current_folder_date = folder_dates(i);
    if current_folder_date < start_filter || current_folder_date > end_filter, continue; end
    if contains(lower(all_folders(i).name), 'bb'), trouble_dates = [trouble_dates; current_folder_date]; end
    
    day_folder = fullfile(all_folders(i).folder, all_folders(i).name);
    geoms_files = [dir(fullfile(day_folder, 'groundbased_aeri_*.nc')); ...
                   dir(fullfile(day_folder, 'output', 'groundbased_aeri_*.nc'))];
    
    for j = 1:length(geoms_files)
        ncfile = fullfile(geoms_files(j).folder, geoms_files(j).name);
        try
            mjd2k = ncread(ncfile, 'DATETIME');
            time = double(mjd2k) * 86400 + 946684800; 
            qc_data = ncread(ncfile, 'FLAG.MEASUREMENT.QUALITY'); 
            
            % --- FIXED: Flag Name Extraction ---
            if isempty(flag_names)
                raw_flags = ncread(ncfile, 'FLAG.NAMES');
                if size(raw_flags, 1) == 256
                    flag_names = strtrim(cellstr(raw_flags'));
                else
                    flag_names = strtrim(cellstr(raw_flags));
                end
            end
            
            % Jan 20th time-shift correction
            if contains(all_folders(i).name, '20260120') || contains(all_folders(i).name, '260120')
                jump_time = posixtime(datetime('2026-01-19 21:56:00'));
                time(time > jump_time) = time(time > jump_time) - 7470;
            end

            mid_idx = find(time >= mid_start & time <= mid_end);
            if ~isempty(mid_idx)
                if isempty(wavenumbers), wavenumbers = ncread(ncfile, 'WAVENUMBER'); wavenumbers = wavenumbers(:); end
                rad = ncread(ncfile, 'RADIANCE.SKY'); 
                if size(rad, 2) == length(mjd2k)
                    chunk = rad(:, mid_idx);
                else
                    chunk = rad(mid_idx, :)';
                end
                chunk(chunk <= -9000) = NaN;
                midnight_rad = [midnight_rad, chunk]; %#ok<AGROW>
                midnight_time = [midnight_time; time(mid_idx)]; %#ok<AGROW>
            end

            all_corrected_times = [all_corrected_times; time(:)]; 
            sz = size(qc_data);
            [~, flag_dim] = min(abs(sz - length(flag_names)));
            if flag_dim == 1, qc_data = qc_data'; end 
            all_exists = [all_exists; ~all(qc_data < 0, 2)]; 
            all_qc_matrix = [all_qc_matrix; qc_data]; 
        catch, continue; end
    end
end

% 3. Calculate Daily Stats
num_days = length(full_range);
avail_qc = zeros(num_days, 1);
avail_total = zeros(num_days, 1);
avail_trouble = zeros(num_days, 1);
daily_qc_failures = zeros(length(flag_names), num_days); 
day_only_all = dateshift(datetime(all_corrected_times, 'ConvertFrom', 'posixtime'), 'start', 'day');

for d = 1:num_days
    d_val = full_range(d);
    if ismember(d_val, trouble_dates), avail_trouble(d) = 100; end
    day_idx = find(day_only_all == d_val & all_exists(:) == 1);
    if ~isempty(day_idx)
        pot_max = round((max(all_corrected_times(day_only_all == d_val)) - min(all_corrected_times(day_only_all == d_val))) / 20);
        if pot_max > 0
            avail_total(d) = min(100 * (length(day_idx) / pot_max), 100);
            day_qc = all_qc_matrix(day_idx, :);
            failed_qc_mask = any(day_qc(:, ~strcmp(flag_names, 'detector_temp_check')) > 0, 2);
            avail_qc(d) = min(100 * (sum(~failed_qc_mask) / pot_max), 100);
            daily_qc_failures(:, d) = sum(day_qc > 0, 1)'; 
        end
    end
end

% --- PLOTTING ---
% FIG 1: Availability
figure('Color', 'w', 'Position', [50 600 1400 400]);
hold on;
bar(full_range, avail_trouble, 'FaceColor', [1 0.85 0], 'EdgeColor', 'none', 'DisplayName', 'Troubleshooting');
bar(full_range, avail_total, 'FaceColor', [0.8 0.2 0.2], 'EdgeColor', 'none', 'DisplayName', 'Instrument Uptime');
bar(full_range, avail_qc, 'FaceColor', [0.15 0.45 0.75], 'EdgeColor', 'none', 'DisplayName', 'QC Passed');
xticks(full_range); xtickformat('dd-MMM'); xtickangle(45);
set(gca, 'FontSize', 12); ylabel('Availability %'); title('AERI PONEX Campaign Status');
legend('Location', 'best'); grid on; hold off;
set(gca, 'FontSize', 18)

% FIG 2: Heatmap
figure('Color', 'w', 'Position', [50 350 1400 400]);
x_labels = categorical(cellstr(datetime(full_range, 'Format', 'dd-MMM')));
h = heatmap(x_labels, flag_names, daily_qc_failures, 'Colormap', hot, 'ColorMethod', 'none');
h.Title = 'Daily QC Failure Counts';

% FIG 3: Midnight Radiance
if ~isempty(midnight_rad)
    figure('Color', 'w', 'Position', [50 50 1400 450]);
    n_spectra = size(midnight_rad, 2);
    yyaxis left; set(gca, 'YColor', 'k'); 
    cmap = winter(n_spectra); hold on;
    for k = 1:n_spectra
        plot(wavenumbers, midnight_rad(:,k), '-', 'Color', cmap(k,:), 'LineWidth', 1.0);
    end
    ylabel('Radiance'); ylim([0, max(midnight_rad(:), [], 'omitnan') * 1.1]);
    
    yyaxis right; set(gca, 'YColor', [0.3 0.3 0.3]);
    std_r = std(midnight_rad, 0, 2, 'omitnan');
    plot(wavenumbers, std_r, 'k-', 'LineWidth', 2.0, 'DisplayName', 'Std Dev');
    ylabel('Standard Deviation');
    
    grid on; xlabel('Wavenumber (cm^{-1})');
    title('EarthCare Overpass Jan 19-20', 'FontSize', 16);
    set(gca, 'FontSize', 17); xlim([500 1800]);
    colormap(winter); cb = colorbar; cb.Label.String = 'Minutes from Midnight';
    cb.Ticks = linspace(0, 1, 5); cb.TickLabels = {'-5', '-2.5', '0', '2.5', '5'};
    annotation('textbox', [0.45, 0.75, 0.1, 0.1], 'String', ...
        sprintf('Spectra: %d', n_spectra), 'FontSize', 14, 'BackgroundColor', 'w', 'FaceAlpha', 0.8);
    hold off; box on;
end
end