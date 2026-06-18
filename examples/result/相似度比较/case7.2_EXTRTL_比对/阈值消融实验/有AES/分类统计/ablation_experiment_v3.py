"""
消融实验v3：基于EXTRTL数据集的消融实验（支持TjIn/TjIn2分类评估）
基于EXTRTL数据集 + 逐基准独立嵌入训练策略（参考use_case_7.2）
实验1：游走长度消融
实验2：Word2Vec向量维度消融
实验3：窗口大小消融
实验4：训练模式(CBOW vs Skip-gram)消融
实验5：检测阈值消融（分TjIn/TjIn2评估）

TjIn/TjIn2分类规则：
  TjIn  = AES + PIC16F84 + RS232 共45个变体
  TjIn2 = 其余电路 共90个变体
"""
import os, sys
os.environ['PYTHONHASHSEED'] = '42'

import time as time_module
import torch
import networkx as nx
import pandas as pd
import numpy as np
from pathlib import Path
import pickle
import random
import matplotlib
matplotlib.use('Agg')  # 非交互式后端，避免弹窗
import matplotlib.pyplot as plt

random.seed(42)
np.random.seed(42)
if torch.cuda.is_available():
    torch.cuda.manual_seed_all(42)
    torch.backends.cudnn.deterministic = True
    torch.backends.cudnn.benchmark = False

sys.path.append(os.path.dirname(sys.path[0]))
from hw2vec.config import Config
from hw2vec.hw2graph import *
from hw2vec.graphwalk import *
from hw2vec.TJDetection import *
from collections import defaultdict

_graph_drawer = GraphDrawer()


def load_ground_truth_signals(csv_path='EXTRTL_dataset.csv'):
    """加载真实标签（ground truth）"""
    ground_truth = {}
    try:
        for encoding in ['utf-8', 'gbk', 'latin-1']:
            try:
                with open(csv_path, 'r', encoding=encoding) as f:
                    first_line = f.readline().strip()
                if first_line.startswith('#'):
                    df = pd.read_csv(csv_path, encoding=encoding, skiprows=1)
                else:
                    df = pd.read_csv(csv_path, encoding=encoding)
                break
            except UnicodeDecodeError:
                continue
        
        for _, row in df.iterrows():
            if pd.isna(row.get('circuit_name')) or pd.isna(row.get('signal_name')):
                continue
            try:
                circuit_name = str(row['circuit_name']).strip()
                signal_name = str(row['signal_name']).strip()
                if not circuit_name or not signal_name or circuit_name == 'nan':
                    continue
                if circuit_name not in ground_truth:
                    ground_truth[circuit_name] = []
                ground_truth[circuit_name].append(signal_name)
            except (KeyError, AttributeError):
                continue
        print(f"加载GT: {len(ground_truth)} 个电路, {sum(len(v) for v in ground_truth.values())} 个信号")
        return ground_truth
    except Exception as e:
        print(f"加载ground truth失败: {e}")
        return {}


def clean_signal_name(node_name):
    """清理信号名（去掉_rn_0后缀）"""
    if '_rn_' in node_name:
        node_name = node_name[:node_name.index('_rn_')]
    return node_name


def extract_circuit_name(subgraph):
    """提取电路名"""
    if hasattr(subgraph, 'name') and subgraph.name:
        return subgraph.name
    return 'unknown'


def evaluate_detection(detected_signals, ground_truth, all_signals_count, circuit_name):
    """评估单个电路的检测结果"""
    if circuit_name not in ground_truth:
        return None
    
    true_signals = set(ground_truth[circuit_name])
    detected_names = set([s[1] for s in detected_signals])
    
    TP = len(detected_names & true_signals)
    FP = len(detected_names - true_signals)
    FN = len(true_signals - detected_names)
    TN = all_signals_count - TP - FP - FN if all_signals_count > 0 else 0
    
    precision = TP / (TP + FP) if (TP + FP) > 0 else 0
    recall = TP / (TP + FN) if (TP + FN) > 0 else 0
    f1 = 2 * precision * recall / (precision + recall) if (precision + recall) > 0 else 0
    fpr = FP / (FP + TN) if (FP + TN) > 0 else 0
    
    return {
        'TP': TP, 'FP': FP, 'TN': TN, 'FN': FN,
        'Precision': precision, 'Recall': recall, 'F1': f1, 'FPR': fpr
    }


