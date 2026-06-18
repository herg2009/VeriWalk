"""
JPlag信号级改动检测与综合评估工具
扩展JPlag以支持信号级检测，并输出Precision/Recall/F1等指标
"""

import os
import re
import json
import time
import pandas as pd
import numpy as np
from pathlib import Path
from typing import Dict, List, Tuple, Set
from collections import Counter
from sklearn.metrics import precision_score, recall_score, f1_score, confusion_matrix

class SignalLevelDetector:
    """信号级改动检测器（基于JPlag扩展）"""
    
    def __init__(self):
        # 信号提取模式
        self.signal_patterns = {
            'input': re.compile(r'\binput\s+(?:wire|reg)?\s*(?:\[.*?\])?\s*(\w+)', re.IGNORECASE),
            'output': re.compile(r'\boutput\s+(?:wire|reg)?\s*(?:\[.*?\])?\s*(\w+)', re.IGNORECASE),
            'wire': re.compile(r'\bwire\s+(?:\[.*?\])?\s*(\w+)', re.IGNORECASE),
            'reg': re.compile(r'\breg\s+(?:\[.*?\])?\s*(\w+)', re.IGNORECASE),
            'parameter': re.compile(r'\bparameter\s+(?:\[.*?\])?\s*(\w+)', re.IGNORECASE),
        }
    
    def extract_signals(self, file_path: str) -> Dict[str, Set[str]]:
        """
        从Verilog文件中提取所有信号
        
        Returns:
            字典，按类型分类的信号集合
        """
        signals = {
            'input': set(),
            'output': set(),
            'wire': set(),
            'reg': set(),
            'parameter': set()
        }
        
        try:
            with open(file_path, 'r', encoding='utf-8', errors='ignore') as f:
                content = f.read()
            
            # 提取各类信号
            for sig_type, pattern in self.signal_patterns.items():
                matches = pattern.findall(content)
                signals[sig_type].update(matches)
        
        except Exception as e:
            print(f"警告: 读取文件 {file_path} 失败: {e}")
        
        return signals
    
    def detect_signal_changes(self, free_path: str, in_path: str) -> Dict:
        """
        检测信号级改动
        
        Returns:
            包含新增、删除、修改信号的字典
        """
        signals_free = self.extract_signals(free_path)
        signals_in = self.extract_signals(in_path)
        
        changes = {
            'added': {},      # 新增信号
            'removed': {},    # 删除信号
            'modified': {},   # 类型改变的信号
            'unchanged': {}   # 未改变信号
        }
        
        # 检测每种信号类型的变化
        for sig_type in signals_free.keys():
            set_free = signals_free[sig_type]
            set_in = signals_in[sig_type]
            
            # 新增
            added = set_in - set_free
            if added:
                changes['added'][sig_type] = added
            
            # 删除
            removed = set_free - set_in
            if removed:
                changes['removed'][sig_type] = removed
            
            # 未改变
            unchanged = set_free & set_in
            if unchanged:
                changes['unchanged'][sig_type] = unchanged
            
            # 检测类型改变（从一种类型变成另一种）
            for sig in list(removed):
                for other_type in signals_in.keys():
                    if other_type != sig_type and sig in signals_in[other_type]:
                        if 'modified' not in changes:
                            changes['modified'] = {}
                        if sig_type not in changes['modified']:
                            changes['modified'][sig_type] = {}
                        changes['modified'][sig_type][sig] = other_type
                        # 从removed和added中移除
                        removed.discard(sig)
                        signals_in[other_type].discard(sig)
        
        return changes
    
    def get_changed_signals_list(self, changes: Dict) -> Set[str]:
        """获取所有改动信号的扁平化列表"""
        changed = set()
        
        for category in ['added', 'removed', 'modified']:
            if category in changes:
                for sig_type, signals in changes[category].items():
                    if isinstance(signals, dict):
                        changed.update(signals.keys())
                    else:
                        changed.update(signals)
        
        return changed


class EvaluationMetrics:
    """评估指标计算器"""
    
    @staticmethod
    def calculate_metrics(y_true: List[int], y_pred: List[int]) -> Dict:
        """
        计算综合评估指标
        
        Args:
            y_true: 真实标签（0=未改动，1=改动）
            y_pred: 预测标签
            
        Returns:
            包含所有指标的字典
        """
        precision = precision_score(y_true, y_pred, zero_division=0)
        recall = recall_score(y_true, y_pred, zero_division=0)
        f1 = f1_score(y_true, y_pred, zero_division=0)
        
        # 混淆矩阵
        tn, fp, fn, tp = confusion_matrix(y_true, y_pred).ravel()
        
        # 其他指标
        accuracy = (tp + tn) / (tp + tn + fp + fn) if (tp + tn + fp + fn) > 0 else 0
        fpr = fp / (fp + tn) if (fp + tn) > 0 else 0  # 假正率
        fnr = fn / (fn + tp) if (fn + tp) > 0 else 0  # 假负率
        
        return {
            'precision': precision,
            'recall': recall,
            'f1_score': f1,
            'accuracy': accuracy,
            'true_positive': int(tp),
            'true_negative': int(tn),
            'false_positive': int(fp),
            'false_negative': int(fn),
            'fpr': fpr,
            'fnr': fnr
        }


