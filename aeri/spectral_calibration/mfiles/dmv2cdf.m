function dmv2cdf(varargin);
%function dmv2cdf(PATH(optional),FILE(optional));
%
%Convert dmv files to netcdf format using dmvdump
%Default PATH is [getpath,'AE',getdate,'/']
%Default FILE is any .CXS .SUM .RNC in the path


%% Parameters
!hostname > /Users/jgero/Dropbox/documents/MATLAB/temp/host.txt
HOST=importdata('/Users/jgero/Dropbox/documents/MATLAB/temp/host.txt');
HOST=HOST{1};
switch HOST(1:3)
    case 'fan'
        LIBPATH='DYLD_LIBRARY_PATH= PATH=/Users/jgero/anaconda/bin/';  %fangorn.ssec.wisc.edu
        disp(['Host = ',HOST]);
    case 'min'
        LIBPATH='DYLD_LIBRARY_PATH= PATH=/Users/jgero/opt/anaconda3/envs/dmvdump/bin/';  %minas.ssec.wisc.edu
        disp(['Host = ',HOST]);
    case 'mel'
        LIBPATH='DYLD_LIBRARY_PATH= PATH=/Users/jgero/miniconda3/envs/dmv2/bin/';  %melendor; first run 'source activate dmv2'
        disp(['Host = ',HOST]);
    otherwise
        disp('Host not recognized');
end;

%!source activate dmv2
%source deactivate
%dmvdump
%which dmvdump

EXE='dmvdump';


%% Parse input
switch nargin
    case 1
        if ~isempty(varargin{1})
            PATH=varargin{1};
            if PATH(end)~='/', PATH(end+1)='/'; end;
            d=[dir([PATH,'*.CXS']); dir([PATH,'*.SUM']); dir([PATH,'*.RNC'])];
            DATE=getdate;
            DATE=d(1).name(1:6);
        end;
    case 2
        if ~isempty(varargin{1})
            PATH=varargin{1};
        end;
        FILE=varargin{2};
        if PATH(end)~='/', PATH(end+1)='/'; end;
        if length(dir([PATH,FILE]))==1
            disp(['converting: ',PATH,FILE]);
            eval(['!',LIBPATH,' ',EXE,' -o ',PATH,FILE,'.cdf ',PATH,FILE]);
            return;
        else
            error(['file does not exist: ',PATH,FILE]);
        end;
    otherwise
        DATE=getdate;
        PATH=[getpath,'AE',DATE,'/'];
end;


%% Convert
disp(['converting: ',PATH,DATE,'*']);
if length(dir([PATH,DATE(1:6),'F1.CXS']))==1, eval(['!',LIBPATH,' ',EXE,' -o ',PATH,DATE(1:6),'F1.CXS.cdf ',PATH,DATE(1:6),'F1.CXS']); end;
if length(dir([PATH,DATE(1:6),'F2.CXS']))==1, eval(['!',LIBPATH,' ',EXE,' -o ',PATH,DATE(1:6),'F2.CXS.cdf ',PATH,DATE(1:6),'F2.CXS']); end;
if length(dir([PATH,DATE(1:6),'B1.CXS']))==1, eval(['!',LIBPATH,' ',EXE,' -o ',PATH,DATE(1:6),'B1.CXS.cdf ',PATH,DATE(1:6),'B1.CXS']); end;
if length(dir([PATH,DATE(1:6),'B2.CXS']))==1, eval(['!',LIBPATH,' ',EXE,' -o ',PATH,DATE(1:6),'B2.CXS.cdf ',PATH,DATE(1:6),'B2.CXS']); end;
if length(dir([PATH,DATE(1:6),'.SUM']))==1, eval(['!',LIBPATH,' ',EXE,' -o ',PATH,DATE(1:6),'.SUM.cdf ',PATH,DATE(1:6),'.SUM']); end;
if length(dir([PATH,DATE(1:6),'C1.RNC']))==1, eval(['!',LIBPATH,' ',EXE,' -o ',PATH,DATE(1:6),'C1.RNC.cdf ',PATH,DATE(1:6),'C1.RNC']); end;
if length(dir([PATH,DATE(1:6),'C2.RNC']))==1, eval(['!',LIBPATH,' ',EXE,' -o ',PATH,DATE(1:6),'C2.RNC.cdf ',PATH,DATE(1:6),'C2.RNC']); end;

