function writeParamsAuto;
%function writeParamsAuto;
%
%Creates .txt files for:
%  AERI observation DATE
%  AERI SITE
%  AERI UNIT number
%  radiosonde observation DATE
%  radiosonde observation TIME
%  radiosonde observation LABEL
%
%based on available input and manual data


%% Get AERI data

% Check for DMV input
file=dir(['input/aeri/*.SUM.cdf']);
if ~isempty(file)
    DATE=file(1).name(1:6);
    if DATE(1)=='9'
        DATE=['19',DATE];
    else
        DATE=['20',DATE];
    end;
end;
clear file;
    
% Check for ARM input
file=dir(['input/aeri/*aeriengineer*.cdf']);
if ~isempty(file)
    DATE=file(1).name(end-18:end-11);
    i1=strfind(file(1).name,'.');
    SITE=[upper(file(1).name(1:3)),file(1).name(16:i1(1)-1)];
end;
clear file;


%% Get radiosonde data

% Check for EDT input (SSEC)
file=dir(['input/sonde/edtaeri_*.txt']);
if ~isempty(file)
    RSDATE=file(1).name(9:16);
    RSTIME=[file(1).name(18:21),'00'];
end;
clear file;

% Check for ARM input
file=dir(['input/sonde/*sondewnpn*.b1.*.cdf']);
if ~isempty(file)
    RSDATE=file(1).name(end-18:end-11);
    RSTIME=file(1).name(end-9:end-4);
end;
clear file;


%% Get manual input for missing variables
clc;
disp('Use single quotes for all input');

if ~exist('DATE','var')
    DATE=input('Enter date of observation (''YYYYMMDD''): ');
end;

if ~exist('SITE','var')
    SITE=input('Enter site of observation (e.g. ''SSEC''): ');
end;
    
if ~exist('UNIT','var')
    UNIT=input('Enter AERI unit (e.g. ''116''): ');
end;

if ~exist('RSTIME','var')
    RSTIME=input('Enter radiosonde time of observation (''HHMMSS''): ');
    RSDATE=DATE;
end;

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