def load_extrtl_data():
    """从rtl_dfg_graphs_full目录加载EXTRTL数据集"""
    RTL_OUTPUT_DIR = Path(r"Z:\vmshare\GW3\outputs\rtl_dfg_graphs_full")
    file_prefix = "EXTRTL"
    
    nx_subgraphs_all = []
    nx_graphs_all = []
    
    index_pkl = RTL_OUTPUT_DIR / f"{file_prefix}_0_index.pkl"
    if not index_pkl.exists():
        print(f"未找到索引文件: {index_pkl}")
        return nx_graphs_all, nx_subgraphs_all
    
    with open(index_pkl, 'rb') as f:
        index_data = pickle.load(f)
    print(f"从索引文件加载: {index_pkl}")
    print(f"总电路数: {index_data['total_circuits']}")
    
    for pkl_file in RTL_OUTPUT_DIR.glob(f"{file_prefix}_*.pkl"):
        if pkl_file.name.endswith('_index.pkl'):
            continue
        if 'detection_results' in pkl_file.name:
            continue
        try:
            with open(pkl_file, 'rb') as f:
                circuit_data = pickle.load(f)
            nx_subgraphs_all.extend(circuit_data['nx_subgraphs'])
            nx_graphs_all.append(circuit_data['nx_graph'])
        except Exception as e:
            print(f"加载 {pkl_file.name} 失败: {e}")
    
    print(f"已加载: {len(nx_graphs_all)} 个电路, {len(nx_subgraphs_all)} 个子图")
    return nx_graphs_all, nx_subgraphs_all


# TjIn类型的基名列表（AES, PIC16F84, RS232 属于TjIn，其余属于TjIn2）
TJIN_BASE_NAMES = {'AES', 'PIC16F84', 'RS232'}

def classify_variant_type(variant_name):
    """根据变体名称判断属于TjIn还是TjIn2"""
    base_name = variant_name.rsplit('-T', 1)[0] if '-T' in variant_name else variant_name
    return 'TjIn' if base_name in TJIN_BASE_NAMES else 'TjIn2'


def build_circuit_groups(nx_subgraphs_all):
    """预计算：按电路名分组子图，并区分TjIn/TjIn2"""
    base_circuits = {}   # {基准电路名: [子图列表]}
    trojan_circuits = {} # {木马电路名: [子图列表]}
    trojan_type = {}     # {木马电路名: 'TjIn' or 'TjIn2'}
    
    for sg in nx_subgraphs_all:
        if sg.type == 'TjFree':
            if sg.name not in ('wb_conmax',):
                base_circuits.setdefault(sg.name, []).append(sg)
        elif '-T' in sg.name:
            trojan_circuits.setdefault(sg.name, []).append(sg)
            if sg.name not in trojan_type:
                trojan_type[sg.name] = classify_variant_type(sg.name)
    
    return base_circuits, trojan_circuits, trojan_type


