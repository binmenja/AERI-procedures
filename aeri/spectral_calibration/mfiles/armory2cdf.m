function armory2cdf(NCPATH,DATE);
%function armory2cdf(NCPATH,DATE);
%
%Replaces dmv2cdf when dmvdump is not available.
%Uses the netCDF files made by the AERI Armory (dmv_to_netcdf.py, e.g. from
%aeri_qc_netcdf.sh in the AEYYMMDD/output folder) and writes the files
%AERImeanSpectraRNC expects in input/aeri:
%  YYMMDD.SUM.cdf  YYMMDDC1.RNC.cdf  YYMMDDC2.RNC.cdf
%
%dmvdump keeps empty records (missingDataFlag=1, all NaN) and the Armory
%leaves them out, so SUM, C1 and C2 do not have the same number of records,
%while AERImeanSpectraRNC uses the same indices for the three files. Only
%records present in all three (matched on Time) are kept.
%For matched records the radiances are identical to dmvdump (checked on
%AERI-125 2025-02-12).
%
%NCPATH  folder with YYMMDD_sum.nc, YYMMDDC1_rnc.nc, YYMMDDC2_rnc.nc
%DATE    'YYMMDD'
%
%Version history
%
%2026-10-12 BRB McGill

%% Paths
OUTPATH='input/aeri/';
if NCPATH(end)~='/', NCPATH(end+1)='/'; end;
fsum=[NCPATH,DATE,'_sum.nc'];
fc1=[NCPATH,DATE,'C1_rnc.nc'];
fc2=[NCPATH,DATE,'C2_rnc.nc'];


%% Records common to SUM, C1 and C2
tsum=round(double(ncread(fsum,'Time'))*3600);
tc1=round(double(ncread(fc1,'Time'))*3600);
tc2=round(double(ncread(fc2,'Time'))*3600);
[t,isum]=intersect(tsum,intersect(tc1,tc2));
[~,ic1]=intersect(tc1,t);
[~,ic2]=intersect(tc2,t);
disp(['records kept: ',num2str(length(t)),' (SUM ',num2str(length(tsum)),', C1 ',num2str(length(tc1)),', C2 ',num2str(length(tc2)),')']);


%% SUM
sumvars={'Time','surfaceLayerAirTemp675_680','shortwaveWindowAirTemp2510_2515','longwaveWindowAirTemp985_990','atmosphericPressure'};
fout=[OUTPATH,DATE,'.SUM.cdf'];
if exist(fout,'file'), delete(fout); end;
for k=1:length(sumvars)
    x=double(ncread(fsum,sumvars{k}));
    nccreate(fout,sumvars{k},'Dimensions',{'time',length(t)},'Datatype','double','Format','classic');
    ncwrite(fout,sumvars{k},x(isum));
end;


%% C1 and C2
fin={fc1,fc2};
idx={ic1,ic2};
for c=1:2
    fout=[OUTPATH,DATE,'C',num2str(c),'.RNC.cdf'];
    if exist(fout,'file'), delete(fout); end;
    wn=double(ncread(fin{c},'wnum1'));
    rad=double(ncread(fin{c},'mean_rad'));
    rad(rad==-9999)=NaN;
    laser=double(ncread(fin{c},'originalLaserWavenumber'));
    tt=double(ncread(fin{c},'Time'));
    nccreate(fout,'mean_rad_ind','Dimensions',{'mean_rad_ind',length(wn)},'Datatype','double','Format','classic');
    ncwrite(fout,'mean_rad_ind',wn);
    nccreate(fout,'mean_rad','Dimensions',{'mean_rad_ind',length(wn),'time',length(t)},'Datatype','double');
    ncwrite(fout,'mean_rad',rad(:,idx{c}));
    nccreate(fout,'originalLaserWavenumber','Dimensions',{'time',length(t)},'Datatype','double');
    ncwrite(fout,'originalLaserWavenumber',laser(idx{c}));
    nccreate(fout,'Time','Dimensions',{'time',length(t)},'Datatype','double');
    ncwrite(fout,'Time',tt(idx{c}));
    disp(['wrote: ',fout]);
end;
