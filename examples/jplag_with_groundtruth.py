"""
JPlag信号级检测 + Ground Truth评估工具
结合ALLRTL_dataset.csv进行完整的Precision/Recall/F1评估

关键改进：
1. 支持"模块.实例.信号"格式的Ground Truth
2. 从Verilog代码中提取模块层次结构
3. 将提取的信号映射为完整格式进行匹配
4. 输出完整的评估指标
"""

import os
import re
import time
import pandas as pd
import numpy as np
from pathlib import Path
from typing import Dict, List, Tuple, Set
from collections import defaultdict
from sklearn.metrics import precision_score, recall_score, f1_score, confusion_matrix


class VerilogSignalExtractor:
    """Verilog信号提取器 - 支持模块层次结构"""
    
    def __init__(self):
        # 模块声明模式
        self.module_pattern = re.compile(
            r'\bmodule\s+(\w+)\s*[\(#;]',  # 匹配 module xxx (
            re.IGNORECASE
        )
        
        # 实例化模式: module_name instance_name (...)
        self.instance_pattern = re.compile(
            r'\b(\w+)\s+(\w+)\s*\(\s*\.[\w]+',  # 匹配 .port_name
            re.IGNORECASE
        )
        
        # 信号声明模式
        self.signal_patterns = {
            'input': re.compile(r'\binput\s+(?:wire|reg)?\s*(?:\[.*?\])?\s*(\w+)', re.IGNORECASE),
            'output': re.compile(r'\boutput\s+(?:wire|reg)?\s*(?:\[.*?\])?\s*(\w+)', re.IGNORECASE),
            'wire': re.compile(r'\bwire\s+(?:\[.*?\])?\s*(\w+)', re.IGNORECASE),
            'reg': re.compile(r'\breg\s+(?:\[.*?\])?\s*(\w+)', re.IGNORECASE),
            'parameter': re.compile(r'\bparameter\s+(?:\[.*?\])?\s*(\w+)', re.IGNORECASE),
        }
    
    def extract_module_hierarchy(self, file_path: str) -> Dict:
        """
        提取模块层次结构
        
        Returns:
            {
                'module_name': 'top',
                'instances': {
                    'instance_name': 'module_type',
                    ...
                }
            }
        """
        hierarchy = {
            'module_name': None,
            'instances': {}
        }
        
        try:
            with open(file_path, 'r', encoding='utf-8', errors='ignore') as f:
                content = f.read()
            
            # 提取顶层模块名
            module_match = self.module_pattern.search(content)
            if module_match:
                hierarchy['module_name'] = module_match.group(1)
            
            # 提取实例
            instances = self.instance_pattern.findall(content)
            for module_type, instance_name in instances:
                # 过滤关键字
                if instance_name.lower() not in ['input', 'output', 'wire', 'reg', 'if', 'else', 'for', 'begin', 'end']:
                    hierarchy['instances'][instance_name] = module_type
        
        except Exception as e:
            print(f"警告: 读取 {file_path} 失败: {e}")
        
        return hierarchy
    
    def extract_all_signals(self, file_path: str) -> Set[str]:
        """
        提取文件中所有信号（简单名称）
        
        Returns:
            信号名称集合
        """
        signals = set()
        
        try:
            with open(file_path, 'r', encoding='utf-8', errors='ignore') as f:
                content = f.read()
            
            for sig_type, pattern in self.signal_patterns.items():
                matches = pattern.findall(content)
                signals.update(matches)
        
        except Exception as e:
            print(f"警告: 提取信号失败 {file_path}: {e}")
        
        return signals
    
    def build_full_signal_names(self, file_path: str) -> Set[str]:
        """
        构建完整信号名称（模块.实例.信号）
        
        策略：
        1. 提取顶层模块名
        2. 提取所有实例
        3. 对每个信号，尝试匹配可能的实例前缀
        
        Returns:
            完整信号名称集合
        """
        hierarchy = self.extract_module_hierarchy(file_path)
        simple_signals = self.extract_all_signals(file_path)
        
        full_signals = set()
        module_name = hierarchy['module_name'] or 'top'
        instances = list(hierarchy['instances'].keys())
        
        for signal in simple_signals:
            # 策略1: 直接信号（无实例前缀）
            full_signals.add(f"{module_name}.{signal}")
            
            # 策略2: 尝试匹配实例前缀
            for instance in instances:
                # 如果信号名包含实例名的一部分，尝试构建完整路径
                if instance.lower() in signal.lower() or signal.lower() in instance.lower():
                    full_signals.add(f"{module_name}.{instance}.{signal}")
        
        return full_signals


