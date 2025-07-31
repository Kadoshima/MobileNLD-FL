#!/usr/bin/env python3
"""
Final SIMD utilization analysis from Instruments data
Based on actual PMC counter values from the traces
"""

import re
import sys

def analyze_simd_utilization():
    """
    Analyze SIMD utilization from Instruments traces
    
    Traces:
    1. all_counters_fixed.xml - INST_ALL (total instructions)
    2. alu_counters_fixed.xml - INST_SIMD_ALU, INST_SIMD_ST, INST_SIMD_LD
    """
    
    print("=== Instruments実測SIMD利用率分析 ===")
    print("iPhone 13 (A15 Bionic) PMCカウンタによる実測\n")
    
    # 1. ALL instructions (総命令数) の分析
    print("1. 総命令数の分析 (all_counters_fixed.xml)")
    
    all_instructions = []
    with open('all_counters_fixed.xml', 'r', encoding='utf-8', errors='ignore') as f:
        content = f.read()
    
    # Extract pmc-events values
    pmc_pattern = re.compile(r'<pmc-events[^>]*>(\d+)</pmc-events>')
    matches = pmc_pattern.findall(content)
    
    for match in matches:
        value = int(match)
        if value > 0:  # 0を除外（アイドル状態）
            all_instructions.append(value)
    
    total_all_inst = sum(all_instructions)
    avg_all_inst = total_all_inst / len(all_instructions) if all_instructions else 0
    
    print(f"  有効サンプル数: {len(all_instructions):,}")
    print(f"  総命令数: {total_all_inst:,}")
    print(f"  平均命令数/サンプル: {avg_all_inst:,.0f}")
    
    # 2. SIMD instructions の分析
    print(f"\n2. SIMD命令の分析 (alu_counters_fixed.xml)")
    
    simd_data = []
    total_simd_alu = 0
    total_simd_st = 0
    total_simd_ld = 0
    
    with open('alu_counters_fixed.xml', 'r', encoding='utf-8', errors='ignore') as f:
        content = f.read()
    
    # パターン: <pmc-events id="19" fmt="(100,458), (608), (21,203)">100458 608 21203</pmc-events>
    # 3つの値: INST_SIMD_ALU, INST_SIMD_ST, INST_SIMD_LD
    pmc_pattern = re.compile(r'<pmc-events[^>]*>([^<]+)</pmc-events>')
    matches = pmc_pattern.findall(content)
    
    for match in matches:
        # スペース区切りの値を解析
        values = match.strip().split()
        if len(values) >= 3:
            try:
                alu = int(values[0])
                st = int(values[1])
                ld = int(values[2])
                
                if alu > 0 or st > 0 or ld > 0:  # 少なくとも1つのSIMD命令がある
                    simd_data.append({
                        'alu': alu,
                        'st': st,
                        'ld': ld,
                        'total': alu + st + ld
                    })
                    total_simd_alu += alu
                    total_simd_st += st
                    total_simd_ld += ld
            except:
                pass
    
    total_simd = total_simd_alu + total_simd_st + total_simd_ld
    
    print(f"  有効サンプル数: {len(simd_data):,}")
    print(f"  SIMD ALU命令: {total_simd_alu:,}")
    print(f"  SIMD Store命令: {total_simd_st:,}")
    print(f"  SIMD Load命令: {total_simd_ld:,}")
    print(f"  総SIMD命令: {total_simd:,}")
    
    if total_simd > 0:
        print(f"\n  SIMD命令の内訳:")
        print(f"    ALU: {total_simd_alu/total_simd*100:.1f}%")
        print(f"    Store: {total_simd_st/total_simd*100:.1f}%") 
        print(f"    Load: {total_simd_ld/total_simd*100:.1f}%")
    
    # 3. SIMD利用率の計算
    print("\n=== 実測SIMD利用率 ===")
    
    # 注意: 2つのトレースは異なる実行タイミングのため、平均値で推定
    if all_instructions and simd_data:
        # サンプルごとの平均で計算
        avg_simd_per_sample = total_simd / len(simd_data)
        
        # SIMD利用率 = SIMD命令数 / 総命令数
        simd_utilization = (avg_simd_per_sample / avg_all_inst) * 100
        
        print(f"平均SIMD命令/サンプル: {avg_simd_per_sample:,.0f}")
        print(f"平均総命令/サンプル: {avg_all_inst:,.0f}")
        print(f"\n実測SIMD利用率: {simd_utilization:.2f}%")
        
        # アクティブなサンプルのみで再計算（より正確）
        active_simd = [s for s in simd_data if s['total'] > 100]
        if active_simd:
            active_total = sum(s['total'] for s in active_simd)
            active_avg = active_total / len(active_simd)
            active_utilization = (active_avg / avg_all_inst) * 100
            
            print(f"\nアクティブサンプルのみ:")
            print(f"  サンプル数: {len(active_simd)}/{len(simd_data)}")
            print(f"  平均SIMD命令: {active_avg:,.0f}")
            print(f"  SIMD利用率: {active_utilization:.2f}%")
    
    # 4. 詳細統計
    print("\n=== 詳細統計 ===")
    
    if simd_data:
        # SIMD命令の分布
        simd_totals = [s['total'] for s in simd_data]
        simd_totals.sort(reverse=True)
        
        percentiles = [10, 25, 50, 75, 90, 95, 99]
        print("SIMD命令数の分位数:")
        for p in percentiles:
            idx = int(len(simd_totals) * p / 100)
            if idx < len(simd_totals):
                print(f"  {p}%ile: {simd_totals[idx]:,}")
        
        # 高SIMD活動のサンプル
        high_simd = [s for s in simd_totals if s > 10000]
        print(f"\n高SIMD活動サンプル (>10,000命令): {len(high_simd)} ({len(high_simd)/len(simd_totals)*100:.1f}%)")
        
        very_high_simd = [s for s in simd_totals if s > 100000]
        print(f"超高SIMD活動サンプル (>100,000命令): {len(very_high_simd)} ({len(very_high_simd)/len(simd_totals)*100:.1f}%)")

if __name__ == "__main__":
    try:
        analyze_simd_utilization()
    except Exception as e:
        print(f"エラー: {e}")
        import traceback
        traceback.print_exc()