def run_single_variant(trojan_subgraphs, base_free_subgraphs, walk_length, vector_size, window, sg_mode):
    """
    对单个(变体, 基准)对运行检测
    参考7.2的逐基准独立嵌入训练策略
    返回: (detected_signals, total_signals_count, similarity_values)
    """
    # 矩阵退化保护
    if len(trojan_subgraphs) == 1:
        trojan_subgraphs = trojan_subgraphs + trojan_subgraphs
    if len(base_free_subgraphs) == 1:
        base_free_subgraphs = base_free_subgraphs + base_free_subgraphs
    
    Tjdet = TJDetection(Config(['--yaml_path', 'example_gnn4tj.yaml']))
    Tjdet.load_graphs(base_free_subgraphs, trojan_subgraphs)
    
    # 独立训练嵌入
    Tjdet.graph_embds_GW(
        walk_length=walk_length,
        vector_size=vector_size,
        window=window,
        sg=sg_mode,
        seed=42
    )
    
    # 计算相似度
    _, _, similarities = Tjdet.Graph_similarity(prnsimrow=False, prn='off')
    
    # 收集检测到的木马信号
    detected_signals = []
    for subgraph in Tjdet.nx_subgraphs_1:
        first_node = next(iter(subgraph.nodes()))
        signal_name = clean_signal_name(first_node)
        detected_signals.append(signal_name)
    
    n_in_orig = len(trojan_subgraphs) // 2 if len(trojan_subgraphs) > len(set(id(s) for s in trojan_subgraphs)) else len(trojan_subgraphs)
    
    return detected_signals, similarities


def run_batch_experiment(trojan_circuits, base_circuits, ground_truth, 
                         param_name, param_value, **fixed_params):
    """
    运行批次实验：遍历所有变体电路，每个变体仅与对应基准电路比对
    返回: (merged_result, stats_str)
    """
    batch_results = []
    all_similarities = []
    
    for variant_name, variant_subgraphs in sorted(trojan_circuits.items()):
        # 提取对应基准电路名（如 RS232-T100 -> RS232）
        base_name = variant_name.rsplit('-T', 1)[0] if '-T' in variant_name else variant_name
        
        if base_name not in base_circuits:
            continue
        
        base_free_subgraphs = base_circuits[base_name]
        
        try:
            # 逐基准独立训练嵌入并检测
            detected_signal_names, similarities = run_single_variant(
                list(variant_subgraphs), list(base_free_subgraphs),
                walk_length=fixed_params.get('walk_length', 0),
                vector_size=fixed_params.get('vector_size', 128),
                window=fixed_params.get('window', 3),
                sg_mode=fixed_params.get('sg', 0)
            )
            
            if similarities:
                all_similarities.extend(similarities)
            
            # 构建检测结果格式
            detected_signals = [(variant_name, sn, 0.0) for sn in detected_signal_names]
            
            # 该变体电路的总子图数
            total_signals = len(variant_subgraphs)
            
            # 评估
            result = evaluate_detection(detected_signals, ground_truth, total_signals, variant_name)
            if result:
                batch_results.append(result)
                
        except Exception as e:
            print(f"    {variant_name} 错误: {e}")
            continue
    
    if not batch_results:
        return None, ""
    
    # 合并批次结果（宏平均）
    merged = {
        'TP': sum(r['TP'] for r in batch_results),
        'FP': sum(r['FP'] for r in batch_results),
        'TN': sum(r['TN'] for r in batch_results),
        'FN': sum(r['FN'] for r in batch_results),
    }
    
    precision = merged['TP'] / (merged['TP'] + merged['FP']) if (merged['TP'] + merged['FP']) > 0 else 0
    recall = merged['TP'] / (merged['TP'] + merged['FN']) if (merged['TP'] + merged['FN']) > 0 else 0
    f1 = 2 * precision * recall / (precision + recall) if (precision + recall) > 0 else 0
    fpr = merged['FP'] / (merged['FP'] + merged['TN']) if (merged['FP'] + merged['TN']) > 0 else 0
    
    merged.update({
        'Precision': precision, 'Recall': recall, 'F1': f1, 'FPR': fpr,
        'circuit_count': len(batch_results)
    })
    
    # 相似度统计
    stats_str = ""
    if all_similarities:
        stats_str = _graph_drawer.calc_list_statistics(all_similarities, topk=0.01, prn='off')
    
    return merged, stats_str