class GroundTruthLoader:
    """Ground Truth数据加载器"""
    
    @staticmethod
    def load(csv_path: str) -> Dict[str, Set[str]]:
        """
        加载Ground Truth数据
        
        Returns:
            {circuit_name: {signal_name1, signal_name2, ...}}
        """
        ground_truth = {}
        
        try:
            # 尝试多种编码
            for encoding in ['utf-8', 'gbk', 'latin-1']:
                try:
                    df = pd.read_csv(csv_path, encoding=encoding)
                    break
                except UnicodeDecodeError:
                    continue
            else:
                print(f"错误: 无法读取 {csv_path}")
                return ground_truth
            
            # 解析每一行
            for _, row in df.iterrows():
                # 跳过注释行
                idx_str = str(row.get('idx', '')).strip()
                if idx_str.startswith('#') or idx_str == 'idx':
                    continue
                
                try:
                    circuit_name = str(row['circuit_name']).strip()
                    signal_name = str(row['signal_name']).strip()
                    
                    if circuit_name not in ground_truth:
                        ground_truth[circuit_name] = set()
                    ground_truth[circuit_name].add(signal_name)
                
                except (KeyError, AttributeError):
                    continue
            
            print(f"✅ 加载Ground Truth: {len(ground_truth)} 个电路, "
                  f"{sum(len(v) for v in ground_truth.values())} 个信号")
        
        except Exception as e:
            print(f"❌ 加载Ground Truth失败: {e}")
        
        return ground_truth


