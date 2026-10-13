function AERI_LBLRTM_Spectral_Calibration_RNC;
%function AERI_LBLRTM_Spectral_Calibration_RNC;
%
% revised 02 Mar 2010  ROK UW-SSEC
% revised 03 Mar 2010  ROK UW-SSEC
% revised 02 Jul 2010  ROK UW-SSEC changed AERI from row to column vectors
% revised 02 Aug 2010  ROK UW-SSEC fixed bug in output summary table
% revised 22 Dec 2011  ROK UW-SSEC added eps output
% revised 14 Oct 2012  JG UW-SSEC new directory paths, file and variable names


%% Paths
WORKINGPATH='working/';
OUTPUTPATH='output/';


%% Parameters
DATE=num2str(load([WORKINGPATH,'DATE.txt']));
SITE=importdata([WORKINGPATH,'SITE.txt']);  
SITE=SITE{1};
UNIT=num2str(load([WORKINGPATH,'UNIT.txt']));
if length(UNIT)==1
    UNIT(2)=UNIT(1);
    UNIT(1)='0';
end;

FIGLABEL=['AERI-',UNIT,'_',DATE,'_'];

files=dir(['input/aeri/*C1.RNC']);
AERIFILE=files(1).name;
files=[dir(['input/sonde/*.txt']);dir(['input/sonde/*sondewnpn*.b1.*'])];
SONDEFILE=files(1).name;


%% %%%%%%%%%%%%%%%%%%
% AERI LW Channel 1
%%%%%%%%%%%%%%%%%%%%%

%% Load LBLRTM Calculation
files=dir([WORKINGPATH,'tape27_*ch1.txt']);
filename=files(1).name;
temp=importdata([WORKINGPATH,filename],' ',27);
tape27=temp.data;
lblwn = tape27(:,1);
lblrad = 1e7.*tape27(:,2);


%% Load AERI data
files=dir([WORKINGPATH,'AERI-*ch1.mat']);
filename=files(1).name;
load([WORKINGPATH,filename]);
lwwn = lwwn';
lwrad_mean = lwrad_mean';


%% Plot AERI + LBLRTM data
figure(30); clf; hold on;
plot(lwwn,lwrad_mean,'b-',lblwn,lblrad,'r-');
grid on;
legend('AERI-old','LBLRTM')
xlabel('Wavenumber (cm^{-1})')
ylabel('Radiance (RU)')
title([DATE,' ',SITE,' AERI-',UNIT,' Time: ',num2str(TimeLo),'-',num2str(TimeHi),' UTC']);
set(gca,'XLim',[400 1800]);


%% Extract the spectral range of interest starting with a common wavenumber point
spectral_range = [700 770];
aeri_wn_index = find(lwwn >= spectral_range(1) & lwwn <= spectral_range(2));
lblrtm_wn_index = find(lblwn >= spectral_range(1) & lblwn <= spectral_range(2));
lwrad_mean_extract = lwrad_mean(aeri_wn_index);
lblrad_extract = lblrad(lblrtm_wn_index);
lblwn_extract = lblwn(lblrtm_wn_index);


%% Zeropad the spectrum
n = 15;
v_rolloff = [spectral_range(1)+20 spectral_range(2)-20];
[lblwn_zf,lblrad_zf] = zeropad4(lblwn_extract,lblrad_extract,n,v_rolloff);
[lwwn_zf,lwrad_mean_zf] = zeropad4(lblwn_extract,lwrad_mean_extract,n,v_rolloff);


%% Compute RMS error obs-calc for a range of wavenumber scale factors gamma
gamma_array = linspace(0.9999,1.0001,100);
RMS_wnlo = 730;
RMS_wnhi = 740;
RMS_wn_index = find(lblwn_zf >= RMS_wnlo & lblwn_zf <= RMS_wnhi);
RMS_error = zeros(length(gamma_array),1);
for kk = 1:length(gamma_array) 
    % Shift the observation 
    gamma =gamma_array(kk);
    disp(['Scale Factor (ppm): ' num2str(1E6*(gamma-1))]);
    scaled_wn = lwwn_zf*gamma;
    % Resample the shifted spectrum onto the calculation scale
    resampled_lwrad_mean_zf = interp1(scaled_wn,lwrad_mean_zf,lblwn_zf,'linear',0);
    % Compute RMS over specified wavenumber range
    RMS_error(kk) = std(resampled_lwrad_mean_zf(RMS_wn_index)-lblrad_zf(RMS_wn_index));
