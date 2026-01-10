function [] = processDailyAERIdata_GEOMS(root_dir, mat, nc)
% Function to process all AERI data in the specified directory
% Inputs:
% root_dir - root directory containing AERI data files
% mat - boolean flag to save data in .mat format, default off
% nc - boolean flag to save data in netCDF (GEOMS) format
%
% Outputs:
% all_rad - cleaned radiometric data
% all_dates - corresponding timestamps
% overall_flag_counts - total count of flags across all files
% overall_flag_percentages - percentage of flags across all files
close all; 

% Constants
MOPD = 1.03702765; % cm

% Get all AERI data files in the directory and subdirectories
aeri_files = dir(fullfile(root_dir, '**', '*C1_rnc.nc'));
qc_files = dir(fullfile(root_dir, '**', '*QC.nc'));
sum_files = dir(fullfile(root_dir, '**', '*sum.nc'));


% Define the specific flag names to track
flag_names = {
    'abb_temp_outlier_flag', 'abb_thermistor_flag', 'air_interferometer_outlier_flag',...
    'bst_temp_outlier_flag', 'cross_correlation_check', 'detector_check', ...
    'detector_temp_check', 'hatch_flag', 'hbb_covariance_flag', ...
    'hbb_lw_nen_check', 'hbb_stable_flag', 'hbb_std_dev_flag', ...
    'hbb_sw_nen_check', 'hbb_temp_outlier_flag', 'hbb_thermistor_flag', ...
    'hysteresis_check', 'imaginary_radiance_flag', 'lw_responsivity_flag', ...
    'missing_data_flag', 'safing_flag', 'sce_temp_deviation_check', ...
    'sky_brightness_temp_spectral_averages_ch1_flag', 'sky_brightness_temp_spectral_averages_ch2_flag', ...
    'spike_check', 'sw_responsivity_flag'
    };

% Initialize overall flag statistics
overall_flag_counts = struct();
overall_flag_percentages = struct();
total_observations = 0;

