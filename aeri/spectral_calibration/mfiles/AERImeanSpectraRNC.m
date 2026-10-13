function AERImeanSpectraRNC;
%function AERImeanSpectraRNC;
%
% Compute mean AERI spectra over a given time period, based on RNC and SUM files
%
% revised: 02 March 2010  R. Knuteson UW-SSEC
% revised: 03 March 2010  ROK UW-SSEC  This version reads ARM netCDF format files
% revised: 02 July 2010 ROK UW-SSEC  This version read UW-SSEC dmv-ncdf format files
% revised: 15 Sept 2011 ROK UW-SSEC  Special version for use with 3-body or 4-body mode mirror sequence
% revised: 22 Dec  2011 ROK UW-SSEC  Added interactive inputs and eps output
% revised: 14 Oct  2012 JG UW-SSEC   New directory structure, new AERI data file structure


%% Paths
INPUTPATH='input/aeri/';
OUTPUTPATH='output/';
WORKINGPATH='working/';


%% Parameters
DATE=num2str(load([WORKINGPATH,'DATE.txt']));
dateYYMMDD=DATE(end-5:end);
SITE=importdata([WORKINGPATH,'SITE.txt']);  
SITE=SITE{1};
UNIT=num2str(load([WORKINGPATH,'UNIT.txt']));
RSDATE=num2str(load([WORKINGPATH,'RSDATE.txt']));
RSTIME=num2str(load([WORKINGPATH,'RSTIME.txt']));
if length(RSTIME)==4, RSTIME=['00',RSTIME]; end;

rstimevec=datevec(RSTIME,'HHMMSS');
RStimeUTC=rstimevec(4)+rstimevec(5)/60+rstimevec(6)/60/60;

FIGLABEL=['AERI-',UNIT,'_',DATE,'_'];


%% Load SUM file
fileSUM=dir([INPUTPATH,dateYYMMDD,'.SUM.cdf']);
filename=fileSUM(1).name;
eng1=rd_netcdf([INPUTPATH,filename]);


%% Parameters
Time=eng1.Time;


%% Plot brightness temperature time series
figure(10); clf; hold on;
plot(Time,eng1.surfaceLayerAirTemp675_680,'r-');
plot(Time,eng1.shortwaveWindowAirTemp2510_2515,'g-');
plot(Time,eng1.longwaveWindowAirTemp985_990,'b-');
grid on;
xlabel('Time (UTC hours)');
ylabel('Brightness Temperature (K)');
title([DATE,' ',SITE,' AERI-',UNIT]);
set(gca,'XLim',[0 24]);
set(gca,'YLim',[120 310]);
set(gca,'Box','ON');
%set(gca,'XTick',[0 6 12 18 24]);
set(gca,'FontSize',12);
if RSDATE==DATE
    plot([RStimeUTC RStimeUTC],[120 310],'k--','linewidth',2);
    legend('675-680 cm^-^1','2510-2515 cm^-^1','985-990 cm^-^1',['sonde ',RSTIME],'Location','Best');
else
    legend('675-680 cm^-^1','2510-2515 cm^-^1','985-990 cm^-^1','Location','Best');
end;



%% Select time range to compute mean and standard deviation
TimeLo=input('Enter start time for average (UTC hours, e.g. 12.4): ');
TimeHi=input('Enter end   time for average (UTC hours, e.g. 13.4): ');
ind_good=find(TimeLo<=Time & Time<=TimeHi);


%% %%%%%%%%%%%%%%%%%%
% AERI LW Channel 1
%%%%%%%%%%%%%%%%%%%%%

%% Load data
fileC1=dir([INPUTPATH,dateYYMMDD,'C1.RNC.cdf']);
filename=fileC1(1).name;
nc1=rd_netcdf([INPUTPATH,filename]);
lwwn=nc1.mean_rad_ind;
lwrad=nc1.mean_rad;
AERI_ch1_originalLaserWavenumber = nc1.originalLaserWavenumber(1);


%% Average data in time window
lwrad_mean=nanmean(lwrad(ind_good,:),1);
lwrad_stdev=nanstd(lwrad(ind_good,:),1,1);
lwrad_uncer_mean=lwrad_stdev./sqrt(length(ind_good));


%% Plot
figure(11); clf; hold on;
plot(lwwn,lwrad_mean,'k-');
plot(lwwn,lwrad_stdev,'r-');
plot(lwwn,lwrad_uncer_mean,'b-');
grid on;
legend('Mean','Std Dev.','Uncert. in Mean')
xlabel('Wavenumber (cm^{-1})')
ylabel('Radiance (mW/m^2 sr cm^{-1})')
title([DATE,' ',SITE,' AERI-',UNIT,', Time: ',num2str(TimeLo),'-',num2str(TimeHi),' UTC']);
set(gca,'XLim',[400 1800])
set(gca,'Box','ON');


