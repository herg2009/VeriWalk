"""
JPlag风格 Verilog代码相似度检测 —— EXTRTL数据集综合分析工具
================================================================
整合5大功能模块，一次运行完成全部分析：
  01_similarity_analysis   : Token相似度分析（TjIn + TjIn2）
  02_signal_detection      : 信号级改动检测
  03_groundtruth_eval      : Ground Truth评估（Precision/Recall/F1）
  04_visualization          : 可视化图表 + 文本报告

数据集: EXTRTL (TjFree:45基准 + TjIn:45变体 + TjIn2:90变体)
"""

import os
import re
import sys
import json
import time
import pandas as pd
import numpy as np
import matplotlib
import matplotlib.pyplot as plt
from pathlib import Path
from typing import Dict, List, Tuple, Set
from collections import Counter, defaultdict

# 中文字体
matplotlib.rcParams['font.sans-serif'] = ['SimHei', 'Microsoft YaHei']
matplotlib.rcParams['axes.unicode_minus'] = False

# 修复Windows终端GBK编码
if sys.stdout.encoding and sys.stdout.encoding.lower() != 'utf-8':
    try:
        import io
        sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8', errors='replace')
    except Exception:
        pass

# ============================================================
# 路径配置
# ============================================================
EXTRTL_DIR = r"e:\PRO\python\dataset\OK\EXTRTL"
GROUNDTRUTH_CSV = r"e:\PRO\python\HT\hw4vec\examples\EXTRTL_dataset.csv"
OUTPUT_BASE = r"e:\PRO\python\HT\hw4vec\outputs\10_JPlag"

DIR_01 = os.path.join(OUTPUT_BASE, "01_similarity_analysis")
DIR_02 = os.path.join(OUTPUT_BASE, "02_signal_detection")
DIR_03 = os.path.join(OUTPUT_BASE, "03_groundtruth_eval")
DIR_04 = os.path.join(OUTPUT_BASE, "04_visualization")


# ============================================================
# 模块1: Token提取与相似度计算
# ============================================================
class VerilogTokenExtractor:
    """Verilog代码Token提取器（模拟JPlag的Verilog模块）"""
    TOKEN_PATTERNS = {
        'MODULE_DECL': re.compile(r'\bmodule\s+(\w+)', re.IGNORECASE),
        'ENDMODULE': re.compile(r'\bendmodule\b', re.IGNORECASE),
        'PORT_INPUT': re.compile(r'\binput\b', re.IGNORECASE),
        'PORT_OUTPUT': re.compile(r'\boutput\b', re.IGNORECASE),
        'PORT_INOUT': re.compile(r'\binout\b', re.IGNORECASE),
        'DECL_WIRE': re.compile(r'\bwire\b', re.IGNORECASE),
        'DECL_REG': re.compile(r'\breg\b', re.IGNORECASE),
        'DECL_PARAM': re.compile(r'\bparameter\b', re.IGNORECASE),
        'DECL_INTEGER': re.compile(r'\binteger\b', re.IGNORECASE),
        'ASSIGN_CONT': re.compile(r'\bassign\b', re.IGNORECASE),
        'BLOCK_ALWAYS': re.compile(r'\balways\b', re.IGNORECASE),
        'BLOCK_INITIAL': re.compile(r'\binitial\b', re.IGNORECASE),
        'BLOCK_BEGIN': re.compile(r'\bbegin\b', re.IGNORECASE),
        'BLOCK_END': re.compile(r'\bend\b', re.IGNORECASE),
        'COND_IF': re.compile(r'\bif\b', re.IGNORECASE),
        'COND_ELSE': re.compile(r'\belse\b', re.IGNORECASE),
        'COND_CASE': re.compile(r'\bcase\b', re.IGNORECASE),
        'ENDCASE': re.compile(r'\bendcase\b', re.IGNORECASE),
        'COND_DEFAULT': re.compile(r'\bdefault\b', re.IGNORECASE),
        'LOOP_FOR': re.compile(r'\bfor\b', re.IGNORECASE),
        'LOOP_WHILE': re.compile(r'\bwhile\b', re.IGNORECASE),
        'INST_MODULE': re.compile(r'^\s*(\w+)\s+#?\s*\(', re.MULTILINE),
    }

    def extract_tokens(self, file_path: str) -> List[str]:
        tokens = []
        try:
            with open(file_path, 'r', encoding='utf-8', errors='ignore') as f:
                for line in f:
                    stripped = line.strip()
                    if not stripped or stripped.startswith('//') or stripped.startswith('/*'):
                        continue
                    for token_type, pattern in self.TOKEN_PATTERNS.items():
                        if pattern.search(line):
                            tokens.append(token_type)
        except Exception as e:
            print("  [WARN] 读取文件失败 {0}: {1}".format(file_path, e))
        return tokens

    def get_token_stats(self, tokens: List[str]) -> Dict:
        counter = Counter(tokens)
        return {'total_tokens': len(tokens), 'unique_tokens': len(counter),
                'token_distribution': dict(counter)}


