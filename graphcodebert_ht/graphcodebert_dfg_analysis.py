"""
GraphCodeBERT + Verilog DFG 完整分析脚本

利用已有的ALLRTL数据集DFG图数据，结合GraphCodeBERT进行Verilog代码分析。

数据源：
- case6.6_ALLRTL_nx_subgraphs_all.pkl: 子图级别DFG
- case6.6_ALLRTL_nx_graphs_all.pkl: 电路级别DFG
- ALLRTL数据集: TjFree（基准）和 TjIn（变体）

工作流程：
1. 加载已有的NetworkX DFG图数据
2. 从DFG图中提取数据流信息
3. 将数据流编码为文本，附加到Verilog代码
4. 使用GraphCodeBERT获取增强嵌入
5. 计算电路对相似度
6. 输出Precision/Recall/F1评估指标
"""

import os
import sys
import time
import pickle
import torch
import numpy as np
import pandas as pd
from pathlib import Path
from collections import defaultdict
from transformers import AutoTokenizer, AutoModel
from sklearn.metrics.pairwise import cosine_similarity
from sklearn.metrics import precision_score, recall_score, f1_score, confusion_matrix


class GraphCodeBERT_VerilogAnalyzer:
    """GraphCodeBERT + Verilog DFG 分析器"""
    
    def __init__(self, model_name="microsoft/graphcodebert-base", use_gpu=True):
        """
        初始化模型
        
        Args:
            model_name: 预训练模型名称
            use_gpu: 是否使用GPU
        """
        print("="*80)
        print("GraphCodeBERT + Verilog DFG 分析器初始化")
        print("="*80)
        
        # 设备配置
        self.device = torch.device("cuda" if use_gpu and torch.cuda.is_available() else "cpu")
        print(f"\n[1/4] 设备: {self.device}")
        
        # 加载模型
        print(f"[2/4] 加载预训练模型: {model_name}")
        self.tokenizer = AutoTokenizer.from_pretrained(model_name)
        self.model = AutoModel.from_pretrained(model_name)
        self.model.to(self.device)
        self.model.eval()
        print(f"  ✓ 模型加载完成")
        
        # DFG数据缓存
        self.nx_graphs_all = []
        self.nx_subgraphs_all = []
        self.dfg_cache = {}
        
        print(f"[3/4] DFG数据缓存: 已就绪")
        print(f"[4/4] 分析器初始化完成 ✓\n")
    
    def load_dfg_data(self, subgraphs_file, graphs_file=None):
        """
        加载已有的DFG图数据
        
        Args:
            subgraphs_file: 子图DFG文件路径
            graphs_file: 整体图DFG文件路径（可选）
        """
        print(f"\n加载DFG图数据...")
        print(f"  子图文件: {subgraphs_file}")
        
        with open(subgraphs_file, 'rb') as f:
            self.nx_subgraphs_all = pickle.load(f)
        
        print(f"  ✓ 加载 {len(self.nx_subgraphs_all)} 个子图")
        
        if graphs_file and os.path.exists(graphs_file):
            with open(graphs_file, 'rb') as f:
                self.nx_graphs_all = pickle.load(f)
            print(f"  ✓ 加载 {len(self.nx_graphs_all)} 个整体图")
        
        # 构建DFG缓存：按电路名称组织
        self._build_dfg_cache()
    
    def _build_dfg_cache(self):
        """构建DFG缓存，按电路名称组织"""
        print(f"\n构建DFG缓存...")
        
        for nx_graph in self.nx_subgraphs_all:
            circuit_name = nx_graph.name
            
            if circuit_name not in self.dfg_cache:
                self.dfg_cache[circuit_name] = {
                    'subgraphs': [],
                    'total_nodes': 0,
                    'total_edges': 0,
                    'dataflow_edges': []
                }
            
            self.dfg_cache[circuit_name]['subgraphs'].append(nx_graph)
            self.dfg_cache[circuit_name]['total_nodes'] += nx_graph.number_of_nodes()
            self.dfg_cache[circuit_name]['total_edges'] += nx_graph.number_of_edges()
            
            # 提取数据流边
            for u, v, data in nx_graph.edges(data=True):
                edge_type = data.get('type', '')
                if 'data' in str(edge_type).lower() or 'flow' in str(edge_type).lower():
                    self.dfg_cache[circuit_name]['dataflow_edges'].append((u, v))
        
        print(f"  ✓ 缓存 {len(self.dfg_cache)} 个电路的DFG数据")
        
        # 打印统计信息
        for name, info in list(self.dfg_cache.items())[:3]:
            print(f"    - {name}: {info['total_nodes']} nodes, "
                  f"{info['total_edges']} edges, "
                  f"{len(info['dataflow_edges'])} dataflow edges")
    
    def extract_dataflow_summary(self, circuit_name):
        """
        从DFG缓存中提取数据流摘要
        
        Args:
            circuit_name: 电路名称
        
        Returns:
            str: 数据流摘要文本
        """
        if circuit_name not in self.dfg_cache:
            return ""
        
        dfg_info = self.dfg_cache[circuit_name]
        
        # 策略1：简单统计
        summary_lines = [
            f"\n[DFG Summary]",
            f"Total signals: {dfg_info['total_nodes']}",
            f"Total connections: {dfg_info['total_edges']}",
            f"Data flow edges: {len(dfg_info['dataflow_edges'])}"
        ]
        
        # 策略2：关键数据流路径（前20条）
        if dfg_info['dataflow_edges']:
            summary_lines.append("\nKey data flows:")
            for src, tgt in dfg_info['dataflow_edges'][:20]:
                summary_lines.append(f"  {src} -> {tgt}")
        
        # 策略3：信号依赖统计
        signal_deps = defaultdict(set)
        for src, tgt in dfg_info['dataflow_edges']:
            signal_deps[tgt].add(src)
        
        summary_lines.append("\nSignal dependencies:")
        for signal, sources in list(signal_deps.items())[:10]:
            sources_list = ", ".join(list(sources)[:5])
            summary_lines.append(f"  {signal} depends on: [{sources_list}]")
        
        summary_lines.append("[/DFG Summary]\n")
        
        return "\n".join(summary_lines)
    
    def load_verilog_code(self, circuit_path):
        """
        加载Verilog代码
        
        Args:
            circuit_path: 电路目录路径
        
        Returns:
            str: Verilog代码文本
        """
        topmodule_file = Path(circuit_path) / "topModule.v"
        
        if not topmodule_file.exists():
            return ""
        
        with open(topmodule_file, 'r', encoding='utf-8', errors='ignore') as f:
            code = f.read()
        
        return code
    
    def get_enhanced_embedding(self, code_text, dfg_summary):
        """
        获取DFG增强的代码嵌入
        
        Args:
            code_text: Verilog代码
            dfg_summary: DFG数据流摘要
        
        Returns:
            numpy.ndarray: 768维嵌入向量
        """
        # 组合代码和DFG信息
        if dfg_summary:
            enhanced_text = code_text + dfg_summary
        else:
            enhanced_text = code_text
        
        # Tokenize
        tokens = self.tokenizer.tokenize(enhanced_text)
        
        # 截断到最大长度（保留开头和结尾）
        max_length = 512
        if len(tokens) > max_length:
            tokens = tokens[:max_length//2] + tokens[-max_length//2:]
        
        tokens_ids = self.tokenizer.convert_tokens_to_ids(tokens)
        tokens_tensor = torch.tensor([tokens_ids]).to(self.device)
        
        # 获取嵌入
        with torch.no_grad():
            outputs = self.model(tokens_tensor)
            # 使用[CLS] token的表示
            cls_embedding = outputs.last_hidden_state[:, 0, :].cpu().numpy()
        
        return cls_embedding
    
    def analyze_circuit_pair(self, circuit_in_name, circuit_free_name, 
                            code_in, code_free):
        """
        分析一对电路（基准 vs 变体）
        
        Args:
            circuit_in_name: 变体电路名称
            circuit_free_name: 基准电路名称
            code_in: 变体代码
            code_free: 基准代码
        
        Returns:
            dict: 分析结果
        """
        start_time = time.time()
        
        # 提取DFG摘要
        dfg_summary_in = self.extract_dataflow_summary(circuit_in_name)
        dfg_summary_free = self.extract_dataflow_summary(circuit_free_name)
        
        # 获取增强嵌入
        emb_in = self.get_enhanced_embedding(code_in, dfg_summary_in)
        emb_free = self.get_enhanced_embedding(code_free, dfg_summary_free)
        
        # 计算相似度
        similarity = cosine_similarity(emb_in, emb_free)[0][0]
        
        detect_time = time.time() - start_time
        
        return {
            'circuit_name': circuit_in_name,
            'similarity': similarity,
            'detection_time': detect_time,
            'has_dfg_in': bool(dfg_summary_in),
            'has_dfg_free': bool(dfg_summary_free)
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
        
        print(f"✓ Ground Truth: {len(gt_signals)} 个电路, "
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
                print(f"  ⚠️ 未找到基准电路: {base_name}")
                continue
            
            # 加载Verilog代码
            code_in = self.load_verilog_code(circuit_in_path)
            code_free = self.load_verilog_code(circuit_free_path)
            
            if not code_in or not code_free:
                print(f"  ⚠️ 代码加载失败: {circuit_in_name}")
                continue
            
            # 分析电路对
            result = self.analyze_circuit_pair(
                circuit_in_name, base_name, code_in, code_free
            )
            
            results.append(result)
            
            # 打印进度
            elapsed = time.time() - total_start
            print(f"  [{len(results):3d}] {circuit_in_name:20s} | "
                  f"sim={result['similarity']:.4f} | "
                  f"time={result['detection_time']:.3f}s | "
                  f"total={elapsed:.1f}s")
        
        # 转换为DataFrame
        df_results = pd.DataFrame(results)
        
        total_time = time.time() - total_start
        print(f"\n{'='*80}")
        print(f"分析完成")
        print(f"  总电路数: {len(df_results)}")
        print(f"  总耗时: {total_time:.2f}s")
        print(f"  平均耗时: {df_results['detection_time'].mean():.3f}s/电路")
        print(f"  平均相似度: {df_results['similarity'].mean():.4f}")
        print(f"{'='*80}")
        
        return df_results
    
    def evaluate_with_ground_truth(self, df_results, ground_truth_file, 
                                   threshold=0.85):
        """
        使用Ground Truth评估检测性能
        
        Args:
            df_results: 分析结果DataFrame
            ground_truth_file: Ground Truth文件
            threshold: 相似度阈值
        
        Returns:
            dict: 评估指标
        """
        print(f"\n{'='*80}")
        print(f"使用Ground Truth评估（阈值={threshold}）")
        print(f"{'='*80}")
        
        # 加载Ground Truth
        gt_df = pd.read_csv(ground_truth_file)
        
        # 构建真实标签
        # 有Ground Truth信号的电路 = 有改动（label=1）
        circuits_with_changes = set(gt_df['circuit_name'].unique())
        
        y_true = []
        y_pred = []
        
        for _, row in df_results.iterrows():
            circuit_name = row['circuit_name']
            similarity = row['similarity']
            
            # 真实标签
            has_change = circuit_name in circuits_with_changes
            y_true.append(1 if has_change else 0)
            
            # 预测标签（相似度低于阈值 = 有改动）
            predicted_change = similarity < threshold
            y_pred.append(1 if predicted_change else 0)
        
        # 计算指标
        precision = precision_score(y_true, y_pred, zero_division=0)
        recall = recall_score(y_true, y_pred, zero_division=0)
        f1 = f1_score(y_true, y_pred, zero_division=0)
        
        tn, fp, fn, tp = confusion_matrix(y_true, y_pred).ravel()
        
        accuracy = (tp + tn) / (tp + tn + fp + fn)
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
            'tp': tp,
            'fp': fp,
            'tn': tn,
            'fn': fn,
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
        print(f"  FPR: {fpr:.4f} ({fpr*100:.2f}%)")
        print(f"  FNR: {fnr:.4f} ({fnr*100:.2f}%)")
        print(f"{'='*80}")
        
        return metrics


def main():
    """主函数"""
    print("\n" + "="*80)
    print("GraphCodeBERT + Verilog DFG 完整分析")
    print("="*80 + "\n")
    
    # 配置
    allrtl_dir = r"E:\PRO\python\HT\hw4vec\assets\ALLRTL"
    subgraphs_file = r"e:\PRO\python\HT\hw4vec\examples\case6.6_ALLRTL_nx_subgraphs_all.pkl"
    graphs_file = r"e:\PRO\python\HT\hw4vec\examples\case6.6_ALLRTL_nx_graphs_all.pkl"
    ground_truth_file = r"e:\PRO\python\HT\hw4vec\examples\ALLRTL_dataset.csv"
    
    # 1. 初始化模型
    analyzer = GraphCodeBERT_VerilogAnalyzer(use_gpu=True)
    
    # 2. 加载DFG数据
    analyzer.load_dfg_data(subgraphs_file, graphs_file)
    
    # 3. 分析ALLRTL数据集
    df_results = analyzer.analyze_allrtl_dataset(allrtl_dir, ground_truth_file)
    
    # 4. 评估性能
    metrics = analyzer.evaluate_with_ground_truth(df_results, ground_truth_file)
    
    # 5. 保存结果
    output_dir = Path("e:/PRO/python/HT/hw4vec/examples/result/相似度比较/case6.7_ALLRTL_比对_GraphCodeBERT")
    output_dir.mkdir(parents=True, exist_ok=True)
    
    # 保存详细结果
    results_file = output_dir / "graphcodebert_results.csv"
    df_results.to_csv(results_file, index=False)
    print(f"\n✓ 详细结果已保存: {results_file}")
    
    # 保存评估报告
    report_file = output_dir / "evaluation_report.txt"
    with open(report_file, 'w', encoding='utf-8') as f:
        f.write("GraphCodeBERT + Verilog DFG 评估报告\n")
        f.write("="*80 + "\n\n")
        f.write(f"数据集: ALLRTL\n")
        f.write(f"电路数: {metrics['total_circuits']}\n")
        f.write(f"阈值: {metrics['threshold']}\n\n")
        f.write(f"混淆矩阵:\n")
        f.write(f"  TP={metrics['tp']}  FP={metrics['fp']}\n")
        f.write(f"  FN={metrics['fn']}  TN={metrics['tn']}\n\n")
        f.write(f"核心指标:\n")
        f.write(f"  Precision: {metrics['precision']:.4f}\n")
        f.write(f"  Recall:    {metrics['recall']:.4f}\n")
        f.write(f"  F1-Score:  {metrics['f1_score']:.4f}\n")
        f.write(f"  Accuracy:  {metrics['accuracy']:.4f}\n\n")
        f.write(f"辅助指标:\n")
        f.write(f"  FPR: {metrics['fpr']:.4f}\n")
        f.write(f"  FNR: {metrics['fnr']:.4f}\n")
    
    print(f"✓ 评估报告已保存: {report_file}")
    
    print(f"\n{'='*80}")
    print(f"✅ 分析完成！")
    print(f"{'='*80}")


if __name__ == "__main__":
    main()