end;


%% Find the value of gamma which minimizes the RMS error between obs-calc
[min_RMS min_RMS_index] = min(RMS_error);
lw_bestfit_gamma = gamma_array(min_RMS_index);
new_AERI_ch1_originalLaserWavenumber = lw_bestfit_gamma.*AERI_ch1_originalLaserWavenumber;


%% Resample the shifted spectrum onto the calculation scale
gamma = lw_bestfit_gamma;
scaled_wn = lwwn_zf*gamma;
resampled_lwrad_mean_zf = interp1(scaled_wn,lwrad_mean_zf,lblwn_zf,'linear',0);
resampled_lwwn_zf = lblwn_zf;


%% Plot zero-filled spectra and wavenumber fit
figure(31);

subplot(211); hold on;
plot(lblwn_zf, lwrad_mean_zf,'b--');
plot(lblwn_zf,lblrad_zf,'r-');
plot(lblwn_zf, resampled_lwrad_mean_zf,'b-')
grid on;
legend('AERI-old','LBLRTM','AERI-new','Location','northeast');
xlabel('Wavenumber (cm^{-1})');
ylabel('Radiance (RU)');
title([DATE,' ',SITE,' AERI-',UNIT,' Time: ',num2str(TimeLo),'-',num2str(TimeHi),' UTC']);
set(gca,'XLim',[RMS_wnlo RMS_wnhi]);

subplot(212);
plot(1E6.*(gamma_array-1),RMS_error,'kx-');
grid on;
legend(['RMS Error '  num2str(RMS_wnlo) '-' num2str(RMS_wnhi) ' cm^{-1}'],'Location','North');
xlabel('Wavenumber Scale Factor (ppm)');
ylabel('RMS Error (RU)');
title(['Best Fit Scale Factor: ' num2str(lw_bestfit_gamma,7) ' (' num2str(1E6*(lw_bestfit_gamma-1),2) ' ppm)'] );


%% Save figure
saveas(gcf,[OUTPUTPATH,FIGLABEL,'spectral_cal_ch1.fig'],'fig');
saveas(gcf,[OUTPUTPATH,FIGLABEL,'spectral_cal_ch1.eps'],'epsc');
saveas(gcf,[OUTPUTPATH,FIGLABEL,'spectral_cal_ch1.png'],'png');


%% Extract the spectral range of interest starting with a common wavenumber point
spectral_range = [600 1800];
aeri_wn_index = find(lwwn >= spectral_range(1) & lwwn <= spectral_range(2));
lblrtm_wn_index = find(lblwn >= spectral_range(1) & lblwn <= spectral_range(2));
lwrad_mean_extract = lwrad_mean(aeri_wn_index);
lblrad_extract = lblrad(lblrtm_wn_index);
lblwn_extract = lblwn(lblrtm_wn_index);


%% Zeropad the spectrum
n = 15;
v_rolloff = [spectral_range(1)+20 spectral_range(2)-20];
[lblwn_zf,lblrad_zf] = zeropad4(lblwn_extract,lblrad_extract,n,v_rolloff);
[lwwn_zf,lwrad_mean_zf] = zeropad4(lblwn_extract,lwrad_mean_extract,n,v_rolloff);


%% Resample the shifted spectrum onto the calculation scale
gamma = lw_bestfit_gamma;
scaled_wn = lwwn_zf*gamma;
resampled_lwrad_mean_zf = interp1(scaled_wn,lwrad_mean_zf,lblwn_zf,'linear',0);
resampled_lwwn_zf = lblwn_zf;


%% Plot resampled observation and calculation
figure(32); clf;

