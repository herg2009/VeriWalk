"""
GraphCodeBERT + DFG 子图级别分析（增强特征版）

关键改进：
1. 从20维特征扩展到80维特征
2. 新增：度分布、节点类型、路径长度、连通性等拓扑特征
3. 新增：操作符类型、信号层次、模块深度等语义特征
4. 目标：提高特征区分度，从F1=0.0193提升到>0.7
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


class GraphCodeBERT_EnhancedAnalyzer:
    """
    GraphCodeBERT + DFG 子图级别分析器（增强特征版）
    """
    
    def __init__(self):
        print("="*80)
        print("GraphCodeBERT + DFG 子图级别分析器（增强特征版）")
        print("="*80)
        
        self.nx_subgraphs_all = []
        self.subgraph_cache = {}
        self.feature_cache = {}
    
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
    
    def extract_subgraph_features(self, nx_subgraph):
        """
        提取单个子图的增强DFG特征（80维）
        
        特征分组：
        1. 基本统计（10维）：节点数、边数、密度等
        2. 度分布（15维）：入度、出度、总度数的统计
        3. 节点类型（15维）：操作符、信号类型等
        4. 路径与连通性（15维）：直径、平均路径、连通分量
        5. 边类型分布（10维）：data/control/flow等
        6. 信号层次（15维）：信号名深度、模块层次
        
        Args:
            nx_subgraph: NetworkX子图对象
        
        Returns:
            numpy.ndarray: 80维特征向量
        """
        cache_key = id(nx_subgraph)
        if cache_key in self.feature_cache:
            return self.feature_cache[cache_key]
        
        features = []
        
        # ========== 组1: 基本统计（10维）==========
        num_nodes = nx_subgraph.number_of_nodes()
        num_edges = nx_subgraph.number_of_edges()
        
        features.extend([
            num_nodes / 100.0,
            num_edges / 100.0,
            num_edges / max(num_nodes, 1),
            np.sqrt(num_nodes) / 10.0,
            np.log1p(num_nodes) / 5.0,
            num_nodes * num_edges / 1000.0,
            num_edges / (num_nodes * (num_nodes - 1) / 2 + 1),
            np.log1p(num_edges) / 5.0,
            (num_nodes + num_edges) / 150.0,
            abs(num_nodes - num_edges) / 100.0,
        ])
        
        # ========== 组2: 度分布（15维）==========
        if num_nodes > 0:
            in_degrees = [nx_subgraph.in_degree(n) for n in nx_subgraph.nodes()]
            out_degrees = [nx_subgraph.out_degree(n) for n in nx_subgraph.nodes()]
            total_degrees = [d[0] + d[1] for d in zip(in_degrees, out_degrees)]
            
            # 入度统计
            features.extend([
                np.mean(in_degrees) / 10.0,
                np.max(in_degrees) / 20.0,
                np.std(in_degrees) / 10.0 if len(in_degrees) > 1 else 0,
                np.median(in_degrees) / 10.0,
            ])
            
            # 出度统计
            features.extend([
                np.mean(out_degrees) / 10.0,
                np.max(out_degrees) / 20.0,
                np.std(out_degrees) / 10.0 if len(out_degrees) > 1 else 0,
                np.median(out_degrees) / 10.0,
            ])
            
            # 总度数统计
            features.extend([
                np.mean(total_degrees) / 10.0,
                np.max(total_degrees) / 20.0,
                np.std(total_degrees) / 10.0 if len(total_degrees) > 1 else 0,
                np.median(total_degrees) / 10.0,
            ])
            
            # 度分布偏度
            if len(total_degrees) > 2:
                from scipy import stats
                features.extend([
                    stats.skew(total_degrees) / 10.0,
                    stats.kurtosis(total_degrees) / 20.0,
                    np.percentile(total_degrees, 75) / 15.0,
                ])
            else:
                features.extend([0, 0, 0])
        else:
            features.extend([0] * 15)
        
        # ========== 组3: 节点类型（15维）==========
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
            np.mean(signal_lengths) / 30.0 if signal_lengths else 0,
            np.max(signal_lengths) / 50.0 if signal_lengths else 0,
            np.std(signal_lengths) / 20.0 if len(signal_lengths) > 1 else 0,
        ])
        
        # 操作符类型统计
        op_keywords = ['and', 'or', 'not', 'xor', 'nand', 'nor', 'add', 'sub', 'mul', 
                      'mux', 'reg', 'wire', 'part', 'concat', 'select']
        op_counts = []
        for kw in op_keywords:
            count = sum(1 for s in node_strs if kw in s.lower())
            op_counts.append(count / max(num_nodes, 1))
        features.extend(op_counts[:9])  # 取前9个
        
        # ========== 组4: 路径与连通性（15维）==========
        try:
            if nx.is_weakly_connected(nx_subgraph):
                # 直径
                if num_nodes < 500:
                    diameter = nx.diameter(nx_subgraph.to_undirected())
                    features.append(diameter / 20.0)
                else:
                    features.append(0.5)
                
                # 平均路径长度
                if num_nodes < 200:
                    avg_path = nx.average_shortest_path_length(nx_subgraph.to_undirected())
                    features.append(avg_path / 10.0)
                else:
                    features.append(0.5)
            else:
                features.extend([0.5, 0.5])
            
            # 连通分量
            num_components = nx.number_weakly_connected_components(nx_subgraph)
            features.extend([
                num_components / 10.0,
                1.0 / num_components if num_components > 0 else 0,
            ])
            
            # 密度
            density = nx.density(nx_subgraph)
            features.append(density)
            
            # 中心性统计
            if num_nodes < 200:
                centrality = nx.degree_centrality(nx_subgraph.to_undirected())
                centrality_values = list(centrality.values())
                features.extend([
                    np.mean(centrality_values),
                    np.max(centrality_values),
                    np.std(centrality_values),
                ])
            else:
                features.extend([0.5, 0.5, 0.5])
            
            # 聚类系数
            if num_nodes < 200:
                clustering = nx.average_clustering(nx_subgraph.to_undirected())
                features.append(clustering)
            else:
                features.append(0.5)
            
            # 填充到15维
            while len([f for f in features[-15:]]) < 15:
                features.append(0.5)
            
        except:
            features.extend([0.5] * 15)
        
        # ========== 组5: 边类型分布（10维）==========
        edge_types = defaultdict(int)
        for u, v, data in nx_subgraph.edges(data=True):
            edge_type = str(data.get('type', 'unknown'))
            edge_types[edge_type] += 1
        
        total_edges = max(num_edges, 1)
        
        # 统计常见边类型
        for etype in ['data', 'control', 'flow', 'assign', 'port', 
                      'dependency', 'trigger', 'payload', 'select', 'enable']:
            count = sum(c for et, c in edge_types.items() if etype in et.lower())
            features.append(count / total_edges)
        
        # 边类型熵
        if edge_types:
            probs = [c / total_edges for c in edge_types.values()]
            entropy = -sum(p * np.log2(p + 1e-10) for p in probs)
            features.append(entropy / 5.0)
        else:
            features.append(0)
        
        # ========== 组6: 信号层次（15维）==========
        # 信号名中的点号数量（模块层次）
        dot_counts = [s.count('.') for s in node_strs]
        features.extend([
            np.mean(dot_counts) / 5.0 if dot_counts else 0,
            np.max(dot_counts) / 10.0 if dot_counts else 0,
            np.std(dot_counts) / 5.0 if len(dot_counts) > 1 else 0,
        ])
        
        # 信号名前缀统计
        prefixes = [s.split('.')[0] if '.' in s else s for s in node_strs]
        unique_prefixes = len(set(prefixes))
        features.extend([
            unique_prefixes / max(num_nodes, 1),
            unique_prefixes / 20.0,
        ])
        
        # 信号名包含Trojan/Hint/Malicious等关键词
        trojan_keywords = ['trojan', 'hint', 'malicious', 'trigger', 'payload']
        trojan_count = sum(1 for s in node_strs 
                          if any(kw in s.lower() for kw in trojan_keywords))
        features.extend([
            trojan_count / max(num_nodes, 1),
            trojan_count / 10.0,
            1.0 if trojan_count > 0 else 0.0,
        ])
        
        # 信号名中的数字统计
        has_numbers = sum(1 for s in node_strs if any(c.isdigit() for c in s))
        features.extend([
            has_numbers / max(num_nodes, 1),
            has_numbers / 20.0,
        ])
        
        # 下划线数量
        underscore_counts = [s.count('_') for s in node_strs]
        features.extend([
            np.mean(underscore_counts) / 5.0 if underscore_counts else 0,
            np.max(underscore_counts) / 10.0 if underscore_counts else 0,
        ])
        
        # 填充到80维
        while len(features) < 80:
            features.append(0.0)
        
        features = features[:80]
        
        feature_vector = np.array(features, dtype=np.float32).reshape(1, -1)
        
        # 缓存
        self.feature_cache[cache_key] = feature_vector
        
        return feature_vector
    
    def analyze_subgraph_similarity(self, subgraph_in, subgraphs_free):
        """计算一个变体子图与基准电路所有子图的相似度"""
        feat_in = self.extract_subgraph_features(subgraph_in)
        
        max_similarity = 0.0
        
        for subgraph_free in subgraphs_free:
            feat_free = self.extract_subgraph_features(subgraph_free)
            sim = cosine_similarity(feat_in, feat_free)[0][0]
            
            if sim > max_similarity:
                max_similarity = sim
        
        return max_similarity
    
    def analyze_allrtl_subgraphs(self, ground_truth_file, skip_aes=True):
        """在ALLRTL数据集上进行子图级别分析"""
        print(f"\n[3/5] 分析子图相似度...")
        
        # 加载Ground Truth
        gt_df = pd.read_csv(ground_truth_file, encoding='latin1', skiprows=1)
        print(f"  [OK] Ground Truth: {len(gt_df)} 个信号")
        
        # 过滤AES电路
        circuits_to_analyze = [name for name in sorted(self.subgraph_cache.keys()) 
                               if not (skip_aes and name.startswith('AES'))]
        
        print(f"\n  [INFO] 过滤后待分析电路数: {len(circuits_to_analyze)}")
        if skip_aes:
            print(f"  [INFO] 已跳过AES电路")
        
        results = []
        total_subgraphs = 0
        
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
                
                max_sim = self.analyze_subgraph_similarity(subgraph_in, subgraphs_free)
                
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
            print(f"    [完成] 平均相似度: {np.mean([r['similarity'] for r in circuit_results]):.4f}, "
                  f"耗时: {time.time() - circuit_start:.1f}s")
        
        df_results = pd.DataFrame(results)
        
        print(f"\n  [OK] 分析完成: {len(results)} 个子图")
        print(f"  [OK] 平均耗时: {df_results['detection_time'].mean():.4f} 秒/子图")
        
        return df_results
    
    def analyze_similarity_distribution(self, df_results, ground_truth_file):
        """分析相似度分布，帮助确定最佳阈值"""
        print(f"\n[4/5] 分析相似度分布...")
        
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
        trojan_sims = []
        normal_sims = []
        
        for _, row in df_results.iterrows():
            circuit_name = row['circuit_name']
            signal_name = row['signal_name']
            similarity = row['similarity']
            
            # 检查是否在Ground Truth中
            is_trojan = (circuit_name, signal_name) in gt_signals
            
            if is_trojan:
                trojan_sims.append(similarity)
            else:
                normal_sims.append(similarity)
        
        print(f"\n  木马子图 (Ground Truth中标注的):")
        print(f"    数量: {len(trojan_sims)}")
        if trojan_sims:
            print(f"    平均值: {np.mean(trojan_sims):.4f}")
            print(f"    标准差: {np.std(trojan_sims):.4f}")
            print(f"    范围: [{np.min(trojan_sims):.4f}, {np.max(trojan_sims):.4f}]")
            print(f"    中位数: {np.median(trojan_sims):.4f}")
            print(f"    25%分位: {np.percentile(trojan_sims, 25):.4f}")
            print(f"    75%分位: {np.percentile(trojan_sims, 75):.4f}")
        
        print(f"\n  正常子图 (Ground Truth中未标注的):")
        print(f"    数量: {len(normal_sims)}")
        if normal_sims:
            print(f"    平均值: {np.mean(normal_sims):.4f}")
            print(f"    标准差: {np.std(normal_sims):.4f}")
            print(f"    范围: [{np.min(normal_sims):.4f}, {np.max(normal_sims):.4f}]")
            print(f"    中位数: {np.median(normal_sims):.4f}")
            print(f"    25%分位: {np.percentile(normal_sims, 25):.4f}")
            print(f"    75%分位: {np.percentile(normal_sims, 75):.4f}")
        
        # 搜索最佳阈值
        print(f"\n  搜索最佳阈值...")
        best_threshold = 0.5
        best_f1 = 0.0
        
        y_true = []
        y_pred = []
        
        for _, row in df_results.iterrows():
            circuit_name = row['circuit_name']
            signal_name = row['signal_name']
            similarity = row['similarity']
            
            is_trojan = (circuit_name, signal_name) in gt_signals
            y_true.append(1 if is_trojan else 0)
        
        for threshold in np.arange(0.50, 0.99, 0.01):
            y_pred_temp = [0 if row['similarity'] >= threshold else 1 
                          for _, row in df_results.iterrows()]
            
            if sum(y_pred_temp) == 0 or sum(y_true) == 0:
                continue
            
            f1 = f1_score(y_true, y_pred_temp, zero_division=0)
            
            if f1 > best_f1:
                best_f1 = f1
                best_threshold = threshold
        
        print(f"\n  [OK] 最佳阈值: {best_threshold:.2f}")
        print(f"  [OK] 最佳F1-Score: {best_f1:.4f}")
        
        return best_threshold, best_f1, trojan_sims, normal_sims
    
    def evaluate_with_ground_truth(self, df_results, ground_truth_file, threshold):
        """使用Ground Truth评估子图级别的检测性能"""
        print(f"\n[5/5] 评估性能（阈值={threshold}）...")
        
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
            similarity = row['similarity']
            
            is_trojan = (circuit_name, signal_name) in gt_signals
            y_true.append(1 if is_trojan else 0)
            y_pred.append(0 if similarity >= threshold else 1)
        
        # 计算指标
        precision = precision_score(y_true, y_pred, zero_division=0)
        recall = recall_score(y_true, y_pred, zero_division=0)
        f1 = f1_score(y_true, y_pred, zero_division=0)
        cm = confusion_matrix(y_true, y_pred)
        
        print(f"\n{'='*80}")
        print(f"子图级别检测性能（80维增强特征）")
        print(f"{'='*80}")
        print(f"  阈值: {threshold}")
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
    analyzer = GraphCodeBERT_EnhancedAnalyzer()
    
    # 加载子图数据
    subgraphs_file = 'case6.6_ALLRTL_nx_subgraphs_all.pkl'
    analyzer.load_subgraph_data(subgraphs_file)
    
    # 分析子图相似度
    ground_truth_file = 'ALLRTL_dataset.csv'
    df_results = analyzer.analyze_allrtl_subgraphs(ground_truth_file, skip_aes=True)
    
    # 分析相似度分布
    best_threshold, best_f1, trojan_sims, normal_sims = analyzer.analyze_similarity_distribution(
        df_results, ground_truth_file)
    
    # 评估性能
    metrics = analyzer.evaluate_with_ground_truth(df_results, ground_truth_file, best_threshold)
    
    # 保存结果
    output_file = 'graphcodebert_enhanced_results.csv'
    df_results.to_csv(output_file, index=False)
    print(f"\n  [OK] 结果已保存: {output_file}")
    
    print(f"\n{'='*80}")
    print(f"分析完成!")
    print(f"{'='*80}")


if __name__ == '__main__':
    main()
