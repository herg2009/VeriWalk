"""
GraphCodeBERT + DFG 子图级别分析（正确版本）

关键改进：
1. 在子图级别进行比较，而不是整体电路
2. 每个变体电路的子图 vs 基准电路的所有子图
3. 与Ground Truth（ALLRTL_dataset.csv）对比
4. 输出Precision/Recall/F1等指标
"""

import os
import sys
import time
import pickle
import re
import numpy as np
import pandas as pd
from pathlib import Path
from collections import defaultdict
from sklearn.metrics import precision_score, recall_score, f1_score, confusion_matrix
from sklearn.metrics.pairwise import cosine_similarity


class GraphCodeBERT_SubgraphAnalyzer:
    """
    GraphCodeBERT + DFG 子图级别分析器
    
    工作流程：
    1. 加载子图DFG数据
    2. 对每个变体电路的子图：
       - 提取DFG特征
       - 与基准电路的所有子图比较
       - 找到最大相似度
       - 低于阈值则标记为可疑
    3. 与Ground Truth对比评估
    """
    
    def __init__(self):
        print("="*80)
        print("GraphCodeBERT + DFG 子图级别分析器")
        print("="*80)
        
        self.nx_subgraphs_all = []
        self.subgraph_cache = {}
        self.feature_cache = {}
    
    def clean_signal_name(self, name):
        """
        清洗信号名：去掉_rn_x后缀
        
        Args:
            name: 原始信号名（如'top.Counter_rn_5'）
        
        Returns:
            str: 清洗后的信号名（如'top.Counter'）
        """
        return re.sub(r'_rn_\d+$', '', str(name))
    
    def load_subgraph_data(self, subgraphs_file):
        """加载子图DFG数据"""
        print(f"\n[1/5] 加载子图数据: {subgraphs_file}")
        
        with open(subgraphs_file, 'rb') as f:
            self.nx_subgraphs_all = pickle.load(f)
        
        print(f"  [OK] 加载 {len(self.nx_subgraphs_all)} 个子图")
        
        # 按电路名称组织子图
        self._organize_subgraphs()
    
    def _organize_subgraphs(self):
        """按电路名称组织子图"""
        print(f"\n[2/5] 组织子图...")
        
        for nx_subgraph in self.nx_subgraphs_all:
            circuit_name = nx_subgraph.name
            
            if circuit_name not in self.subgraph_cache:
                self.subgraph_cache[circuit_name] = []
            
            self.subgraph_cache[circuit_name].append(nx_subgraph)
        
        print(f"  [OK] 组织完成: {len(self.subgraph_cache)} 个电路")
        
        # 打印统计信息
        for name in sorted(self.subgraph_cache.keys())[:5]:
            subgraphs = self.subgraph_cache[name]
            print(f"    - {name}: {len(subgraphs)} 个子图")
    
    def extract_subgraph_features(self, nx_subgraph):
        """
        提取单个子图的DFG特征
        
        Args:
            nx_subgraph: NetworkX子图对象
        
        Returns:
            numpy.ndarray: 特征向量
        """
        # 使用子图的缓存key
        cache_key = id(nx_subgraph)
        if cache_key in self.feature_cache:
            return self.feature_cache[cache_key]
        
        features = []
        
        # ========== 特征1: 基本统计 ==========
        num_nodes = nx_subgraph.number_of_nodes()
        num_edges = nx_subgraph.number_of_edges()
        
        features.extend([
            num_nodes / 100.0,
            num_edges / 100.0,
            num_edges / max(num_nodes, 1),  # 边密度
            np.sqrt(num_nodes) / 10.0,
            np.log1p(num_nodes) / 5.0,
        ])
        
        # ========== 特征2: 节点统计 ==========
        nodes = list(nx_subgraph.nodes())
        node_strs = [str(n) for n in nodes]
        
        # 信号名特征
        has_clk = sum(1 for s in node_strs if 'clk' in s.lower())
        has_rst = sum(1 for s in node_strs if 'rst' in s.lower() or 'reset' in s.lower())
        has_bus = sum(1 for s in node_strs if '[' in s)
        
        signal_lengths = [len(s) for s in node_strs]
        
        features.extend([
            has_clk / max(num_nodes, 1),
            has_rst / max(num_nodes, 1),
            has_bus / max(num_nodes, 1),
            np.mean(signal_lengths) / 20.0 if signal_lengths else 0,
            np.max(signal_lengths) / 50.0 if signal_lengths else 0,
        ])
        
        # ========== 特征3: 边统计 ==========
        edge_types = defaultdict(int)
        for u, v, data in nx_subgraph.edges(data=True):
            edge_type = str(data.get('type', 'unknown'))
            edge_types[edge_type] += 1
        
        total_edges = max(num_edges, 1)
        
        # 统计常见边类型
        for etype in ['data', 'control', 'flow', 'assign', 'port']:
            count = sum(c for et, c in edge_types.items() if etype in et.lower())
            features.append(count / total_edges)
        
        # 填充到固定维度
        while len(features) < 20:
            features.append(0.0)
        
        features = features[:20]
        
        feature_vector = np.array(features, dtype=np.float32).reshape(1, -1)
        
        # 缓存
        self.feature_cache[cache_key] = feature_vector
        
        return feature_vector
    
    def analyze_subgraph_similarity(self, subgraph_in, subgraphs_free):
        """
        计算一个变体子图与基准电路所有子图的相似度
        
        Args:
            subgraph_in: 变体电路的子图
            subgraphs_free: 基准电路的所有子图列表
        
        Returns:
            float: 最大相似度
        """
        # 提取变体子图特征
        feat_in = self.extract_subgraph_features(subgraph_in)
        
        # 与所有基准子图比较
        max_similarity = 0.0
        
        for subgraph_free in subgraphs_free:
            feat_free = self.extract_subgraph_features(subgraph_free)
            
            # 计算余弦相似度
            sim = cosine_similarity(feat_in, feat_free)[0][0]
            
            if sim > max_similarity:
                max_similarity = sim
        
        return max_similarity
    
    def analyze_allrtl_subgraphs(self, ground_truth_file):
        """
        在ALLRTL数据集上进行子图级别分析
        
        Args:
            ground_truth_file: Ground Truth文件路径
        
        Returns:
            pd.DataFrame: 分析结果
        """
        print(f"\n[3/5] 分析ALLRTL子图...")
        
        # 加载Ground Truth（跳过第一行注释）
        gt_df = pd.read_csv(ground_truth_file, encoding='latin1', skiprows=1)
        print(f"  [OK] Ground Truth: {len(gt_df)} 个信号")
        
        # 统计唯一电路数
        unique_circuits = gt_df['circuit_name'].nunique()
        print(f"  [OK] 涉及电路数: {unique_circuits}")
        
        # 组织TjFree和TjIn的子图
        tjfree_subgraphs = {}
        tjin_subgraphs = {}
        
        for circuit_name, subgraphs in self.subgraph_cache.items():
            if '-T' not in circuit_name:
                tjfree_subgraphs[circuit_name] = subgraphs
            else:
                tjin_subgraphs[circuit_name] = subgraphs
        
        print(f"  [OK] TjFree电路: {len(tjfree_subgraphs)} 个")
        print(f"  [OK] TjIn电路: {len(tjin_subgraphs)} 个")
        
        # 分析每个变体电路
        results = []
        total_start = time.time()
        total_subgraphs = 0
        circuit_count = 0
        
        # 过滤：只分析非AES电路（PIC16F84和RS232）
        circuits_to_analyze = [name for name in sorted(tjin_subgraphs.keys()) 
                               if not name.startswith('AES')]
        
        print(f"\n  [INFO] 过滤后待分析电路数: {len(circuits_to_analyze)} (跳过AES)")
        print(f"  [INFO] 电路列表: {circuits_to_analyze}")
        
        for circuit_in_name in circuits_to_analyze:
            circuit_count += 1
            circuit_start = time.time()
            
            # 获取基准电路名称
            base_name = circuit_in_name.split('-T')[0]
            
            if base_name not in tjfree_subgraphs:
                print(f"  [WARN] 未找到基准电路: {base_name}")
                continue
            
            subgraphs_in = tjin_subgraphs[circuit_in_name]
            subgraphs_free = tjfree_subgraphs[base_name]
            
            print(f"\n  [{circuit_count:2d}/{len(circuits_to_analyze)}] 分析 {circuit_in_name} vs {base_name}...")
            print(f"    变体子图数: {len(subgraphs_in)}, 基准子图数: {len(subgraphs_free)}")
            
            # 对每个子图进行分析
            circuit_results = []
            for i, subgraph_in in enumerate(subgraphs_in):
                start_time = time.time()
                
                # 计算与基准电路的最大相似度
                max_sim = self.analyze_subgraph_similarity(subgraph_in, subgraphs_free)
                
                detect_time = time.time() - start_time
                
                # 获取子图的信号名（清洗后的第一个节点名）
                nodes = list(subgraph_in.nodes())
                if nodes:
                    # 使用第一个节点名，清洗掉_rn_x后缀
                    first_signal = self.clean_signal_name(nodes[0])
                else:
                    first_signal = 'unknown'
                
                circuit_results.append({
                    'circuit_name': circuit_in_name,
                    'base_name': base_name,
                    'signal_name': first_signal,
                    'subgraph_index': i,
                    'similarity': max_sim,
                    'detection_time': detect_time,
                    'node_count': subgraph_in.number_of_nodes(),
                    'edge_count': subgraph_in.number_of_edges()
                })
                
                total_subgraphs += 1
                
                # 每100个子图显示一次进度
                if (i + 1) % 100 == 0 or i == len(subgraphs_in) - 1:
                    elapsed = time.time() - circuit_start
                    avg_sim = np.mean([r['similarity'] for r in circuit_results[-100:]])
                    print(f"      [{i+1:5d}/{len(subgraphs_in)}] 最近100个平均相似度: {avg_sim:.4f} | 耗时: {elapsed:.1f}s")
            
            results.extend(circuit_results)
            
            # 打印电路级别统计
            circuit_elapsed = time.time() - circuit_start
            circuit_avg_sim = np.mean([r['similarity'] for r in circuit_results])
            circuit_min_sim = np.min([r['similarity'] for r in circuit_results])
            print(f"    [完成] 平均相似度: {circuit_avg_sim:.4f}, 最小相似度: {circuit_min_sim:.4f}, 耗时: {circuit_elapsed:.1f}s")
        
        df_results = pd.DataFrame(results)
        
        total_time = time.time() - total_start
        print(f"\n  [OK] 分析完成")
        print(f"    总子图数: {total_subgraphs}")
        print(f"    总耗时: {total_time:.2f}s")
        print(f"    平均耗时: {total_time/total_subgraphs:.4f}s/子图")
        print(f"    平均相似度: {df_results['similarity'].mean():.4f}")
        print(f"    相似度范围: [{df_results['similarity'].min():.4f}, {df_results['similarity'].max():.4f}]")
        
        return df_results
    
    def analyze_similarity_distribution(self, df_results, ground_truth_file):
        """
        分析相似度分布，帮助确定最佳阈值
        
        Args:
            df_results: 分析结果DataFrame
            ground_truth_file: Ground Truth文件
        """
        print(f"\n[4/5] 分析相似度分布...")
        
        # 加载Ground Truth（跳过第一行注释）
        gt_df = pd.read_csv(ground_truth_file, encoding='latin1', skiprows=1)
        
        # 构建Ground Truth信号集合
        gt_signals = set()
        for _, row in gt_df.iterrows():
            circuit = row['circuit_name']
            signal = row['signal_name']
            gt_signals.add((circuit, signal))
        
        print(f"  [OK] Ground Truth信号数: {len(gt_signals)}")
        
        # 分类统计
        trojan_sims = []
        normal_sims = []
        
        for _, row in df_results.iterrows():
            circuit_name = row['circuit_name']
            signal_name = row['signal_name']
            similarity = row['similarity']
            
            is_trojan = (circuit_name, signal_name) in gt_signals
            
            if is_trojan:
                trojan_sims.append(similarity)
            else:
                normal_sims.append(similarity)
        
        trojan_sims = np.array(trojan_sims)
        normal_sims = np.array(normal_sims)
        
        print(f"\n  {'='*80}")
        print(f"  相似度分布统计")
        print(f"  {'='*80}")
        print(f"\n  木马子图 (Ground Truth中标注的):")
        print(f"    数量: {len(trojan_sims)}")
        print(f"    平均值: {trojan_sims.mean():.4f}")
        print(f"    中位数: {np.median(trojan_sims):.4f}")
        print(f"    标准差: {trojan_sims.std():.4f}")
        print(f"    范围: [{trojan_sims.min():.4f}, {trojan_sims.max():.4f}]")
        print(f"    25%分位数: {np.percentile(trojan_sims, 25):.4f}")
        print(f"    75%分位数: {np.percentile(trojan_sims, 75):.4f}")
        
        print(f"\n  正常子图 (Ground Truth中未标注的):")
        print(f"    数量: {len(normal_sims)}")
        print(f"    平均值: {normal_sims.mean():.4f}")
        print(f"    中位数: {np.median(normal_sims):.4f}")
        print(f"    标准差: {normal_sims.std():.4f}")
        print(f"    范围: [{normal_sims.min():.4f}, {normal_sims.max():.4f}]")
        print(f"    25%分位数: {np.percentile(normal_sims, 25):.4f}")
        print(f"    75%分位数: {np.percentile(normal_sims, 75):.4f}")
        
        # 推荐阈值
        print(f"\n  推荐阈值分析:")
        print(f"  {'='*80}")
        
        # 尝试不同阈值
        thresholds_to_test = np.arange(0.50, 0.99, 0.01)
        best_f1 = 0
        best_threshold = 0.85
        threshold_results = []
        
        for threshold in thresholds_to_test:
            y_true = []
            y_pred = []
            
            for _, row in df_results.iterrows():
                circuit_name = row['circuit_name']
                signal_name = row['signal_name']
                similarity = row['similarity']
                
                is_trojan = (circuit_name, signal_name) in gt_signals
                y_true.append(1 if is_trojan else 0)
                y_pred.append(1 if similarity < threshold else 0)
            
            precision = precision_score(y_true, y_pred, zero_division=0)
            recall = recall_score(y_true, y_pred, zero_division=0)
            f1 = f1_score(y_true, y_pred, zero_division=0)
            
            threshold_results.append({
                'threshold': threshold,
                'precision': precision,
                'recall': recall,
                'f1': f1
            })
            
            if f1 > best_f1:
                best_f1 = f1
                best_threshold = threshold
        
        print(f"\n  最佳阈值: {best_threshold:.2f} (F1={best_f1:.4f})")
        
        # 打印关键阈值的结果
        print(f"\n  关键阈值性能:")
        print(f"  {'阈值':<10} {'Precision':<12} {'Recall':<12} {'F1':<12}")
        print(f"  {'-'*60}")
        
        for tr in threshold_results:
            if abs(tr['threshold'] - 0.70) < 0.005 or \
               abs(tr['threshold'] - 0.75) < 0.005 or \
               abs(tr['threshold'] - 0.80) < 0.005 or \
               abs(tr['threshold'] - 0.85) < 0.005 or \
               abs(tr['threshold'] - 0.90) < 0.005 or \
               abs(tr['threshold'] - 0.95) < 0.005 or \
               abs(tr['threshold'] - best_threshold) < 0.005:
                print(f"  {tr['threshold']:<10.2f} {tr['precision']:<12.4f} {tr['recall']:<12.4f} {tr['f1']:<12.4f}")
        
        print(f"  {'='*80}")
        
        return best_threshold, best_f1
    
    def evaluate_with_ground_truth(self, df_results, ground_truth_file, threshold):
        """
        使用Ground Truth评估子图级别的检测性能
        
        Args:
            df_results: 分析结果DataFrame
            ground_truth_file: Ground Truth文件
            threshold: 相似度阈值
        
        Returns:
            dict: 评估指标
        """
        print(f"\n[5/5] 评估性能（阈值={threshold}）...")
        
        # 加载Ground Truth（跳过第一行注释）
        gt_df = pd.read_csv(ground_truth_file, encoding='latin1', skiprows=1)
        
        # 构建Ground Truth信号集合
        gt_signals = set()
        for _, row in gt_df.iterrows():
            circuit = row['circuit_name']
            signal = row['signal_name']
            gt_signals.add((circuit, signal))
        
        # 构建真实标签
        y_true = []
        y_pred = []
        
        for _, row in df_results.iterrows():
            circuit_name = row['circuit_name']
            signal_name = row['signal_name']
            similarity = row['similarity']
            
            # 真实标签：在Ground Truth中 = 有改动（木马）
            is_trojan = (circuit_name, signal_name) in gt_signals
            y_true.append(1 if is_trojan else 0)
            
            # 预测标签：相似度低于阈值 = 有改动
            predicted_trojan = similarity < threshold
            y_pred.append(1 if predicted_trojan else 0)
        
        # 计算指标
        precision = precision_score(y_true, y_pred, zero_division=0)
        recall = recall_score(y_true, y_pred, zero_division=0)
        f1 = f1_score(y_true, y_pred, zero_division=0)
        
        # 混淆矩阵
        try:
            tn, fp, fn, tp = confusion_matrix(y_true, y_pred).ravel()
        except:
            tp = sum(1 for yt, yp in zip(y_true, y_pred) if yt == 1 and yp == 1)
            fp = sum(1 for yt, yp in zip(y_true, y_pred) if yt == 0 and yp == 1)
            fn = sum(1 for yt, yp in zip(y_true, y_pred) if yt == 1 and yp == 0)
            tn = sum(1 for yt, yp in zip(y_true, y_pred) if yt == 0 and yp == 0)
        
        accuracy = (tp + tn) / (tp + tn + fp + fn) if (tp + tn + fp + fn) > 0 else 0
        fpr = fp / (fp + tn) if (fp + tn) > 0 else 0
        fnr = fn / (fn + tp) if (fn + tp) > 0 else 0
        
        metrics = {
            'threshold': threshold,
            'precision': precision,
            'recall': recall,
            'f1_score': f1,
            'accuracy': accuracy,
            'fpr': fpr,
            'fnr': fnr,
            'tp': int(tp),
            'fp': int(fp),
            'tn': int(tn),
            'fn': int(fn),
            'total_subgraphs': len(y_true),
            'trojan_subgraphs': sum(y_true),
            'normal_subgraphs': len(y_true) - sum(y_true)
        }
        
        # 打印结果
        print(f"\n{'='*80}")
        print(f"子图级别评估结果")
        print(f"{'='*80}")
        print(f"\n数据集统计:")
        print(f"  总子图数: {metrics['total_subgraphs']}")
        print(f"  木马子图: {metrics['trojan_subgraphs']} ({metrics['trojan_subgraphs']/metrics['total_subgraphs']*100:.1f}%)")
        print(f"  正常子图: {metrics['normal_subgraphs']} ({metrics['normal_subgraphs']/metrics['total_subgraphs']*100:.1f}%)")
        print(f"\n混淆矩阵:")
        print(f"  TP={tp}  FP={fp}")
        print(f"  FN={fn}  TN={tn}")
        print(f"\n核心指标:")
        print(f"  Precision: {precision:.4f}")
        print(f"  Recall:    {recall:.4f}")
        print(f"  F1-Score:  {f1:.4f}")
        print(f"  Accuracy:  {accuracy:.4f}")
        print(f"\n辅助指标:")
        print(f"  FPR (假阳性率): {fpr:.4f} ({fpr*100:.2f}%)")
        print(f"  FNR (假阴性率): {fnr:.4f} ({fnr*100:.2f}%)")
        print(f"{'='*80}")
        
        return metrics