%% Save plot
saveas(gcf,[OUTPUTPATH,FIGLABEL,'ch1.fig'],'fig')
saveas(gcf,[OUTPUTPATH,FIGLABEL,'ch1.eps'],'epsc')
saveas(gcf,[OUTPUTPATH,FIGLABEL,'ch1.png'],'png')


%% Save mean spectrum
save([WORKINGPATH,'AERI-',UNIT,'_',DATE,'_ch1.mat'],'lwwn','lwrad_mean','lwrad_stdev','lwrad_uncer_mean','dateYYMMDD','TimeLo','TimeHi','AERI_ch1_originalLaserWavenumber');


%% %%%%%%%%%%%%%%%%%%
% AERI SW Channel 2
%%%%%%%%%%%%%%%%%%%%%

%% Load data
fileC2=dir([INPUTPATH,dateYYMMDD,'C2.RNC.cdf']);
filename=fileC2(1).name;
nc2=rd_netcdf([INPUTPATH,filename]);
swwn=nc2.mean_rad_ind;
swrad=nc2.mean_rad;
AERI_ch2_originalLaserWavenumber = nc2.originalLaserWavenumber(1);


%% Average data in time window
swrad_mean=nanmean(swrad(ind_good,:),1);
swrad_stdev=nanstd(swrad(ind_good,:),1,1);
swrad_uncer_mean=swrad_stdev./sqrt(length(ind_good));


%% Plot
figure(12); clf; hold on;
plot(swwn,swrad_mean,'k-');
plot(swwn,swrad_stdev,'r-');
plot(swwn,swrad_uncer_mean,'b-');
grid on;
legend('Mean','Std Dev.','Uncert. in Mean')
xlabel('Wavenumber (cm^{-1})')
ylabel('Radiance (mW/m^2 sr cm^{-1})')
title([DATE,' ',SITE,' AERI-',UNIT,', Time: ',num2str(TimeLo),'-',num2str(TimeHi),' UTC']);
set(gca,'XLim',[1800 3000])
set(gca,'Box','ON');


%% Save plot
saveas(gcf,[OUTPUTPATH,FIGLABEL,'ch2.fig'],'fig')
saveas(gcf,[OUTPUTPATH,FIGLABEL,'ch2.eps'],'epsc')
saveas(gcf,[OUTPUTPATH,FIGLABEL,'ch2.png'],'png')


%% Save mean spectrum
save([WORKINGPATH,'AERI-',UNIT,'_',DATE,'_ch2.mat'],'swwn','swrad_mean','swrad_stdev','swrad_uncer_mean','dateYYMMDD','TimeLo','TimeHi','AERI_ch2_originalLaserWavenumber');


%% Plot time series

%% mean surface temperature
TS=nanmean(eng1.surfaceLayerAirTemp675_680(ind_good));
PS=nanmean(eng1.atmosphericPressure(ind_good));


%% Replot brightness temperature time series
figure(10); clf; hold on;
plot(Time,eng1.surfaceLayerAirTemp675_680,'r-');
plot(Time,eng1.shortwaveWindowAirTemp2510_2515,'g-');
plot(Time,eng1.longwaveWindowAirTemp985_990,'b-');
grid on;
xlabel('Time (UTC hours)');
ylabel('Brightness Temperature (K)');
title([DATE,' ',SITE,' AERI-',UNIT,', Time: ',num2str(TimeLo),'-',num2str(TimeHi),' UTC, T_S=',num2str(TS),' K, P_S=',num2str(PS),' hPa']);
set(gca,'XLim',[0 24]);
set(gca,'YLim',[120 310]);
set(gca,'XTick',[0 6 12 18 24]);
set(gca,'FontSize',12);
if RSDATE==DATE
    plot([RStimeUTC RStimeUTC],[120 310],'k--','linewidth',2);
    plot([TimeLo TimeLo],[100 310],'k',[TimeHi TimeHi],[100 310],'k','LineWidth',2);
    legend('675-680 cm^-^1','2510-2515 cm^-^1','985-990 cm^-^1',['sonde ',RSTIME],'Start','End','Location','Best');
else
    plot([TimeLo TimeLo],[100 310],'k',[TimeHi TimeHi],[100 310],'k','LineWidth',2);
    legend('675-680 cm^-^1','2510-2515 cm^-^1','985-990 cm^-^1','Start','End','Location','Best');
end;


%% Save plot
saveas(gcf,[OUTPUTPATH,FIGLABEL,'timeseries.fig'],'fig')
saveas(gcf,[OUTPUTPATH,FIGLABEL,'timeseries.eps'],'epsc')
saveas(gcf,[OUTPUTPATH,FIGLABEL,'timeseries.png'],'png')