class JPlagGroundTruthEvaluator:
    """JPlag + Ground Truth评估器"""
    
    def __init__(self, ground_truth: Dict[str, Set[str]]):
        self.ground_truth = ground_truth
        self.extractor = VerilogSignalExtractor()
        
    def evaluate_single_circuit(self, circuit_name: str, free_path: str, in_path: str) -> Dict:
        """
        评估单个电路的信号级检测结果
        
        Returns:
            包含所有评估指标的字典
        """
        start_time = time.time()
        
        # 1. 提取信号
        signals_free = self.extractor.extract_all_signals(free_path)
        signals_in = self.extractor.extract_all_signals(in_path)
        
        # 2. 检测改动
        added_signals = signals_in - signals_free
        removed_signals = signals_free - signals_in
        modified_signals = added_signals | removed_signals
        
        # 3. 构建预测标签（所有提取的信号）
        all_signals = signals_free | signals_in
        y_true = []
        y_pred = []
        
        # 获取该电路的Ground Truth
        gt_signals = self.ground_truth.get(circuit_name, set())
        
        # 对每个信号，判断是否为真实改动 & 是否被检测到
        for signal in all_signals:
            # 真实标签：是否在Ground Truth中
            is_true_positive = any(
                signal in gt_signal or gt_signal.endswith(f".{signal}")
                for gt_signal in gt_signals
            )
            y_true.append(1 if is_true_positive else 0)
            
            # 预测标签：是否被检测到（新增或删除）
            is_detected = (signal in added_signals) or (signal in removed_signals)
            y_pred.append(1 if is_detected else 0)
        
        # 4. 计算指标
        detection_time = time.time() - start_time
        
        if len(y_true) == 0 or sum(y_true) == 0:
            # 没有Ground Truth或没有改动
            return {
                'circuit_name': circuit_name,
                'detection_time_s': detection_time,
                'total_signals': len(all_signals),
                'added_signals': len(added_signals),
                'removed_signals': len(removed_signals),
                'gt_signals_count': len(gt_signals),
                'precision': None,
                'recall': None,
                'f1_score': None,
                'tp': 0,
                'fp': 0,
                'tn': 0,
                'fn': len(gt_signals),
                'accuracy': 0,
                'fpr': 0,
                'fnr': 0
            }
        
        # 计算混淆矩阵
        tp = sum(1 for t, p in zip(y_true, y_pred) if t == 1 and p == 1)
        fp = sum(1 for t, p in zip(y_true, y_pred) if t == 0 and p == 1)
        tn = sum(1 for t, p in zip(y_true, y_pred) if t == 0 and p == 0)
        fn = sum(1 for t, p in zip(y_true, y_pred) if t == 1 and p == 0)
        
        precision = tp / (tp + fp) if (tp + fp) > 0 else 0
        recall = tp / (tp + fn) if (tp + fn) > 0 else 0
        f1 = 2 * precision * recall / (precision + recall) if (precision + recall) > 0 else 0
        accuracy = (tp + tn) / (tp + tn + fp + fn) if (tp + tn + fp + fn) > 0 else 0
        fpr = fp / (fp + tn) if (fp + tn) > 0 else 0
        fnr = fn / (fn + tp) if (fn + tp) > 0 else 0
        
        return {
            'circuit_name': circuit_name,
            'detection_time_s': detection_time,
            'total_signals': len(all_signals),
            'added_signals': len(added_signals),
            'removed_signals': len(removed_signals),
            'gt_signals_count': len(gt_signals),
            'precision': precision,
            'recall': recall,
            'f1_score': f1,
            'tp': tp,
            'fp': fp,
            'tn': tn,
            'fn': fn,
            'accuracy': accuracy,
            'fpr': fpr,
            'fnr': fnr
        }
    
    def evaluate_all(self, dataset_dir: str, output_dir: str = 'jplag_groundtruth_evaluation'):
        """
        评估整个数据集
        
        Args:
            dataset_dir: ALLRTL数据集路径
            output_dir: 输出目录
        """
        Path(output_dir).mkdir(parents=True, exist_ok=True)
        
        free_dir = os.path.join(dataset_dir, 'TjFree')
        in_dir = os.path.join(dataset_dir, 'TjIn')
        
        results = []
        
        # 遍历所有变体电路
        if os.path.exists(in_dir):
            for circuit_folder in sorted(os.listdir(in_dir)):
                circuit_in_path = os.path.join(in_dir, circuit_folder)
                
                if not os.path.isdir(circuit_in_path):
                    continue
                
                # 提取电路名称（如 AES-T100）
                circuit_name = circuit_folder
                
                # 检查是否在Ground Truth中
                if circuit_name not in self.ground_truth:
                    print(f"⚠️ Ground Truth中未找到: {circuit_name}")
                    continue
                
                # 查找对应的基准电路（提取基础名，如 AES-T100 -> AES）
                base_name = circuit_name.split('-')[0]
                circuit_free_path = os.path.join(free_dir, base_name)
                
                if not os.path.exists(circuit_free_path):
                    print(f"⚠️ 未找到基准电路: {base_name} (from {circuit_name})")
                    continue
                
                # 查找topModule.v文件
                free_top = os.path.join(circuit_free_path, 'topModule.v')
                in_top = os.path.join(circuit_in_path, 'topModule.v')
                
                if not os.path.exists(free_top) or not os.path.exists(in_top):
                    print(f"⚠️ 缺少topModule.v: {circuit_name}")
                    continue
                
                # 评估
                print(f"🔍 评估: {circuit_name} (基准: {base_name})")
                result = self.evaluate_single_circuit(circuit_name, free_top, in_top)
                results.append(result)
        
        # 保存结果
        df_results = pd.DataFrame(results)
        output_csv = os.path.join(output_dir, 'evaluation_results.csv')
        df_results.to_csv(output_csv, index=False)
        print(f"\n✅ 结果已保存: {output_csv}")
        
        # 统计总体指标
        self.print_summary(results)
        
        return results
    
    def print_summary(self, results: List[Dict]):
        """打印评估摘要"""
        if not results:
            print("⚠️ 没有评估结果")
            return
        
        df = pd.DataFrame(results)
        
        print("\n" + "="*80)
        print("📊 JPlag信号级检测 - Ground Truth评估报告")
        print("="*80)
        
        print(f"\n📁 评估电路数: {len(results)}")
        print(f"⏱️  平均检测时间: {df['detection_time_s'].mean():.4f} 秒")
        print(f"🔢 平均信号数: {df['total_signals'].mean():.1f}")
        
        # 过滤有效指标（非None）
        valid_metrics = df.dropna(subset=['precision'])
        
        if len(valid_metrics) > 0:
            print(f"\n🎯 综合评估指标（基于 {len(valid_metrics)} 个有Ground Truth的电路）:")
            print(f"   Precision: {valid_metrics['precision'].mean():.4f}")
            print(f"   Recall:    {valid_metrics['recall'].mean():.4f}")
            print(f"   F1-Score:  {valid_metrics['f1_score'].mean():.4f}")
            print(f"   Accuracy:  {valid_metrics['accuracy'].mean():.4f}")
            print(f"   FPR:       {valid_metrics['fpr'].mean():.4f}")
            print(f"   FNR:       {valid_metrics['fnr'].mean():.4f}")
            
            print(f"\n📈 混淆矩阵总计:")
            print(f"   TP: {valid_metrics['tp'].sum()}")
            print(f"   FP: {valid_metrics['fp'].sum()}")
            print(f"   TN: {valid_metrics['tn'].sum()}")
            print(f"   FN: {valid_metrics['fn'].sum()}")
        
        # 按电路类型统计
        print(f"\n📂 按电路类型统计:")
        for prefix in ['AES', 'PIC16F84', 'RS232']:
            type_results = [r for r in results if r['circuit_name'].startswith(prefix)]
            if type_results:
                type_df = pd.DataFrame(type_results).dropna(subset=['precision'])
                if len(type_df) > 0:
                    print(f"\n   {prefix} ({len(type_df)} 个电路):")
                    print(f"      Precision: {type_df['precision'].mean():.4f}")
                    print(f"      Recall:    {type_df['recall'].mean():.4f}")
                    print(f"      F1-Score:  {type_df['f1_score'].mean():.4f}")
        
        print("="*80)


