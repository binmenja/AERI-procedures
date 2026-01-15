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
    % Radiance B is in mW/m2/sr/cm-1, convert to W/m2/sr/cm-1 by /1000
    L = B(:,i) ./ 1000;
    
    % Handle negative or zero radiance which causes log() to produce complex numbers (or NaN/Inf)
    % Planck function inverse logic: T = c2*v / ln( (c1*v^3/L) + 1 )
    % If (c1*v^3/L + 1) <= 0, we get complex numbers or NaNs. This happens if L is negative/zero
    % We should treat these as invalid or clip them.
    
    % Mask valid radiances
    valid_mask = L > 0;
    
    % Compute T only for valid L
    if any(valid_mask)
        term = (c1 .* wavnum(valid_mask).^3 ./ L(valid_mask)) + 1;
        % Ensure term > 0 just in case
        valid_term = term > 0;
        
        final_mask = false(size(valid_mask));
        final_mask(valid_mask) = valid_term;
        
        t(final_mask,i) = c2 .* wavnum(final_mask) ./ log(term(valid_term));
    end
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
