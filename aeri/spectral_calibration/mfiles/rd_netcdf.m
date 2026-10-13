function theResult = rd_netcdf(varargin);

%function theResult = rd_netcdf(theNetCDFFile(optional), varlist(optional))
%
%Load variables from a NetCDF file into a Matlab strucutre
%
%Inputs:
% theNetCDFFile   optional [string]
%                  NetCDF file name
%                  If no filename provided then GUI is launched to get file
%                  name
% varlist         optional [cell array]
%                  list of variables to import
%
%Output:
% theResult            Matlab structure with NetCDF data
% theResult.variables  list of variables imported
%
%
% version 1997 Dr. Charles R. Denham, ZYDECO.
%
% version of DCT 9/29/97 to return all variables in a structure
% and to return fields w/ multiple dimensions.
%
% version 18 May 2010 R. Knuteson, UW-SSEC - Make backwards compatible with
% old netCDF library code
%
% version 3 Feb 2012 J. Gero, UW-SSEC
% Retains backwards compatibility in parameter format with 9/29/97 version:
%     second input variable is a cell array of variable names
%     theResult.variables field is included


%% Parse input variables
switch nargin
    case 0  %if no file name specified, launch GUI to get file name
        [filename,pathname] = uigetfile;
        theNetCDFFile = [pathname filename];
    case 1
        theNetCDFFile = varargin{1};
    case 2
        theNetCDFFile = varargin{1};
        varlist = varargin{2};
    otherwise
    error('Too many input variables specified');
end;


%% Test for correct output variable
if nargout > 1
    error('Too many output variables specified');
end;
    

%% Default result
theResult = [];


%% Using built-in fuctions - present in Matlab 2010 and later

%open file
f = netcdf.open(theNetCDFFile, 'nowrite');
if isempty(f)
    error('Unable to open file');
end;

if nargin < 2  %no variable list specified.  return all variables.
    %get #dimensions, #variables, #attributes, record dimension
    [numdims, numvars, numglobalatts, unlimdimID] = netcdf.inq(f);
    for k = 0:numvars-1  %loop over number of variables
        [varname, xtype, varDimIDs, varAtts] = netcdf.inqVar(f,k);  %get variable name
        varid = netcdf.inqVarID(f,varname);  %get variable ID
        data = netcdf.getVar(f,varid,'double');  %get data, store as 'double'
        
        % If variable has 2 or more dimensions, reverse the order so as to
        % maintain consistency with the older netcdf library function call.
        % This is because the built-in functions are using Fortran
        % dimension order while the netcdf libraries are using C order.
        data_dims = ndims(data);
        if (data_dims >= 3 || size(data,2) > 1)
            data = permute(data,[data_dims:-1:1]);
        end;
        
        %store name and data
        result.variables{k+1}=varname;
        eval(['result.',varname,' = data;']);
    end;
    
else  %variable list specified.  return specified variables
    result.variables=varlist;
    for i = 1:length(varlist)
        varname=varlist{i};
        %try to get variable ID.  If wrong name provided display error
        try
            varid = netcdf.inqVarID(f,varname);
        catch
            disp(['Error: Incorrect variable name: ',varname]);
            netcdf.close(f)
            return;
        end;
        data = netcdf.getVar(f,varid,'double');  %get data, store as 'double'
        
        % If variable has 2 or more dimensions, reverse the order so as to
        % maintain consistency with the older netcdf library function call.
        % This is because the built-in functions are using Fortran
        % dimension order while the netcdf libraries are using C order.
        data_dims = ndims(data);
        if (data_dims >= 3 || size(data,2) > 1)
            data = permute(data,[data_dims:-1:1]);
        end;
        
        %store data
        eval(['result.',varname,' = data;']);
    end;
end;

%close file
netcdf.close(f)


%% Assign output
theResult = result;
