function [freq_points, power_points] = a15_dvfs_get_curve()
% a15_dvfs_get_curve  DVFSカーブを取得
%   周波数(GHz)と電力(W)のポイント配列を返します。

    load_points = 0:5:100;
    n_points    = numel(load_points);
    freq_points = zeros(n_points,1);
    power_points = zeros(n_points,1);

    for i = 1:n_points
        [f, p, ~] = a15_dvfs_model(load_points(i));
        freq_points(i)  = f / 1e9;  % GHz 単位
        power_points(i) = p;
    end
end 