subplot(211);
plot(lblwn_zf, resampled_lwrad_mean_zf,'b',lblwn_zf,lblrad_zf,'r');
grid on;
legend('AERI-new','LBLRTM');
xlabel('Wavenumber (cm^{-1})');
ylabel('Radiance (RU)');
title([DATE,' ',SITE,' AERI-',UNIT,' Time: ',num2str(TimeLo),'-',num2str(TimeHi),' UTC']);
set(gca,'XLim',[v_rolloff(1) v_rolloff(2)]);

subplot(212);
plot(lblwn_zf,resampled_lwrad_mean_zf-lblrad_zf,'k');
grid on;
xlabel('Wavenumber (cm^{-1})');
ylabel('Obs-Calc (RU)');


%% Save figure
saveas(gcf,[OUTPUTPATH,FIGLABEL,'LBLRTM_ch1.fig'],'fig');
saveas(gcf,[OUTPUTPATH,FIGLABEL,'LBLRTM_ch1.eps'],'epsc');
saveas(gcf,[OUTPUTPATH,FIGLABEL,'LBLRTM_ch1.png'],'png');


%% %%%%%%%%%%%%%%%%%%
% AERI SW Channel 2
%%%%%%%%%%%%%%%%%%%%%

%% Load LBLRTM Calculation
files=dir([WORKINGPATH,'tape27_*ch2.txt']);
filename=files(1).name;
temp=importdata([WORKINGPATH,filename],' ',27);
tape27=temp.data;
lblwn = tape27(:,1);
lblrad = 1e7.*tape27(:,2);


%% load AERI data
files=dir([WORKINGPATH,'AERI-*ch2.mat']);
filename=files(1).name;
load([WORKINGPATH,filename]);
swwn = swwn';
swrad_mean = swrad_mean';


%% Plot AERI + LBLRTM data
figure(35); clf; hold on;
plot(swwn,swrad_mean,'b',lblwn,lblrad,'r');
grid on;
legend('AERI-old','LBLRTM')
xlabel('Wavenumber (cm^{-1})')
ylabel('Radiance (RU)')
title([DATE,' ',SITE,' AERI-',UNIT,' Time: ',num2str(TimeLo),'-',num2str(TimeHi),' UTC']);
set(gca,'XLim',[1800 3000])


%% Extract the spectral range of interest starting with a common wavenumber point
spectral_range = [2080 2280];
aeri_wn_index = find(swwn >= spectral_range(1) & swwn <= spectral_range(2));
lblrtm_wn_index = find(lblwn >= spectral_range(1) & lblwn <= spectral_range(2));
swrad_mean_extract = swrad_mean(aeri_wn_index);
lblrad_extract = lblrad(lblrtm_wn_index);
lblwn_extract = lblwn(lblrtm_wn_index);


%% Zeropad the spectrum
n = 15;
v_rolloff = [spectral_range(1)+20 spectral_range(2)-20];
[lblwn_zf,lblrad_zf] = zeropad4(lblwn_extract,lblrad_extract,n,v_rolloff);
[swwn_zf,swrad_mean_zf] = zeropad4(lblwn_extract,swrad_mean_extract,n,v_rolloff);


%% Compute RMS error obs-calc for a range of wavenumber scale factors gamma
gamma_array = linspace(0.9999,1.0001,100);
RMS_wnlo = 2194;
RMS_wnhi = 2200;
RMS_wn_index = find(lblwn_zf >= RMS_wnlo & lblwn_zf <= RMS_wnhi);
RMS_error = zeros(length(gamma_array),1);
for kk = 1:length(gamma_array) 
    % Shift the observation 
    gamma =gamma_array(kk);
    disp(['Scale Factor (ppm): ' num2str(1E6*(gamma-1))])
    scaled_wn = swwn_zf*gamma;
    % Resample the shifted spectrum onto the calculation scale
    resampled_swrad_mean_zf = interp1(scaled_wn,swrad_mean_zf,lblwn_zf,'linear',0);
    % Compute RMS over specified wavenumber range
    RMS_error(kk) = std(resampled_swrad_mean_zf(RMS_wn_index)-lblrad_zf(RMS_wn_index));
end


