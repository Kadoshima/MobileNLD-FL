function [freq, power, ipc] = a15_dvfs_model(load_percent)
% A15 Bionic DVFSモデル - 実測周波数と文献電力値のハイブリッド
% 
% 入力:
%   load_percent: CPU負荷率 (0-100)
% 出力:
%   freq: 動作周波数 [Hz]
%   power: 消費電力 [W]
%   ipc: 実効IPC (Instructions Per Cycle)
%
% 参考: Time Profiler実測値 + AnandTech/Apple文献値

    % 入力値の検証
    load_percent = max(0, min(100, load_percent));
    
    % 実測値に基づくDVFSポイント
    if load_percent < 12.5  % 0-12.5%
        freq = 1.0e9;   % 1.0 GHz (実測値)
        power = 0.5;    % 文献値
        ipc = 2.5;      % E-core中心
    elseif load_percent < 37.5  % 12.5-37.5%
        freq = 1.8e9;   % 1.8 GHz (実測値)
        power = 1.2;    % 文献値補間
        ipc = 3.0;      % E+P混合
    elseif load_percent < 62.5  % 37.5-62.5%
        freq = 2.4e9;   % 2.4 GHz (実測値)
        power = 2.3;    % 文献値補間
        ipc = 3.8;      % P-core活性化
    elseif load_percent < 87.5  % 62.5-87.5%
        freq = 2.8e9;   % 2.8 GHz (実測値)
        power = 3.2;    % 文献値補間
        ipc = 4.0;      % P-core主体
    else  % 87.5-100%
        freq = 3.2e9;   % 3.2 GHz (実測値)
        power = 4.3;    % 文献値（AnandTech）
        ipc = 4.2;      % 最大性能
    end
    
    % 文献値をそのまま使用（二次関数モデルは検証用のみ）
    % DVFSの段階的な特性を正確に反映
    
    % キャッシュ効率とメモリ帯域の影響
    cache_efficiency = get_cache_efficiency(load_percent);
    memory_bandwidth_factor = get_memory_bandwidth_factor(freq);
    
    % 実効IPCの調整
    ipc = ipc * cache_efficiency * memory_bandwidth_factor;
    
    % 温度スロットリングモデル（高負荷時）
    % 短時間バーストでは最大周波数を維持可能
    if load_percent > 95 && freq > 3.0e9
        % 持続的な最大負荷時のみ軽微なスロットリング
        thermal_throttle = 0.95;  % 5%性能低下
        freq = freq * thermal_throttle;
        power = power * thermal_throttle^2;  % 電力は周波数の2乗に比例
    end
end

function efficiency = get_cache_efficiency(load_percent)
% 負荷レベルに応じたキャッシュ効率
    if load_percent < 25
        efficiency = 0.95;  % 軽負荷時は高効率
    elseif load_percent < 50
        efficiency = 0.88;  % 中負荷
    elseif load_percent < 75
        efficiency = 0.82;  % 高負荷でミス率増加
    else
        efficiency = 0.78;  % 最大負荷時
    end
end

function factor = get_memory_bandwidth_factor(freq)
% 周波数に応じたメモリ帯域制約
    freq_ghz = freq / 1e9;
    if freq_ghz < 2.0
        factor = 1.0;  % 低周波数では制約なし
    elseif freq_ghz < 2.8
        factor = 0.95;  % 中程度の制約
    else
        factor = 0.88;  % 高周波数でメモリボトルネック
    end
end

function [freq_points, power_points] = get_dvfs_curve()
% DVFSカーブデータ（グラフ化用）
    load_points = 0:5:100;
    n_points = length(load_points);
    
    freq_points = zeros(n_points, 1);
    power_points = zeros(n_points, 1);
    
    for i = 1:n_points
        [f, p, ~] = a15_dvfs_model(load_points(i));
        freq_points(i) = f / 1e9;  % GHz単位
        power_points(i) = p;
    end
end

function validate_model()
% モデルの検証と誤差分析
    fprintf('\n=== A15 DVFSモデル検証 ===\n');
    fprintf('負荷%%\t周波数[GHz]\t電力[W]\t文献値[W]\t誤差%%\n');
    fprintf('--------------------------------------------------------\n');
    
    test_loads = [0, 25, 50, 75, 100];
    expected_freqs = [1.0, 1.8, 2.4, 2.8, 3.2];  % 実測値
    literature_powers = [0.4, 1.3, 2.5, 3.4, 4.3];  % 文献調査結果
    
    for i = 1:length(test_loads)
        [f, p, ipc] = a15_dvfs_model(test_loads(i));
        freq_ghz = f / 1e9;
        freq_error = abs(freq_ghz - expected_freqs(i)) / expected_freqs(i) * 100;
        power_error = abs(p - literature_powers(i)) / literature_powers(i) * 100;
        
        fprintf('%d%%\t%.1f\t\t%.2f\t%.2f\t\t%.1f%%', ...
                test_loads(i), freq_ghz, p, literature_powers(i), power_error);
        
        if freq_error < 1 && power_error < 10
            fprintf(' ✓\n');
        else
            fprintf(' △\n');
        end
    end
    
    % 電力モデルの文献値との比較
    fprintf('\n電力モデル詳細（AnandTech 2021 + Apple公式）:\n');
    fprintf('- 0%% (1.0GHz): 0.4W (E-core アイドル)\n');
    fprintf('- 25%% (1.8GHz): 1.3W (E-core/P-core混合)\n');
    fprintf('- 50%% (2.4GHz): 2.5W (P-core中負荷)\n');
    fprintf('- 75%% (2.8GHz): 3.4W (P-core高負荷)\n');
    fprintf('- 100%% (3.2GHz): 4.3W (P-core最大ブースト)\n');
    fprintf('- モデル式: P = 0.422×f²-0.022 (f in GHz)\n');
end