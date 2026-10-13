function aeri_write5(prof,comment,VBOUND,TBOUND,HBOUND,aflag,CO2amt,gcflag,Channel,outfile);
%
% function basic_write5(prof,comment,VBOUND,TBOUND,HBOUND,aflag,gcflag);
%
% produce an LBLRTM TAPE5 input file for the GIFTS instrument
%
% Inputs:
%   prof : structure containing atmospheric profile data: 
%      .pressure (Nx1) level pressure (mbar)
%      .tdry     (Nx1) level temperature (K)
%      .w        (Nx1) level water vapor mass mixing ratio (g/kg)
%      .alt      (Nx1) level altitudes (km)
%      .oz       (Nx1) level ozone (ppmv)
%   comment : descriptive comment
%   VBOUND : wavenumber info = [beginning_wavenumber ending_wavenumber]
%   TBOUND : surface info = [temperature at surface (K), surface emissivity]
%   HBOUND : geometry info = 
%            [observer_altitude (km) endpoint_altitude (km) zenith_angle@observer altitude (deg)]
%   aflag : code for standard atmosphere,
%           1. Tropical, 2. Midlatitude Summer, 3. Midlatitude Winter, 
%           4. Subarctic Summer, 5. Subarctic Winter, 6. U.S. Standard
%   CO2amt : CO2 amount in ppmv
%   gcflag : code for gas combinations
%           1. all gases  2. water vapor continuum only
%           3. water vapor line only   4. water vapor continuum, lines, & ozone
%           5. ozone only   6. dry
%   Channel = 1 (LW) or 2 (SW)
%
% Outputs:
%   A TAPE5 file, named "tape5", is produced in the current directory
%
% Notes:
%   0. This version specific to downwelling radiance calculations.
%   1. Uses given profile levels for layering 
%           (no checks for good/bad profile values)
%           (no extrapolating to top/bottom atmospheres)
%
% revised: 03 March 2010   ROK UW-SSEC  (specify Channel = 1 or 2)
% revised: 14 Oct 2023 JG UW-SSEC: new output path and file names
%
%------------------------------------------------------------------------------

%% Parameters
WORKINGPATH='working/';

UNIT=num2str(load([WORKINGPATH,'UNIT.txt']));
if length(UNIT)==1
    UNIT(2)=UNIT(1);
    UNIT(1)='0';
end;

RSLABEL=importdata([WORKINGPATH,'RSLABEL.txt']);  
RSLABEL=RSLABEL{1};


%% Open the output file (LBLRTM format)
if Channel == 1
    fid = fopen([WORKINGPATH,'tape5_AERI-',UNIT,'_',RSLABEL,'_ch1.txt'],'w');
else
    fid = fopen([WORKINGPATH,'tape5_AERI-',UNIT,'_',RSLABEL,'_ch2.txt'],'w');
end    

%% Line 1: comments
fprintf(fid,'$ %s \n',comment);


%% Line 2: flags
   if (gcflag == 1 )
      if (outfile ==1)
          flagstring = ' HI=1 F4=1 CN=1 AE=0 EM=1 SC=0 FI=0 PL=0 TS=0 AM=1 MG=1 LA=0 MS=0 XS=1   00   00';
      else
          flagstring = ' HI=1 F4=1 CN=1 AE=0 EM=1 SC=0 FI=0 PL=0 TS=0 AM=1 MG=0 LA=0 MS=0 XS=1   00   00';
      end
   else
      if (outfile ==1)
          flagstring = ' HI=1 F4=1 CN=6 AE=0 EM=1 SC=0 FI=0 PL=0 TS=0 AM=1 MG=1 LA=0 MS=0 XS=1   00   00';
      else
          flagstring = ' HI=1 F4=1 CN=6 AE=0 EM=1 SC=0 FI=0 PL=0 TS=0 AM=1 MG=0 LA=0 MS=0 XS=1   00   00';
      end
   end
%  F4 =1
%  CN =1   1=include continuum, 6=look to continuum multipliers
%  AE =0
%  EM =1
%  SC =0
%  FI =1
%  PL =0
%  TS =0
%  AM =1
%  MG =1   1 for OD files, 0 for TAPE6 file
%  LA =0
%  MS =0
%  XS =0
fprintf(fid,flagstring);
fprintf(fid,'\n');