%% Find the value of gamma which minimizes the RMS error between obs-calc
[min_RMS min_RMS_index] = min(RMS_error);
sw_bestfit_gamma = gamma_array(min_RMS_index);
new_AERI_ch2_originalLaserWavenumber = sw_bestfit_gamma.*AERI_ch2_originalLaserWavenumber;


%% Resample the shifted spectrum onto the calculation scale
gamma = sw_bestfit_gamma;
scaled_wn = swwn_zf*gamma;
resampled_swrad_mean_zf = interp1(scaled_wn,swrad_mean_zf,lblwn_zf,'linear',0);
resampled_swwn_zf = lblwn_zf;


%% Plot zero-filled spectra and wavenumber fit
figure(36); clf;

subplot(211); hold on;
plot(lblwn_zf, swrad_mean_zf,'b--');
plot(lblwn_zf,lblrad_zf,'r-');
plot(lblwn_zf, resampled_swrad_mean_zf,'b-');
grid on;
legend('AERI-old','LBLRTM','AERI-new','Location','northeast');
xlabel('Wavenumber (cm^{-1})')
ylabel('Radiance (RU)')
title([DATE,' ',SITE,' AERI-',UNIT,' Time: ',num2str(TimeLo),'-',num2str(TimeHi),' UTC']);
set(gca,'XLim',[RMS_wnlo RMS_wnhi]);

subplot(212);
plot(1E6.*(gamma_array-1),RMS_error,'kx-');
grid on;
legend(['RMS Error '  num2str(RMS_wnlo) '-' num2str(RMS_wnhi) ' cm^{-1}'],'Location','North');
xlabel('Wavenumber Scale Factor (ppm)');
ylabel('RMS Error (RU)');
title(['Best Fit Scale Factor: ' num2str(sw_bestfit_gamma,7) ' (' num2str(1E6*(sw_bestfit_gamma-1),2) ' ppm)'] );


%% Save figure
saveas(gcf,[OUTPUTPATH,FIGLABEL,'spectral_cal_ch2.fig'],'fig');
saveas(gcf,[OUTPUTPATH,FIGLABEL,'spectral_cal_ch2.eps'],'epsc');
saveas(gcf,[OUTPUTPATH,FIGLABEL,'spectral_cal_ch2.png'],'png');




%% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Display and print summary to a text file
disp('----------------------------------------------------------');
disp('--------   AERI Spectral Calibration Summary  ------------');
disp(' ');
disp([DATE,' ',SITE,' AERI-',UNIT,' Time: ',num2str(TimeLo),'-',num2str(TimeHi),' UTC']);
disp(['AERI  file:  ',AERIFILE]);
disp(['sonde file:  ',SONDEFILE]);
disp(['Created:  ',datestr(now)]);
disp(' ');
disp(['Old AERI LW ch1 originalLaserWavenumber (cm-1): ' num2str(AERI_ch1_originalLaserWavenumber)])
disp(['Old AERI SW ch2 originalLaserWavenumber (cm-1): ' num2str(AERI_ch2_originalLaserWavenumber)])
disp(['AERI LW ch1 best fit scale factor: ' num2str(lw_bestfit_gamma,7) ' (' num2str(1E6*(lw_bestfit_gamma-1),2) ' ppm)'])
disp(['AERI SW ch2 best fit scale factor: ' num2str(sw_bestfit_gamma,7) ' (' num2str(1E6*(sw_bestfit_gamma-1),2) ' ppm)'])
disp(['New AERI LW ch1 originalLaserWavenumber (cm-1): ' num2str(new_AERI_ch1_originalLaserWavenumber)])
disp(['New AERI SW ch2 originalLaserWavenumber (cm-1): ' num2str(new_AERI_ch2_originalLaserWavenumber)])
disp('----------------------------------------------------------')


