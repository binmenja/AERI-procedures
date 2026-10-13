function writeLBLRTM;
%function writeLBLRTM;
%
%Creates a .txt file with LBLRTM commands to:
%copy over tape5 files
%run LBLRTM
%copy back tape27 files
%
%Version history
%
%2012-10-14 JG UW-SSEC
%2012-10-15 JG UW-SSEC, change to write file

%% Parameters
REMOTEHOST='armada';
REMOTEPATH='/home/jgero/lblrtm';
S=pwd;
WORKINGPATH=[S,'/working/'];

files=dir([WORKINGPATH,'tape5_*.txt']);
file1=files(1).name;
file2=files(2).name;
LABEL=file1(7:end-8);
REMOTEWORKINGPATH=[REMOTEPATH,'/spectral_calibration_',LABEL];


%% Write file
fid = fopen([WORKINGPATH,'runLBLRTM.txt'],'w');
fprintf(fid,'%s\n',['ssh ',REMOTEHOST]);
fprintf(fid,'\n');
fprintf(fid,'%s\n',['cd ',REMOTEPATH]);
fprintf(fid,'%s\n',['unzip lblrtm_work.zip']);
fprintf(fid,'%s\n',['mv work_rename spectral_calibration_',LABEL]);
fprintf(fid,'%s\n',['exit']);
fprintf(fid,'\n');
fprintf(fid,'%s\n',['scp ',WORKINGPATH,'tape5_* ',REMOTEHOST,':',REMOTEWORKINGPATH]);
fprintf(fid,'\n');
fprintf(fid,'%s\n',['ssh ',REMOTEHOST]);
fprintf(fid,'\n');
fprintf(fid,'%s\n',['cd ',REMOTEWORKINGPATH]);
fprintf(fid,'%s\n',['cp ',file1,' TAPE5']);
fprintf(fid,'%s\n',['./lblrtm']);
fprintf(fid,'%s\n',['mv TAPE27 tape27_',LABEL,'_ch1.txt']);
fprintf(fid,'%s\n',['cp ',file2,' TAPE5']);
fprintf(fid,'%s\n',['./lblrtm']);
fprintf(fid,'%s\n',['mv TAPE27 tape27_',LABEL,'_ch2.txt']);
fprintf(fid,'%s\n',['exit']);
fprintf(fid,'\n');
fprintf(fid,'%s\n',['scp ''',REMOTEHOST,':',REMOTEWORKINGPATH,'/tape27_',LABEL,'_ch*.txt'' ',WORKINGPATH]);
fclose(fid);

