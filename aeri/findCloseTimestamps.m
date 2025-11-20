function [indices1, indices2] = findCloseTimestamps(times1, times2, tolerance)
% findCloseTimestamps - Find timestamps in two arrays that are within tolerance
%
% Inputs:
%   times1 - First array of timestamps (seconds)
%   times2 - Second array of timestamps (seconds)
%   tolerance - Maximum allowed time difference (seconds)
%
% Outputs:
%   indices1 - Indices into times1 of matching timestamps
%   indices2 - Indices into times2 of matching timestamps

    indices1 = [];
    indices2 = [];
    
    for i = 1:length(times1)
        % Find times2 entries within tolerance
        time_diffs = abs(times2 - times1(i));
        close_idx = find(time_diffs <= tolerance);
        
        if ~isempty(close_idx)
            % Take the closest match
            [~, best_idx] = min(time_diffs(close_idx));
            indices1 = [indices1; i];
            indices2 = [indices2; close_idx(best_idx)];
        end
    end
    
    % Remove duplicate indices2 (keep first occurrence)
    if ~isempty(indices2)
        [unique_indices2, unique_idx] = unique(indices2);
        indices1 = indices1(unique_idx);
        indices2 = unique_indices2;
    end
end