class JPlagSimilarityCalculator:
    """JPlag相似度计算器（Greedy String Tiling简化版）"""

    def __init__(self, min_token_match: int = 6):
        self.min_token_match = min_token_match

    def calculate_similarity(self, tokens1: List[str], tokens2: List[str]) -> float:
        if not tokens1 or not tokens2:
            return 0.0
        matched = self._greedy_matching(tokens1, tokens2)
        max_len = max(len(tokens1), len(tokens2))
        return min(matched / max_len, 1.0) if max_len > 0 else 0.0

    def _greedy_matching(self, seq1, seq2) -> int:
        matched = 0
        marked1, marked2 = set(), set()
        while True:
            best = self._find_longest_match(seq1, seq2, marked1, marked2)
            if best is None or best[0] < self.min_token_match:
                break
            length, s1, s2 = best
            matched += length
            for i in range(length):
                marked1.add(s1 + i)
                marked2.add(s2 + i)
        return matched

    def _find_longest_match(self, seq1, seq2, marked1, marked2):
        best_len, best_s1, best_s2 = 0, -1, -1
        for i in range(len(seq1)):
            if i in marked1:
                continue
            for j in range(len(seq2)):
                if j in marked2:
                    continue
                if seq1[i] == seq2[j]:
                    length = 0
                    while (i + length < len(seq1) and j + length < len(seq2)
                           and seq1[i + length] == seq2[j + length]
                           and (i + length) not in marked1
                           and (j + length) not in marked2):
                        length += 1
                    if length > best_len:
                        best_len, best_s1, best_s2 = length, i, j
        return (best_len, best_s1, best_s2) if best_len >= self.min_token_match else None


# ============================================================
# 模块2: 信号级检测
# ============================================================
class SignalLevelDetector:
    """信号级改动检测器"""
    SIGNAL_PATTERNS = {
        'input': re.compile(r'\binput\s+(?:wire|reg)?\s*(?:\[.*?\])?\s*(\w+)', re.IGNORECASE),
        'output': re.compile(r'\boutput\s+(?:wire|reg)?\s*(?:\[.*?\])?\s*(\w+)', re.IGNORECASE),
        'wire': re.compile(r'\bwire\s+(?:\[.*?\])?\s*(\w+)', re.IGNORECASE),
        'reg': re.compile(r'\breg\s+(?:\[.*?\])?\s*(\w+)', re.IGNORECASE),
        'parameter': re.compile(r'\bparameter\s+(?:\[.*?\])?\s*(\w+)', re.IGNORECASE),
    }

    def extract_signals(self, file_path: str) -> Dict[str, Set[str]]:
        signals = {k: set() for k in self.SIGNAL_PATTERNS}
        try:
            with open(file_path, 'r', encoding='utf-8', errors='ignore') as f:
                content = f.read()
            for sig_type, pattern in self.SIGNAL_PATTERNS.items():
                signals[sig_type].update(pattern.findall(content))
        except Exception as e:
            print("  [WARN] 提取信号失败 {0}: {1}".format(file_path, e))
        return signals

    def detect_changes(self, free_path: str, in_path: str) -> Dict:
        sig_free = self.extract_signals(free_path)
        sig_in = self.extract_signals(in_path)
        changes = {'added': {}, 'removed': {}, 'unchanged': {}}
        for sig_type in sig_free:
            added = sig_in[sig_type] - sig_free[sig_type]
            removed = sig_free[sig_type] - sig_in[sig_type]
            unchanged = sig_free[sig_type] & sig_in[sig_type]
            if added:
                changes['added'][sig_type] = added
            if removed:
                changes['removed'][sig_type] = removed
            if unchanged:
                changes['unchanged'][sig_type] = unchanged
        return changes

    def get_all_signals(self, file_path: str) -> Set[str]:
        signals = self.extract_signals(file_path)
        all_sigs = set()
        for s in signals.values():
            all_sigs.update(s)
        return all_sigs

    def get_changed_list(self, changes: Dict) -> Set[str]:
        changed = set()
        for cat in ['added', 'removed']:
            if cat in changes:
                for sigs in changes[cat].values():
                    changed.update(sigs)
        return changed


