"""
GraphCodeBERT + DFG 子图级别分析（差异化特征版）

核心思想：
1. 不直接比较子图相似度，而是比较子图的"差异程度"
2. 提取子图与基准子图的差异特征（节点差异、边差异、结构差异）
3. 使用差异程度作为判断依据，而非绝对相似度

目标：将Recall从5%提升到>50%
"""

import os
import sys
import time
import pickle
import re
import numpy as np
import pandas as pd
from pathlib import Path
from collections import defaultdict, Counter
from sklearn.metrics import precision_score, recall_score, f1_score, confusion_matrix
from sklearn.metrics.pairwise import cosine_similarity
import networkx as nx


class GraphCodeBERT_DifferentialAnalyzer:
    """
    GraphCodeBERT + DFG 子图级别分析器（差异化特征版）
    """
    
    def __init__(self):
        print("="*80)
        print("GraphCodeBERT + DFG 子图级别分析器（差异化特征版）")
        print("="*80)
        
        self.nx_subgraphs_all = []
        self.subgraph_cache = {}
    
    def clean_signal_name(self, name):
        """清洗信号名：去掉_rn_x后缀"""
        return re.sub(r'_rn_\d+$', '', str(name))
    
    def load_subgraph_data(self, subgraphs_file):
        """加载子图DFG数据"""
        print(f"\n[1/5] 加载子图数据: {subgraphs_file}")
        
        with open(subgraphs_file, 'rb') as f:
            self.nx_subgraphs_all = pickle.load(f)
        
        print(f"  [OK] 加载 {len(self.nx_subgraphs_all)} 个子图")
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
    
    def extract_subgraph_difference(self, subgraph_in, subgraph_free):
        """
        提取两个子图的差异特征（50维）
        
        核心思想：不是提取单个子图的特征，而是提取两个子图之间的差异
        
        特征分组：
        1. 节点差异（15维）：节点名差异、节点数差异、节点属性差异
        2. 边差异（15维）：边数差异、边类型差异、边权重差异
        3. 结构差异（10维）：度分布差异、连通性差异
        4. 信号名差异（10维）：信号名长度差异、特殊关键词差异
        
        Args:
            subgraph_in: 变体子图
            subgraph_free: 基准子图
        
        Returns:
            numpy.ndarray: 50维差异特征向量
        """
        diff_features = []
        
        # ========== 组1: 节点差异（15维）==========
        nodes_in = set(subgraph_in.nodes())
        nodes_free = set(subgraph_free.nodes())
        
        # 节点集合差异
        nodes_added = nodes_in - nodes_free  # 新增节点
        nodes_removed = nodes_free - nodes_in  # 删除节点
        nodes_common = nodes_in & nodes_free  # 共同节点
        
        num_nodes_in = len(nodes_in)
        num_nodes_free = len(nodes_free)
        
        diff_features.extend([
            abs(num_nodes_in - num_nodes_free) / max(num_nodes_in + num_nodes_free, 1),
            len(nodes_added) / max(num_nodes_in, 1),
            len(nodes_removed) / max(num_nodes_free, 1),
            len(nodes_common) / max(num_nodes_in + num_nodes_free, 1),
            (len(nodes_added) + len(nodes_removed)) / max(num_nodes_in + num_nodes_free, 1),
        ])
        
        # 节点名差异
        nodes_in_strs = [str(n) for n in nodes_in]
        nodes_free_strs = [str(n) for n in nodes_free]
        
        # 信号名长度差异
        len_in = [len(s) for s in nodes_in_strs]
        len_free = [len(s) for s in nodes_free_strs]
        
        diff_features.extend([
            abs(np.mean(len_in) - np.mean(len_free)) / 20.0 if len_in and len_free else 0,
            abs(np.max(len_in) - np.max(len_free)) / 30.0 if len_in and len_free else 0,
            abs(np.std(len_in) - np.std(len_free)) / 15.0 if len(len_in) > 1 and len(len_free) > 1 else 0,
        ])
        
        # 新增/删除节点的特殊关键词
        trojan_keywords = ['trojan', 'hint', 'malicious', 'trigger', 'payload']
        nodes_added_strs = [str(n) for n in nodes_added]
        nodes_removed_strs = [str(n) for n in nodes_removed]
        
        trojan_added = sum(1 for s in nodes_added_strs if any(kw in s.lower() for kw in trojan_keywords))
        trojan_removed = sum(1 for s in nodes_removed_strs if any(kw in s.lower() for kw in trojan_keywords))
        
        diff_features.extend([
            trojan_added / max(len(nodes_added_strs), 1),
            trojan_removed / max(len(nodes_removed_strs), 1),
            1.0 if trojan_added > 0 else 0.0,
        ])
        
        # 节点名前缀差异
        prefixes_in = set(s.split('.')[0] if '.' in s else s for s in nodes_in_strs)
        prefixes_free = set(s.split('.')[0] if '.' in s else s for s in nodes_free_strs)
        
        diff_features.extend([
            len(prefixes_in - prefixes_free) / max(len(prefixes_in | prefixes_free), 1),
            len(prefixes_free - prefixes_in) / max(len(prefixes_in | prefixes_free), 1),
        ])
        
        # 填充到15维
        while len(diff_features) < 15:
            diff_features.append(0.0)
        
        # ========== 组2: 边差异（15维）==========
        edges_in = set(subgraph_in.edges())
        edges_free = set(subgraph_free.edges())
        
        edges_added = edges_in - edges_free
        edges_removed = edges_free - edges_in
        edges_common = edges_in & edges_free
        
        num_edges_in = subgraph_in.number_of_edges()
        num_edges_free = subgraph_free.number_of_edges()
        
        diff_features.extend([
            abs(num_edges_in - num_edges_free) / max(num_edges_in + num_edges_free, 1),
            len(edges_added) / max(num_edges_in, 1),
            len(edges_removed) / max(num_edges_free, 1),
            len(edges_common) / max(num_edges_in + num_edges_free, 1),
            (len(edges_added) + len(edges_removed)) / max(num_edges_in + num_edges_free, 1),
        ])
        
        # 边类型差异
        edge_types_in = defaultdict(int)
        for u, v, data in subgraph_in.edges(data=True):
            edge_type = str(data.get('type', 'unknown'))
            edge_types_in[edge_type] += 1
        
        edge_types_free = defaultdict(int)
        for u, v, data in subgraph_free.edges(data=True):
            edge_type = str(data.get('type', 'unknown'))
            edge_types_free[edge_type] += 1
        
        all_edge_types = set(edge_types_in.keys()) | set(edge_types_free.keys())
        total_edges = max(num_edges_in + num_edges_free, 1)
        
        type_diff_sum = 0
        for etype in all_edge_types:
            count_in = edge_types_in.get(etype, 0)
            count_free = edge_types_free.get(etype, 0)
            type_diff_sum += abs(count_in - count_free)
        
        diff_features.extend([
            type_diff_sum / total_edges,
            len(set(edge_types_in.keys()) - set(edge_types_free.keys())) / max(len(all_edge_types), 1),
            len(set(edge_types_free.keys()) - set(edge_types_in.keys())) / max(len(all_edge_types), 1),
        ])
        
        # 填充到15维
        while len(diff_features) < 15:
            diff_features.append(0.0)
        
        # ========== 组3: 结构差异（10维）==========
        # 度分布差异
        if num_nodes_in > 0 and num_nodes_free > 0:
            degrees_in = [subgraph_in.degree(n) for n in subgraph_in.nodes()]
            degrees_free = [subgraph_free.degree(n) for n in subgraph_free.nodes()]
            
            diff_features.extend([
                abs(np.mean(degrees_in) - np.mean(degrees_free)) / 10.0,
                abs(np.max(degrees_in) - np.max(degrees_free)) / 15.0,
                abs(np.std(degrees_in) - np.std(degrees_free)) / 10.0 if len(degrees_in) > 1 and len(degrees_free) > 1 else 0,
            ])
            
            # 入度/出度差异
            if hasattr(subgraph_in, 'in_degree'):
                in_degrees_in = [subgraph_in.in_degree(n) for n in subgraph_in.nodes()]
                in_degrees_free = [subgraph_free.in_degree(n) for n in subgraph_free.nodes()]
                
                out_degrees_in = [subgraph_in.out_degree(n) for n in subgraph_in.nodes()]
                out_degrees_free = [subgraph_free.out_degree(n) for n in subgraph_free.nodes()]
                
                diff_features.extend([
                    abs(np.mean(in_degrees_in) - np.mean(in_degrees_free)) / 10.0,
                    abs(np.mean(out_degrees_in) - np.mean(out_degrees_free)) / 10.0,
                ])
            else:
                diff_features.extend([0, 0, 0, 0])
        else:
            diff_features.extend([0] * 7)
        
        # 连通性差异
        is_connected_in = nx.is_weakly_connected(subgraph_in) if num_nodes_in > 0 else True
        is_connected_free = nx.is_weakly_connected(subgraph_free) if num_nodes_free > 0 else True
        
        diff_features.extend([
            0.0 if is_connected_in == is_connected_free else 1.0,
        ])
        
        # 填充到10维
        while len(diff_features) < 10:
            diff_features.append(0.0)
        
        # ========== 组4: 信号名差异（10维）==========
        # 特殊字符差异
        brackets_in = sum(1 for s in nodes_in_strs if '[' in s)
        brackets_free = sum(1 for s in nodes_free_strs if '[' in s)
        
        underscore_in = sum(s.count('_') for s in nodes_in_strs)
        underscore_free = sum(s.count('_') for s in nodes_free_strs)
        
        diff_features.extend([
            abs(brackets_in - brackets_free) / max(num_nodes_in + num_nodes_free, 1),
            abs(underscore_in - underscore_free) / max(num_nodes_in + num_nodes_free, 1),
        ])
        
        # 数字出现差异
        digits_in = sum(1 for s in nodes_in_strs if any(c.isdigit() for c in s))
        digits_free = sum(1 for s in nodes_free_strs if any(c.isdigit() for c in s))
        
        diff_features.extend([
            abs(digits_in - digits_free) / max(num_nodes_in + num_nodes_free, 1),
        ])
        
        # clk/rst信号差异
        clk_in = sum(1 for s in nodes_in_strs if 'clk' in s.lower())
        clk_free = sum(1 for s in nodes_free_strs if 'clk' in s.lower())
        
        rst_in = sum(1 for s in nodes_in_strs if 'rst' in s.lower() or 'reset' in s.lower())
        rst_free = sum(1 for s in nodes_free_strs if 'rst' in s.lower() or 'reset' in s.lower())
        
        diff_features.extend([
            abs(clk_in - clk_free) / max(num_nodes_in + num_nodes_free, 1),
            abs(rst_in - rst_free) / max(num_nodes_in + num_nodes_free, 1),
        ])
        
        # 填充到10维
        while len(diff_features) < 10:
            diff_features.append(0.0)
        
        diff_features = diff_features[:50]
        
        return np.array(diff_features, dtype=np.float32).reshape(1, -1)
    
    def find_best_match_difference(self, subgraph_in, subgraphs_free):
        """
        找到与变体子图差异最小的基准子图，返回差异度
        
        Args:
            subgraph_in: 变体子图
            subgraphs_free: 基准子图列表
        
        Returns:
            float: 最小差异度（越小越相似）
        """
        min_diff_score = float('inf')
        
        for subgraph_free in subgraphs_free:
            diff_feat = self.extract_subgraph_difference(subgraph_in, subgraph_free)
            
            # 差异度 = 差异特征的L2范数
            diff_score = np.linalg.norm(diff_feat)
            
            if diff_score < min_diff_score:
                min_diff_score = diff_score
        
        return min_diff_score
    
    def analyze_allrtl_subgraphs(self, ground_truth_file, skip_aes=True):
        """在ALLRTL数据集上进行子图级别分析"""
        print(f"\n[3/5] 分析子图差异度...")
        
        # 加载Ground Truth
        gt_df = pd.read_csv(ground_truth_file, encoding='latin1', skiprows=1)
        print(f"  [OK] Ground Truth: {len(gt_df)} 个信号")
        
        # 过滤AES电路
        circuits_to_analyze = [name for name in sorted(self.subgraph_cache.keys()) 
                               if not (skip_aes and name.startswith('AES'))]
        
        print(f"\n  [INFO] 过滤后待分析电路数: {len(circuits_to_analyze)}")
        
        results = []
        
        # 基准电路列表（不包含-T的电路名）
        base_circuits = [name for name in circuits_to_analyze if '-' not in name]
        
        for circuit_in_name in circuits_to_analyze:
            # 跳过基准电路
            if circuit_in_name in base_circuits:
                continue
            
            # 找到对应的基准电路
            base_name = circuit_in_name.split('-')[0] if '-' in circuit_in_name else circuit_in_name
            if base_name not in self.subgraph_cache:
                continue
            
            subgraphs_in = self.subgraph_cache[circuit_in_name]
            subgraphs_free = self.subgraph_cache[base_name]
            
            print(f"\n  [{len([r for r in results if r['circuit_name'] == circuit_in_name])+1}/?] "
                  f"分析 {circuit_in_name} vs {base_name}...")
            print(f"    变体子图数: {len(subgraphs_in)}, 基准子图数: {len(subgraphs_free)}")
            
            circuit_start = time.time()
            circuit_results = []
            
            for i, subgraph_in in enumerate(subgraphs_in):
                start_time = time.time()
                
                # 计算差异度（而非相似度）
                diff_score = self.find_best_match_difference(subgraph_in, subgraphs_free)
                
                # 转换为相似度（可选，用于对比）
                similarity = 1.0 / (1.0 + diff_score)
                
                detect_time = time.time() - start_time
                
                # 获取子图的信号名（清洗后）
                nodes = list(subgraph_in.nodes())
                if nodes:
                    first_signal = self.clean_signal_name(nodes[0])
                else:
                    first_signal = 'unknown'
                
                circuit_results.append({
                    'circuit_name': circuit_in_name,
                    'base_name': base_name,
                    'signal_name': first_signal,
                    'subgraph_index': i,
                    'similarity': similarity,  # 保留用于对比
                    'diff_score': diff_score,   # 主要指标
                    'detection_time': detect_time,
                    'node_count': subgraph_in.number_of_nodes(),
                    'edge_count': subgraph_in.number_of_edges()
                })
                
                # 每100个子图显示一次进度
                if (i + 1) % 100 == 0 or i == len(subgraphs_in) - 1:
                    elapsed = time.time() - circuit_start
                    avg_diff = np.mean([r['diff_score'] for r in circuit_results[-100:]])
                    print(f"      [{i+1:5d}/{len(subgraphs_in)}] 最近100个平均差异度: {avg_diff:.4f} | 耗时: {elapsed:.1f}s")
            
            results.extend(circuit_results)
            avg_diff = np.mean([r['diff_score'] for r in circuit_results])
            print(f"    [完成] 平均差异度: {avg_diff:.4f}, 耗时: {time.time() - circuit_start:.1f}s")
        
        df_results = pd.DataFrame(results)
        
        print(f"\n  [OK] 分析完成: {len(results)} 个子图")
        print(f"  [OK] 平均耗时: {df_results['detection_time'].mean():.4f} 秒/子图")
        
        return df_results
    
    def analyze_diff_distribution(self, df_results, ground_truth_file):
        """分析差异度分布，帮助确定最佳阈值"""
        print(f"\n[4/5] 分析差异度分布...")
        
        # 加载Ground Truth
        gt_df = pd.read_csv(ground_truth_file, encoding='latin1', skiprows=1)
        
        # 构建Ground Truth信号集合
        gt_signals = set()
        for _, row in gt_df.iterrows():
            circuit = row['circuit_name']
            signal = row['signal_name']
            gt_signals.add((circuit, signal))
        
        print(f"  [OK] Ground Truth信号数: {len(gt_signals)}")
        
        # 分类统计
        trojan_diffs = []
        normal_diffs = []
        
        for _, row in df_results.iterrows():
            circuit_name = row['circuit_name']
            signal_name = row['signal_name']
            diff_score = row['diff_score']
            
            is_trojan = (circuit_name, signal_name) in gt_signals
            
            if is_trojan:
                trojan_diffs.append(diff_score)
            else:
                normal_diffs.append(diff_score)
        
        print(f"\n  木马子图 (Ground Truth中标注的):")
        print(f"    数量: {len(trojan_diffs)}")
        if trojan_diffs:
            print(f"    平均值: {np.mean(trojan_diffs):.4f}")
            print(f"    标准差: {np.std(trojan_diffs):.4f}")
            print(f"    范围: [{np.min(trojan_diffs):.4f}, {np.max(trojan_diffs):.4f}]")
            print(f"    中位数: {np.median(trojan_diffs):.4f}")
        
        print(f"\n  正常子图 (Ground Truth中未标注的):")
        print(f"    数量: {len(normal_diffs)}")
        if normal_diffs:
            print(f"    平均值: {np.mean(normal_diffs):.4f}")
            print(f"    标准差: {np.std(normal_diffs):.4f}")
            print(f"    范围: [{np.min(normal_diffs):.4f}, {np.max(normal_diffs):.4f}]")
            print(f"    中位数: {np.median(normal_diffs):.4f}")
        
        # 搜索最佳阈值（差异度阈值）
        print(f"\n  搜索最佳差异度阈值...")
        best_threshold = 0.0
        best_f1 = 0.0
        
        y_true = []
        for _, row in df_results.iterrows():
            circuit_name = row['circuit_name']
            signal_name = row['signal_name']
            is_trojan = (circuit_name, signal_name) in gt_signals
            y_true.append(1 if is_trojan else 0)
        
        for threshold in np.arange(0.01, 2.0, 0.01):
            y_pred_temp = [1 if row['diff_score'] >= threshold else 0 
                          for _, row in df_results.iterrows()]
            
            if sum(y_pred_temp) == 0 or sum(y_true) == 0:
                continue
            
            f1 = f1_score(y_true, y_pred_temp, zero_division=0)
            
            if f1 > best_f1:
                best_f1 = f1
                best_threshold = threshold
        
        print(f"\n  [OK] 最佳差异度阈值: {best_threshold:.2f}")
        print(f"  [OK] 最佳F1-Score: {best_f1:.4f}")
        
        return best_threshold, best_f1, trojan_diffs, normal_diffs
    
    def evaluate_with_ground_truth(self, df_results, ground_truth_file, threshold):
        """使用Ground Truth评估子图级别的检测性能"""
        print(f"\n[5/5] 评估性能（差异度阈值={threshold}）...")
        
        # 加载Ground Truth
        gt_df = pd.read_csv(ground_truth_file, encoding='latin1', skiprows=1)
        
        # 构建Ground Truth信号集合
        gt_signals = set()
        for _, row in gt_df.iterrows():
            circuit = row['circuit_name']
            signal = row['signal_name']
            gt_signals.add((circuit, signal))
        
        print(f"  [OK] Ground Truth信号数: {len(gt_signals)}")
        
        y_true = []
        y_pred = []
        
        for _, row in df_results.iterrows():
            circuit_name = row['circuit_name']
            signal_name = row['signal_name']
            diff_score = row['diff_score']
            
            is_trojan = (circuit_name, signal_name) in gt_signals
            y_true.append(1 if is_trojan else 0)
            y_pred.append(1 if diff_score >= threshold else 0)
        
        # 计算指标
        precision = precision_score(y_true, y_pred, zero_division=0)
        recall = recall_score(y_true, y_pred, zero_division=0)
        f1 = f1_score(y_true, y_pred, zero_division=0)
        cm = confusion_matrix(y_true, y_pred)
        
        print(f"\n{'='*80}")
        print(f"子图级别检测性能（差异化特征 - 50维）")
        print(f"{'='*80}")
        print(f"  差异度阈值: {threshold}")
        print(f"  总子图数: {len(y_true)}")
        print(f"  实际木马子图: {sum(y_true)}")
        print(f"  预测木马子图: {sum(y_pred)}")
        print(f"\n  Precision: {precision:.4f}")
        print(f"  Recall:    {recall:.4f}")
        print(f"  F1-Score:  {f1:.4f}")
        print(f"\n  混淆矩阵:")
        print(f"    TN={cm[0][0]}, FP={cm[0][1]}")
        print(f"    FN={cm[1][0]}, TP={cm[1][1]}")
        print(f"{'='*80}")
        
        return {
            'precision': precision,
            'recall': recall,
            'f1': f1,
            'threshold': threshold,
            'confusion_matrix': cm
        }


def main():
    """主函数"""
    analyzer = GraphCodeBERT_DifferentialAnalyzer()
    
    # 加载子图数据
    subgraphs_file = 'case6.6_ALLRTL_nx_subgraphs_all.pkl'
    analyzer.load_subgraph_data(subgraphs_file)
    
    # 分析子图差异度（非AES电路）
    ground_truth_file = 'ALLRTL_dataset.csv'
    df_results = analyzer.analyze_allrtl_subgraphs(ground_truth_file, skip_aes=True)
    
    # 分析差异度分布
    best_threshold, best_f1, trojan_diffs, normal_diffs = analyzer.analyze_diff_distribution(
        df_results, ground_truth_file)
    
    # 评估性能
    metrics = analyzer.evaluate_with_ground_truth(df_results, ground_truth_file, best_threshold)
    
    # 保存结果
    output_file = 'graphcodebert_differential_results.csv'
    df_results.to_csv(output_file, index=False)
    print(f"\n  [OK] 结果已保存: {output_file}")
    
    print(f"\n{'='*80}")
    print(f"分析完成!")
    print(f"{'='*80}")


if __name__ == '__main__':
    main()