def run_threshold_experiment(trojan_circuits, base_circuits, ground_truth,
                             thresholds, trojan_type,
                             walk_length=0, vector_size=128, window=3, sg_mode=0):
    """\n阈值消融实验：测试不同阈值条件下的检测性能\n分TjIn/TjIn2分别评估\n返回: {'ALL': {t: metrics}, 'TjIn': {t: metrics}, 'TjIn2': {t: metrics}}\n"""
    # 收集每个变体每个子图的最大相似度和信号信息
    # 格式: [(circuit_name, signal_name, max_similarity, variant_type), ...]
    all_subgraph_info = []
    
    for variant_name, variant_subgraphs in sorted(trojan_circuits.items()):
        base_name = variant_name.rsplit('-T', 1)[0] if '-T' in variant_name else variant_name
        if base_name not in base_circuits:
            continue
        
        base_free_subgraphs = base_circuits[base_name]
        trojan_list = list(variant_subgraphs)
        free_list = list(base_free_subgraphs)
        
        # 矩阵退化保护
        if len(trojan_list) == 1:
            trojan_list = trojan_list + trojan_list
        if len(free_list) == 1:
            free_list = free_list + free_list
        
        vtype = trojan_type.get(variant_name, 'TjIn2')
        
        try:
            Tjdet = TJDetection(Config(['--yaml_path', 'example_gnn4tj.yaml']))
            Tjdet.load_graphs(free_list, trojan_list)
            Tjdet.graph_embds_GW(walk_length=walk_length, vector_size=vector_size,
                                 window=window, sg=sg_mode, seed=42)
            
            # 手动计算相似度矩阵（不使用Graph_similarity的内置阈值）
            embds_in_tensor = torch.stack(Tjdet.graph_embds_in)
            embds_free_tensor = torch.stack(Tjdet.graph_embds_free)
            sim_matrix = torch.cosine_similarity(
                embds_in_tensor.unsqueeze(1), embds_free_tensor.unsqueeze(0), dim=-1
            ).squeeze(-1).detach().cpu().numpy()
            
            # 获取原始子图数（扩展前）
            n_in_orig = len(variant_subgraphs)
            
            # 收集每个子图的最大相似度和信号名
            for i in range(min(n_in_orig, sim_matrix.shape[0])):
                max_sim = float(np.max(sim_matrix[i, :]))
                first_node = next(iter(variant_subgraphs[i].nodes()))
                signal_name = clean_signal_name(first_node)
                all_subgraph_info.append((variant_name, signal_name, max_sim, vtype))
        except Exception as e:
            print(f"    {variant_name} 嵌入生成失败: {e}")
            continue
    
    if not all_subgraph_info:
        return {'ALL': {}, 'TjIn': {}, 'TjIn2': {}}
    
    # 对每个阈值，分ALL/TjIn/TjIn2分别评估
    results = {'ALL': {}, 'TjIn': {}, 'TjIn2': {}}
    
    for thresh in thresholds:
        # 按类别分别统计
        for category in ['ALL', 'TjIn', 'TjIn2']:
            total_TP = total_FP = total_FN = 0
            circuits_detected = {}
            
            for circuit_name, signal_name, max_sim, vtype in all_subgraph_info:
                if category != 'ALL' and vtype != category:
                    continue
                if circuit_name not in circuits_detected:
                    circuits_detected[circuit_name] = []
                if max_sim < thresh:
                    circuits_detected[circuit_name].append(signal_name)
            
            for circuit_name, detected_list in circuits_detected.items():
                if circuit_name not in ground_truth:
                    continue
                true_signals = set(ground_truth[circuit_name])
                detected_names = set(detected_list)
                
                total_TP += len(detected_names & true_signals)
                total_FP += len(detected_names - true_signals)
                total_FN += len(true_signals - detected_names)
            
            precision = total_TP / (total_TP + total_FP) if (total_TP + total_FP) > 0 else 0
            recall = total_TP / (total_TP + total_FN) if (total_TP + total_FN) > 0 else 0
            f1 = 2 * precision * recall / (precision + recall) if (precision + recall) > 0 else 0
            
            results[category][thresh] = {
                'TP': total_TP, 'FP': total_FP, 'FN': total_FN,
                'Precision': precision, 'Recall': recall, 'F1': f1
            }
    
    return results