# ============================================================
# 模块3: Ground Truth加载与评估
# ============================================================
class GroundTruthLoader:
    @staticmethod
    def load(csv_path: str) -> Dict[str, Set[str]]:
        gt = {}
        try:
            for enc in ['utf-8', 'gbk', 'latin-1']:
                try:
                    df = pd.read_csv(csv_path, encoding=enc)
                    break
                except UnicodeDecodeError:
                    continue
            else:
                return gt
            for _, row in df.iterrows():
                idx_str = str(row.get('idx', '')).strip()
                if idx_str.startswith('#') or idx_str == 'idx':
                    continue
                try:
                    cn = str(row['circuit_name']).strip()
                    sn = str(row['signal_name']).strip()
                    gt.setdefault(cn, set()).add(sn)
                except (KeyError, AttributeError):
                    continue
            print("  [OK] 加载Ground Truth: {} 个电路, "
                  "{} 个信号".format(len(gt), sum(len(v) for v in gt.values())))
        except Exception as e:
            print("  [FAIL] 加载失败: {0}".format(e))
        return gt


# ============================================================
# 模块4: EXTRTL分析器（核心调度）
# ============================================================
class EXTRTLJPlagAnalyzer:
    """EXTRTL数据集JPlag综合分析器"""

    def __init__(self, dataset_dir: str, gt_csv: str, output_base: str):
        self.dataset_dir = Path(dataset_dir)
        self.tjfree = self.dataset_dir / "TjFree"
        self.tjin = self.dataset_dir / "TjIn"
        self.tjin2 = self.dataset_dir / "TjIn2"
        self.output_base = Path(output_base)

        self.token_ext = VerilogTokenExtractor()
        self.sim_calc = JPlagSimilarityCalculator(min_token_match=6)
        self.sig_det = SignalLevelDetector()
        self.ground_truth = GroundTruthLoader.load(gt_csv)

        for d in [DIR_01, DIR_02, DIR_03, DIR_04]:
            os.makedirs(d, exist_ok=True)

    # ---- 辅助: 查找电路对 ----
    def _find_pairs(self, variant_dir: Path) -> List[Tuple[str, str, str]]:
        pairs = []
        if not variant_dir.exists():
            return pairs
        for vc in sorted(variant_dir.iterdir()):
            if not vc.is_dir():
                continue
            cname = vc.name
            top_v = vc / "topModule.v"
            if not top_v.exists():
                continue
            base_name = cname.split('-')[0]
            top_f = self.tjfree / base_name / "topModule.v"
            if top_f.exists():
                pairs.append((cname, str(top_f), str(top_v)))
        return pairs

    # ============================================================
    # 任务1: 相似度分析
    # ============================================================
    def run_similarity_analysis(self):
        print("\n" + "=" * 70)
        print("任务1: Token相似度分析 (01_similarity_analysis)")
        print("=" * 70)

        all_results = []
        for label, vdir in [("TjIn", self.tjin), ("TjIn2", self.tjin2)]:
            pairs = self._find_pairs(vdir)
            print(f"\n  [{label}] 找到 {len(pairs)} 对匹配电路")
            for cname, fp, ip in pairs:
                tokens_f = self.token_ext.extract_tokens(fp)
                tokens_i = self.token_ext.extract_tokens(ip)
                sim = self.sim_calc.calculate_similarity(tokens_f, tokens_i)
                stats_f = self.token_ext.get_token_stats(tokens_f)
                stats_i = self.token_ext.get_token_stats(tokens_i)
                size_f = os.path.getsize(fp)
                size_i = os.path.getsize(ip)
                all_results.append({
                    'source': label,
                    'circuit_name': cname,
                    'similarity': round(sim, 4),
                    'free_total_tokens': stats_f['total_tokens'],
                    'in_total_tokens': stats_i['total_tokens'],
                    'size_free': size_f,
                    'size_in': size_i,
                    'size_change_percent': round((size_i - size_f) / size_f * 100, 2) if size_f > 0 else 0,
                })

        df = pd.DataFrame(all_results)

        # 保存CSV
        csv_path = os.path.join(DIR_01, "similarity_results.csv")
        df.to_csv(csv_path, index=False, encoding='utf-8-sig')
        print(f"  [OK] CSV: {csv_path}")

        # 保存JSON
        json_path = os.path.join(DIR_01, "detailed_results.json")
        df.to_json(json_path, orient='records', indent=2, force_ascii=False)
        print(f"  [OK] JSON: {json_path}")

        # 生成文本报告
        self._gen_similarity_report(df)
        return df

    def _gen_similarity_report(self, df: pd.DataFrame):
        rpt = os.path.join(DIR_01, "analysis_report.txt")
        with open(rpt, 'w', encoding='utf-8') as f:
            f.write("=" * 70 + "\n")
            f.write("JPlag Verilog代码相似度分析报告 —— EXTRTL数据集\n")
            f.write("=" * 70 + "\n\n")

            for source in ["TjIn", "TjIn2"]:
                sub = df[df['source'] == source]
                if sub.empty:
                    continue
                f.write(f"\n{'─' * 70}\n")
                f.write(f"▶ 数据来源: {source} ({len(sub)} 对电路)\n")
                f.write(f"{'─' * 70}\n")
                f.write(f"  平均相似度: {sub['similarity'].mean():.4f}\n")
                f.write(f"  中位数相似度: {sub['similarity'].median():.4f}\n")
                f.write(f"  最高/最低: {sub['similarity'].max():.4f} / {sub['similarity'].min():.4f}\n")
                f.write(f"  标准差: {sub['similarity'].std():.4f}\n\n")

                high = len(sub[sub['similarity'] >= 0.9])
                mid = len(sub[(sub['similarity'] >= 0.7) & (sub['similarity'] < 0.9)])
                low = len(sub[sub['similarity'] < 0.7])
                f.write(f"  高相似度 (>=0.9): {high} ({high/len(sub)*100:.1f}%)\n")
                f.write(f"  中相似度 (0.7-0.9): {mid} ({mid/len(sub)*100:.1f}%)\n")
                f.write(f"  低相似度 (<0.7): {low} ({low/len(sub)*100:.1f}%)\n\n")

                # 按电路基础名分组统计
                f.write("  按基础电路分组:\n")
                sub_copy = sub.copy()
                sub_copy['base'] = sub_copy['circuit_name'].apply(lambda x: x.split('-')[0])
                for base, grp in sub_copy.groupby('base'):
                    f.write(f"    {base:30s}  n={len(grp):2d}  "
                            f"avg={grp['similarity'].mean():.4f}  "
                            f"sz_chg={grp['size_change_percent'].mean():+.2f}%\n")

                f.write(f"\n  改动最大Top5:\n")
                for _, r in sub.nsmallest(5, 'similarity').iterrows():
                    f.write(f"    {r['circuit_name']:30s} sim={r['similarity']:.4f}  "
                            f"Δsize={r['size_change_percent']:+.2f}%\n")
                f.write(f"\n  改动最小Top5:\n")
                for _, r in sub.nlargest(5, 'similarity').iterrows():
                    f.write(f"    {r['circuit_name']:30s} sim={r['similarity']:.4f}  "
                            f"Δsize={r['size_change_percent']:+.2f}%\n")

            # 全局汇总
            f.write(f"\n{'─' * 70}\n")
            f.write(f"▶ 全局汇总 ({len(df)} 对电路)\n")
            f.write(f"{'─' * 70}\n")
            f.write(f"  平均相似度: {df['similarity'].mean():.4f}\n")
            f.write(f"  中位数: {df['similarity'].median():.4f}\n")
            f.write(f"  标准差: {df['similarity'].std():.4f}\n")
            f.write("=" * 70 + "\n")

        print(f"  [OK] 报告: {rpt}")

    # ============================================================
    # 任务2: 信号级改动检测
    # ============================================================
    def run_signal_detection(self):
        print("\n" + "=" * 70)
        print("任务2: 信号级改动检测 (02_signal_detection)")
        print("=" * 70)

        all_results = []
        for label, vdir in [("TjIn", self.tjin), ("TjIn2", self.tjin2)]:
            pairs = self._find_pairs(vdir)
            print(f"\n  [{label}] {len(pairs)} 对电路")
            for cname, fp, ip in pairs:
                t0 = time.time()
                changes = self.sig_det.detect_changes(fp, ip)
                elapsed = time.time() - t0
                added_cnt = sum(len(v) for v in changes['added'].values())
                removed_cnt = sum(len(v) for v in changes['removed'].values())
                all_results.append({
                    'source': label,
                    'circuit_name': cname,
                    'detection_time_s': round(elapsed, 4),
                    'added_signals': added_cnt,
                    'removed_signals': removed_cnt,
                    'total_changes': added_cnt + removed_cnt,
                })

        df = pd.DataFrame(all_results)
        csv_path = os.path.join(DIR_02, "signal_detection_results.csv")
        df.to_csv(csv_path, index=False, encoding='utf-8-sig')
        print(f"\n  [OK] CSV: {csv_path}")

        # 摘要
        summary_path = os.path.join(DIR_02, "detection_summary.txt")
        with open(summary_path, 'w', encoding='utf-8') as f:
            f.write("JPlag 信号级改动检测摘要 —— EXTRTL数据集\n")
            f.write("=" * 70 + "\n\n")
            for src in ["TjIn", "TjIn2"]:
                sub = df[df['source'] == src]
                if sub.empty:
                    continue
                f.write(f"▶ {src} ({len(sub)} 个电路)\n")
                f.write(f"  平均检测时间: {sub['detection_time_s'].mean():.4f} s\n")
                f.write(f"  平均改动信号数: {sub['total_changes'].mean():.1f}\n")
                f.write(f"  最多/最少改动: {sub['total_changes'].max()} / {sub['total_changes'].min()}\n\n")
            f.write(f"▶ 全局 ({len(df)} 个电路)\n")
            f.write(f"  总检测时间: {df['detection_time_s'].sum():.4f} s\n")
            f.write(f"  平均检测时间: {df['detection_time_s'].mean():.4f} s\n")
        print(f"  [OK] 摘要: {summary_path}")
        return df

    # ============================================================
    # 任务3: Ground Truth评估
    # ============================================================
    def run_groundtruth_eval(self):
        print("\n" + "=" * 70)
        print("任务3: Ground Truth评估 (03_groundtruth_eval)")
        print("=" * 70)

        if not self.ground_truth:
            print("  [WARN] 无Ground Truth数据，跳过")
            return None

        all_results = []
        for label, vdir in [("TjIn", self.tjin), ("TjIn2", self.tjin2)]:
            pairs = self._find_pairs(vdir)
            print(f"\n  [{label}] {len(pairs)} 对电路")
            for cname, fp, ip in pairs:
                if cname not in self.ground_truth:
                    continue
                t0 = time.time()
                sigs_free = self.sig_det.get_all_signals(fp)
                sigs_in = self.sig_det.get_all_signals(ip)
                elapsed = time.time() - t0

                added = sigs_in - sigs_free
                removed = sigs_free - sigs_in
                all_sigs = sigs_free | sigs_in
                gt_sigs = self.ground_truth[cname]

                y_true, y_pred = [], []
                for sig in all_sigs:
                    is_gt = any(sig in gs or gs.endswith(f".{sig}") for gs in gt_sigs)
                    is_det = sig in added or sig in removed
                    y_true.append(1 if is_gt else 0)
                    y_pred.append(1 if is_det else 0)

                tp = sum(1 for t, p in zip(y_true, y_pred) if t == 1 and p == 1)
                fp = sum(1 for t, p in zip(y_true, y_pred) if t == 0 and p == 1)
                tn = sum(1 for t, p in zip(y_true, y_pred) if t == 0 and p == 0)
                fn = sum(1 for t, p in zip(y_true, y_pred) if t == 1 and p == 0)
                prec = tp / (tp + fp) if (tp + fp) > 0 else 0.0
                rec = tp / (tp + fn) if (tp + fn) > 0 else 0.0
                f1 = 2 * prec * rec / (prec + rec) if (prec + rec) > 0 else 0.0

                all_results.append({
                    'source': label, 'circuit_name': cname,
                    'detection_time_s': round(elapsed, 4),
                    'total_signals': len(all_sigs),
                    'added_signals': len(added), 'removed_signals': len(removed),
                    'gt_signals_count': len(gt_sigs),
                    'precision': prec, 'recall': rec, 'f1_score': f1,
                    'tp': tp, 'fp': fp, 'tn': tn, 'fn': fn,
                    'fpr': fp / (fp + tn) if (fp + tn) > 0 else 0,
                    'fnr': fn / (fn + tp) if (fn + tp) > 0 else 0,
                })

        df = pd.DataFrame(all_results)
        csv_path = os.path.join(DIR_03, "evaluation_results.csv")
        df.to_csv(csv_path, index=False, encoding='utf-8-sig')
        print(f"\n  [OK] CSV: {csv_path}")

        # 详细报告
        self._gen_gt_report(df)
        return df

    def _gen_gt_report(self, df: pd.DataFrame):
        rpt = os.path.join(DIR_03, "evaluation_report.txt")
        with open(rpt, 'w', encoding='utf-8') as f:
            f.write("JPlag信号级检测 - Ground Truth评估报告 —— EXTRTL数据集\n")
            f.write("=" * 70 + "\n\n")
            for src in ["TjIn", "TjIn2"]:
                sub = df[df['source'] == src]
                if sub.empty:
                    continue
                f.write(f"{'─' * 70}\n")
                f.write(f"▶ {src} ({len(sub)} 个电路)\n")
                f.write(f"{'─' * 70}\n\n")

                for _, r in sub.iterrows():
                    f.write(f"电路: {r['circuit_name']}\n")
                    f.write(f"  检测时间: {r['detection_time_s']:.4f}s\n")
                    f.write(f"  信号总数: {r['total_signals']}\n")
                    f.write(f"  新增/删除信号: {r['added_signals']}/{r['removed_signals']}\n")
                    f.write(f"  GT信号数: {r['gt_signals_count']}\n")
                    f.write(f"  Precision: {r['precision']:.4f}\n")
                    f.write(f"  Recall: {r['recall']:.4f}\n")
                    f.write(f"  F1-Score: {r['f1_score']:.4f}\n")
                    f.write(f"  TP/FP/TN/FN: {r['tp']}/{r['fp']}/{r['tn']}/{r['fn']}\n\n")

                tp = sub['tp'].sum()
                fp_ = sub['fp'].sum()
                tn = sub['tn'].sum()
                fn = sub['fn'].sum()
                op = tp / (tp + fp_) if (tp + fp_) > 0 else 0
                or_ = tp / (tp + fn) if (tp + fn) > 0 else 0
                of1 = 2 * op * or_ / (op + or_) if (op + or_) > 0 else 0
                f.write(f"  [{src}汇总] TP={tp} FP={fp_} TN={tn} FN={fn}\n")
                f.write(f"  Precision={op:.4f} Recall={or_:.4f} F1={of1:.4f}\n\n")

            # 全局
            tp = df['tp'].sum()
            fp_ = df['fp'].sum()
            tn = df['tn'].sum()
            fn = df['fn'].sum()
            op = tp / (tp + fp_) if (tp + fp_) > 0 else 0
            or_ = tp / (tp + fn) if (tp + fn) > 0 else 0
            of1 = 2 * op * or_ / (op + or_) if (op + or_) > 0 else 0
            f.write(f"{'─' * 70}\n")
            f.write(f"▶ 全局汇总 ({len(df)} 个电路)\n")
            f.write(f"{'─' * 70}\n")
            f.write(f"  TP={tp} FP={fp_} TN={tn} FN={fn}\n")
            f.write(f"  Precision={op:.4f} Recall={or_:.4f} F1={of1:.4f}\n")
            f.write(f"  平均检测时间: {df['detection_time_s'].mean():.4f} s\n")
            f.write(f"  总检测时间: {df['detection_time_s'].sum():.4f} s\n")
            f.write("=" * 70 + "\n")
        print(f"  [OK] 报告: {rpt}")

    # ============================================================
    # 任务4: 可视化图表
    # ============================================================
    def run_visualization(self, sim_df: pd.DataFrame, gt_df: pd.DataFrame):
        print("\n" + "=" * 70)
        print("任务4: 可视化图表 (04_visualization)")
        print("=" * 70)

        if sim_df is not None and not sim_df.empty:
            self._plot_similarity(sim_df)

        if gt_df is not None and not gt_df.empty:
            self._plot_groundtruth(gt_df)

    def _plot_similarity(self, df: pd.DataFrame):
        # 图1: 相似度分布直方图 (TjIn + TjIn2 叠加)
        fig, ax = plt.subplots(figsize=(10, 6))
        for src, color, alpha in [("TjIn", '#3498db', 0.7), ("TjIn2", '#e74c3c', 0.5)]:
            sub = df[df['source'] == src]
            if not sub.empty:
                ax.hist(sub['similarity'], bins=15, color=color, alpha=alpha,
                        edgecolor='black', label=f'{src} (n={len(sub)})')
        ax.axvline(df['similarity'].mean(), color='red', linestyle='--', linewidth=2,
                   label=f"Total Mean: {df['similarity'].mean():.4f}")
        ax.set_xlabel('JPlag Similarity Score', fontweight='bold')
        ax.set_ylabel('Count', fontweight='bold')
        ax.set_title('EXTRTL JPlag Similarity Distribution', fontweight='bold')
        ax.legend()
        ax.grid(True, alpha=0.3)
        plt.tight_layout()
        plt.savefig(os.path.join(DIR_04, "fig01_similarity_distribution.png"), dpi=200, bbox_inches='tight')
        plt.close()
        print(f"  [OK] fig01_similarity_distribution.png")

        # 图2: 按来源和电路类型的箱线图
        fig, ax = plt.subplots(figsize=(12, 6))
        df_copy = df.copy()
        df_copy['base'] = df_copy['circuit_name'].apply(lambda x: x.split('-')[0])
        bases = sorted(df_copy['base'].unique())
        data_boxes = []
        labels = []
        for b in bases:
            sub = df_copy[df_copy['base'] == b]
            if len(sub) >= 2:
                data_boxes.append(sub['similarity'].values)
                labels.append(b)
        if data_boxes:
            bp = ax.boxplot(data_boxes, labels=labels, patch_artist=True)
            for patch in bp['boxes']:
                patch.set_facecolor('#3498db')
                patch.set_alpha(0.6)
            ax.set_xlabel('Base Circuit', fontweight='bold')
            ax.set_ylabel('Similarity', fontweight='bold')
            ax.set_title('Similarity by Base Circuit (EXTRTL)', fontweight='bold')
            ax.tick_params(axis='x', rotation=45)
            ax.grid(True, alpha=0.3, axis='y')
        plt.tight_layout()
        plt.savefig(os.path.join(DIR_04, "fig02_similarity_by_circuit.png"), dpi=200, bbox_inches='tight')
        plt.close()
        print(f"  [OK] fig02_similarity_by_circuit.png")

        # 图3: 大小变化 vs 相似度
        fig, ax = plt.subplots(figsize=(10, 6))
        colors = df['similarity']
        sc = ax.scatter(df['size_change_percent'], df['similarity'],
                        c=colors, cmap='RdYlGn_r', s=60, alpha=0.7, edgecolors='black', linewidth=0.5)
        z = np.polyfit(df['size_change_percent'], df['similarity'], 1)
        p = np.poly1d(z)
        x_line = np.linspace(df['size_change_percent'].min(), df['size_change_percent'].max(), 100)
        ax.plot(x_line, p(x_line), "r--", alpha=0.8, linewidth=2, label=f'Trend (slope: {z[0]:.4f})')
        ax.set_xlabel('Size Change (%)', fontweight='bold')
        ax.set_ylabel('Similarity', fontweight='bold')
        ax.set_title('Size Change vs Similarity (EXTRTL)', fontweight='bold')
        ax.legend()
        ax.grid(True, alpha=0.3)
        plt.colorbar(sc, ax=ax, label='Similarity')
        plt.tight_layout()
        plt.savefig(os.path.join(DIR_04, "fig03_size_vs_similarity.png"), dpi=200, bbox_inches='tight')
        plt.close()
        print(f"  [OK] fig03_size_vs_similarity.png")

        # 图4: TjIn vs TjIn2 相似度对比
        fig, ax = plt.subplots(figsize=(10, 6))
        tjin = df[df['source'] == 'TjIn']['similarity']
        tjin2 = df[df['source'] == 'TjIn2']['similarity']
        positions = [1, 2]
        bp = ax.boxplot([tjin.values, tjin2.values], positions=positions, widths=0.5,
                        patch_artist=True, labels=['TjIn (45)', 'TjIn2 (90)'])
        colors_box = ['#3498db', '#e74c3c']
        for patch, c in zip(bp['boxes'], colors_box):
            patch.set_facecolor(c)
            patch.set_alpha(0.7)
        ax.set_ylabel('Similarity', fontweight='bold')
        ax.set_title('TjIn vs TjIn2 Similarity Comparison', fontweight='bold')
        ax.grid(True, alpha=0.3, axis='y')
        plt.tight_layout()
        plt.savefig(os.path.join(DIR_04, "fig04_tjin_vs_tjin2.png"), dpi=200, bbox_inches='tight')
        plt.close()
        print(f"  [OK] fig04_tjin_vs_tjin2.png")

    def _plot_groundtruth(self, df: pd.DataFrame):
        # 图5: P/R/F1 按来源对比
        fig, axes = plt.subplots(1, 3, figsize=(15, 5))
        metrics = ['precision', 'recall', 'f1_score']
        titles = ['Precision', 'Recall', 'F1-Score']
        colors = ['#2ecc71', '#3498db', '#9b59b6']

        for idx, (metric, title, color) in enumerate(zip(metrics, titles, colors)):
            ax = axes[idx]
            data = []
            labels = []
            for src in ["TjIn", "TjIn2"]:
                sub = df[df['source'] == src][metric].dropna()
                if not sub.empty:
                    data.append(sub.values)
                    labels.append(f'{src}\n(n={len(sub)})')
            if data:
                bp = ax.boxplot(data, labels=labels, patch_artist=True)
                for patch in bp['boxes']:
                    patch.set_facecolor(color)
                    patch.set_alpha(0.7)
            ax.set_title(title, fontweight='bold')
            ax.set_ylim(0, 1.1)
            ax.grid(True, alpha=0.3, axis='y')
            # 均值标注
            all_vals = df[metric].dropna()
            if not all_vals.empty:
                ax.axhline(all_vals.mean(), color='red', linestyle='--', alpha=0.7,
                           label=f'Mean: {all_vals.mean():.3f}')
                ax.legend(fontsize=9)
        plt.suptitle('JPlag Ground Truth Evaluation (EXTRTL)', fontweight='bold', y=1.02)
        plt.tight_layout()
        plt.savefig(os.path.join(DIR_04, "fig05_metrics_comparison.png"), dpi=200, bbox_inches='tight')
        plt.close()
        print(f"  [OK] fig05_metrics_comparison.png")

        # 图6: 混淆矩阵
        tp = df['tp'].sum()
        fp = df['fp'].sum()
        tn = df['tn'].sum()
        fn = df['fn'].sum()
        cm = np.array([[tp, fn], [fp, tn]])

        fig, ax = plt.subplots(figsize=(8, 6))
        im = ax.imshow(cm, cmap='Blues', aspect='auto')
        labels_cm = [['TP', 'FN'], ['FP', 'TN']]
        for i in range(2):
            for j in range(2):
                ax.text(j, i, f'{labels_cm[i][j]}\n{cm[i, j]}',
                        ha="center", va="center", fontsize=18, fontweight='bold')
        ax.set_xticks([0, 1])
        ax.set_xticklabels(['Predicted: Changed', 'Predicted: Unchanged'])
        ax.set_yticks([0, 1])
        ax.set_yticklabels(['Actual: Changed', 'Actual: Unchanged'])
        total = tp + fp + tn + fn
        ax.set_title(f'Confusion Matrix (EXTRTL, n={len(df)})', fontweight='bold', pad=15)
        ax.text(0.5, -0.15, f'Total: {total}  Accuracy: {(tp+tn)/total:.3f}',
                transform=ax.transAxes, ha='center', fontsize=11,
                bbox=dict(boxstyle='round', facecolor='lightyellow', alpha=0.8))
        plt.colorbar(im, ax=ax, fraction=0.046, pad=0.04)
        plt.tight_layout()
        plt.savefig(os.path.join(DIR_04, "fig06_confusion_matrix.png"), dpi=200, bbox_inches='tight')
        plt.close()
        print(f"  [OK] fig06_confusion_matrix.png")

        # 图7: P-R散点图
        fig, ax = plt.subplots(figsize=(10, 8))
        markers = {'TjIn': ('o', '#3498db'), 'TjIn2': ('^', '#e74c3c')}
        for src, (mk, clr) in markers.items():
            sub = df[df['source'] == src].dropna(subset=['precision', 'recall'])
            if not sub.empty:
                ax.scatter(sub['precision'], sub['recall'], c=clr, marker=mk,
                           s=80, alpha=0.7, label=f'{src} (n={len(sub)})',
                           edgecolors='black', linewidth=0.8)
        # F1等值线
        p_vals = np.linspace(0.01, 1, 100)
        for f1 in [0.2, 0.4, 0.6, 0.8]:
            r_vals = f1 * p_vals / (2 * p_vals - f1 + 1e-10)
            valid = (r_vals >= 0) & (r_vals <= 1)
            ax.plot(p_vals[valid], r_vals[valid], '--', color='gray', alpha=0.3)
            ax.text(0.95, f1 / (2 - f1 + 0.01), f'F1={f1}', fontsize=9, color='gray', alpha=0.5, ha='right')
        avg_p = df['precision'].mean()
        avg_r = df['recall'].mean()
        ax.plot(avg_p, avg_r, 'r*', markersize=20, label=f'Avg (P={avg_p:.3f}, R={avg_r:.3f})')
        ax.set_xlabel('Precision', fontweight='bold')
        ax.set_ylabel('Recall', fontweight='bold')
        ax.set_title('JPlag P-R Scatter (EXTRTL)', fontweight='bold')
        ax.set_xlim(0, 1.05)
        ax.set_ylim(0, 1.05)
        ax.grid(True, alpha=0.3)
        ax.legend()
        plt.tight_layout()
        plt.savefig(os.path.join(DIR_04, "fig07_pr_scatter.png"), dpi=200, bbox_inches='tight')
        plt.close()
        print(f"  [OK] fig07_pr_scatter.png")


