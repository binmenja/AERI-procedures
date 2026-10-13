function doit;
%function doit;
%
%top level function for performing AERI spectral calibration
%uses AERI spectra and RS profile in 'input' directory
%runs functions in 'mfiles' directory
%writes intermediary files in 'working' directory
%creates output figures and summary in 'output' directory
%
%Version history
%2012-10-14 created by JG
%2016-02-16 updated for ARM/SSEC versions for AERI files and sondes


%% File structure
% Make a copy of the spectralcalibration directory structure
% Rename Spectral_Calibration_AERI-UNITNUMBER_YYYYMMDD


%% Input data
% AERI spectral data goes into the input/aeri directory
%   Either ARM NetCDF AERI data for ch1 and ch2
%   Or C1.RNC, C2.RNC and SUM files
% Get sonde data and put it in input/sonde directory
%   Make a matlab readable .txt file by commenting out the header and footer using %
%   Check for missing data


%% Clear workspace
clear all;
close all;
clc;


%% Set up paths
% Must enter Spectral_Calibration_AERI_UNITNUMBER_YYYYMMDD/ directory below
DATE='250212';
cd ~/Dropbox/documents/MATLAB/spectralcalibration/Spectral_Calibration_AERI-125_2025-02-12
PATH=pwd;
if PATH(end)~='/', PATH(end+1)='/'; end;
addpath mfiles


%% Convert to NetCDF
% If AERI RNC/SUM files aren't already in NetCDF format
dmv2cdf([PATH,'input/aeri/'],[DATE,'.SUM']);
dmv2cdf([PATH,'input/aeri/'],[DATE,'C1.RNC']);
dmv2cdf([PATH,'input/aeri/'],[DATE,'C2.RNC']);
%armory2cdf('/path/to/AEYYMMDD/output',DATE);  % McGill: use the AERI Armory netCDF files instead of dmvdump


%% Write parameters
% Write text files for AERI site, number, date and radiosonde date, time

%writeParamsManual;
writeParamsAuto;


%% Compute mean AERI spectra
% Input the appropriate time window (average at least 1 hour of data), and the name of the site
% This creates 3 figures in output and 2 .mat files with average spectra in working

AERImeanSpectraRNC;  %Need *.SUM.cdf, *C1.RNC.cdf, *C2.RNC.cdf files


%% Make TAPE5 with sonde data
% Ensure correct input file name is used
% Ensure altitude, pressure, temperature, dew point and rh are ingested correctly
% Ensure appropriate atmosphere is used
% Ensure appropriate CO2 level is used (https://www.esrl.noaa.gov/gmd/ccgg/trends/)
% This generates 1 figure of the RS profile in output and creates 2 tape5 files in working

makeTape5_McGill;

% If sonde is not collocated with AERI, may need to manually edit tape5 files to
% (i) use surface pressure/altitude appropriate for observation and
% (ii) change to surface temperature appropriate to the observation
%   line 1: Append a comment stating changes made
%   line XX: find the nearest pressure level appropriate to the observed PS; change PS; delete/add lines as necessary
%   line XX: change TS in first, and possible a few subsequent levels
%   line 5.3: update number of levels used
%   line 6.1: update surface elevation
%   line 7?: update altitude levels, all rows but last must have 8 entries
%   line X: update number of levels used


%% Run LBLRTM to calculate spectra from sonde data
% Ensure correct remote host is used
% This creates a file in the working directory with the command line commands to
%   copy tape5 files to remote host
%   run LBLRTM
%   transfer tape27 back to working directory

writeLBLRTM_zsh;
%writeLBLRTMremote;
%writeLBLRTM_rorqual;  % McGill: run LBLRTM on Rorqual compute nodes
% Open a terminal window, copy/paste each block of commands from working/runLBLRTM.txt


%% Perform spectral calibration
% Comment out tape27 headers
% Using .mat files and tape27 files as input, perform spectral calibration
% This generates figures showing the spectra and fitting in output and a summary txt file

AERI_LBLRTM_Spectral_Calibration_RNC;

%% Save data on armada
writeSAVE;
% Open a terminal window, copy/past command from working/save.txt




