
function [wnbr4,rad4] = zeropad4(wnbr,rad,n,v_rolloff)

%
% function [wnbr4,rad4] = zeropad4(wnbr,rad,n,v_rolloff)
%
% interpolate a vector to a finer sampling via fft zero padding.
% 
% Input variables:
%   wnbr	wavenumbers (x)
%   rad		radiances   f(x)
%   n		2^n +1 = # points in resulting spectrum
%   v_rolloff   [2x1] wavenumber boundaries for roll-off
%
% Output variables:
%   wnbr4	wavenumbers (x_fine)
%   rad4	radiances   f(x_fine)
%

% default value of n is 15
if ~exist('n')
  n = 15;
end

% default value for rolloff width is 5 percent of bandwidth
if ~exist('v_rolloff')
  v_rolloff(1) = 0.05*(max(wnbr)-min(wnbr)) + min(wnbr);
  v_rolloff(2) =-0.05*(max(wnbr)-min(wnbr)) + max(wnbr);
end

% # of points in input spectrum
npts1 = length(wnbr);

% roll-off 
ind = find(wnbr < v_rolloff(1));
temp=ind-min(ind);temp=temp/max(temp); 
rad(ind) = rad(max(ind)+1)*(sin(temp*pi-pi/2)*0.5+0.5);
ind = find(wnbr > v_rolloff(2));
temp=ind-min(ind);temp=temp/max(temp); 
rad(ind) = rad(min(ind)-1)*(cos(temp*pi)*0.5+0.5);

% even function created with input radiances and mirror image of
% input radiances.  first and last points are unique.
rad2 = [rad ; flipud(rad(2:npts1-1))];

% forward fft and number of points
yfft2 = fft(rad2);
npts2 = length(yfft2);

% number of points in zeropadded fft and in output spectrum
npts3 = 2^(n+1);
npts4 = 2^n +1;

% zero-padded fft
yfft3 = zeros(npts3,1);
yfft3(1:npts2/2 +1) = yfft2(1:npts2/2 +1);
yfft3(npts3 - npts2/2 +2:npts3) = yfft2(npts2/2+2:npts2);

% inverse fft of zeropadded fft
rad4 = fft(yfft3)/npts2;

% retain first half of spectrum
rad4 = real(rad4(1:npts4));

% create new wavenumber scale
wnbr4 = linspace(min(wnbr),max(wnbr),npts4)';

