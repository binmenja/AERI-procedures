function [e1,e2] = rh2e(p,t,rh,Tconvert)

%
% function [e1,e2] = rh2e(p,t,rh,Tconvert)
%
% compute H2O partial pressure (e, mbar) given reference
% pressure (p, mbar), temperature (t, K), and relative humidity (rh, %)
%
% Two partial pressures are returned: e1 is with RH defined as the ratio
% of water vapor partial pressure to saturation vapor pressure and
% e2 is with RH defined as the ratio of water vapor mixing ratio to
% saturation mixing ratio.
%
% if input, Tconvert is used as the temperature point to switch
% from using saturation vapor pressure over water to over ice.
%
% Not in the original JG package (called by rh2dp); written to match
% rh2mr/e2mr. Only used for the dew point in the sonde plot.
%

% saturation pressure
if nargin == 3
  esat = satvap(t);
  wsat = satmix(p,t);
elseif nargin == 4
  esat = satvap(t,Tconvert);
  wsat = satmix(p,t,Tconvert);
end

% H2O partial pressure
e1 = rh./100.*esat;

% using WMO definition of relative humidity
w2 = rh./100.*wsat;
eps = 0.621970585;
e2 = p.*w2./(1000.*eps + w2);