def plot_threshold_results(all_results, save_path='threshold_ablation.png'):
    """绘制阈值消融实验结果图表（分ALL/TjIn/TjIn2三条线，横向3子图）"""
    if not all_results or not all_results.get('ALL'):
        return
    
    thresholds = sorted(all_results['ALL'].keys())
    categories = ['ALL', 'TjIn', 'TjIn2']
    display_names = {'ALL': 'ALL', 'TjIn': 'TrustHub', 'TjIn2': 'FreeCores'}
    colors = {'ALL': 'b', 'TjIn': 'g', 'TjIn2': 'r'}
    markers = {'ALL': 'o', 'TjIn': 's', 'TjIn2': '^'}
    
    fig, axes = plt.subplots(1, 3, figsize=(18, 5))
    
    # 辅助函数：根据实际数据范围设置Y轴刻度
    def _auto_ylim(ax, all_vals, margin=0.05):
        vmin = min(min(v) for v in all_vals if v)
        vmax = max(max(v) for v in all_vals if v)
        span = vmax - vmin if vmax > vmin else 0.1
        ax.set_ylim(max(0, vmin - span * margin), min(1.0, vmax + span * margin))
    
    # 左图：F1 vs Threshold
    ax = axes[0]
    all_f1 = []
    for cat in categories:
        vals = [all_results[cat][t]['F1'] for t in thresholds]
        all_f1.append(vals)
        ax.plot(thresholds, vals, f'{colors[cat]}-{markers[cat]}', label=display_names[cat], markersize=3)
    ax.set_xlabel('Threshold')
    ax.set_ylabel('F1 Score')
    ax.set_title('F1 vs Threshold')
    ax.legend(fontsize=8)
    ax.grid(True, alpha=0.3)
    _auto_ylim(ax, all_f1)
    
    # 中图：Recall vs Threshold
    ax = axes[1]
    all_recall = []
    for cat in categories:
        vals = [all_results[cat][t]['Recall'] for t in thresholds]
        all_recall.append(vals)
        ax.plot(thresholds, vals, f'{colors[cat]}-{markers[cat]}', label=display_names[cat], markersize=3)
    ax.set_xlabel('Threshold')
    ax.set_ylabel('Recall')
    ax.set_title('Recall vs Threshold')
    ax.legend(fontsize=8)
    ax.grid(True, alpha=0.3)
    _auto_ylim(ax, all_recall)
    
    # 右图：TP vs Threshold (ALL)
    ax = axes[2]
    tp_vals = [all_results['ALL'][t]['TP'] for t in thresholds]
    ax.plot(thresholds, tp_vals, 'b-o', label='TP', markersize=3)
    ax.set_xlabel('Threshold')
    ax.set_ylabel('TP Count')
    ax.set_title('TP vs Threshold (ALL)')
    ax.legend(fontsize=8)
    ax.grid(True, alpha=0.3)
    # 压缩Y轴
    tp_min, tp_max = min(tp_vals), max(tp_vals)
    tp_span = tp_max - tp_min if tp_max > tp_min else 5
    ax.set_ylim(max(0, tp_min - tp_span * 0.1), tp_max + tp_span * 0.1)
    
    plt.tight_layout()
    plt.savefig(save_path, dpi=150, bbox_inches='tight')
    print(f"\n图表已保存: {save_path}")
    plt.close()