def main():
    """主函数"""
    # 配置路径
    dataset_dir = r'e:\PRO\python\HT\hw4vec\assets\ALLRTL'
    groundtruth_csv = r'e:\PRO\python\HT\hw4vec\examples\ALLRTL_dataset.csv'
    output_dir = r'e:\PRO\python\HT\hw4vec\examples\jplag_groundtruth_evaluation'
    
    print("="*80)
    print("🚀 JPlag信号级检测 + Ground Truth评估")
    print("="*80)
    
    # 1. 加载Ground Truth
    print("\n📥 步骤1: 加载Ground Truth...")
    ground_truth = GroundTruthLoader.load(groundtruth_csv)
    
    if not ground_truth:
        print("❌ 无法加载Ground Truth，退出")
        return
    
    # 2. 初始化评估器
    print("\n⚙️  步骤2: 初始化评估器...")
    evaluator = JPlagGroundTruthEvaluator(ground_truth)
    
    # 3. 执行评估
    print("\n🔍 步骤3: 执行信号级检测与评估...")
    results = evaluator.evaluate_all(dataset_dir, output_dir)
    
    # 4. 输出详细报告
    print("\n📊 步骤4: 生成评估报告...")
    report_path = os.path.join(output_dir, 'evaluation_report.txt')
    with open(report_path, 'w', encoding='utf-8') as f:
        f.write("JPlag信号级检测 - Ground Truth评估报告\n")
        f.write("="*80 + "\n\n")
        f.write(f"评估电路数: {len(results)}\n")
        f.write(f"Ground Truth来源: {groundtruth_csv}\n\n")
        
        # 写入每个电路的详细结果
        for result in results:
            f.write(f"\n电路: {result['circuit_name']}\n")
            f.write(f"  检测时间: {result['detection_time_s']:.4f}s\n")
            f.write(f"  信号总数: {result['total_signals']}\n")
            f.write(f"  新增信号: {result['added_signals']}\n")
            f.write(f"  删除信号: {result['removed_signals']}\n")
            f.write(f"  GT信号数: {result['gt_signals_count']}\n")
            if result['precision'] is not None:
                f.write(f"  Precision: {result['precision']:.4f}\n")
                f.write(f"  Recall: {result['recall']:.4f}\n")
                f.write(f"  F1-Score: {result['f1_score']:.4f}\n")
                f.write(f"  TP/FP/TN/FN: {result['tp']}/{result['fp']}/{result['tn']}/{result['fn']}\n")
    
    print(f"✅ 详细报告已保存: {report_path}")
    print("\n🎉 评估完成！")


if __name__ == '__main__':
    main()