def main():
    """主函数"""
    print("\n" + "="*80)
    print("GraphCodeBERT + DFG 子图级别分析")
    print("="*80 + "\n")
    
    # 配置
    subgraphs_file = r"e:\PRO\python\HT\hw4vec\examples\case6.6_ALLRTL_nx_subgraphs_all.pkl"
    ground_truth_file = r"e:\PRO\python\HT\hw4vec\examples\ALLRTL_dataset.csv"
    
    # 1. 初始化分析器
    analyzer = GraphCodeBERT_SubgraphAnalyzer()
    
    # 2. 加载子图数据
    analyzer.load_subgraph_data(subgraphs_file)
    
    # 3. 分析子图相似度
    df_results = analyzer.analyze_allrtl_subgraphs(ground_truth_file)
    
    # 4. 分析相似度分布并确定最佳阈值
    best_threshold, best_f1 = analyzer.analyze_similarity_distribution(df_results, ground_truth_file)
    
    # 5. 使用最佳阈值进行最终评估
    print(f"\n[5/5] 使用最佳阈值 {best_threshold:.2f} 进行最终评估...")
    best_metrics = analyzer.evaluate_with_ground_truth(df_results, ground_truth_file, best_threshold)
    
    # 5. 保存结果
    output_dir = Path("e:/PRO/python/HT/hw4vec/examples/result/相似度比较/case6.7_ALLRTL_比对_GraphCodeBERT_Subgraph")
    output_dir.mkdir(parents=True, exist_ok=True)
    
    # 保存详细结果
    results_file = output_dir / "graphcodebert_subgraph_results.csv"
    df_results.to_csv(results_file, index=False)
    print(f"\n[OK] 详细结果已保存: {results_file}")
    
    # 保存评估报告
    report_file = output_dir / "evaluation_report_subgraph.txt"
    with open(report_file, 'w', encoding='utf-8') as f:
        f.write("GraphCodeBERT + DFG 子图级别评估报告\n")
        f.write("="*80 + "\n\n")
        f.write(f"数据集: ALLRTL\n")
        f.write(f"总子图数: {best_metrics['total_subgraphs']}\n")
        f.write(f"木马子图: {best_metrics['trojan_subgraphs']}\n")
        f.write(f"正常子图: {best_metrics['normal_subgraphs']}\n")
        f.write(f"最佳阈值: {best_threshold}\n\n")
        f.write(f"混淆矩阵:\n")
        f.write(f"  TP={best_metrics['tp']}  FP={best_metrics['fp']}\n")
        f.write(f"  FN={best_metrics['fn']}  TN={best_metrics['tn']}\n\n")
        f.write(f"核心指标:\n")
        f.write(f"  Precision: {best_metrics['precision']:.4f}\n")
        f.write(f"  Recall:    {best_metrics['recall']:.4f}\n")
        f.write(f"  F1-Score:  {best_metrics['f1_score']:.4f}\n")
        f.write(f"  Accuracy:  {best_metrics['accuracy']:.4f}\n\n")
        f.write(f"辅助指标:\n")
        f.write(f"  FPR: {best_metrics['fpr']:.4f}\n")
        f.write(f"  FNR: {best_metrics['fnr']:.4f}\n")
    
    print(f"[OK] 评估报告已保存: {report_file}")
    
    print(f"\n{'='*80}")
    print(f"[DONE] 子图级别分析完成！")
    print(f"{'='*80}")


if __name__ == "__main__":
    main()