%% Write summary file
fid = fopen([OUTPUTPATH,FIGLABEL,'spectral_cal_summary.txt'],'w');
fprintf(fid,'%s\n','----------------------------------------------------------');
fprintf(fid,'%s\n','--------   AERI Spectral Calibration Summary  ------------');
fprintf(fid,'\n');
fprintf(fid,'%s\n',[DATE,' ',SITE,' AERI-',UNIT,' Time: ',num2str(TimeLo),'-',num2str(TimeHi),' UTC']);
fprintf(fid,'%s\n',['AERI  file:  ',AERIFILE]);
fprintf(fid,'%s\n',['sonde file:  ',SONDEFILE]);
fprintf(fid,'%s\n',['Created:  ',datestr(now)]);
fprintf(fid,'\n');
fprintf(fid,'%s\n',['Old AERI LW ch1 originalLaserWavenumber (cm-1): ' num2str(AERI_ch1_originalLaserWavenumber)]);
fprintf(fid,'%s\n',['Old AERI SW ch2 originalLaserWavenumber (cm-1): ' num2str(AERI_ch2_originalLaserWavenumber)]);
fprintf(fid,'%s\n',['AERI LW ch1 best fit scale factor: ' num2str(lw_bestfit_gamma,7) ' (' num2str(1E6*(lw_bestfit_gamma-1),2) ' ppm)']);
fprintf(fid,'%s\n',['AERI SW ch2 best fit scale factor: ' num2str(sw_bestfit_gamma,7) ' (' num2str(1E6*(sw_bestfit_gamma-1),2) ' ppm)']);
fprintf(fid,'%s\n',['New AERI LW ch1 originalLaserWavenumber (cm-1): ' num2str(new_AERI_ch1_originalLaserWavenumber)]);
fprintf(fid,'%s\n',['New AERI SW ch2 originalLaserWavenumber (cm-1): ' num2str(new_AERI_ch2_originalLaserWavenumber)]);
fprintf(fid,'%s\n','----------------------------------------------------------');
fclose(fid);
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%




%% Extract the spectral range of interest starting with a common wavenumber point
spectral_range = [1800 3000];
aeri_wn_index = find(swwn >= spectral_range(1) & swwn <= spectral_range(2));
lblrtm_wn_index = find(lblwn >= spectral_range(1) & lblwn <= spectral_range(2));
swrad_mean_extract = swrad_mean(aeri_wn_index);
lblrad_extract = lblrad(lblrtm_wn_index);
lblwn_extract = lblwn(lblrtm_wn_index);


%% Zeropad the spectrum
n = 15;
v_rolloff = [spectral_range(1)+20 spectral_range(2)-20];
[lblwn_zf,lblrad_zf] = zeropad4(lblwn_extract,lblrad_extract,n,v_rolloff);
[swwn_zf,swrad_mean_zf] = zeropad4(lblwn_extract,swrad_mean_extract,n,v_rolloff);


%% Resample the shifted spectrum onto the calculation scale
gamma = sw_bestfit_gamma;
scaled_wn = swwn_zf*gamma;
resampled_swrad_mean_zf = interp1(scaled_wn,swrad_mean_zf,lblwn_zf,'linear',0);
resampled_swwn_zf = lblwn_zf;


%% Plot resampled observation and calculation
figure(37); clf;

subplot(211);
plot(lblwn_zf, resampled_swrad_mean_zf,'b',lblwn_zf,lblrad_zf,'r');
grid on;
legend('AERI-new','LBLRTM');
xlabel('Wavenumber (cm^{-1})');
ylabel('Radiance (RU)');
title([DATE,' ',SITE,' AERI-',UNIT,' Time: ',num2str(TimeLo),'-',num2str(TimeHi),' UTC']);
set(gca,'XLim',[v_rolloff(1) v_rolloff(2)]);

subplot(212);
plot(lblwn_zf,resampled_swrad_mean_zf-lblrad_zf,'k');
grid on;
xlabel('Wavenumber (cm^{-1})');
ylabel('Obs-Calc (RU)');


%% Save figure
saveas(gcf,[OUTPUTPATH,FIGLABEL,'LBLRTM_ch2.fig'],'fig');
saveas(gcf,[OUTPUTPATH,FIGLABEL,'LBLRTM_ch2.eps'],'epsc');
saveas(gcf,[OUTPUTPATH,FIGLABEL,'LBLRTM_ch2.png'],'png');