%% Line 3: continuum multipliers (only use if CN=6)
switch (gcflag)
  case 2, fprintf(fid,'%10.3f%10.3f%10.3f%10.3f%10.3f%10.3f%10.3f\n',[1 1 0 0 0 0 0]); %wco
  case 3, fprintf(fid,'%10.3f%10.3f%10.3f%10.3f%10.3f%10.3f%10.3f\n',[0 0 0 0 0 0 0]); %wnc
  case 4, fprintf(fid,'%10.3f%10.3f%10.3f%10.3f%10.3f%10.3f%10.3f\n',[1 1 0 1 0 0 0]); %wvo
  case 5, fprintf(fid,'%10.3f%10.3f%10.3f%10.3f%10.3f%10.3f%10.3f\n',[0 0 0 1 0 0 0]); %ozo
  case 6, fprintf(fid,'%10.3f%10.3f%10.3f%10.3f%10.3f%10.3f%10.3f\n',[0 0 1 0 1 1 1]); %dry
end  %switch(gcflag)


%% Line 4: wavenumber bounds
fprintf(fid,'%10.3f%10.3f\n',[VBOUND(1) VBOUND(2)]);


%% Line 5: boundary temperature and emissivity
%   TBOUND  = [surface_temperature (K) scalar_surface_emissivity ()]
fprintf(fid,'%10.3f%10.3f%10.3f%10.3f\n',[TBOUND(1) TBOUND(2) 0 0]);


%% Line 6:  profile info
no_input_levels = length(prof.alt);


%% define layers
boundaries = prof.alt;
%boundaries = [0.000 0.350 0.580 0.820 1.050 1.290 1.530 1.770 ...
%              2.020 2.270 2.520 2.780 3.040 3.300 3.570 3.840 ...
%              4.110 4.380 4.660 4.940 5.220 5.510 5.800 6.090 ...    
%              6.380 6.670 6.960 7.260 7.560 7.860 8.160 8.460 ...    
%              8.770 9.080 9.390 9.700 10.020 10.340 10.650 10.980 ...
%              11.300 11.630 11.960 12.300 12.640 12.990 13.350 13.720 ...
%              14.100 14.480 14.870 15.270 15.680 16.090 16.510 16.930 ...
%              17.360 17.800 18.260 18.730 19.220 19.720 20.240];
%no_boundaries = no_input_levels;
no_boundaries = length(boundaries);

MODEL = 0;			     % user supplied atmospheric profile
ITYPE = 2;			     % slant path calculation
IBMAX = no_boundaries;		     % number of layer boundaries
NOZERO = 1;			     % suppress zeroing absorber amounts
NOPRNT = 1;			     % selects short printout
NMOL   = 7;			     % number of molecules
IPUNCH = 1;
IFXTYP = 0;
MUNITS = 0;
RE = 0;
HSPACE = 100;
VBAR = (VBOUND(1)+VBOUND(2))/2;
CO2MX = CO2amt; 		     % CO2 mixing ratio (ppmv) 

fprintf(fid,'%5i%5i%5i%5i%5i%5i%5i%2i %2i%10.3f%10.3f%10.3f%10.3f\n',...
	[MODEL ITYPE IBMAX NOZERO NOPRNT NMOL IPUNCH IFXTYP MUNITS RE HSPACE VBAR 0]);


%% print slant path parameters
% {H1} observer altitude = HBOUND(1)
% {H2} end point altitude = HBOUND(2)
% {ANGLE} zenith angle at H1 =0 for uplooking = 180 for downlooking = HBOUND(3)
fprintf(fid,'%10.3f%10.3f%10.3f\n',[HBOUND(1) HBOUND(2) HBOUND(3)]);
for i = 1:no_boundaries
	fprintf(fid,'%10.3f',boundaries(i));
	if rem(i,8)==0 & i ~= no_boundaries
		fprintf(fid,'\n',[]);
	end
end
fprintf(fid,'\n');


fprintf(fid,'%5i levels in the user defined profile\n',no_input_levels);
switch (aflag)
  case 1, aflagstring='1111';
  case 2, aflagstring='2222';
  case 3, aflagstring='3333';
  case 4, aflagstring='4444';
  case 5, aflagstring='5555';
  case 6, aflagstring='6666';
