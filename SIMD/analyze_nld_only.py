#!/usr/bin/env python3
"""
NLD関数のみのSIMD利用率を分析
"""

import re

def analyze_nld_simd():
    """NLD関数実行時のSIMD命令のみを分析"""
    
    print("=== NLD関数のSIMD利用率分析 ===\n")
    
    # NLD関連の関数パターン
    nld_patterns = [
        'lyapunovExponent',
        'dfaAlpha', 
        'SIMDOptimizations',
        'OptimizedNonlinearDynamics',
        'euclideanDistance',
        'linearRegression',
        'findNearestNeighbor',
        'calculateFluctuation',
        'vDSP_'  # Accelerate functions used in NLD
    ]
    
    nld_samples = []
    total_samples = 0
    
    with open('alu_counters_fixed.xml', 'r', encoding='utf-8', errors='ignore') as f:
        content = f.read()
    
    # rowごとに解析
    rows = content.split('<row>')
    
    for row in rows[1:]:  # 最初の空要素をスキップ
        total_samples += 1
        
        # NLD関数を含むかチェック
        is_nld = False
        for pattern in nld_patterns:
            if pattern in row:
                is_nld = True
                break
        
        if is_nld:
            # PMC値を抽出
            pmc_match = re.search(r'<pmc-events[^>]*>([^<]+)</pmc-events>', row)
            if pmc_match:
                values = pmc_match.group(1).strip().split()
                if len(values) >= 3:
                    try:
                        alu = int(values[0])
                        st = int(values[1])
                        ld = int(values[2])
                        total = alu + st + ld
                        
                        # 関数名を抽出
                        func_match = re.search(r'name="([^"]+)"', row)
                        func_name = func_match.group(1) if func_match else "Unknown"
                        
                        nld_samples.append({
                            'func': func_name,
                            'alu': alu,
                            'st': st,
                            'ld': ld,
                            'total': total
                        })
                    except:
                        pass
    
    print(f"総サンプル数: {total_samples:,}")
    print(f"NLD関数サンプル数: {len(nld_samples)} ({len(nld_samples)/total_samples*100:.1f}%)\n")
    
    if nld_samples:
        # NLD関数のSIMD命令統計
        total_nld_simd = sum(s['total'] for s in nld_samples)
        total_nld_alu = sum(s['alu'] for s in nld_samples)
        total_nld_st = sum(s['st'] for s in nld_samples)
        total_nld_ld = sum(s['ld'] for s in nld_samples)
        
        print("NLD関数のSIMD命令:")
        print(f"  ALU: {total_nld_alu:,}")
        print(f"  Store: {total_nld_st:,}")
        print(f"  Load: {total_nld_ld:,}")
        print(f"  合計: {total_nld_simd:,}")
        
        # 平均
        avg_per_sample = total_nld_simd / len(nld_samples)
        print(f"\n平均SIMD命令/NLDサンプル: {avg_per_sample:,.0f}")
        
        # 高SIMD活動のサンプル
        high_simd = [s for s in nld_samples if s['total'] > 100000]
        print(f"高SIMD活動 (>100k): {len(high_simd)} samples")
        
        # 関数別統計
        print("\n関数別SIMD命令数 (上位):")
        func_stats = {}
        for sample in nld_samples:
            func = sample['func']
            if func not in func_stats:
                func_stats[func] = {'count': 0, 'total': 0}
            func_stats[func]['count'] += 1
            func_stats[func]['total'] += sample['total']
        
        sorted_funcs = sorted(func_stats.items(), key=lambda x: x[1]['total'], reverse=True)[:10]
        for func, stats in sorted_funcs:
            avg = stats['total'] / stats['count']
            print(f"  {func[:50]}: {stats['total']:,} ({stats['count']}回, 平均{avg:,.0f})")

if __name__ == "__main__":
    analyze_nld_simd()