function makeTape5_McGill;
%function makeTape5_McGill;
%
% Read netCDF file downloaded from the ARM archive and write LBLRTM TAPE5 file
%
% NOTE: Since ARM sondes may contain more levels than LBLRTM can handle we will
%       routinely interpolate to 100 levels linear in the max and min pressure.
%
% Download web site
%  http://www.archive.arm.gov/adb/JSP/user.jsp
%  http://www.arm.gov/data/datastreams/sondewnpn
%  
%
% Format:
%   nc{'pres'} = ncfloat('time'); 
%   nc{'pres'}.long_name = ncchar('Pressure\0');
%   x = ncfloat('time');
%   nc{'tdry'}.long_name = ncchar('Dry Bulb Temperature\0');
%   nc{'dp'} = ncfloat('time'); 
%   nc{'dp'}.long_name = ncchar('Dewpoint Temperature\0');
%   nc{'rh'} = ncfloat('time'); 
%   nc{'rh'}.long_name = ncchar('Relative Humidity\0');
%   nc{'alt'} = ncfloat('time'); %% 2551 elements.
%   nc{'alt'}.long_name = ncchar('altitude\0');
%   nc{'alt'}.units = ncchar('meters above Mean Sea Level\0');
%   nc{'lat'} = ncfloat('time'); 
%   nc{'lat'}.long_name = ncchar('north latitude\0');
%   nc{'lon'} = ncfloat('time'); 
%   nc{'lon'}.long_name = ncchar('east longitude\0');
%   nc{'base_time'} = nclong; %% 1 element.
%   nc{'base_time'}.long_name = ncchar('Base time in Epoch\0');
%   nc{'base_time'}.units = ncchar('seconds since 1970-1-1 0:00:00 0:00\0');
%   nc{'time_offset'} = ncdouble('time'); 
%   nc{'time_offset'}.long_name = ncchar('Time offset from base_time\0');
%   nc{'time_offset'}.units = ncchar('seconds since 2010-01-22 23:28:00 0:00\0');
%   nc{'time'} = ncdouble('time'); %% 2551 elements.
%   nc{'time'}.long_name = ncchar('Time offset from midnight\0');
%   nc{'time'}.units = ncchar('seconds since 2010-01-22 00:00:00 0:00\0');
%
% revised: 03 Mar 2010  ROK  UW-SSEC
% revised: 14 Oct 2012  JG UW-SSEC


%% Paths
INPUTPATH='input/sonde/';
OUTPUTPATH='output/';
WORKINGPATH='working/';


%% Parameters
DATE=num2str(load([WORKINGPATH,'DATE.txt']));
SITE=importdata([WORKINGPATH,'SITE.txt']);  
SITE=SITE{1};
RSDATE=num2str(load([WORKINGPATH,'RSDATE.txt']));
rsdatevec=datevec(RSDATE,'yyyymmdd');
rsmonth=rsdatevec(2)+rsdatevec(3)/30;


%% Read in sonde data
files=dir([INPUTPATH,'*sonde*',DATE,'*.nc']);
filename=files(1).name;
vars={'HEIGHT_AGL','PRESSURE_INSITU','TEMPERATURE_INSITU','HUMIDITY.RELATIVE_INSITU'};
sonde=rd_netcdf([INPUTPATH,filename],vars);


%% Assign atmospheric variables  
pres=sonde.PRESSURE_INSITU;         % hPa
alt=sonde.HEIGHT_AGL;               % m
tdry=sonde.TEMPERATURE_INSITU;      % degC
rh=sonde.HUMIDITY.RELATIVE_INSITU;  % percent


%% Change missing data flag from -9999 to NaN
pres(pres == -9999) = NaN;
alt(alt == -9999) = NaN;
tdry(tdry == -9999) = NaN;
rh(rh == -9999) = NaN;


%% Change to standard naming convention and units
pressure = pres;                         % mb (hPa)
altitude = alt./1000;                    % km
temperature = tdry + 273.15;             % Kelvin



%% compute dewpt from rh, temperature, and pressure
[dewpt,~] = rh2dp(pressure,temperature,rh);  %K

%% compute mixing ratio from dewpt, temperature, and pressure
[w,~] = rh2mr(pressure,temperature,rh);  %g/kg


%% Remove levels that contain any NaNs in the p,alt,t,or w
good_levels = find(~(isnan(pressure) | isnan(altitude) | isnan(temperature) | isnan(w)));
pressure = pressure(good_levels);
altitude = altitude(good_levels);
temperature = temperature(good_levels);
dewpt = dewpt(good_levels);
w = w(good_levels);
rh = rh(good_levels);


%% Remove levels containing non-unique pressure values
[P,good_index,J] = unique(pressure);     % find the indices of the unique pressures
good_index = sort(good_index,'ascend');  % undo the sorting done by function unique
pressure = pressure(good_index);
altitude = altitude(good_index);
temperature = temperature(good_index);
dewpt = dewpt(good_index);
w = w(good_index);
rh = rh(good_index);


%% Interpolate to 100 levels equally spaced in pressure between max and min pressure
interp_pressure = linspace(max(pressure),min(pressure),100);
interp_altitude = interp1(pressure,altitude,interp_pressure);
interp_temperature = interp1(pressure,temperature,interp_pressure);
interp_dewpt = interp1(pressure,dewpt,interp_pressure);
interp_w = interp1(pressure,w,interp_pressure);
interp_rh = interp1(pressure,rh,interp_pressure);