end  %switch(aflag)
for i = 1:no_input_levels
  switch (gcflag)
    case 1
         gcflagvar=[prof.w(i),CO2amt,prof.oz(i)];
    case 2
         gcflagvar=[prof.w(i),CO2amt,0.0];
         aflagstring='AAAA';
    case 3
         gcflagvar=[prof.w(i),0.0,0.0];
         aflagstring='AAAA';
    case 4
         gcflagvar=[prof.w(i),0.0,prof.oz(i)];
         aflagstring='AAAA';
    case 5
         gcflagvar=[0.0,0.0,prof.oz(i)];
         aflagstring='AAAA';
    case 6
         gcflagvar=[0.0,CO2amt,0.0];
%2         gcflagvar=[0.0,CO2amt,prof.oz(i)];
         aflagstring='AAAA';
  end   %switch(gcflag)
  fprintf(fid,'%10.3f%10.4f%10.3f%13s%4s\n',prof.alt(i),prof.pressure(i),prof.tdry(i),'     AA   CAA',aflagstring);  %mimic HW sig.dig.
  fprintf(fid,'%10.3f%10.3f%10.5f\n',gcflagvar);
% fprintf(fid,'%10.3f%10.3f%10.3f%13s%4s\n',prof.alt(i),prof.pressure(i),prof.tdry(i),'     AA   CAA',aflagstring);  %DT format
% fprintf(fid,'%10.3f%10.3f%10.3f\n',gcflagvar);								 %DT format
end  %loop of levels

%

fprintf(fid,'%5i%5i%5i selected x-sections are :\n',[3 0 0]);
fprintf(fid,'CCL4      F11       F12 \n');
fprintf(fid,'%5i%5i   \n',[2 0]);
fprintf(fid,'%10.3f     AAA\n',min(prof.alt));
fprintf(fid,'%10.3e%10.3e%10.3e\n',[1.105e-04 2.783e-04 5.027e-04]);
fprintf(fid,'%10.3f     AAA\n',max(prof.alt));
fprintf(fid,'%10.3e%10.3e%10.3e\n',[1.105e-04 2.783e-04 5.027e-04]);

if Channel == 1
    fprintf(fid,'');
    fprintf(fid,'');
    fprintf(fid,'$ *** FFTSCAN for the Downwelling Radiance at the Surface ***\n');
    fprintf(fid,' HI=0 F4=0 CN=0 AE=0 EM=0 SC=3 FI=0 PL=0 TS=0 AM=0 MG=0 LA=0 OD=0 XS=1    0    0\n');
    fprintf(fid,'1.03702766 547.719181803.71268    1   -4     0.48214700   12    1    1   13  0 0\n');
    fprintf(fid,'-1.\n');
    fprintf(fid,'');
    fprintf(fid,'');
    fprintf(fid,'$ Transfer to ASCII plotting data\n');
     fprintf(fid,' HI=0 F4=0 CN=0 AE=0 EM=0 SC=0 FI=0 PL=1 TS=0 AM=0 MG=0 LA=0 OD=0 XS=1    0    0\n');
    fprintf(fid,'# Plot title not used\n');
    fprintf(fid,' 550.129941799.85550   10.2000  100.0000    5    0   13    0    1.0000 0  0    0\n');
    fprintf(fid,'    0.0000    1.2000    7.0200    0.2000    4    0    1    1    0    0 0    3 27\n');
else 
    fprintf(fid,'');
    fprintf(fid,'');
    fprintf(fid,'$ *** FFTSCAN for the Downwelling Radiance at the Surface ***\n');
    fprintf(fid,' HI=0 F4=0 CN=0 AE=0 EM=0 SC=3 FI=0 PL=0 TS=0 AM=0 MG=0 LA=0 OD=0 XS=1    0    0\n');
    fprintf(fid,'1.037027661796.480423022.09850    1   -4     0.48214700   12    1    1   13  0 0\n');
    fprintf(fid,'-1.\n');
    fprintf(fid,'');
    fprintf(fid,'');
    fprintf(fid,'$ Transfer to ASCII plotting data\n');
     fprintf(fid,' HI=0 F4=0 CN=0 AE=0 EM=0 SC=0 FI=0 PL=1 TS=0 AM=0 MG=0 LA=0 OD=0 XS=1    0    0\n');
    fprintf(fid,'# Plot title not used\n');
    fprintf(fid,'1800.337523020.16992   10.2000  100.0000    5    0   13    0    1.0000 0  0    0\n');
    fprintf(fid,'    0.0000    1.2000    7.0200    0.2000    4    0    1    1    0    0 0    3 27\n');
end 

fprintf(fid,'-1.\n');

fprintf(fid,'%%\n');
fclose(fid);

