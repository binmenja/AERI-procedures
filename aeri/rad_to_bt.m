function t=rad_to_bt(wavnum,B)
% function B=plank_wavnum(wavnum,t) % If I wanna get B from t and wavnum
% wavnum [ cm-1], t [ K ], B [ mW / m2 sr cm-1 ] wnum in first dim and
% spectra number in second dim
 
c1=1.191066e-8; % [ W / m2 / sr / cm-1 ] 
%c1 = 1.191043934e-08; 
c2=1.438833; % [ K / cm-1 ]
%c2 = 1.438769911;

% When doing it on arrays of wavenumbers and radiance
%t = [];
%if length(wavnum(:)) > 1 && length(B(:)) > 1 && ...
%   length(wavnum(:)) ~= length(B(:))
%  disp('ERROR - planck_v2: mismatching sizes of wavnum and B!');
%  return;
%elseif length(wavnum(:)) == length(B(:))
%  wavnum = reshape(wavnum,size(B));
%end


t = NaN(length(wavnum),size(B,2));
for i = 1:size(B,2)
    t(:,i) = c2 .* wavnum ./ log((c1 .* wavnum.^3 ./ (B(:,i) ./ 1000)) + 1);
end
% When doing it on arrays of wavenumbers and temperature
%B = [];
%if length(wavnum(:)) > 1 && length(t(:)) > 1 && ...
%   length(wavnum(:)) ~= length(t(:))
%  disp('ERROR - planck_v2: mismatching sizes of wavnum and t!');
%  return;
%elseif length(wavnum(:)) == length(t(:))
%  wavnum = reshape(wavnum,size(t));
%end

%B = c1.*wavnum.^3./(exp(c2.*wavnum./t)-1);

return;
