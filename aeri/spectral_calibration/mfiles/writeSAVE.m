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

REMOTEHOST2='armada';
REMOTEPATH='/data/calibration_tests/';

REMOTEWORKINGPATH=[REMOTEPATH,'aeri_',UNIT,'/spectral_calibration/'];


%% Write file
fid = fopen([WORKINGPATH,'SAVE.txt'],'w');
fprintf(fid,'%s\n',['scp -r ',S,' ',REMOTEHOST2,':',REMOTEWORKINGPATH,'.']);
fprintf(fid,'\n');
fclose(fid);
