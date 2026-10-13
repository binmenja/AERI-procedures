function writeLBLRTMremote;
%function writeLBLRTMremote;
%
%Creates a .txt file with LBLRTM commands to:
%tunnel into ash
%copy over tape5 files
%run LBLRTM
%copy back tape27 files
%
%Version history
%
%2016-02-16 JG UW-sSEC, remote version


%% Parameters
LOGIN='jgero';
TUNNEL='ash.ssec.wisc.edu';
TUNNELPATH='/home/jgero/lblrtmtemp/';

REMOTEHOST='bora11';
REMOTEPATH='/home/jgero/lblrtm/';
S=pwd;
WORKINGPATH=[S,'/working/'];

files=dir([WORKINGPATH,'tape5_*.txt']);
file1=files(1).name;
file2=files(2).name;
LABEL=file1(7:end-8);
outfile1=['tape27_',LABEL,'_ch1.txt'];
outfile2=['tape27_',LABEL,'_ch2.txt'];
REMOTEWORKINGPATH=[REMOTEPATH,'spectral_calibration_',LABEL];


%% Write file
fid = fopen([WORKINGPATH,'runLBLRTM.txt'],'w');
fprintf(fid,'%s\n',['scp ',WORKINGPATH,'tape5_*.txt ',LOGIN,'@',TUNNEL,':',TUNNELPATH]);
fprintf(fid,'\n');
fprintf(fid,'%s\n',['ssh ',LOGIN,'@',TUNNEL]);
fprintf(fid,'\n');
fprintf(fid,'%s\n',['ssh ',REMOTEHOST]);
fprintf(fid,'\n');
fprintf(fid,'%s\n',['cd ',REMOTEPATH]);
fprintf(fid,'%s\n',['unzip lblrtm_work.zip']);
fprintf(fid,'%s\n',['mv work_rename spectral_calibration_',LABEL]);
fprintf(fid,'%s\n',['cd ',REMOTEWORKINGPATH]);
fprintf(fid,'%s\n',['scp ',TUNNEL,':',TUNNELPATH,'tape5_*.txt .']);
fprintf(fid,'\n');
fprintf(fid,'%s\n',['cp ',file1,' TAPE5']);
fprintf(fid,'%s\n',['./lblrtm']);
fprintf(fid,'%s\n',['mv TAPE27 ',outfile1]);
fprintf(fid,'%s\n',['cp ',file2,' TAPE5']);
fprintf(fid,'%s\n',['./lblrtm']);
fprintf(fid,'%s\n',['mv TAPE27 ',outfile2]);
fprintf(fid,'%s\n',['scp tape27_*.txt ',TUNNEL,':',TUNNELPATH]);
fprintf(fid,'\n');
fprintf(fid,'%s\n',['exit']);
fprintf(fid,'\n');
fprintf(fid,'%s\n',['exit']);
fprintf(fid,'\n');
fprintf(fid,'%s\n',['scp ',LOGIN,'@',TUNNEL,':',TUNNELPATH,'tape27_',LABEL,'_ch*.txt ',WORKINGPATH]);
fclose(fid);
