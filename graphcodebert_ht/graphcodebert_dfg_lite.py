"""
GraphCodeBERT + Verilog DFG 简化版分析脚本（方案3）

特点：
✅ 不依赖新版torch（兼容HW4VEC的torch 1.6.0）
✅ 使用DFG统计特征模拟嵌入
✅ 完整验证流程：DFG提取 → 特征编码 → 相似度计算 → Ground Truth评估
✅ 后续可轻松替换为真实GraphCodeBERT

工作流程：
1. 加载已有的NetworkX DFG图数据
2. 从DFG图中提取统计特征（节点数、边数、数据流等）
3. 将特征编码为向量（模拟GraphCodeBERT的768维嵌入）
4. 计算电路对相似度
5. 输出Precision/Recall/F1评估指标
"""

import os
import sys
import time
import pickle
import numpy as np
import pandas as pd
from pathlib import Path
from collections import defaultdict
from sklearn.metrics.pairwise import cosine_similarity
from sklearn.metrics import precision_score, recall_score, f1_score, confusion_matrix


class GraphCodeBERT_VerilogAnalyzer_Lite:
    """
    GraphCodeBERT + Verilog DFG 分析器（简化版）
    
    使用DFG统计特征模拟GraphCodeBERT的嵌入表示
    """
    
    def __init__(self):
        print("="*80)
        print("GraphCodeBERT + Verilog DFG 分析器（简化版）")
        print("="*80)
        print("\n说明:")
        print("  - 使用DFG统计特征模拟嵌入（不依赖新版torch）")
        print("  - 完整验证分析流程")
        print("  - 后续可替换为真实GraphCodeBERT模型\n")
        
        # DFG数据缓存
        self.nx_graphs_all = []
        self.nx_subgraphs_all = []
        self.dfg_cache = {}
        
        # Verilog代码缓存
        self.code_cache = {}
        
        # 特征向量缓存
        self.feature_cache = {}
    
    def load_dfg_data(self, subgraphs_file, graphs_file=None):
        """
        加载DFG图数据
        
        Args:
            subgraphs_file: 子图DFG文件路径（.pkl）
            graphs_file: 整体图DFG文件路径（可选）
        """
        print(f"\n[1/6] 加载DFG图数据...")
        print(f"  子图文件: {subgraphs_file}")
        
        with open(subgraphs_file, 'rb') as f:
            self.nx_subgraphs_all = pickle.load(f)
        
        print(f"  [OK] 加载 {len(self.nx_subgraphs_all)} 个子图")
        
        if graphs_file and os.path.exists(graphs_file):
            with open(graphs_file, 'rb') as f:
                self.nx_graphs_all = pickle.load(f)
            print(f"  [OK] 加载 {len(self.nx_graphs_all)} 个整体图")
        
        # 构建DFG缓存
        self._build_dfg_cache()
    
    def _build_dfg_cache(self):
        """构建DFG缓存，按电路名称组织"""
        print(f"\n[2/6] 构建DFG缓存...")
        
        for nx_graph in self.nx_subgraphs_all:
            circuit_name = nx_graph.name
            
            if circuit_name not in self.dfg_cache:
                self.dfg_cache[circuit_name] = {
                    'subgraphs': [],
                    'nodes': set(),
                    'edges': [],
                    'dataflow_edges': [],
                    'node_types': defaultdict(int),
                    'edge_types': defaultdict(int),
                    'signal_names': set()
                }
            
            self.dfg_cache[circuit_name]['subgraphs'].append(nx_graph)
            
            # 收集节点和边
            for node in nx_graph.nodes():
                self.dfg_cache[circuit_name]['nodes'].add(node)
                # 提取信号名
                self.dfg_cache[circuit_name]['signal_names'].add(str(node))
            
            for u, v, data in nx_graph.edges(data=True):
                edge_info = {
                    'source': u,
                    'target': v,
                    'type': data.get('type', 'unknown'),
                    'data': data
                }
                self.dfg_cache[circuit_name]['edges'].append(edge_info)
                
                # 统计边类型
                edge_type = str(data.get('type', 'unknown'))
                self.dfg_cache[circuit_name]['edge_types'][edge_type] += 1
                
                # 识别数据流边
                if 'data' in edge_type.lower() or 'flow' in edge_type.lower():
                    self.dfg_cache[circuit_name]['dataflow_edges'].append((u, v))
            
            # 统计节点类型
            for node in nx_graph.nodes():
                node_str = str(node).lower()
                if 'clk' in node_str:
                    self.dfg_cache[circuit_name]['node_types']['clock'] += 1
                elif 'rst' in node_str or 'reset' in node_str:
                    self.dfg_cache[circuit_name]['node_types']['reset'] += 1
                elif 'input' in node_str:
                    self.dfg_cache[circuit_name]['node_types']['input'] += 1
                elif 'output' in node_str:
                    self.dfg_cache[circuit_name]['node_types']['output'] += 1
                else:
                    self.dfg_cache[circuit_name]['node_types']['internal'] += 1
        
        print(f"  [OK] 缓存 {len(self.dfg_cache)} 个电路的DFG数据")
        
        # 打印统计信息
        print(f"\n  DFG统计示例（前3个电路）:")
        for name in sorted(self.dfg_cache.keys())[:3]:
            info = self.dfg_cache[name]
            print(f"    - {name}:")
            print(f"      节点数: {len(info['nodes'])}, 边数: {len(info['edges'])}")
            print(f"      数据流边: {len(info['dataflow_edges'])}")
            print(f"      信号数: {len(info['signal_names'])}")
    
    def extract_dfg_features(self, circuit_name, base_name=None):
        """
        从DFG提取特征向量（模拟GraphCodeBERT的嵌入）
        
        改进策略：不仅提取绝对特征，还提取相对于基准电路的差异特征
        
        特征设计（100维）：
        - 基本统计特征（10维）
        - 节点类型分布（10维）
        - 边类型分布（20维）
        - 数据流特征（20维）
        - 信号名特征（20维）
        - 图结构特征（20维）
        
        Args:
            circuit_name: 电路名称
            base_name: 基准电路名称（用于计算差异特征）
        
        Returns:
            numpy.ndarray: 100维特征向量
        """
        # 如果是配对分析，计算差异特征
        if base_name and base_name in self.dfg_cache:
            return self._extract_difference_features(circuit_name, base_name)
        
        # 否则提取绝对特征
        if circuit_name in self.feature_cache:
            return self.feature_cache[circuit_name]
        
        if circuit_name not in self.dfg_cache:
            return np.zeros(100)
        
        info = self.dfg_cache[circuit_name]
        features = []
        
        # ========== 特征组1: 基本统计（10维）==========
        num_nodes = len(info['nodes'])
        num_edges = len(info['edges'])
        num_dataflow = len(info['dataflow_edges'])
        num_signals = len(info['signal_names'])
        num_subgraphs = len(info['subgraphs'])
        
        features.extend([
            num_nodes / 1000.0,  # 归一化
            num_edges / 1000.0,
            num_dataflow / 500.0,
            num_signals / 1000.0,
            num_subgraphs / 100.0,
            num_edges / max(num_nodes, 1),  # 边密度
            num_dataflow / max(num_edges, 1),  # 数据流比例
            np.sqrt(num_nodes) / 10.0,
            np.log1p(num_nodes) / 10.0,
            np.log1p(num_edges) / 10.0
        ])
        
        # ========== 特征组2: 节点类型分布（10维）==========
        node_types = info['node_types']
        total_nodes = max(num_nodes, 1)
        
        features.extend([
            node_types.get('clock', 0) / total_nodes,
            node_types.get('reset', 0) / total_nodes,
            node_types.get('input', 0) / total_nodes,
            node_types.get('output', 0) / total_nodes,
            node_types.get('internal', 0) / total_nodes,
            # 二次特征
            (node_types.get('clock', 0) * node_types.get('input', 0)) / total_nodes,
            (node_types.get('clock', 0) * node_types.get('output', 0)) / total_nodes,
            node_types.get('clock', 0) / max(node_types.get('internal', 1), 1),
            node_types.get('input', 0) / max(node_types.get('output', 1), 1),
            (node_types.get('input', 0) + node_types.get('output', 0)) / total_nodes
        ])
        
        # ========== 特征组3: 边类型分布（20维）==========
        edge_types = info['edge_types']
        total_edges = max(num_edges, 1)
        
        # 统计常见边类型
        common_edge_types = ['data', 'control', 'flow', 'dependency', 'assign', 
                            'port', 'net', 'reg', 'wire', 'always']
        
        for etype in common_edge_types:
            count = sum(1 for et in edge_types.keys() if etype in et.lower())
            features.append(count / total_edges)
        
        # 填充到20维
        while len([f for f in features[-20:]]) < 20:
            features.append(0.0)
        
        # ========== 特征组4: 数据流特征（20维）==========
        dataflow_edges = info['dataflow_edges']
        
        if dataflow_edges:
            # 计算入度和出度
            in_degree = defaultdict(int)
            out_degree = defaultdict(int)
            
            for src, tgt in dataflow_edges:
                out_degree[src] += 1
                in_degree[tgt] += 1
            
            # 统计特征
            in_values = list(in_degree.values()) if in_degree else [0]
            out_values = list(out_degree.values()) if out_degree else [0]
            
            features.extend([
                len(in_degree) / max(num_nodes, 1),  # 有入度的节点比例
                len(out_degree) / max(num_nodes, 1),  # 有出度的节点比例
                np.mean(in_values) / 10.0,
                np.max(in_values) / 50.0,
                np.mean(out_values) / 10.0,
                np.max(out_values) / 50.0,
                np.std(in_values) / 10.0 if len(in_values) > 1 else 0,
                np.std(out_values) / 10.0 if len(out_values) > 1 else 0,
                # 扇入扇出特征
                sum(1 for v in in_values if v > 1) / max(len(in_values), 1),
                sum(1 for v in out_values if v > 1) / max(len(out_values), 1),
            ])
            
            # 填充到20维
            while len([f for f in features[-20:]]) < 20:
                features.append(0.0)
        else:
            features.extend([0.0] * 20)
        
        # ========== 特征组5: 信号名特征（20维）==========
        signal_names = info['signal_names']
        
        # 信号名统计
        signal_lengths = [len(s) for s in signal_names]
        has_bus = sum(1 for s in signal_names if '[' in s)
        has_clk = sum(1 for s in signal_names if 'clk' in s.lower())
        has_rst = sum(1 for s in signal_names if 'rst' in s.lower() or 'reset' in s.lower())
        
        features.extend([
            np.mean(signal_lengths) / 20.0 if signal_lengths else 0,
            np.max(signal_lengths) / 50.0 if signal_lengths else 0,
            np.min(signal_lengths) / 20.0 if signal_lengths else 0,
            np.std(signal_lengths) / 10.0 if len(signal_lengths) > 1 else 0,
            has_bus / max(num_signals, 1),
            has_clk / max(num_signals, 1),
            has_rst / max(num_signals, 1),
            # 信号名前缀统计
            sum(1 for s in signal_names if s.startswith('i_') or s.startswith('in_')) / max(num_signals, 1),
            sum(1 for s in signal_names if s.startswith('o_') or s.startswith('out_')) / max(num_signals, 1),
            sum(1 for s in signal_names if s.startswith('w_') or s.startswith('wire_')) / max(num_signals, 1),
        ])
        
        # 填充到20维
        while len([f for f in features[-20:]]) < 20:
            features.append(0.0)
        
        # ========== 特征组6: 图结构特征（20维）==========
        # 简化的图结构特征
        avg_degree = (2 * num_edges) / max(num_nodes, 1)
        
        features.extend([
            avg_degree / 10.0,
            np.log1p(avg_degree) / 5.0,
            num_nodes / max(num_edges, 1),
            num_edges / max(num_nodes**2, 1),  # 图密度
            # 子图分布特征
            num_subgraphs / max(num_nodes, 1),
            np.log1p(num_subgraphs) / 5.0,
            # 复杂度指标
            (num_nodes + num_edges) / 1000.0,
            (num_nodes * num_edges) / 100000.0,
            np.sqrt(num_nodes * num_edges) / 100.0,
            num_dataflow / max(num_nodes, 1),
        ])
        
        # 填充到20维
        while len([f for f in features[-20:]]) < 20:
            features.append(0.0)
        
        # 确保正好100维
        features = features[:100]
        while len(features) < 100:
            features.append(0.0)
        
        feature_vector = np.array(features, dtype=np.float32).reshape(1, -1)
        
        # 缓存
        self.feature_cache[circuit_name] = feature_vector
        
        return feature_vector
    
    def _extract_difference_features(self, circuit_in_name, circuit_free_name):
        """
        提取两个电路之间的差异特征（关键改进！）
        
        这个方法的思路：
        - 不是分别提取两个电路的特征然后比较
        - 而是直接提取它们之间的差异作为特征
        - 这样更能捕捉到改动的本质
        
        Args:
            circuit_in_name: 变体电路
            circuit_free_name: 基准电路
        
        Returns:
            numpy.ndarray: 100维差异特征向量
        """
        cache_key = f"{circuit_in_name}_vs_{circuit_free_name}"
        if cache_key in self.feature_cache:
            return self.feature_cache[cache_key]
        
        info_in = self.dfg_cache.get(circuit_in_name, {})
        info_free = self.dfg_cache.get(circuit_free_name, {})
        
        if not info_in or not info_free:
            return np.zeros(100)
        
        features = []
        
        # ========== 差异特征组1: 规模差异（20维）==========
        nodes_in = len(info_in.get('nodes', set()))
        nodes_free = len(info_free.get('nodes', set()))
        edges_in = len(info_in.get('edges', []))
        edges_free = len(info_free.get('edges', []))
        signals_in = len(info_in.get('signal_names', set()))
        signals_free = len(info_free.get('signal_names', set()))
        subgraphs_in = len(info_in.get('subgraphs', []))
        subgraphs_free = len(info_free.get('subgraphs', []))
        
        # 绝对差异
        features.extend([
            abs(nodes_in - nodes_free) / 100.0,
            abs(edges_in - edges_free) / 100.0,
            abs(signals_in - signals_free) / 100.0,
            abs(subgraphs_in - subgraphs_free) / 10.0,
            # 相对差异
            (nodes_in - nodes_free) / max(nodes_free, 1),
            (edges_in - edges_free) / max(edges_free, 1),
            (signals_in - signals_free) / max(signals_free, 1),
            (subgraphs_in - subgraphs_free) / max(subgraphs_free, 1),
            # 比值
            nodes_in / max(nodes_free, 1),
            edges_in / max(edges_free, 1),
            signals_in / max(signals_free, 1),
            subgraphs_in / max(subgraphs_free, 1),
            # 二次特征
            abs(nodes_in - nodes_free) * abs(edges_in - edges_free) / 10000.0,
            (nodes_in + edges_in) / max(nodes_free + edges_free, 1),
            np.log1p(abs(nodes_in - nodes_free)) / 5.0,
            np.log1p(abs(edges_in - edges_free)) / 5.0,
        ])
        
        # 填充到20维
        while len(features) < 20:
            features.append(0.0)
        
        # ========== 差异特征组2: 信号集合差异（30维）==========
        signals_in_set = info_in.get('signal_names', set())
        signals_free_set = info_free.get('signal_names', set())
        
        # 集合运算
        added_signals = signals_in_set - signals_free_set  # 新增的信号
        removed_signals = signals_free_set - signals_in_set  # 删除的信号
        common_signals = signals_in_set & signals_free_set  # 共同的信号
        
        features.extend([
            len(added_signals) / max(signals_in, 1),  # 新增比例
            len(removed_signals) / max(signals_free, 1),  # 删除比例
            len(common_signals) / max(signals_in, 1),  # 保留比例
            len(common_signals) / max(signals_free, 1),
            # Jaccard相似度
            len(common_signals) / max(len(signals_in_set | signals_free_set), 1),
            # 信号名长度差异
            np.mean([len(s) for s in added_signals]) / 20.0 if added_signals else 0,
            np.mean([len(s) for s in removed_signals]) / 20.0 if removed_signals else 0,
        ])
        
        # 信号名前缀差异
        for prefix in ['i_', 'in_', 'o_', 'out_', 'w_', 'wire_', 'clk', 'rst', 'reset']:
            added_with_prefix = sum(1 for s in added_signals if prefix in s.lower())
            removed_with_prefix = sum(1 for s in removed_signals if prefix in s.lower())
            features.extend([
                added_with_prefix / max(len(added_signals), 1),
                removed_with_prefix / max(len(removed_signals), 1)
            ])
        
        # 填充到30维
        while len(features) < 50:
            features.append(0.0)
        
        # ========== 差异特征组3: 节点类型差异（20维）==========
        node_types_in = info_in.get('node_types', defaultdict(int))
        node_types_free = info_free.get('node_types', defaultdict(int))
        
        for ntype in ['clock', 'reset', 'input', 'output', 'internal']:
            count_in = node_types_in.get(ntype, 0)
            count_free = node_types_free.get(ntype, 0)
            features.extend([
                abs(count_in - count_free) / max(nodes_free, 1),
                (count_in - count_free) / max(count_free, 1) if count_free > 0 else 0,
                count_in / max(count_free, 1),
                count_free / max(count_in, 1)
            ])
        
        # 填充到20维
        while len(features) < 70:
            features.append(0.0)
        
        # ========== 差异特征组4: 边类型差异（20维）==========
        edge_types_in = info_in.get('edge_types', defaultdict(int))
        edge_types_free = info_free.get('edge_types', defaultdict(int))
        
        common_edge_types = ['data', 'control', 'flow', 'dependency', 'assign', 
                            'port', 'net', 'reg', 'wire', 'always']
        
        for etype in common_edge_types:
            count_in = sum(c for et, c in edge_types_in.items() if etype in et.lower())
            count_free = sum(c for et, c in edge_types_free.items() if etype in et.lower())
            features.extend([
                abs(count_in - count_free) / max(edges_free, 1),
                (count_in - count_free) / max(count_free, 1) if count_free > 0 else 0,
            ])
        
        # 填充到20维
        while len(features) < 90:
            features.append(0.0)
        
        # ========== 差异特征组5: 综合指标（10维）==========
        # 改动强度指标
        total_changes = len(added_signals) + len(removed_signals)
        features.extend([
            total_changes / max(signals_free, 1),  # 总改动比例
            total_changes / max(signals_in, 1),
            np.log1p(total_changes) / 5.0,
            # 结构变化
            abs(nodes_in - nodes_free) + abs(edges_in - edges_free) / 100.0,
            # 复杂度变化
            abs((nodes_in * edges_in) - (nodes_free * edges_free)) / 10000.0,
            # 综合评分
            (len(added_signals) * 2 + len(removed_signals)) / max(signals_free, 1),
            len(common_signals) / max(signals_in, 1),
            len(common_signals) / max(signals_free, 1),
            # 归一化改动分数
            total_changes / max(nodes_in + nodes_free, 1),
            total_changes / max(edges_in + edges_free, 1),
        ])
        
        # 确保正好100维
        features = features[:100]
        while len(features) < 100:
            features.append(0.0)
        
        feature_vector = np.array(features, dtype=np.float32).reshape(1, -1)
        
        # 缓存
        self.feature_cache[cache_key] = feature_vector
        
        return feature_vector
    
    def load_verilog_code(self, circuit_path):
        """加载Verilog代码"""
        circuit_name = Path(circuit_path).name
        topmodule_file = Path(circuit_path) / "topModule.v"
        
        if not topmodule_file.exists():
            return ""
        
        with open(topmodule_file, 'r', encoding='utf-8', errors='ignore') as f:
            code = f.read()
        
        self.code_cache[circuit_name] = code
        return code
    
    def analyze_circuit_pair(self, circuit_in_name, circuit_free_name):
        """
        分析一对电路（基准 vs 变体）
        
        Args:
            circuit_in_name: 变体电路名称
            circuit_free_name: 基准电路名称
        
        Returns:
            dict: 分析结果
        """
        start_time = time.time()
        
        # 使用差异特征（直接提取两者之间的差异）
        diff_features = self.extract_dfg_features(circuit_in_name, circuit_free_name)
        
        # 对于无改动的电路，差异特征应该接近零向量
        # 计算差异向量的范数作为"不相似度"
        diff_norm = np.linalg.norm(diff_features)
        
        # 将差异范数转换为相似度（范数越大，相似度越低）
        # 使用指数衰减函数: similarity = exp(-alpha * norm)
        alpha = 0.1  # 衰减系数
        similarity = np.exp(-alpha * diff_norm)
        
        detect_time = time.time() - start_time
        
        return {
            'circuit_name': circuit_in_name,
            'similarity': float(similarity),
            'detection_time': detect_time,
            'diff_norm': float(diff_norm),
            'has_dfg_in': circuit_in_name in self.dfg_cache,
            'has_dfg_free': circuit_free_name in self.dfg_cache
        }
    
    def analyze_allrtl_dataset(self, allrtl_dir, ground_truth_file):
        """
        分析完整的ALLRTL数据集
        
        Args:
            allrtl_dir: ALLRTL数据集目录
            ground_truth_file: Ground Truth文件路径
        
        Returns:
            pd.DataFrame: 分析结果
        """
        print(f"\n{'='*80}")
        print(f"分析ALLRTL数据集")
        print(f"{'='*80}")
        
        # 加载Ground Truth
        gt_df = pd.read_csv(ground_truth_file)
        gt_signals = {}
        for _, row in gt_df.iterrows():
            circuit = row['circuit_name']
            signal = row['signal_name']
            if circuit not in gt_signals:
                gt_signals[circuit] = set()
            gt_signals[circuit].add(signal)
        
        print(f"[OK] Ground Truth: {len(gt_signals)} 个电路, "
              f"{sum(len(s) for s in gt_signals.values())} 个信号")
        
        # 数据集路径
        tjfree_dir = Path(allrtl_dir) / "TjFree"
        tjin_dir = Path(allrtl_dir) / "TjIn"
        
        results = []
        total_start = time.time()
        
        # 遍历所有变体电路
        for circuit_in_path in sorted(tjin_dir.iterdir()):
            if not circuit_in_path.is_dir():
                continue
            
            circuit_in_name = circuit_in_path.name
            
            # 查找对应的基准电路
            base_name = circuit_in_name.split('-T')[0]
            circuit_free_path = tjfree_dir / base_name
            
            if not circuit_free_path.exists():
                print(f"  [WARN] 未找到基准电路: {base_name}")
                continue
            
            # 分析电路对
            result = self.analyze_circuit_pair(circuit_in_name, base_name)
            
            results.append(result)
            
            # 打印进度
            elapsed = time.time() - total_start
            print(f"  [{len(results):3d}] {circuit_in_name:20s} | "
                  f"sim={result['similarity']:.4f} | "
                  f"time={result['detection_time']:.4f}s | "
                  f"total={elapsed:.1f}s")
        
        # 转换为DataFrame
        df_results = pd.DataFrame(results)
        
        total_time = time.time() - total_start
        print(f"\n{'='*80}")
        print(f"分析完成")
        print(f"  总电路数: {len(df_results)}")
        print(f"  总耗时: {total_time:.2f}s")
        print(f"  平均耗时: {df_results['detection_time'].mean():.4f}s/电路")
        print(f"  平均相似度: {df_results['similarity'].mean():.4f}")
        print(f"  相似度范围: [{df_results['similarity'].min():.4f}, {df_results['similarity'].max():.4f}]")
        print(f"{'='*80}")
        
        return df_results
    
    def evaluate_with_ground_truth(self, df_results, ground_truth_file, 
                                   threshold=0.85):
        """
        使用Ground Truth评估检测性能
        
        Args:
            df_results: 分析结果DataFrame
            ground_truth_file: Ground Truth文件
            threshold: 相似度阈值（低于此值认为有改动）
        
        Returns:
            dict: 评估指标
        """
        print(f"\n{'='*80}")
        print(f"使用Ground Truth评估（阈值={threshold}）")
        print(f"{'='*80}")
        
        # 加载Ground Truth
        gt_df = pd.read_csv(ground_truth_file)
        
        # 构建真实标签
        circuits_with_changes = set(gt_df['circuit_name'].unique())
        
        y_true = []
        y_pred = []
        
        for _, row in df_results.iterrows():
            circuit_name = row['circuit_name']
            similarity = row['similarity']
            
            # 真实标签：有Ground Truth = 有改动
            has_change = circuit_name in circuits_with_changes
            y_true.append(1 if has_change else 0)
            
            # 预测标签：相似度低于阈值 = 有改动
            predicted_change = similarity < threshold
            y_pred.append(1 if predicted_change else 0)
        
        # 计算指标
        precision = precision_score(y_true, y_pred, zero_division=0)
        recall = recall_score(y_true, y_pred, zero_division=0)
        f1 = f1_score(y_true, y_pred, zero_division=0)
        
        # 处理混淆矩阵可能的错误
        try:
            tn, fp, fn, tp = confusion_matrix(y_true, y_pred).ravel()
        except:
            # 如果所有预测都是同一类
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
            'total_circuits': len(y_true)
        }
        
        # 打印结果
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
    print("GraphCodeBERT + Verilog DFG 简化版分析")
    print("="*80 + "\n")
    
    # 配置路径
    allrtl_dir = r"E:\PRO\python\HT\hw4vec\assets\ALLRTL"
    subgraphs_file = r"e:\PRO\python\HT\hw4vec\examples\case6.6_ALLRTL_nx_subgraphs_all.pkl"
    graphs_file = r"e:\PRO\python\HT\hw4vec\examples\case6.6_ALLRTL_nx_graphs_all.pkl"
    ground_truth_file = r"e:\PRO\python\HT\hw4vec\examples\ALLRTL_dataset.csv"
    
    # 1. 初始化分析器
    analyzer = GraphCodeBERT_VerilogAnalyzer_Lite()
    
    # 2. 加载DFG数据
    analyzer.load_dfg_data(subgraphs_file, graphs_file)
    
    # 3. 分析ALLRTL数据集
    df_results = analyzer.analyze_allrtl_dataset(allrtl_dir, ground_truth_file)
    
    # 4. 评估性能（尝试多个阈值）
    thresholds = [0.70, 0.75, 0.80, 0.85, 0.90, 0.95]
    best_f1 = 0
    best_threshold = 0.85
    best_metrics = None
    
    print(f"\n{'='*80}")
    print(f"阈值敏感性分析")
    print(f"{'='*80}")
    print(f"{'阈值':<10} {'Precision':<12} {'Recall':<12} {'F1':<12} {'Accuracy':<12}")
    print(f"{'-'*80}")
    
    for threshold in thresholds:
        metrics = analyzer.evaluate_with_ground_truth(df_results, ground_truth_file, threshold)
        print(f"{threshold:<10.2f} {metrics['precision']:<12.4f} {metrics['recall']:<12.4f} "
              f"{metrics['f1_score']:<12.4f} {metrics['accuracy']:<12.4f}")
        
        if metrics['f1_score'] > best_f1:
            best_f1 = metrics['f1_score']
            best_threshold = threshold
            best_metrics = metrics
    
    print(f"\n最佳阈值: {best_threshold:.2f}, F1-Score: {best_f1:.4f}")
    print(f"{'='*80}")
    
    # 5. 保存结果
    output_dir = Path("e:/PRO/python/HT/hw4vec/examples/result/相似度比较/case6.7_ALLRTL_比对_GraphCodeBERT")
    output_dir.mkdir(parents=True, exist_ok=True)
    
    # 保存详细结果
    results_file = output_dir / "graphcodebert_lite_results.csv"
    df_results.to_csv(results_file, index=False)
    print(f"\n[OK] 详细结果已保存: {results_file}")
    
    # 保存评估报告
    report_file = output_dir / "evaluation_report_lite.txt"
    with open(report_file, 'w', encoding='utf-8') as f:
        f.write("GraphCodeBERT + Verilog DFG 评估报告（简化版）\n")
        f.write("="*80 + "\n\n")
        f.write(f"数据集: ALLRTL\n")
        f.write(f"电路数: {len(df_results)}\n")
        f.write(f"最佳阈值: {best_threshold}\n\n")
        
        if best_metrics:
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
            f.write(f"  FNR: {best_metrics['fnr']:.4f}\n\n")
        
        f.write(f"说明:\n")
        f.write(f"  - 使用DFG统计特征模拟GraphCodeBERT嵌入\n")
        f.write(f"  - 不依赖新版torch，兼容HW4VEC环境\n")
        f.write(f"  - 后续可替换为真实GraphCodeBERT模型\n")
    
    print(f"[OK] 评估报告已保存: {report_file}")
    
    print(f"\n{'='*80}")
    print(f"[DONE] 分析完成！")
    print(f"{'='*80}")


if __name__ == "__main__":
    main()
