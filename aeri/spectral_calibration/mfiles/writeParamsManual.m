function writeParamsManual;
%function writeParamsManual;
%
%Creates .txt files for:
%  AERI observation DATE
%  AERI SITE
%  AERI UNIT number
%  radiosonde observation DATE
%  radiosonde observation TIME
%  radiosonde observation LABEL
%
%based on manual input


%% Get manual input
clc;
disp('Use single quotes for all input');
DATE=input('Enter date of observation (''YYYYMMDD''): ');
SITE=input('Enter site of observation (e.g. ''SSEC''): ');
UNIT=input('Enter AERI unit (e.g. ''116''): ');
RSTIME=input('Enter radiosonde time of observation (''HHMMSS''): ');


%% Additional parameters
RSDATE=DATE;
RSLABEL=[RSDATE,'T',RSTIME];


%% Write files
WORKINGPATH='working/';

fid=fopen([WORKINGPATH,'DATE.txt'],'w');
fprintf(fid,'%s\n',DATE);
fclose(fid);

fid=fopen([WORKINGPATH,'SITE.txt'],'w');
fprintf(fid,'%s\n',SITE);
fclose(fid);

fid=fopen([WORKINGPATH,'UNIT.txt'],'w');
fprintf(fid,'%s\n',UNIT);
fclose(fid);

fid=fopen([WORKINGPATH,'RSDATE.txt'],'w');
fprintf(fid,'%s\n',RSDATE);
fclose(fid);

fid=fopen([WORKINGPATH,'RSTIME.txt'],'w');
fprintf(fid,'%s\n',RSTIME);
fclose(fid);

fid=fopen([WORKINGPATH,'RSLABEL.txt'],'w');
fprintf(fid,'%s\n',RSLABEL);
fclose(fid);
