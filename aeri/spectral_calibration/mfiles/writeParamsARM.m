function writeParamsARM;
%function writeParamsARM;
%
%Creates .txt files for:
%  AERI observation DATE
%  AERI SITE
%  AERI UNIT number
%  radiosonde observation DATE
%  radiosonde observation TIME
%  radiosonde observation LABEL
%
%based on ARM NetCDF files for AERI and SONDE data


%% Get AERI data
files=dir(['input/aeri/*aeriengineer*.cdf']);
filename=files(1).name;
DATE=filename(22:29);
SITE=[upper(filename(1:3)),filename(16:17)];
switch SITE
    case 'SGPC1'
        UNIT='108';
    case 'NSAC1'
        UNIT='110';
    case 'TWPC1'
        UNIT='109';
    case 'TWPC3'
        UNIT='105';
    case 'MAOM1'
        UNIT='107';
    case 'PVCM1'
        UNIT='107';
    case 'PGHM1'
        UNIT='107';
    case 'TMPM1'
        UNIT='112';
    case 'ACXM1'
        UNIT='112';
    otherwise
        UNIT='XYZ';
end;


%% Get radiosonde data
files=dir(['input/sonde/*sondewnpn*.b1.*.cdf']);
filename=files(1).name;
RSDATE=filename(19:26);
RSTIME=filename(28:33);
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
