function writeSAVE;
%function writeSAVE;
%
%Creates a .txt file with commands to copy over output to armada repository
%
%Version history
%
%2021-02-10 JG UW-SSEC


%% Parameters
S=pwd;
WORKINGPATH=[S,'/working/'];
UNIT=num2str(load([WORKINGPATH,'UNIT.txt']));
if length(UNIT)==1
    UNIT(2)=UNIT(1);
    UNIT(1)='0';
end;
DIR=S(end-36-length(UNIT):end);

LOGIN='jgero';
REMOTEHOST1='ash.ssec.wisc.edu';
REMOTEPATH1='/home/jgero/lblrtmtemp/';
REMOTEHOST2='armada';
REMOTEPATH='/data/calibration_tests/';

files=dir([WORKINGPATH,'tape5_*.txt']);
file1=files(1).name;
file2=files(2).name;
LABEL=file1(7:end-8);
REMOTEWORKINGPATH=[REMOTEPATH,'aeri_',UNIT,'/spectral_calibration/'];


%% Write file
fid = fopen([WORKINGPATH,'SAVE.txt'],'w');
fprintf(fid,'%s\n',['scp -r ',S,' ',LOGIN,'@',REMOTEHOST1,':',REMOTEPATH1,'.']);
fprintf(fid,'\n');
fprintf(fid,'%s\n',['ssh ',LOGIN,'@',REMOTEHOST1]);
fprintf(fid,'\n');
fprintf(fid,'%s\n',['scp -r ',REMOTEPATH1,DIR,'/ ',REMOTEHOST2,':',REMOTEWORKINGPATH,'.']);
fprintf(fid,'%s\n',['rm -r ',REMOTEPATH1,'*']);
fprintf(fid,'%s\n',['exit']);
fprintf(fid,'\n');
fclose(fid);