%% plot sonde at original pressure levels
figure(20); clf;

subplot(1,2,1); hold on;
plot(temperature,altitude,'r',dewpt,altitude,'k','LineWidth',1);
grid on;
legend('Tair','DewPt');
xlabel('Tdry / Tdew (K)');
ylabel('Altitude (km)');
title(filename,'interpreter','none');
set(gca,'FontSize',12);

subplot(1,2,2);
h1 = line(w,altitude,'Color','b','LineWidth',1);
set(gca,'FontSize',12);
ax1 = gca;
xlabel(ax1,'w (g/kg)','Color','b');
hold on;
ax2 = axes('Position',get(ax1,'Position'),...
           'XAxisLocation','top',...
           'YAxisLocation','right',...
           'Color','none',...
           'XColor','k','YColor','k');
h2 = line(rh,altitude,'Color','k','Parent',ax2);
set(gca,'FontSize',10);
grid on;
xlabel(ax2,'RH (%)');
% print -dpng ARM_sonde


%% Plot sonde interpolated to 100 pressure levels
figure(21); clf;
subplot(121)
plot(interp_temperature,interp_altitude,'r.-',interp_dewpt,interp_altitude,'k.-','LineWidth',1)
grid on
set(gca,'FontSize',12)
xlabel('Tdry / Tdew (K)')
ylabel('Altitude (km)')
legend('Tair','DewPt')
title(filename,'interpreter','none')
subplot(122)
h1 = line(interp_w,interp_altitude,'Color','b','Marker','.','LineWidth',1);
set(gca,'FontSize',12)
ax1 = gca;
xlabel(ax1,'w (g/kg)','Color','b')
hold on
ax2 = axes('Position',get(ax1,'Position'),...
           'XAxisLocation','top',...
           'YAxisLocation','right',...
           'Color','none',...
           'XColor','k','YColor','k');
h2 = line(interp_rh,interp_altitude,'Color','k','Marker','.','Parent',ax2);
set(gca,'FontSize',10)
grid on
xlabel(ax2,'RH (%)')


%% Save plot
saveas(gcf,[OUTPUTPATH,filename '.fig'],'fig');
saveas(gcf,[OUTPUTPATH,filename '.eps'],'epsc');
saveas(gcf,[OUTPUTPATH,filename '.png'],'png');


%% Overwrite original sonde data with interpolated level data
pressure = interp_pressure;
altitude = interp_altitude;
temperature = interp_temperature;
dewpt = interp_dewpt;
w = interp_w;
rh = interp_rh;


%% prof structure representing the atmospheric state
prof.surfaceElevation  = altitude(1); % Site altitude (km)
prof.alt = altitude;                % sonde altitude bins
prof.SP =  pressure(1);             % surface pressure
prof.pressure = pressure;           % pressure vertical grid 
prof.tdry = temperature;            % temperature profile in K
prof.w = w;                         % water vapor mixing ratio in g/kg
prof.oz = 0.*w;                     % ozone profile
prof.skt = 0.0;                     % surface temperature in K
InstrumentAltInKm = altitude(1);    % instrument altitude in kilometers


%% *************************************************************************
% Define each profile as one of the following atmospheres:
%    1. Tropical   2. Midlat Summer   3. Midlat Winter
%    4. Subartic Summer   5. Subartic Winter  6. US Standard
%***************************************************************************
atmflag=5;      % H2O CO2  default_O3

ATM={'Tropical','Midlat Summer','Midlat Winter','Subartic Summer','Subartic Winter','US Standard'};
disp(['Using  ',ATM{atmflag},'  atmosphere for LBLRTM'])


%% *************************************************************************
% Define Input Parameters
%***************************************************************************
surf_alt = prof.surfaceElevation;    %********* surface altitude, km
zangle =[0.000];             %* satellite zenith angle at H1, degrees
CO2 = 427.;                  %********** CO2, ppmv 2025-02-12

iprof=1;                     % Choose a profile to make a tape5 file for
igascombo=1;                 % Choose a gas combination  1==all gases
isza=1;                      % Choose a satellite zenith angles, 1=nadir
comment=['McGill Sounding: ',filename];         % Make up a title for your profile
outfile=0;                   % '0' for TOA radiance, '1' for OD files

zh1 = prof.alt(1);               %********** instrument altitude, km  (surface for AERI)
zh2 = prof.alt(end);             %********** end point altitude, km
t1 = prof.skt;                   %********** temperature at surface, K 
t2 = 1.0;                        % surface emissivity


%% Create tape5 for radiance calculations only
Channel = 1;
v1 = 470.237;                    %********** start wavenumber, cm^-1
v2 = 1849.855;                   %********** end wavenumber, cm^-1
aeri_write5(prof,comment,[v1,v2],[t1,t2],[zh1 zh2 zangle(isza)],atmflag(iprof),CO2,igascombo,Channel,outfile);
Channel = 2;
v1 = 1750.338;                    %********** start wavenumber, cm^-1
v2 = 3070.000;                   %********** end wavenumber, cm^-1
aeri_write5(prof,comment,[v1,v2],[t1,t2],[zh1 zh2 zangle(isza)],atmflag(iprof),CO2,igascombo,Channel,outfile);



