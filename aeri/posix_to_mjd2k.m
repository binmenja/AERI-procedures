function mjd2k = posix_to_mjd2k(posix_time)
% posix_to_mjd2k - Convert POSIX time to Modified Julian Date 2000
%
% Convert POSIX time (seconds since 1970-01-01 00:00:00 UTC) to MJD2K
% MJD2K is 0.0 on 2000-01-01 00:00:00 UTC
% POSIX time for 2000-01-01 00:00:00 UTC = 946684800 seconds
%
% Input:
%   posix_time - POSIX timestamp(s) in seconds
%
% Output:
%   mjd2k - Modified Julian Date 2000 value(s)

    mjd2k = double((posix_time - 946684800) / 86400.0);
end
