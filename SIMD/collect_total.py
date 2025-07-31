import xml.etree.ElementTree as ET
import sys
import numpy as np

# 使い方: python3 analyze_counters.py <xml_file> [start_time] [end_time] [schema] [all_index] [simd_indices]
# 例: python3 analyze_counters.py all_counters.xml 1234567890000 1234567900000 counters-profile 0 "1 2 3"
if len(sys.argv) < 2:
    print("使い方: python3 analyze_counters.py <xml_file> [start_time] [end_time] [schema] [all_index] [simd_indices]")
    print("  - start_time, end_time: Signpost区間（ナノ秒、任意）")
    print("  - schema: テーブルスキーマ（デフォルト: counters-profile）")
    print("  - all_index: ALLカウンタの列インデックス（デフォルト: 0）")
    print("  - simd_indices: SIMDカウンタの列インデックス（スペース区切り、デフォルト: 1 2 3）")
    sys.exit(1)

xml_file = sys.argv[1]
start_time = int(sys.argv[2]) if len(sys.argv) > 2 else 0
end_time = int(sys.argv[3]) if len(sys.argv) > 3 else float('inf')
schema = sys.argv[4] if len(sys.argv) > 4 else "counters-profile"
all_index = int(sys.argv[5]) if len(sys.argv) > 5 else 0
simd_indices_str = sys.argv[6] if len(sys.argv) > 6 else "1 2 3"
simd_indices = [int(i) for i in simd_indices_str.split()]

values_list = []  # rowごとの値を蓄積

try:
    tree = ET.parse(xml_file)
    root = tree.getroot()

    # 指定スキーマのテーブルを探す
    table_found = False
    for table in root.findall(f".//table[@schema='{schema}']"):
        table_found = True
        for row in table.findall('row'):
            time_elem = row.find('time')
            pmc_elem = row.find('pmc-events')

            if time_elem is not None and pmc_elem is not None and pmc_elem.text:
                time_ns = int(time_elem.text)

                # Signpost区間内のみ処理（ノイズ除去）
                if start_time <= time_ns <= end_time:
                    values = [int(v) for v in pmc_elem.text.split() if v.strip().isdigit()]
                    if values and len(values) >= max([all_index] + simd_indices) + 1:  # インデックス範囲チェック
                        values_list.append(values)

    if not table_found:
        print(f"エラー: 指定スキーマ '{schema}' のテーブルが見つかりませんでした。TOCを確認してください。")
        sys.exit(1)

    if values_list:
        values_array = np.array(values_list)
        counters_sums = np.sum(values_array, axis=0)
        counters_means = np.mean(values_array, axis=0)
        counters_stds = np.std(values_array, axis=0)

        print(f"ファイル名: {xml_file}")
        print(f"スキーマ: {schema}")
        print(f"有効行数 (区間内): {len(values_list)}")
        print(f"カウンタ合計: {list(counters_sums)}")
        print(f"平均値: {list(counters_means)} ± {list(counters_stds)}")

        # SIMD利用率計算
        if counters_sums[all_index] > 0:
            simd_total = sum(counters_sums[i] for i in simd_indices)
            utilization = (simd_total / counters_sums[all_index]) * 100
            print(f"SIMD利用率: {utilization:.2f}% (ALL列: {all_index}, SIMD列: {simd_indices})")
        else:
            print("警告: ALLカウンタが0です。利用率計算不可。")
    else:
        print("有効なデータが見つかりませんでした。区間やスキーマを確認してください。")

except Exception as e:
    print(f"エラーが発生しました: {e}")