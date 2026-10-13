function writeLBLRTM_rorqual;
%function writeLBLRTM_rorqual;
%
%Same as writeLBLRTM_zsh but for Rorqual (Alliance Canada).
%LBLRTM is not allowed on the login nodes, so the two runs are done in a
%Slurm job. Creates in the working directory:
%  runLBLRTM.txt  commands to copy tape5 files, submit the job, copy back tape27 files
%  lblrtm_job.sh  Slurm job script
%
%Uses the LBLRTM install in the project space (executable, TAPE3, FSCDXS
%and xs are linked into the run folder on scratch).
%
%Version history
%
%2026-10-12 BRB McGill, from writeLBLRTM_zsh (JG UW-SSEC)

%% Parameters
REMOTEHOST='rorqual';
ACCOUNT='rrg-yihuang-ad';
LBLRTMPATH='/home/binmenja/links/projects/rrg-yihuang-ad/binmenja/models/LBLRTM';
LBLRTMEXE='lblrtm_v12.17_linux_gnu_dbl';
REMOTEPATH='/home/binmenja/links/scratch/spectral_calibration';
S=pwd;
WORKINGPATH=[S,'/working/'];

files=dir([WORKINGPATH,'tape5_*.txt']);
file1=files(1).name;
file2=files(2).name;
LABEL=file1(7:end-8);
REMOTEWORKINGPATH=[REMOTEPATH,'/spectral_calibration_',LABEL];


%% Write Slurm job script
fid = fopen([WORKINGPATH,'lblrtm_job.sh'],'w');
fprintf(fid,'%s\n','#!/bin/bash');
fprintf(fid,'%s\n',['#SBATCH --account=',ACCOUNT]);
fprintf(fid,'%s\n',['#SBATCH --job-name=lblrtm_',LABEL]);
fprintf(fid,'%s\n','#SBATCH --time=02:00:00');
fprintf(fid,'%s\n','#SBATCH --ntasks=1');
fprintf(fid,'%s\n','#SBATCH --cpus-per-task=1');
fprintf(fid,'%s\n','#SBATCH --mem=4G');
fprintf(fid,'%s\n','#SBATCH --output=lblrtm_%j.out');
fprintf(fid,'\n');
fprintf(fid,'%s\n',['cd ',REMOTEWORKINGPATH]);
fprintf(fid,'%s\n',['ln -sf ',LBLRTMPATH,'/',LBLRTMEXE,' lblrtm']);
fprintf(fid,'%s\n',['ln -sf ',LBLRTMPATH,'/TAPE3 TAPE3']);
fprintf(fid,'%s\n',['ln -sf ',LBLRTMPATH,'/FSCDXS FSCDXS']);
fprintf(fid,'%s\n',['ln -sfn ',LBLRTMPATH,'/xs xs']);
fprintf(fid,'%s\n',['ln -sf ',LBLRTMPATH,'/data/absco-ref_wv-mt-ckd.nc absco-ref_wv-mt-ckd.nc']);
fprintf(fid,'%s\n',['cp ',file1,' TAPE5']);
fprintf(fid,'%s\n','./lblrtm');
fprintf(fid,'%s\n',['mv TAPE27 tape27_',LABEL,'_ch1.txt']);
fprintf(fid,'%s\n',['cp ',file2,' TAPE5']);
fprintf(fid,'%s\n','./lblrtm');
fprintf(fid,'%s\n',['mv TAPE27 tape27_',LABEL,'_ch2.txt']);
fclose(fid);


%% Write file
fid = fopen([WORKINGPATH,'runLBLRTM.txt'],'w');
fprintf(fid,'%s\n',['ssh ',REMOTEHOST,' mkdir -p ',REMOTEWORKINGPATH]);
fprintf(fid,'\n');
fprintf(fid,'%s\n',['scp ',WORKINGPATH,'tape5_* ',WORKINGPATH,'lblrtm_job.sh ',REMOTEHOST,':',REMOTEWORKINGPATH]);
fprintf(fid,'\n');
fprintf(fid,'%s\n',['ssh ',REMOTEHOST]);
fprintf(fid,'\n');
fprintf(fid,'%s\n',['cd ',REMOTEWORKINGPATH]);
fprintf(fid,'%s\n',['sbatch lblrtm_job.sh']);
fprintf(fid,'%s\n',['squeue -u $USER']);
fprintf(fid,'%s\n',['# wait for the job to finish, check lblrtm_*.out, then']);
fprintf(fid,'%s\n',['ls tape27_*']);
fprintf(fid,'%s\n',['exit']);
fprintf(fid,'\n');
fprintf(fid,'%s\n',['scp ''',REMOTEHOST,':',REMOTEWORKINGPATH,'/tape27_',LABEL,'_ch*.txt'' ',WORKINGPATH]);
fclose(fid);


%% Same as runLBLRTM.txt in one go: bash working/runLBLRTM.sh
%% sbatch --wait returns when the job ends; MFA is asked once if ControlMaster is set for rorqual
fid = fopen([WORKINGPATH,'runLBLRTM.sh'],'w');
fprintf(fid,'%s\n','#!/bin/bash');
fprintf(fid,'%s\n','set -e');
fprintf(fid,'%s\n',['ssh ',REMOTEHOST,' mkdir -p ',REMOTEWORKINGPATH]);
fprintf(fid,'%s\n',['scp ',WORKINGPATH,'tape5_* ',WORKINGPATH,'lblrtm_job.sh ',REMOTEHOST,':',REMOTEWORKINGPATH]);
fprintf(fid,'%s\n','echo "LBLRTM job submitted, waiting for it to finish..."');
fprintf(fid,'%s\n',['ssh ',REMOTEHOST,' "cd ',REMOTEWORKINGPATH,' && sbatch --wait lblrtm_job.sh" || { ssh ',REMOTEHOST,' "cat ',REMOTEWORKINGPATH,'/lblrtm_*.out"; exit 1; }']);
fprintf(fid,'%s\n',['ssh ',REMOTEHOST,' "cat ',REMOTEWORKINGPATH,'/lblrtm_*.out"']);
fprintf(fid,'%s\n',['scp ''',REMOTEHOST,':',REMOTEWORKINGPATH,'/tape27_',LABEL,'_ch*.txt'' ',WORKINGPATH]);
fprintf(fid,'%s\n',['ls -l ',WORKINGPATH,'tape27_*']);
fclose(fid);
