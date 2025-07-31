import xml.etree.ElementTree as ET
import sys
import numpy as np

if len(sys.argv) < 2:
    print("使い方: python3 analyze_counters_v4.py <xml_file> [start_time] [end_time] [all_index] [simd_indices]")
    print("  - start_time, end_time: Signpost区間 (ナノ秒, 任意)")
    print("  - all_index: ALLカウンタ列 (デフォルト: 0)")
    print("  - simd_indices: SIMDカウンタ列 (スペース区切り, デフォルト: 1 2 3)")
    sys.exit(1)

xml_file = sys.argv[1]
start_time = int(sys.argv[2]) if len(sys.argv) > 2 else 0
end_time = int(sys.argv[3]) if len(sys.argv) > 3 else float('inf')
all_index = int(sys.argv[4]) if len(sys.argv) > 4 else 0
simd_indices_str = sys.argv[5] if len(sys.argv) > 5 else "1 2 3"
simd_indices = [int(i) for i in simd_indices_str.split()]

values_list = []

try:
    tree = ET.parse(xml_file)
    root = tree.getroot()

    # 全要素をiterで走査し、schema name="counters-profile"を探す
    schema_found = False
    for elem in root.iter():
        if elem.tag == 'schema' and elem.get('name') == 'counters-profile':
            schema_found = True
            # 親ノードからrowを探す (ネスト対応)
            parent = elem
            while parent is not None:
                rows = parent.findall('row')
                if rows:
                    break
                parent = parent.getparent() if hasattr(parent, 'getparent') else None  # 安全に親取得

            if rows:
                for row in rows:
                    time_elem = row.find('sample-time') or row.find('time')
                    pmc_elem = row.find('pmc-events') or row.find('counters-array')

                    time_ns = int(time_elem.text) if time_elem is not None and time_elem.text else 0

                    if start_time <= time_ns <= end_time and pmc_elem is not None and pmc_elem.text:
                        values = [int(v) for v in pmc_elem.text.split() if v.strip().isdigit()]
                        if values and len(values) >= max([all_index] + simd_indices) + 1:
                            values_list.append(values)

    if not schema_found:
        print("エラー: 'counters-profile' スキーマが見つかりませんでした。grepでXMLを確認してください。")
        sys.exit(1)

    if values_list:
        values_array = np.array(values_list, dtype=float)
        counters_sums = np.sum(values_array, axis=0)
        counters_means = np.mean(values_array, axis=0)
        counters_stds = np.std(values_array, axis=0)

        print(f"ファイル名: {xml_file}")
        print(f"有効行数 (区間内): {len(values_list)}")
        print(f"カウンタ合計: {list(counters_sums)}")
        print(f"平均値: {list(counters_means)} ± {list(counters_stds)}")

        # SIMD利用率計算
        if len(counters_sums) > all_index and counters_sums[all_index] > 0:
            simd_total = sum(counters_sums[i] for i in simd_indices if i < len(counters_sums))
            utilization = (simd_total / counters_sums[all_index]) * 100
            print(f"SIMD利用率: {utilization:.2f}% (ALL列: {all_index}, SIMD列: {simd_indices})")
    else:
        print("有効なデータが見つかりませんでした。Signpost区間やXML構造を確認してください。")

except Exception as e:
    print(f"エラーが発生しました: {e}")
