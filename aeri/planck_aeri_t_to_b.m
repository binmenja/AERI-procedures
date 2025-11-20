function B = planck_aeri_t_to_b(wavnum, t)
    % PLANCK_AERI Calculates spectral radiance from wavenumber and temperature
    % 
    % Inputs:
    %   wavnum - Wavenumbers [cm^-1]
    %   t      - Temperature [K]
    %
    % Outputs:
    %   B      - Spectral radiance [mW / m2 sr cm^-1]
    
    % Constants
    c1 = 1.191066e-8;  % [W / m2 / sr / cm^-1] 
    c2 = 1.438833;     % [K / cm^-1]
    
    % Preallocate output
    B = NaN(size(wavnum,1), size(t,2));
    
    % Calculate spectral radiance for each column
    for i = 1:size(t,2)
        B(:,i) = 1000 .* (c1 .* wavnum.^3) ./ (exp(c2 .* wavnum ./ t(:,i)) - 1);
    end
    
end