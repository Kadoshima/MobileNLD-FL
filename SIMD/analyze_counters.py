import xml.etree.ElementTree as ET
import sys
import numpy as np

if len(sys.argv) < 2:
    print("使い方: python3 analyze_counters_v3.py <xml_file> [start_time] [end_time] [schema]")
    sys.exit(1)

xml_file = sys.argv[1]
start_time = int(sys.argv[2]) if len(sys.argv) > 2 else 0
end_time = int(sys.argv[3]) if len(sys.argv) > 3 else float('inf')
schema = sys.argv[4] if len(sys.argv) > 4 else "counters-profile"

values_list = []

try:
    tree = ET.parse(xml_file)
    root = tree.getroot()

    # ネスト深くテーブル/スキーマを探す（<node>対応）
    schema_nodes = root.findall(f".//*[schema/@name='{schema}']") + root.findall(f".//schema[@name='{schema}']")
    if not schema_nodes:
        print(f"エラー: 指定スキーマ '{schema}' が見つかりませんでした。XMLをgrepで確認してください。")
        sys.exit(1)

    for node in schema_nodes:
        # <node>内の<row>を探す
        rows = node.findall('.//row')  # ネスト対応
        for row in rows:
            time_elem = row.find('sample-time') or row.find('time')  # タイムタグ調整
            pmc_elem = row.find('pmc-events') or row.find('counters-array')  # 値タグ調整

            time_ns = int(time_elem.text) if time_elem is not None and time_elem.text else 0

            if start_time <= time_ns <= end_time and pmc_elem is not None and pmc_elem.text:
                values = [int(v) for v in pmc_elem.text.split() if v.strip().isdigit()]
                if values:
                    values_list.append(values)

    if values_list:
        values_array = np.array(values_list, dtype=float)
        counters_sums = np.sum(values_array, axis=0)
        counters_means = np.mean(values_array, axis=0)
        counters_stds = np.std(values_array, axis=0)

        print(f"ファイル名: {xml_file}")
        print(f"スキーマ: {schema}")
        print(f"有効行数 (区間内): {len(values_list)}")
        print(f"カウンタ合計: {list(counters_sums)}")
        print(f"平均値: {list(counters_means)} ± {list(counters_stds)}")

        # SIMD利用率計算例（調整可能）
        if len(counters_sums) >= 4 and counters_sums[0] > 0:
            simd_total = sum(counters_sums[i] for i in [1, 2, 3])
            utilization = (simd_total / counters_sums[0]) * 100
            print(f"SIMD利用率: {utilization:.2f}% (仮定: 列0=ALL, 列1-3=SIMD)")
    else:
        print("有効なデータが見つかりませんでした。区間やタグを確認してください。")

except Exception as e:
    print(f"エラーが発生しました: {e}")