% Process each AERI file
for i = 1:length(aeri_files)
    try
        aeri_file = fullfile(aeri_files(i).folder, aeri_files(i).name);
        
        % Read latitude, longitude, and altitude from the file
        try
            lat = ncread(aeri_file, 'Latitude');
            lat = lat(1);
            lon = ncread(aeri_file, 'Longitude');
            lon = lon(1);
            altitude = ncread(aeri_file, 'Altitude');
            altitude = altitude(1);
        catch
            warning('Could not read location data from file: %s. Skipping.', aeri_file);
            continue;
        end
        
        % Determine location and serial number based on latitude/longitude
        % Define known site locations with tolerance
        tolerance = 0.5; % degrees 
        
        % Known site coordinates
        gault_lat = 45.54;
        gault_lon = -73.15;
        nrc_lat = 45.45;
        nrc_lon = -75.62;
        burnside_lat = 45.52;
        burnside_lon = -73.63;
        inuvik_lat = 68.1832;  
        inuvik_lon = -133.2840; 
        radar_lat = 45.4241;
        radar_lon = -73.9377;
        
        if abs(lat - gault_lat) < tolerance && abs(lon - gault_lon) < tolerance
            location = 'gault';
            serial = '125';
        elseif abs(lat - nrc_lat) < tolerance && abs(lon - nrc_lon) < tolerance
            location = 'nrc';
            serial = '122';
        elseif abs(lat - burnside_lat) < tolerance && abs(lon - burnside_lon) < tolerance
            location = 'burnside';
            serial = '124';
        elseif abs(lat - inuvik_lat) < tolerance && abs(lon - inuvik_lon) < tolerance
            location = 'inuvik';
            serial = '125';
        elseif abs(lat - radar_lat) < tolerance && abs(lon - radar_lon) < tolerance
            location = 'radar';
            serial = '122';
        else
            % Unknown location - use generic identifier and continue processing
            location = sprintf('unknown_%.4f_%.4f', abs(lat), abs(lon));
            serial = 'UNK';
            warning('Unknown location for coordinates (lat=%.4f, lon=%.4f) in file: %s. Proceeding with location=''%s''.', lat, lon, aeri_file, location);
        end
        
        % Warning about verifying location metadata
        fprintf('\n[LOCATION INFO] File: %s\n', aeri_files(i).name);
        fprintf('  Location: %s (Serial: %s)\n', location, serial);
        fprintf('  Lat: %.4f°, Lon: %.4f°, Alt: %.1f m\n', lat, lon, altitude);
        fprintf('  WARNING: Verify lat/lon/altitude are correct if instrument was recently moved!\n');

            % Extract date information from the RNC filename
            [~, aeri_basename, ~] = fileparts(aeri_files(i).name);
            date_part = regexp(aeri_basename, '\d+', 'match'); % all digit runs in name

            if isempty(date_part)
                warning('Could not extract date from AERI file: %s - Skipping', aeri_file);
                continue;
            end

            date_part = date_part{1}; % take first match, e.g. '241003' or '20241003'

            % Handle 6-digit vs 8-digit style (QC files often have yyyyMMdd)
            if length(date_part) == 6
                % e.g. '241003' -> '20241003' for QC
                date_part_for_qc = ['20', date_part];
            else
                date_part_for_qc = date_part;
            end

            %% --- Find QC file that matches date (and optionally site) ---
            qc_file = '';
            % Get the parent folder (AE*) of the current AERI file
            aeri_parent_folder = fileparts(aeri_files(i).folder);
            
            for j = 1:length(qc_files)
                this_qc_fullpath = fullfile(qc_files(j).folder, qc_files(j).name);
                qc_parent_folder = fileparts(qc_files(j).folder);

                % Match files from the same AE* folder and date
                if strcmp(aeri_parent_folder, qc_parent_folder) && ...
                   contains(qc_files(j).name, [date_part_for_qc, 'QC'])
                    qc_file = this_qc_fullpath;
                    break;
                end
            end

            if isempty(qc_file)
                warning('No QC file found for %s at site %s on %s - Skipping', aeri_file, location, date_part_for_qc);
                continue;
            end

            %% --- Find SUM file that matches date (and optionally site) ---
            sum_file = '';
            for j = 1:length(sum_files)
                this_sum_fullpath = fullfile(sum_files(j).folder, sum_files(j).name);
                sum_parent_folder = fileparts(sum_files(j).folder);

                % Match files from the same AE* folder and date
                if strcmp(aeri_parent_folder, sum_parent_folder) && ...
                   contains(sum_files(j).name, [date_part, '_sum'])
                    sum_file = this_sum_fullpath;
                    break;
                end
            end

            if isempty(sum_file)
                warning('No summary file found for %s at site %s on %s - Skipping', aeri_file, location, date_part);
                continue;
            end

            fprintf('\n[FILE SELECTION]\n');
            fprintf('  Site:        %s\n', location);
            fprintf('  AERI file:   %s\n', aeri_file);
            fprintf('  QC file:     %s\n', qc_file);
            fprintf('  SUM file:    %s\n\n', sum_file);

        % Read AERI data
        aeri_basetime = ncread(aeri_file, 'base_time');
        aeri_timeoff = ncread(aeri_file, 'time_offset');
        rad = ncread(aeri_file, 'mean_rad');
        wnum = ncread(aeri_file, 'wnum1');

        % Read QC data
        qc_basetime = ncread(qc_file, 'base_time');
        qc_timeoff = ncread(qc_file, 'time_offset');

        % Read summary data
        sum_basetime = ncread(sum_file, 'base_time');
        sum_timeoff = ncread(sum_file, 'time_offset');
        skyNENch1 = ncread(sum_file, 'SkyNENch1');
        respSpecAVGch1 = ncread(sum_file, 'ResponsivitySpectralAveragesCh1');
        ABB_apex_temp = ncread(sum_file, 'ABBapexTemp');
        sum_wnum = ncread(sum_file, 'wnum1');

        % Combine base_time and time_offset to get full timestamps in seconds
        aeri_seconds = double(aeri_timeoff) + double(aeri_basetime);
        size(aeri_seconds);
        qc_seconds = double(qc_timeoff) + double(qc_basetime);
        sum_seconds = double(sum_timeoff) + double(sum_basetime);

        % % Debug: Check if timestamps look reasonable
        % fprintf('Sample AERI timestamp: %.0f (should be around 1.7e9 for 2024)\n', aeri_seconds(1));
        % sample_date = datetime(aeri_seconds(1), 'ConvertFrom', 'posixtime', 'TimeZone', 'UTC');
        % fprintf('Sample date: %s\n', datestr(sample_date));

        % Check if timestamps are in milliseconds instead of seconds
        if aeri_seconds(1) > 2e12  % If timestamp is larger than year 2033 in seconds
            fprintf('Timestamps appear to be in milliseconds, converting to seconds\n');
            aeri_seconds = aeri_seconds / 1000;
            qc_seconds = qc_seconds / 1000;
            sum_seconds = sum_seconds / 1000;
        end

        max_time_diff = 1; % maximum allowed time difference in seconds between files

        % First find close matches between QC and Summary data
        [match_indices_qc, match_indices_sum] = findCloseTimestamps(qc_seconds, sum_seconds, max_time_diff);

        if isempty(match_indices_qc)
            warning('No close timestamp matches found between QC and summary data for file: %s - Skipping', aeri_file);
            continue;
        end

        % Then find close matches between AERI and matched QC data
        matched_qc_seconds = qc_seconds(match_indices_qc);
        [match_indices_aeri, indices_into_matched_qc] = findCloseTimestamps(aeri_seconds, matched_qc_seconds, max_time_diff);

        if isempty(match_indices_aeri)
            warning('No close timestamp matches found between AERI and QC data for file: %s - Skipping', aeri_file);
            continue;
        end

        % Determine final indices for all three datasets
        pos_aeri = match_indices_aeri;
        pos_qc = match_indices_qc(indices_into_matched_qc);
        pos_sum = match_indices_sum(indices_into_matched_qc);

        % Use AERI timestamps as the reference
        common_seconds = aeri_seconds(pos_aeri);
        % Keep only the matched timestamps 
        rad = rad(:, pos_aeri);
        dates = datetime(common_seconds, 'ConvertFrom', 'posixtime');
        skyNENch1 = skyNENch1(:, pos_sum);
        respSpecAVGch1 = respSpecAVGch1(:, pos_sum);

        ABB_apex_temp = ABB_apex_temp(pos_sum);
        ABB_apex_temp = ABB_apex_temp(:);  % Forces it to column vector
        ABB_apex_temp_2D = repmat(ABB_apex_temp.', length(wnum), 1);
        Rad_ABB = planck_aeri_t_to_b(wnum, ABB_apex_temp_2D);
        absoluteCalError = 0.01.*Rad_ABB./3; % 1% of the radiance is 3 sigma

        % Interpolate skyNENch1 and respSpecAVGch1 to match AERI data wnum resolution (2655 channels for standard range AERI, 2904 for extended)
        skyNENch1_interp = interp1(sum_wnum, skyNENch1, wnum, 'linear', 'extrap');

        respSpecAVGch1_interp = interp1(sum_wnum, respSpecAVGch1, wnum, 'linear', 'extrap');

        % Process flag statistics for this file
        file_flag_counts = struct();
        file_flag_percentages = struct();

        % Read and process each flag
        for k = 1:length(flag_names)
            try
                current_flag = ncread(qc_file, flag_names{k});
                current_flag = current_flag(pos_qc);

                % Count flags for this file
                file_flag_counts.(flag_names{k}) = sum(current_flag > 0);
                file_flag_percentages.(flag_names{k}) = (file_flag_counts.(flag_names{k}) / length(current_flag)) * 100;

                % Aggregate overall flag counts
                if ~isfield(overall_flag_counts, flag_names{k})
                    overall_flag_counts.(flag_names{k}) = 0;
                end
                overall_flag_counts.(flag_names{k}) = overall_flag_counts.(flag_names{k}) + file_flag_counts.(flag_names{k});
            catch ME
                warning('Could not read flag: %s. Error: %s', flag_names{k}, ME.message);
            end
        end

        % Create a structure to store ALL flags for each timestamp (not just filtering ones)
        flag_details = zeros(length(flag_names), length(pos_qc));

        for k = 1:length(flag_names)
            try
                current_flag = ncread(qc_file, flag_names{k});
                current_flag = current_flag(pos_qc);
                flag_details(k, :) = current_flag > 0;
            catch ME
                warning('Could not read flag: %s. Error: %s', flag_names{k}, ME.message);
                % Set to 0 (no flag) if flag cannot be read
                flag_details(k, :) = false(1, length(pos_qc));
            end
        end

        % Update total observations
        total_observations = total_observations + length(pos_qc);
        disp(total_observations);
        % Save the data for the day
        if nargin < 3
            disp('No output format specified. Saving in GEOMS format only.');
            mat = false;
            nc = true;
        end
        if mat
            % For .mat files, create a subdirectory in the AE folder
            aeri_parent_dir = fileparts(aeri_files(i).folder);
            mat_output_dir = fullfile(aeri_parent_dir, 'output', location);
            if ~exist(mat_output_dir, 'dir')
                mkdir(mat_output_dir);
            end
            daily_output_filename = fullfile(mat_output_dir, sprintf('AERI_%s_%s.mat', location, date_part));
            save(daily_output_filename, 'rad', 'dates', 'wnum', ...
                'skyNENch1_interp', 'respSpecAVGch1_interp','absoluteCalError', ...
                'flag_details', 'flag_names', ...
                'file_flag_counts', 'file_flag_percentages', 'MOPD', '-v7.3');

            fprintf('Daily AERI data saved to: %s\n', daily_output_filename);
        end

        if nc
            % Save data in netCDF format
            % Construct GEOMS-compliant file name
            location = upper(location); % Here the location variable has to be the location of the instrument, I used "Gault", "NRC", "Burnside", "Inuvik", "Radar", or "unknown"
            affiliation_acronym = 'MCGILL'; %
            data_location = location; % e.g., GAULT, NRC, etc.
            data_file_version = '001'; % Version of the data file
            data_discipline = 'ATMOSPHERIC.PHYSICS;INSITU;GROUNDBASED'; % Updated per Meriem Kacimi's feedback
            data_source = sprintf('AERI_MCGILL%s', serial); % Use serial directly: AERI_MCGILL125, AERI_MCGILL122, AERI_MCGILL124

            % Use matched timestamps
            time_seconds = common_seconds; % This is because I have my original time variables in seconds since Posix, see below how I convert it to the MJD2K format;
            size(time_seconds);
            % Create ISO 8601 date-time strings for global attributes (GEOMS requirement)
            start_dt = datetime(time_seconds(1), 'ConvertFrom', 'posixtime', 'TimeZone', 'UTC');
            stop_dt = datetime(time_seconds(end), 'ConvertFrom', 'posixtime', 'TimeZone', 'UTC');
            start_datestr_iso = datestr(start_dt, 'yyyymmddTHHMMSSZ');
            stop_datestr_iso = datestr(stop_dt, 'yyyymmddTHHMMSSZ');

            % Create filename with lowercase ISO format
            start_datestr_filename = lower(start_datestr_iso);
            stop_datestr_filename = lower(stop_datestr_iso);

            % Create output directory next to the AERI file
            % Save GEOMS files in same folder structure as input
            aeri_parent_dir = fileparts(aeri_files(i).folder); % Get AE* folder
            nc_output_dir = fullfile(aeri_parent_dir, 'output');
            if ~exist(nc_output_dir, 'dir')
                mkdir(nc_output_dir);
            end

            % Construct GEOMS-compliant filename per Meriem's format
            nc_output_filename = fullfile(nc_output_dir, sprintf('%s_%s_%s_%s_%s_%s_%s.nc', ...
                'groundbased', ... 
                'aeri', ... % Instrument type
                sprintf('mcgill%s', serial), ... % Affiliation + serial: mcgill125, mcgill122, mcgill124
                lower(data_location), ... % e.g., gault
                start_datestr_filename, ... % ISO 8601 format: 20241003t000412z
                stop_datestr_filename, ... % ISO 8601 format: 20241003t235537z
                data_file_version)); % e.g., 001
            if exist(nc_output_filename, 'file')
                delete(nc_output_filename);
                fprintf('Deleted existing file: %s\n', nc_output_filename);
            end
            if length(nc_output_filename) > 256
                warning('FILE_NAME exceeds 256 characters; truncating');
                nc_output_filename = nc_output_filename(1:256);
            end

            % Create and write to netCDF file
            ncid = netcdf.create(nc_output_filename, 'NETCDF4'); % Watchout, this does not overwrite the file if it already exists and throws an error. Thus, I delete the file if it exists before creating a new one.

            % Define dimensions for the variables
            time_dimid = netcdf.defDim(ncid, 'DATETIME', length(time_seconds));
            wnum_dimid = netcdf.defDim(ncid, 'WAVENUMBER', length(wnum));
            flag_dimid = netcdf.defDim(ncid, 'FLAG_NAMES', length(flag_names)); % All AERI Armory QC flags
            string_dimid = netcdf.defDim(ncid, 'string_length', 256);

            % Define variables (remove FLAG and RADIANCE.SKY_CLEANED)
            time_varid = netcdf.defVar(ncid, 'DATETIME', 'double', time_dimid);
            lat_varid = netcdf.defVar(ncid, 'LATITUDE', 'double', []);
            lon_varid = netcdf.defVar(ncid, 'LONGITUDE', 'double', []);
            alt_varid = netcdf.defVar(ncid, 'ALTITUDE', 'double', []);
            wnum_varid = netcdf.defVar(ncid, 'WAVENUMBER', 'double', wnum_dimid);
            rad_varid = netcdf.defVar(ncid, 'RADIANCE.SKY', 'double', [wnum_dimid, time_dimid]);
            skynen_varid = netcdf.defVar(ncid, 'RADIANCE.SKY_NOISE', 'double', [wnum_dimid, time_dimid]);
            resp_varid = netcdf.defVar(ncid, 'RESPONSIVITY.SPECTRAL', 'double', [wnum_dimid, time_dimid]);
            calerror_varid = netcdf.defVar(ncid, 'RADIANCE.SKY_ERROR', 'double', [wnum_dimid, time_dimid]);
            flag_details_varid = netcdf.defVar(ncid, 'FLAG.MEASUREMENT.QUALITY', 'byte', [flag_dimid, time_dimid]);
            flag_names_varid = netcdf.defVar(ncid, 'FLAG.NAMES', 'char', [flag_dimid, string_dimid]);
            mopd_varid = netcdf.defVar(ncid, 'MAXIMUM.OPTICAL.PATH.DIFFERENCE', 'double', []);

            % Define variable attributes
            % DATETIME
            netcdf.putAtt(ncid, time_varid, 'VAR_NAME', 'DATETIME');
            netcdf.putAtt(ncid, time_varid, 'VAR_DESCRIPTION', 'Time of measurement in Modified Julian Date 2000');
            netcdf.putAtt(ncid, time_varid, 'VAR_NOTES', '');
            netcdf.putAtt(ncid, time_varid, 'VAR_SIZE', sprintf('%d', length(time_seconds)));
            netcdf.putAtt(ncid, time_varid, 'VAR_DEPEND', 'DATETIME');
            netcdf.putAtt(ncid, time_varid, 'VAR_DATA_TYPE', 'DOUBLE');
            netcdf.putAtt(ncid, time_varid, 'VAR_UNITS', 'MJD2K');
            netcdf.putAtt(ncid, time_varid, 'VAR_SI_CONVERSION', '0;86400;s');
            % Convert min/max times to MJD2K for valid range
            min_mjd2k = posix_to_mjd2k(min(time_seconds));
            max_mjd2k = posix_to_mjd2k(max(time_seconds));
            netcdf.putAtt(ncid, time_varid, 'VAR_VALID_MIN', sprintf('%.8f', min_mjd2k));
            netcdf.putAtt(ncid, time_varid, 'VAR_VALID_MAX', sprintf('%.8f', max_mjd2k));
            netcdf.putAtt(ncid, time_varid, 'VAR_FILL_VALUE', '-9999.0');

            % LATITUDE
            netcdf.putAtt(ncid, lat_varid, 'VAR_NAME', 'LATITUDE');
            netcdf.putAtt(ncid, lat_varid, 'VAR_DESCRIPTION', 'Latitude of the AERI instrument');
            netcdf.putAtt(ncid, lat_varid, 'VAR_NOTES', '');
            netcdf.putAtt(ncid, lat_varid, 'VAR_SIZE', '1');
            netcdf.putAtt(ncid, lat_varid, 'VAR_DEPEND', 'CONSTANT');
            netcdf.putAtt(ncid, lat_varid, 'VAR_DATA_TYPE', 'DOUBLE');
            netcdf.putAtt(ncid, lat_varid, 'VAR_UNITS', 'deg');
            netcdf.putAtt(ncid, lat_varid, 'VAR_SI_CONVERSION', '0;0.017453292519943295;rad');
            netcdf.putAtt(ncid, lat_varid, 'VAR_VALID_MIN', '-90.0');
            netcdf.putAtt(ncid, lat_varid, 'VAR_VALID_MAX', '90.0');
            netcdf.putAtt(ncid, lat_varid, 'VAR_FILL_VALUE', '-9999.0');

            % LONGITUDE
            netcdf.putAtt(ncid, lon_varid, 'VAR_NAME', 'LONGITUDE');
            netcdf.putAtt(ncid, lon_varid, 'VAR_DESCRIPTION', 'Longitude of the AERI instrument');
            netcdf.putAtt(ncid, lon_varid, 'VAR_NOTES', '');
            netcdf.putAtt(ncid, lon_varid, 'VAR_SIZE', '1');
            netcdf.putAtt(ncid, lon_varid, 'VAR_DEPEND', 'CONSTANT');
            netcdf.putAtt(ncid, lon_varid, 'VAR_DATA_TYPE', 'DOUBLE');
            netcdf.putAtt(ncid, lon_varid, 'VAR_UNITS', 'deg');
            netcdf.putAtt(ncid, lon_varid, 'VAR_SI_CONVERSION', '0;0.017453292519943295;rad');
            netcdf.putAtt(ncid, lon_varid, 'VAR_VALID_MIN', '-180.0');
            netcdf.putAtt(ncid, lon_varid, 'VAR_VALID_MAX', '180.0');
            netcdf.putAtt(ncid, lon_varid, 'VAR_FILL_VALUE', '-9999.0');

            % ALTITUDE
            netcdf.putAtt(ncid, alt_varid, 'VAR_NAME', 'ALTITUDE');
            netcdf.putAtt(ncid, alt_varid, 'VAR_DESCRIPTION', 'Altitude of the AERI instrument above sea level');
            netcdf.putAtt(ncid, alt_varid, 'VAR_NOTES', '');
            netcdf.putAtt(ncid, alt_varid, 'VAR_SIZE', '1');
            netcdf.putAtt(ncid, alt_varid, 'VAR_DEPEND', 'CONSTANT');
            netcdf.putAtt(ncid, alt_varid, 'VAR_DATA_TYPE', 'DOUBLE');
            netcdf.putAtt(ncid, alt_varid, 'VAR_UNITS', 'm');
            netcdf.putAtt(ncid, alt_varid, 'VAR_SI_CONVERSION', '0;1;m');
            netcdf.putAtt(ncid, alt_varid, 'VAR_VALID_MIN', '-500.0');
            netcdf.putAtt(ncid, alt_varid, 'VAR_VALID_MAX', '10000.0');
            netcdf.putAtt(ncid, alt_varid, 'VAR_FILL_VALUE', '-9999.0');

            % WAVENUMBER
            netcdf.putAtt(ncid, wnum_varid, 'VAR_NAME', 'WAVENUMBER');
            netcdf.putAtt(ncid, wnum_varid, 'VAR_DESCRIPTION', 'Spectral wavenumber');
            netcdf.putAtt(ncid, wnum_varid, 'VAR_NOTES', '');
            netcdf.putAtt(ncid, wnum_varid, 'VAR_SIZE', sprintf('%d', length(wnum)));
            netcdf.putAtt(ncid, wnum_varid, 'VAR_DEPEND', 'WAVENUMBER');
            netcdf.putAtt(ncid, wnum_varid, 'VAR_DATA_TYPE', 'DOUBLE');
            netcdf.putAtt(ncid, wnum_varid, 'VAR_UNITS', 'cm-1');
            netcdf.putAtt(ncid, wnum_varid, 'VAR_SI_CONVERSION', '0;100;m-1');
            netcdf.putAtt(ncid, wnum_varid, 'VAR_VALID_MIN', sprintf('%f', min(wnum)));
            netcdf.putAtt(ncid, wnum_varid, 'VAR_VALID_MAX', sprintf('%f', max(wnum)));
            netcdf.putAtt(ncid, wnum_varid, 'VAR_FILL_VALUE', '-9999.0');

            % RADIANCE.SKY
            netcdf.putAtt(ncid, rad_varid, 'VAR_NAME', 'RADIANCE.SKY');
            netcdf.putAtt(ncid, rad_varid, 'VAR_DESCRIPTION', 'Calibrated atmospheric radiance');
            netcdf.putAtt(ncid, rad_varid, 'VAR_NOTES', 'Atmospheric infrared radiance spectra. Use FLAG.MEASUREMENT.QUALITY to filter data based on quality control flags. Details about the flags can be found at https://gitlab.ssec.wisc.edu/aeri/aeri_quality_control');
            netcdf.putAtt(ncid, rad_varid, 'VAR_SIZE', sprintf('%d;%d', length(wnum), length(time_seconds)));
            netcdf.putAtt(ncid, rad_varid, 'VAR_DEPEND', 'DATETIME;WAVENUMBER');
            netcdf.putAtt(ncid, rad_varid, 'VAR_DATA_TYPE', 'DOUBLE');
            netcdf.putAtt(ncid, rad_varid, 'VAR_UNITS', 'mW m-2 sr-1 cm-1');
            netcdf.putAtt(ncid, rad_varid, 'VAR_SI_CONVERSION', '0;0.001;W m-2 sr-1 m-1');
            netcdf.putAtt(ncid, rad_varid, 'VAR_VALID_MIN', '0.0');
            netcdf.putAtt(ncid, rad_varid, 'VAR_VALID_MAX', '1000.0');
            netcdf.putAtt(ncid, rad_varid, 'VAR_FILL_VALUE', '-9999.0');

            % RADIANCE.SKY_NOISE
            netcdf.putAtt(ncid, skynen_varid, 'VAR_NAME', 'RADIANCE.SKY_NOISE');
            netcdf.putAtt(ncid, skynen_varid, 'VAR_DESCRIPTION', 'Sky noise equivalent radiance (NESR)');
            netcdf.putAtt(ncid, skynen_varid, 'VAR_NOTES', 'SkyNENch1 values interpolated to match radiance wavenumbers');
            netcdf.putAtt(ncid, skynen_varid, 'VAR_SIZE', sprintf('%d;%d', length(wnum), length(time_seconds)));
            netcdf.putAtt(ncid, skynen_varid, 'VAR_DEPEND', 'DATETIME;WAVENUMBER');
            netcdf.putAtt(ncid, skynen_varid, 'VAR_DATA_TYPE', 'DOUBLE');
            netcdf.putAtt(ncid, skynen_varid, 'VAR_UNITS', 'mW m-2 sr-1 cm-1');
            netcdf.putAtt(ncid, skynen_varid, 'VAR_SI_CONVERSION', '0;0.001;W m-2 sr-1 m-1');
            netcdf.putAtt(ncid, skynen_varid, 'VAR_VALID_MIN', '0.0');
            netcdf.putAtt(ncid, skynen_varid, 'VAR_VALID_MAX', '1000.0');
            netcdf.putAtt(ncid, skynen_varid, 'VAR_FILL_VALUE', '-9999.0');

            % RESPONSIVITY.SPECTRAL
            netcdf.putAtt(ncid, resp_varid, 'VAR_NAME', 'RESPONSIVITY.SPECTRAL');
            netcdf.putAtt(ncid, resp_varid, 'VAR_DESCRIPTION', 'Responsivity spectral averages');
            netcdf.putAtt(ncid, resp_varid, 'VAR_NOTES', 'ResponsivitySpectralAveragesCh1 values interpolated to match radiance wavenumbers');
            netcdf.putAtt(ncid, resp_varid, 'VAR_SIZE', sprintf('%d;%d', length(wnum), length(time_seconds)));
            netcdf.putAtt(ncid, resp_varid, 'VAR_DEPEND', 'DATETIME;WAVENUMBER');
            netcdf.putAtt(ncid, resp_varid, 'VAR_DATA_TYPE', 'DOUBLE');
            netcdf.putAtt(ncid, resp_varid, 'VAR_UNITS', 'counts mW-1 m2 sr cm');
            netcdf.putAtt(ncid, resp_varid, 'VAR_SI_CONVERSION', '0;1000;counts W-1 m2 sr m-1');
            netcdf.putAtt(ncid, resp_varid, 'VAR_VALID_MIN', '0.0');
            netcdf.putAtt(ncid, resp_varid, 'VAR_VALID_MAX', '10000.0');
            netcdf.putAtt(ncid, resp_varid, 'VAR_FILL_VALUE', '-9999.0');

            % RADIANCE.SKY_ERROR
            netcdf.putAtt(ncid, calerror_varid, 'VAR_NAME', 'RADIANCE.SKY_ERROR');
            netcdf.putAtt(ncid, calerror_varid, 'VAR_DESCRIPTION', 'Absolute calibration error -1-sigma absolute calibration error for the radiance. Calculated based on ambient blackbody apex temperature.');
            netcdf.putAtt(ncid, calerror_varid, 'VAR_NOTES', '1-sigma absolute calibration error for the radiance. Calculated based on ambient blackbody apex temperature.');
            netcdf.putAtt(ncid, calerror_varid, 'VAR_SIZE', sprintf('%d;%d', length(wnum), length(time_seconds)));
            netcdf.putAtt(ncid, calerror_varid, 'VAR_DEPEND', 'WAVENUMBER;DATETIME');
            netcdf.putAtt(ncid, calerror_varid, 'VAR_DATA_TYPE', 'DOUBLE');
            netcdf.putAtt(ncid, calerror_varid, 'VAR_UNITS', 'mW m-2 sr-1 cm-1');
            netcdf.putAtt(ncid, calerror_varid, 'VAR_SI_CONVERSION', '0;0.001;W m-2 sr-1 m-1');
            netcdf.putAtt(ncid, calerror_varid, 'VAR_VALID_MIN', '0.0');
            netcdf.putAtt(ncid, calerror_varid, 'VAR_VALID_MAX', '1000.0');
            netcdf.putAtt(ncid, calerror_varid, 'VAR_FILL_VALUE', '-9999.0');

            % FLAG.MEASUREMENT.QUALITY (now contains ALL flags)
            netcdf.putAtt(ncid, flag_details_varid, 'VAR_NAME', 'FLAG.MEASUREMENT.QUALITY');
            netcdf.putAtt(ncid, flag_details_varid, 'VAR_DESCRIPTION', 'Detailed quality control flags');
            netcdf.putAtt(ncid, flag_details_varid, 'VAR_NOTES', 'Binary flags for each specific test: 0 = passed, 1 = failed. User can choose which flags to apply for QC.');
            netcdf.putAtt(ncid, flag_details_varid, 'VAR_SIZE', sprintf('%d;%d', length(flag_names), length(time_seconds)));
            netcdf.putAtt(ncid, flag_details_varid, 'VAR_DEPEND', 'FLAG.NAMES;DATETIME');
            netcdf.putAtt(ncid, flag_details_varid, 'VAR_DATA_TYPE', 'BYTE');
            netcdf.putAtt(ncid, flag_details_varid, 'VAR_UNITS', '1');
            netcdf.putAtt(ncid, flag_details_varid, 'VAR_SI_CONVERSION', '0;1;1');
            netcdf.putAtt(ncid, flag_details_varid, 'VAR_VALID_MIN', '0');
            netcdf.putAtt(ncid, flag_details_varid, 'VAR_VALID_MAX', '1');
            netcdf.putAtt(ncid, flag_details_varid, 'VAR_FILL_VALUE', '-1');

            % FLAG.NAMES
            netcdf.putAtt(ncid, flag_names_varid, 'VAR_NAME', 'FLAG.NAMES');
            netcdf.putAtt(ncid, flag_names_varid, 'VAR_DESCRIPTION', 'Names of all available quality control flags');
            netcdf.putAtt(ncid, flag_names_varid, 'VAR_NOTES', 'Complete list of all flags from AERI Armory QC system. User can choose which to apply.');
            netcdf.putAtt(ncid, flag_names_varid, 'VAR_SIZE', sprintf('%d', length(flag_names)));
            netcdf.putAtt(ncid, flag_names_varid, 'VAR_DEPEND', 'FLAG.NAMES');
            netcdf.putAtt(ncid, flag_names_varid, 'VAR_DATA_TYPE', 'STRING');
            netcdf.putAtt(ncid, flag_names_varid, 'VAR_UNITS', '');
            netcdf.putAtt(ncid, flag_names_varid, 'VAR_SI_CONVERSION', '');
            netcdf.putAtt(ncid, flag_names_varid, 'VAR_VALID_MIN', '');
            netcdf.putAtt(ncid, flag_names_varid, 'VAR_VALID_MAX', '');
            netcdf.putAtt(ncid, flag_names_varid, 'VAR_FILL_VALUE', '');

            % MAXIMUM.OPTICAL.PATH.DIFFERENCE (renamed from MOPD)
            netcdf.putAtt(ncid, mopd_varid, 'VAR_NAME', 'MAXIMUM.OPTICAL.PATH.DIFFERENCE');
            netcdf.putAtt(ncid, mopd_varid, 'VAR_DESCRIPTION', 'Maximum Optical Path Difference');
            netcdf.putAtt(ncid, mopd_varid, 'VAR_NOTES', 'Full Width Half Maximum = 1.2067/(2*Maximum Optical Path Difference). AERI Ideal Line Shape available upon request.');
            netcdf.putAtt(ncid, mopd_varid, 'VAR_SIZE', '1');
            netcdf.putAtt(ncid, mopd_varid, 'VAR_DEPEND', 'CONSTANT');
            netcdf.putAtt(ncid, mopd_varid, 'VAR_DATA_TYPE', 'DOUBLE');
            netcdf.putAtt(ncid, mopd_varid, 'VAR_UNITS', 'cm');
            netcdf.putAtt(ncid, mopd_varid, 'VAR_SI_CONVERSION', '0;0.01;m');
            netcdf.putAtt(ncid, mopd_varid, 'VAR_VALID_MIN', '0.0');
            netcdf.putAtt(ncid, mopd_varid, 'VAR_VALID_MAX', '10.0');
            netcdf.putAtt(ncid, mopd_varid, 'VAR_FILL_VALUE', '-9999.0');

            % Global attributes (GEOMS header information)
            netcdf.putAtt(ncid, netcdf.getConstant('NC_GLOBAL'), 'Conventions', 'GEOMS-1.0');
            netcdf.putAtt(ncid, netcdf.getConstant('NC_GLOBAL'), 'title', sprintf('AERI %s processed data', location));
            netcdf.putAtt(ncid, netcdf.getConstant('NC_GLOBAL'), 'source', 'AERI instrument');
            netcdf.putAtt(ncid, netcdf.getConstant('NC_GLOBAL'), 'history', sprintf('Created on %s', datestr(now, 'yyyy-mm-dd HH:MM:SS')));
            netcdf.putAtt(ncid, netcdf.getConstant('NC_GLOBAL'), 'PI_NAME', 'Huang;Yi');
            netcdf.putAtt(ncid, netcdf.getConstant('NC_GLOBAL'), 'PI_AFFILIATION', 'McGill University;MCGILL');
            netcdf.putAtt(ncid, netcdf.getConstant('NC_GLOBAL'), 'PI_ADDRESS', '805 Sherbrooke St W, Montreal, QC H3A 0B9;CANADA');
            netcdf.putAtt(ncid, netcdf.getConstant('NC_GLOBAL'), 'PI_EMAIL', 'yi.huang@mcgill.ca');
            netcdf.putAtt(ncid, netcdf.getConstant('NC_GLOBAL'), 'DO_NAME', 'Riot-Bretecher;Benjamin');
            netcdf.putAtt(ncid, netcdf.getConstant('NC_GLOBAL'), 'DO_AFFILIATION', 'McGill University;MCGILL');
            netcdf.putAtt(ncid, netcdf.getConstant('NC_GLOBAL'), 'DO_ADDRESS', '805 Sherbrooke St W, Montreal, QC H3A 0B9;CANADA');
            netcdf.putAtt(ncid, netcdf.getConstant('NC_GLOBAL'), 'DO_EMAIL', 'benjamin.riotbretecher@mail.mcgill.ca');
            netcdf.putAtt(ncid, netcdf.getConstant('NC_GLOBAL'), 'DS_NAME', 'Riot-Bretecher;Benjamin');
            netcdf.putAtt(ncid, netcdf.getConstant('NC_GLOBAL'), 'DS_AFFILIATION', 'McGill University;MCGILL');
            netcdf.putAtt(ncid, netcdf.getConstant('NC_GLOBAL'), 'DS_ADDRESS', '805 Sherbrooke St W, Montreal, QC H3A 0B9;CANADA');
            netcdf.putAtt(ncid, netcdf.getConstant('NC_GLOBAL'), 'DS_EMAIL', 'benjamin.riotbretecher@mail.mcgill.ca');
            netcdf.putAtt(ncid, netcdf.getConstant('NC_GLOBAL'), 'DATA_DESCRIPTION', sprintf('Processed AERI radiance data from %s', location));
            netcdf.putAtt(ncid, netcdf.getConstant('NC_GLOBAL'), 'DATA_DISCIPLINE', data_discipline);
            netcdf.putAtt(ncid, netcdf.getConstant('NC_GLOBAL'), 'DATA_GROUP', 'EXPERIMENTAL;SCALAR.STATIONARY');
            netcdf.putAtt(ncid, netcdf.getConstant('NC_GLOBAL'), 'DATA_LOCATION', data_location);
            netcdf.putAtt(ncid, netcdf.getConstant('NC_GLOBAL'), 'DATA_SOURCE', data_source);
            netcdf.putAtt(ncid, netcdf.getConstant('NC_GLOBAL'), 'DATA_VARIABLES', 'DATETIME;LATITUDE;LONGITUDE;ALTITUDE;WAVENUMBER;RADIANCE.SKY;RADIANCE.SKY_NOISE;RESPONSIVITY.SPECTRAL;RADIANCE.SKY_ERROR;FLAG.MEASUREMENT.QUALITY;FLAG.NAMES;MAXIMUM.OPTICAL.PATH.DIFFERENCE');
            netcdf.putAtt(ncid, netcdf.getConstant('NC_GLOBAL'), 'DATA_START_DATE', start_datestr_iso);
            netcdf.putAtt(ncid, netcdf.getConstant('NC_GLOBAL'), 'DATA_STOP_DATE', stop_datestr_iso);
            netcdf.putAtt(ncid, netcdf.getConstant('NC_GLOBAL'), 'DATA_FILE_VERSION', data_file_version);
            netcdf.putAtt(ncid, netcdf.getConstant('NC_GLOBAL'), 'DATA_MODIFICATIONS', sprintf('Version %s', data_file_version));
            netcdf.putAtt(ncid, netcdf.getConstant('NC_GLOBAL'), 'DATA_CAVEATS', 'Unknown');
            netcdf.putAtt(ncid, netcdf.getConstant('NC_GLOBAL'), 'DATA_RULES_OF_USE', 'Unknown');
            netcdf.putAtt(ncid, netcdf.getConstant('NC_GLOBAL'), 'DATA_ACKNOWLEDGEMENT', ' ');
            netcdf.putAtt(ncid, netcdf.getConstant('NC_GLOBAL'), 'DATA_QUALITY', 'Quality-controlled using multiple flags from AERI Armory; see FLAG.MEASUREMENT.QUALITY');
            netcdf.putAtt(ncid, netcdf.getConstant('NC_GLOBAL'), 'DATA_TEMPLATE', 'GEOMS-TE-AERI-STATION-001');
            netcdf.putAtt(ncid, netcdf.getConstant('NC_GLOBAL'), 'DATA_PROCESSOR', ' ');
            [~, filename_only, ext] = fileparts(nc_output_filename);
            netcdf.putAtt(ncid, netcdf.getConstant('NC_GLOBAL'), 'FILE_NAME', [filename_only, ext]);
            file_generation_iso = datestr(datetime('now', 'TimeZone', 'UTC'), 'yyyymmddTHHMMSSZ');
            netcdf.putAtt(ncid, netcdf.getConstant('NC_GLOBAL'), 'FILE_GENERATION_DATE', file_generation_iso);
            netcdf.putAtt(ncid, netcdf.getConstant('NC_GLOBAL'), 'FILE_ACCESS', 'Benjamin Riot-Bretêcher;');
            netcdf.putAtt(ncid, netcdf.getConstant('NC_GLOBAL'), 'FILE_PROJECT_ID', 'Unknown');
            netcdf.putAtt(ncid, netcdf.getConstant('NC_GLOBAL'), 'FILE_DOI', ' ');
            netcdf.putAtt(ncid, netcdf.getConstant('NC_GLOBAL'), 'FILE_ASSOCIATION', 'Benjamin Riot-Bretêcher;');
            string_meta_version = strcat('04R',data_file_version, ';IDLCR8HDF');
            netcdf.putAtt(ncid, netcdf.getConstant('NC_GLOBAL'), 'FILE_META_VERSION', string_meta_version);

            % End define mode before writing data
            netcdf.endDef(ncid);

            % Write data
            time_mjd2k = posix_to_mjd2k(time_seconds);
            netcdf.putVar(ncid, time_varid, time_mjd2k);
            netcdf.putVar(ncid, lat_varid, lat);
            netcdf.putVar(ncid, lon_varid, lon);
            netcdf.putVar(ncid, alt_varid, altitude);
            netcdf.putVar(ncid, wnum_varid, wnum);
            netcdf.putVar(ncid, rad_varid, rad);
            netcdf.putVar(ncid, skynen_varid, skyNENch1_interp);
            netcdf.putVar(ncid, resp_varid, respSpecAVGch1_interp);
            netcdf.putVar(ncid, calerror_varid, absoluteCalError);
            netcdf.putVar(ncid, flag_details_varid, uint8(flag_details));
            netcdf.putVar(ncid, mopd_varid, MOPD);

            % Write all flag names
            for k = 1:length(flag_names)
                if ~isempty(flag_names{k})
                    netcdf.putVar(ncid, flag_names_varid, [k-1, 0], [1, length(flag_names{k})], flag_names{k});
                end
            end

            % Close the file
            netcdf.close(ncid);

            fprintf('Daily AERI data saved to GEOMS-compliant netCDF: %s\n', nc_output_filename);
        end

    catch ME
        warning('Error processing AERI file %s: %s\nStack trace:\n%s', ...
            aeri_files(i).name, ME.message, getReport(ME));
    end
end


% Calculate overall flag percentages
for k = 1:length(flag_names)
    if isfield(overall_flag_counts, flag_names{k})
        overall_flag_percentages.(flag_names{k}) = ...
            (overall_flag_counts.(flag_names{k}) / total_observations) * 100;
    end
end

end