# ============================================================
# 主入口
# ============================================================
def main():
    print("=" * 70)
    print("JPlag EXTRTL数据集综合分析")
    print("=" * 70)
    print(f"  数据集: {EXTRTL_DIR}")
    print(f"  Ground Truth: {GROUNDTRUTH_CSV}")
    print(f"  输出目录: {OUTPUT_BASE}")

    analyzer = EXTRTLJPlagAnalyzer(EXTRTL_DIR, GROUNDTRUTH_CSV, OUTPUT_BASE)

    t0 = time.time()

    # 任务1: 相似度分析
    sim_df = analyzer.run_similarity_analysis()

    # 任务2: 信号级检测
    sig_df = analyzer.run_signal_detection()

    # 任务3: Ground Truth评估
    gt_df = analyzer.run_groundtruth_eval()

    # 任务4: 可视化
    analyzer.run_visualization(sim_df, gt_df)

    total_time = time.time() - t0
    print(f"\n{'=' * 70}")
    print(f"全部分析完成！总耗时: {total_time:.2f} s")
    print(f"{'=' * 70}")
    print(f"\n输出目录: {OUTPUT_BASE}")
    print(f"  ├── 01_similarity_analysis/  (CSV + JSON + 报告)")
    print(f"  ├── 02_signal_detection/     (CSV + 摘要)")
    print(f"  ├── 03_groundtruth_eval/     (CSV + 报告)")
    print(f"  └── 04_visualization/        (7张PNG图表)")


if __name__ == "__main__":
    main()