def main():
    print("=" * 80)
    print("消融实验v3：基于EXTRTL数据集的消融实验")
    print("支持TjIn/TjIn2分类评估 | 逐基准独立嵌入训练")
    print("=" * 80)
    
    # 加载EXTRTL数据
    print("\n加载EXTRTL数据集...")
    nx_graphs_all, nx_subgraphs_all = load_extrtl_data()
    if not nx_subgraphs_all:
        print("数据加载失败，退出")
        return
    
    # 预计算电路分组
    base_circuits, trojan_circuits, trojan_type = build_circuit_groups(nx_subgraphs_all)
    n_tjin = sum(1 for v in trojan_type.values() if v == 'TjIn')
    n_tjin2 = sum(1 for v in trojan_type.values() if v == 'TjIn2')
    print(f"基准电路: {len(base_circuits)} 个, 木马变体: {len(trojan_circuits)} 个 (TjIn={n_tjin}, TjIn2={n_tjin2})")
    
    # 加载ground truth
    ground_truth = load_ground_truth_signals('EXTRTL_dataset.csv')
    
    # 构建测试批次
    all_variant_names = sorted(trojan_circuits.keys())
    circuit_groups = {
        'PIC16F84': [v for v in all_variant_names if v.startswith('PIC16F84')],
        'RS232': [v for v in all_variant_names if v.startswith('RS232')],
        'AES': [v for v in all_variant_names if v.startswith('AES')],
        'ALL': all_variant_names,  # 全部变体电路
        'NO_AES': [v for v in all_variant_names if not v.startswith('AES')],  # 不含AES的变体
    }
    
    # 选择测试批次（可多选）
    test_groups = ['ALL']  # 使用全部变体电路
    #test_groups = ['NO_AES']  # 不含AES的变体电路
    #test_groups = ['PIC16F84+RS232']  # 仅使用PIC16F84+RS232合并批次
    
    # 构建合并批次（若被选中）
    if 'PIC16F84+RS232' in test_groups:
        circuit_groups['PIC16F84+RS232'] = sorted(circuit_groups['PIC16F84'] + circuit_groups['RS232'])
    
    print(f"\n测试批次: {', '.join(test_groups)}")
    for group in test_groups:
        print(f"  {group}: {len(circuit_groups[group])} 个变体")
    
    # 筛选出在trojan_circuits中存在的变体
    for group in test_groups:
        circuit_groups[group] = [v for v in circuit_groups[group] if v in trojan_circuits]
    
    # 实验参数设置
    walk_lengths = [2, 3, 4, 5, 6, 0]
    vector_sizes = [64, 128, 256, 512]
    windows = [2, 3, 4, 5]
    sgs = [0, 1]
    
    # 消融实验选择（可多选）：1=游走长度, 2=向量维度, 3=窗口大小, 4=训练模式, 5=检测阈值
    #ENABLED_EXPERIMENTS = [1, 2, 3, 4, 5]  # 默认运行全部
    ENABLED_EXPERIMENTS = [5]  # 仅运行阈值消融
    
    results = []
    
    # ===== 实验1: 游走长度消融 =====
    _skip_exp1 = 1 not in ENABLED_EXPERIMENTS
    if not _skip_exp1:
        print("\n" + "=" * 80)
        print("实验1: 游走长度消融实验")
        print("=" * 80)
    
    if not _skip_exp1:
      for group_name in test_groups:
        variant_names = circuit_groups[group_name]
        test_trojans = {v: trojan_circuits[v] for v in variant_names}
        print(f"\n批次: {group_name} ({len(test_trojans)}个变体)")
        
        for wl in walk_lengths:
            print(f"  walk_length={wl}...", end=' ', flush=True)
            try:
                result, stats = run_batch_experiment(
                    test_trojans, base_circuits, ground_truth,
                    'walk_length', wl,
                    walk_length=wl, vector_size=128, window=3, sg=0
                )
                if result:
                    print(f"F1={result['F1']:.3f}, P={result['Precision']:.3f}, R={result['Recall']:.3f} {stats}")
                    results.append({
                        'batch': group_name, 'param': 'walk_length', 'value': wl,
                        'F1': result['F1'], 'Precision': result['Precision'],
                        'Recall': result['Recall'], 'FPR': result['FPR'],
                        'TP': result['TP'], 'FP': result['FP'],
                        'TN': result['TN'], 'FN': result['FN'],
                        'circuits': result['circuit_count'], 'stats': stats
                    })
                else:
                    print("无评估结果")
            except Exception as e:
                print(f"错误: {e}")
    
    # ===== 实验2: Word2Vec向量维度消融 =====
    _skip_exp2 = 2 not in ENABLED_EXPERIMENTS
    if not _skip_exp2:
        print("\n" + "=" * 80)
        print("实验2: Word2Vec向量维度消融实验")
        print("=" * 80)
    
    if not _skip_exp2:
      for group_name in test_groups:
        variant_names = circuit_groups[group_name]
        test_trojans = {v: trojan_circuits[v] for v in variant_names}
        print(f"\n批次: {group_name} ({len(test_trojans)}个变体)")
        
        for vs in vector_sizes:
            print(f"  vector_size={vs}...", end=' ', flush=True)
            try:
                result, stats = run_batch_experiment(
                    test_trojans, base_circuits, ground_truth,
                    'vector_size', vs,
                    walk_length=0, vector_size=vs, window=3, sg=0
                )
                if result:
                    print(f"F1={result['F1']:.3f}, P={result['Precision']:.3f}, R={result['Recall']:.3f} {stats}")
                    results.append({
                        'batch': group_name, 'param': 'vector_size', 'value': vs,
                        'F1': result['F1'], 'Precision': result['Precision'],
                        'Recall': result['Recall'], 'FPR': result['FPR'],
                        'TP': result['TP'], 'FP': result['FP'],
                        'TN': result['TN'], 'FN': result['FN'],
                        'circuits': result['circuit_count'], 'stats': stats
                    })
            except Exception as e:
                print(f"错误: {e}")
    
    # ===== 实验3: 窗口大小消融 =====
    _skip_exp3 = 3 not in ENABLED_EXPERIMENTS
    if not _skip_exp3:
        print("\n" + "=" * 80)
        print("实验3: Word2Vec窗口大小消融实验")
        print("=" * 80)
    
    if not _skip_exp3:
      for group_name in test_groups:
        variant_names = circuit_groups[group_name]
        test_trojans = {v: trojan_circuits[v] for v in variant_names}
        print(f"\n批次: {group_name} ({len(test_trojans)}个变体)")
        
        for w in windows:
            print(f"  window={w}...", end=' ', flush=True)
            try:
                result, stats = run_batch_experiment(
                    test_trojans, base_circuits, ground_truth,
                    'window', w,
                    walk_length=0, vector_size=128, window=w, sg=0
                )
                if result:
                    print(f"F1={result['F1']:.3f}, P={result['Precision']:.3f}, R={result['Recall']:.3f} {stats}")
                    results.append({
                        'batch': group_name, 'param': 'window', 'value': w,
                        'F1': result['F1'], 'Precision': result['Precision'],
                        'Recall': result['Recall'], 'FPR': result['FPR'],
                        'TP': result['TP'], 'FP': result['FP'],
                        'TN': result['TN'], 'FN': result['FN'],
                        'circuits': result['circuit_count'], 'stats': stats
                    })
            except Exception as e:
                print(f"错误: {e}")
    
    # ===== 实验4: 训练模式消融 =====
    _skip_exp4 = 4 not in ENABLED_EXPERIMENTS
    if not _skip_exp4:
        print("\n" + "=" * 80)
        print("实验4: Word2Vec训练模式消融实验 (CBOW vs Skip-gram)")
        print("=" * 80)
    
    if not _skip_exp4:
      sg_names = {0: 'CBOW', 1: 'Skip-gram'}
      for group_name in test_groups:
        variant_names = circuit_groups[group_name]
        test_trojans = {v: trojan_circuits[v] for v in variant_names}
        print(f"\n批次: {group_name} ({len(test_trojans)}个变体)")
        
        for sg in sgs:
            print(f"  sg={sg}({sg_names[sg]})...", end=' ', flush=True)
            try:
                result, stats = run_batch_experiment(
                    test_trojans, base_circuits, ground_truth,
                    'sg', sg_names[sg],
                    walk_length=0, vector_size=128, window=3, sg=sg
                )
                if result:
                    print(f"F1={result['F1']:.3f}, P={result['Precision']:.3f}, R={result['Recall']:.3f} {stats}")
                    results.append({
                        'batch': group_name, 'param': 'sg', 'value': sg_names[sg],
                        'F1': result['F1'], 'Precision': result['Precision'],
                        'Recall': result['Recall'], 'FPR': result['FPR'],
                        'TP': result['TP'], 'FP': result['FP'],
                        'TN': result['TN'], 'FN': result['FN'],
                        'circuits': result['circuit_count'], 'stats': stats
                    })
            except Exception as e:
                print(f"错误: {e}")
    
    # ===== 实验5: 检测阈值消融 =====
    _skip_exp5 = 5 not in ENABLED_EXPERIMENTS
    if not _skip_exp5:
        print("\n" + "=" * 80)
        print("实验5: 检测阈值消融实验 (0.50 ~ 0.99)")
        print("参数: walk_length=自适应(0), vector_size=128, window=3, sg=CBOW(0)")
        print("=" * 80)
        
    if not _skip_exp5:
      # 阈值范围：0.50到0.99，间靤0.01（共50个阈值）
      thresholds = [round(0.50 + i * 0.01, 2) for i in range(50)]
    
    if not _skip_exp5:
      for group_name in test_groups:
        variant_names = circuit_groups[group_name]
        test_trojans = {v: trojan_circuits[v] for v in variant_names}
        print(f"\n批次: {group_name} ({len(test_trojans)}个变体)")
        print(f"  生成嵌入并收集相似度数据...")
        
        all_results = run_threshold_experiment(
            test_trojans, base_circuits, ground_truth, thresholds, trojan_type,
            walk_length=0, vector_size=128, window=3, sg_mode=0
        )
        
        if all_results and all_results.get('ALL'):
            # 分ALL/TjIn/TjIn2打印表格
            for category in ['ALL', 'TjIn', 'TjIn2']:
                cat_results = all_results.get(category, {})
                if not cat_results:
                    continue
                print(f"\n  === {category} ===")
                print(f"  {'阈值':>6s}  {'TP':>4s} {'FP':>4s} {'FN':>4s}  "
                      f"{'Precision':>9s} {'Recall':>6s} {'F1':>6s}")
                print("  " + "-" * 55)
                for thresh in thresholds:
                    r = cat_results.get(thresh, {})
                    print(f"  {thresh:6.2f}  {r.get('TP',0):4d} {r.get('FP',0):4d} {r.get('FN',0):4d}  "
                          f"{r.get('Precision',0):9.3f} {r.get('Recall',0):6.3f} {r.get('F1',0):6.3f}")
                    results.append({
                        'batch': group_name, 'param': f'threshold_{category}', 'value': thresh,
                        'F1': r.get('F1', 0), 'Precision': r.get('Precision', 0),
                        'Recall': r.get('Recall', 0), 'FPR': 0,
                        'TP': r.get('TP', 0), 'FP': r.get('FP', 0),
                        'TN': 0, 'FN': r.get('FN', 0),
                        'circuits': len(test_trojans), 'stats': ''
                    })
            
            # 生成图表（2x2布局，含ALL/TjIn/TjIn2对比）
            chart_path = f'threshold_ablation_v3_{group_name}.png'
            plot_threshold_results(all_results, save_path=chart_path)
        else:
            print("  无结果")
    
    # 保存结果
    print("\n" + "=" * 80)
    print("保存实验结果...")
    df_results = pd.DataFrame(results)
    output_csv = 'ablation_experiment_v3_results.csv'
    df_results.to_csv(output_csv, index=False, encoding='utf-8-sig')
    print(f"结果已保存到: {output_csv}")
    
    # 输出汇总
    print("\n" + "=" * 80)
    print("实验结果汇总")
    print("=" * 80)
    if not df_results.empty:
        # 选择输出列，格式化小数位
        df_show = df_results[['param', 'value', 'F1', 'Precision', 'Recall', 'FPR', 'stats']].copy()
        for col in ['F1', 'Precision', 'Recall', 'FPR']:
            df_show[col] = df_show[col].map(lambda x: f"{x:.3f}")
        print(df_show.to_string(index=False))
    else:
        print("无结果")


if __name__ == '__main__':
    main()