class JPlagSignalEvaluator:
    """JPlag信号级评估器"""
    
    def __init__(self, dataset_dir: str):
        self.dataset_dir = Path(dataset_dir)
        self.tjfree_dir = self.dataset_dir / "TjFree"
        self.tjin_dir = self.dataset_dir / "TjIn"
        
        self.signal_detector = SignalLevelDetector()
        self.results = []
    
    def evaluate_circuit(self, circuit_name: str, free_path: str, in_path: str,
                        ground_truth_signals: Set[str] = None) -> Dict:
        """
        评估单个电路的检测结果
        
        Args:
            circuit_name: 电路名称
            free_path: 基准文件路径
            in_path: 变体文件路径
            ground_truth_signals: 真实改动信号集合（如果有）
            
        Returns:
            评估结果字典
        """
        start_time = time.time()
        
        # 检测信号级改动
        changes = self.signal_detector.detect_signal_changes(free_path, in_path)
        detected_signals = self.signal_detector.get_changed_signals_list(changes)
        
        # 提取所有信号
        signals_free = self.signal_detector.extract_signals(free_path)
        signals_in = self.signal_detector.extract_signals(in_path)
        all_signals = set()
        for sig_type in signals_free.keys():
            all_signals.update(signals_free[sig_type])
            all_signals.update(signals_in[sig_type])
        
        # 构建标签向量
        if ground_truth_signals:
            y_true = [1 if sig in ground_truth_signals else 0 for sig in all_signals]
            y_pred = [1 if sig in detected_signals else 0 for sig in all_signals]
            
            # 计算指标
            metrics = EvaluationMetrics.calculate_metrics(y_true, y_pred)
        else:
            metrics = {
                'detected_count': len(detected_signals),
                'total_signals': len(all_signals),
                'note': '无Ground Truth，仅统计检测数量'
            }
        
        elapsed_time = time.time() - start_time
        
        # 统计改动
        added_count = sum(len(s) for s in changes['added'].values())
        removed_count = sum(len(s) for s in changes['removed'].values())
        modified_count = sum(len(s) for s in changes.get('modified', {}).values())
        
        result = {
            'circuit_name': circuit_name,
            'detection_time': round(elapsed_time, 4),
            'metrics': metrics,
            'changes': {
                'added_count': added_count,
                'removed_count': removed_count,
                'modified_count': modified_count,
                'total_changes': added_count + removed_count + modified_count
            },
            'detected_signals': list(detected_signals),
            'changes_detail': {
                'added': {k: list(v) for k, v in changes['added'].items()},
                'removed': {k: list(v) for k, v in changes['removed'].items()}
            }
        }
        
        return result
    
    def run_evaluation(self, output_dir: str = None) -> pd.DataFrame:
        """
        运行完整评估
        
        Args:
            output_dir: 输出目录
            
        Returns:
            结果DataFrame
        """
        if output_dir is None:
            output_dir = self.dataset_dir / "jplag_signal_evaluation"
        else:
            output_dir = Path(output_dir)
        
        output_dir.mkdir(parents=True, exist_ok=True)
        
        print("=" * 80)
        print("JPlag 信号级改动检测评估")
        print("=" * 80)
        
        # 遍历所有电路对
        pairs = self._find_circuit_pairs()
        print(f"找到 {len(pairs)} 对电路\n")
        
        results = []
        for circuit_name, free_path, in_path in pairs:
            print(f"评估: {circuit_name}")
            try:
                # 这里可以传入ground truth（如果有的话）
                # ground_truth = self._load_ground_truth(circuit_name)
                result = self.evaluate_circuit(circuit_name, free_path, in_path)
                results.append(result)
            except Exception as e:
                print(f"  错误: {e}")
        
        # 转换为DataFrame
        df_results = self._results_to_dataframe(results)
        
        # 保存结果
        self._save_results(df_results, output_dir)
        
        # 打印汇总
        self._print_summary(df_results)
        
        return df_results
    
    def _find_circuit_pairs(self) -> List[Tuple[str, str, str]]:
        """查找匹配的电路对"""
        pairs = []
        
        for tjin_circuit in self.tjin_dir.iterdir():
            if not tjin_circuit.is_dir():
                continue
            
            circuit_name = tjin_circuit.name
            tjin_topmodule = tjin_circuit / "topModule.v"
            
            if not tjin_topmodule.exists():
                continue
            
            base_name = circuit_name.split('-')[0]
            tjfree_topmodule = self.tjfree_dir / base_name / "topModule.v"
            
            if tjfree_topmodule.exists():
                pairs.append((circuit_name, str(tjfree_topmodule), str(tjin_topmodule)))
        
        return pairs
    
    def _results_to_dataframe(self, results: List[Dict]) -> pd.DataFrame:
        """将结果转换为DataFrame"""
        rows = []
        for r in results:
            row = {
                'circuit_name': r['circuit_name'],
                'detection_time_s': r['detection_time'],
                'added_signals': r['changes']['added_count'],
                'removed_signals': r['changes']['removed_count'],
                'modified_signals': r['changes']['modified_count'],
                'total_changes': r['changes']['total_changes'],
            }
            
            # 添加评估指标
            if 'precision' in r['metrics']:
                row.update({
                    'precision': r['metrics']['precision'],
                    'recall': r['metrics']['recall'],
                    'f1_score': r['metrics']['f1_score'],
                    'accuracy': r['metrics']['accuracy'],
                    'true_positive': r['metrics']['true_positive'],
                    'false_positive': r['metrics']['false_positive'],
                    'true_negative': r['metrics']['true_negative'],
                    'false_negative': r['metrics']['false_negative'],
                    'fpr': r['metrics']['fpr'],
                    'fnr': r['metrics']['fnr']
                })
            else:
                row['note'] = r['metrics'].get('note', '')
            
            rows.append(row)
        
        return pd.DataFrame(rows)
    
    def _save_results(self, df: pd.DataFrame, output_dir: Path):
        """保存评估结果"""
        # CSV
        csv_path = output_dir / "signal_evaluation_results.csv"
        df.to_csv(csv_path, index=False, encoding='utf-8-sig')
        print(f"\n✓ 结果已保存: {csv_path}")
        
        # 统计摘要
        summary_path = output_dir / "evaluation_summary.txt"
        with open(summary_path, 'w', encoding='utf-8') as f:
            f.write("JPlag 信号级改动检测 - 评估摘要\n")
            f.write("=" * 80 + "\n\n")
            
            f.write(f"评估电路数: {len(df)}\n\n")
            
            if 'precision' in df.columns:
                f.write("综合指标（平均值）:\n")
                f.write(f"  Precision: {df['precision'].mean():.4f}\n")
                f.write(f"  Recall:    {df['recall'].mean():.4f}\n")
                f.write(f"  F1-Score:  {df['f1_score'].mean():.4f}\n")
                f.write(f"  Accuracy:  {df['accuracy'].mean():.4f}\n\n")
                
                f.write("混淆矩阵（总计）:\n")
                f.write(f"  TP: {df['true_positive'].sum()}\n")
                f.write(f"  TN: {df['true_negative'].sum()}\n")
                f.write(f"  FP: {df['false_positive'].sum()}\n")
                f.write(f"  FN: {df['false_negative'].sum()}\n\n")
            
            f.write(f"平均检测时间: {df['detection_time_s'].mean():.4f} 秒\n")
            f.write(f"总检测时间: {df['detection_time_s'].sum():.4f} 秒\n")
        
        print(f"✓ 评估摘要: {summary_path}")
    
    def _print_summary(self, df: pd.DataFrame):
        """打印汇总统计"""
        print("\n" + "=" * 80)
        print("评估结果汇总")
        print("=" * 80)
        
        print(f"\n评估电路数: {len(df)}")
        print(f"平均检测时间: {df['detection_time_s'].mean():.4f} 秒")
        
        if 'precision' in df.columns:
            print(f"\n平均 Precision: {df['precision'].mean():.4f}")
            print(f"平均 Recall:    {df['recall'].mean():.4f}")
            print(f"平均 F1-Score:  {df['f1_score'].mean():.4f}")
        
        print(f"\n平均每个电路改动: {df['total_changes'].mean():.1f} 个信号")
        print(f"最多改动: {df['total_changes'].max()} 个信号")
        print(f"最少改动: {df['total_changes'].min()} 个信号")


def main():
    """主函数"""
    dataset_dir = r"e:\PRO\python\HT\hw4vec\assets\ALLRTL"
    output_dir = r"e:\PRO\python\HT\hw4vec\examples\jplag_signal_evaluation"
    
    evaluator = JPlagSignalEvaluator(dataset_dir)
    results = evaluator.run_evaluation(output_dir)
    
    print("\n✅ 评估完成！")
    print(f"结果保存在: {output_dir}")
    
    return results


if __name__ == "__main__":
    main()
