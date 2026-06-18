#20251122：基础程序 use_case_3.py，源程序提取的是整体的图嵌入向量，这里修改用于提取子图的图嵌入向量，并计算余弦相似度。
#20251130: 基本实现了子图的提取、子图的嵌入向量计算，并计算余弦相似度，并绘制成热力图、直方图、网络图等
#20251130：基础程序 use_case_4.py，在源程序的基础上，对模型进行优化，解决相似度过高的问题。会对一些函数进行优化、修改。
#20251226：基础程序 use_case_5.py，在源程序的基础上，改用pytorch.cosine_similarity()计算余弦相似度，
#20260108:基础程序 use_case_5.1.py，修改用于比较同一个代码的free和in版本，计算两都子图的相似度，看看能不能找出不同。
#20260109:基础程序 use_case_6.py，改为使用graph walk算法来生成子图的嵌入向量。添加gensim依赖库，导入Word2Vec函数
#20260111:将graph walk算法相关的函数放到./hw2vec/graphwalk.py中，包括随机游走过程、游走序列、子图节点集等函数，待后续再修改优化。
#20260111：基础程序 use_case_6.1.py，修改用于提取特征集（正常集、木马集、异常集）
#20260117:基础程序 use_case_6.2.py，原程序中free和in代码分别处理，修改为在一个函数处理，同时添加free/in标签、源码文件名等信息。
#20260124:基础程序 use_case_6.3.py，修改用于提取正常集和异常集，需将程序改为循环模式，将木马电路文件逐个与对应的正常电路（如果没有，则与全部正常电路）进行比较，鉴别出木马所在子图。
#20260301:基础程序 use_case_6.4.py，原程序备份，新程序用于AI修改。
#20260314:基础程序 use_case_6.5.py，原程序备份，新程序用于融合Joy和AES所有电路，形成一个完整的数据集。
#20260417:基础程序 use_case_6.6.py，修改用于测试GNN的子图嵌入方法。用于比较效率
#20260508：基础程序 use_case_6.7-GNN.py，修改用于重新抽取正常集和木马集，按照NTL的方式存储。
#20260530：基础程序 use_case_6.8.py，添加了信号到整图节点的映射关系，用于后续GT信号子图节点的快速提取，避免重新从Verilog生成。修改位置为346行开始。
#20260610：基础程序 use_case_6.9.py，新增了部分变体电路（E:\PRO\python\dataset\OK\EXTRTL\TjIn2），修改用于处理新的变体电路。不处理已有的电路，相应的pkl目录为rtl_dfg_graphs_ext
#20260612：基础程序 use_case_7.0.py，原程序仅处理新增电路，修改为处理EXTRTL目录下的所有电路（TjFree、TjIn、TjIn2）共计45+45+90=180个电路，pkl目录改回rtl_dfg_graphs。
#20260613：基础程序 use_case_7.1.py，从use_case_7.0.py复制，修改为处理EXTRTL全量目录（TjFree+TjIn+TjIn2），pkl使用独立目录rtl_dfg_graphs_full，不再依赖NEWRTL的TjFree基准。
#20260614：基础程序 use_case_7.1.py，修改电路间的比对策略，原策略为电路A与所有基准电路的全部子图一起比对，改为电路A与所有基准电路逐个进行比对，再合并结果。目的是避免众多电路合并后，导致单独的节点嵌入被稀释，影响子图的相似度计算。
'''改动处：
1、E:\PRO\python\HT\hw3vec\hw2vec\graph2vec\models.py:class GRAPH2VEC(nn.Module):def embed_graph()中x = F.dropout()中的参数training由self.training改为False，使其不再随机丢弃
   此处仅用于平时试验调试，可保持生成的嵌入向量的稳定性，后面实际运行时需改回去。
2、20260508: 修改为按电路分别存储子图数据，每个电路一个pkl文件，参考NTL的02.10_extract_ntlself_dfg_walk_true.py存储方式
'''
import os, sys, itertools
import time as time_module
import torch
import networkx as nx
import pandas as pd
import numpy as np
import matplotlib.pyplot as plt
import seaborn as sns
from pathlib import Path


import matplotlib.pyplot as plt

sys.path.append(os.path.dirname(sys.path[0]))
from hw2vec.config import Config
from hw2vec.hw2graph import *
from hw2vec.graphwalk import *
from hw2vec.TJDetection import *
from itertools import combinations
from gensim.models import Word2Vec
from collections import defaultdict

'''
$ cd examples
# for running IP piracy detection on our toy RTL dataset using DFG graph type
--yaml_path ./example_gnn4ip.yaml --raw_dataset_path ../assets/IP-RTL-toy --data_pkl_path case4_dfg_sub_rtl.pkl --graph_type DFG (--device cuda)
--yaml_path ./example_gnn4ip.yaml --raw_dataset_path ../assets/IP-RTL-toy --data_pkl_path case4_dfg_sub_rtl.pkl --graph_type DFG ###无需后面的 (--device cpu)

# for running IP piracy detection on our toy RTL dataset using AST graph type
$ python use_case_3.py --yaml_path ./example_gnn4ip.yaml --raw_dataset_path ../assets/IP-RTL-toy --data_pkl_path ast_ip_rtl.pkl --graph_type AST (--device cuda)
# for running IP piracy detection on our toy Netlist dataset using DFG graph type
$ python use_case_3.py --yaml_path ./example_gnn4ip.yaml --raw_dataset_path ../assets/IP-Netlist-toy --data_pkl_path dfg_ip_netlist.pkl --graph_type DFG (--device cuda)
# for running IP piracy detection on our toy Netlist dataset using AST graph type
$ python use_case_3.py --yaml_path ./example_gnn4ip.yaml --raw_dataset_path ../assets/IP-Netlist-toy --data_pkl_path ast_ip_netlist.pkl --graph_type AST (--device cuda)
'''
def write_file(data_path, data,wr='wb'):
    with open(data_path, wr) as f:
        pickle.dump(data, f)

def load_ground_truth_signals(csv_path='ALLRTL_dataset.csv'):
    """
    从CSV文件中读取真实的改动信号（ground truth）
    返回格式: {circuit_name: [signal_name1, signal_name2, ...], ...}
    """
    ground_truth = {}
    try:
        # 尝试多种编码读取
        for encoding in ['utf-8', 'gbk', 'latin-1']:
            try:
                # 先读取文件检查是否有注释行
                with open(csv_path, 'r', encoding=encoding) as f:
                    first_line = f.readline().strip()
                
                # 如果第一行是注释（以#开头），跳过该行读取
                if first_line.startswith('#'):
                    df = pd.read_csv(csv_path, encoding=encoding, skiprows=1)
                else:
                    df = pd.read_csv(csv_path, encoding=encoding)
                break
            except UnicodeDecodeError:
                continue
        else:
            print(f"警告: 无法读取 {csv_path}，所有编码都失败")
            return ground_truth
        
        # 遍历每一行，构建ground truth字典
        for _, row in df.iterrows():
            # 跳过空行和无效数据
            if pd.isna(row.get('circuit_name')) or pd.isna(row.get('signal_name')):
                continue
            try:
                circuit_name = str(row['circuit_name']).strip()
                signal_name = str(row['signal_name']).strip()
                
                # 跳过空值
                if not circuit_name or not signal_name or circuit_name == 'nan':
                    continue
                
                if circuit_name not in ground_truth:
                    ground_truth[circuit_name] = []
                ground_truth[circuit_name].append(signal_name)
            except (KeyError, AttributeError):
                continue
        
        print(f"成功加载 ground truth 数据: {len(ground_truth)} 个电路, {sum(len(v) for v in ground_truth.values())} 个信号")
        return ground_truth
    except Exception as e:
        print(f"警告: 读取 {csv_path} 失败: {e}")
        return {}

def evaluate_detection_results(detected_signals, ground_truth, all_signals_count=0, circuit_name=None):
    """
    评估检测结果与真实标签的对比（完整版，支持TN、FPR、FDR等指标）
    detected_signals: 检测到的信号列表 [(signal_name, similarity), ...] 或 [(circuit, signal, sim), ...]
    ground_truth: 真实的改动信号字典 {circuit_name: [signal_name, ...]}
    all_signals_count: 该电路的总子图数量（用于计算TN和FPR）
    circuit_name: 当前电路名（如果为None，则评估所有电路）
    
    返回: TP, FP, TN, FN, Precision, Recall, F1, FPR, FDR, TNR, TPR等
    """
    if not ground_truth:
        return None
    
    # 获取当前电路的真实信号
    if circuit_name and circuit_name in ground_truth:
        true_signals = set(ground_truth[circuit_name])
    else:
        # 评估所有电路
        true_signals = set()
        for signals in ground_truth.values():
            true_signals.update(signals)
    
    # 提取检测到的信号名（处理两种格式）
    if detected_signals and len(detected_signals[0]) == 3:
        # 格式: [(circuit_name, signal_name, sim_val), ...]
        detected_names = set([s[1] for s in detected_signals])
    else:
        # 格式: [(signal_name, similarity), ...]
        detected_names = set([s[0] if isinstance(s, tuple) else s for s in detected_signals])
    
    # 计算基础指标
    TP = len(detected_names & true_signals)      # 真正例：检测为木马 & 真实木马
    FP = len(detected_names - true_signals)      # 假正例：检测为木马 & 实际正常
    FN = len(true_signals - detected_names)      # 假负例：检测为正常 & 真实木马
    
    # 计算TN（需要知道总信号数）
    if all_signals_count > 0:
        TN = all_signals_count - TP - FP - FN    # 真负例：检测为正常 & 实际正常
    else:
        TN = 0  # 无法计算
    
    # 计算评价指标
    precision = TP / (TP + FP) if (TP + FP) > 0 else 0
    recall = TPR = TP / (TP + FN) if (TP + FN) > 0 else 0  # TPR = Recall = Sensitivity
    f1 = 2 * precision * recall / (precision + recall) if (precision + recall) > 0 else 0
    
    # 新增指标
    fpr = FP / (FP + TN) if (FP + TN) > 0 else 0           # 假正率 (False Positive Rate)
    tnr = TN / (TN + FP) if (TN + FP) > 0 else 0           # 真负率 (True Negative Rate) = Specificity
    fdr = FP / (TP + FP) if (TP + FP) > 0 else 0           # 错误发现率 (False Discovery Rate) = 1 - Precision
    npv = TN / (TN + FN) if (TN + FN) > 0 else 0           # 负预测值 (Negative Predictive Value)
    
    # 其他指标
    accuracy = (TP + TN) / (TP + TN + FP + FN) if (TP + TN + FP + FN) > 0 else 0
    balanced_acc = (TPR + tnr) / 2 if (TPR + tnr) > 0 else 0  # 平衡准确率
    
    return {
        'TP': TP,
        'FP': FP,
        'TN': TN,
        'FN': FN,
        'Precision': precision,
        'Recall': recall,
        'F1': f1,
        'TPR': TPR,              # True Positive Rate = Sensitivity = Recall
        'FPR': fpr,              # False Positive Rate
        'TNR': tnr,              # True Negative Rate = Specificity
        'FDR': fdr,              # False Discovery Rate
        'NPV': npv,              # Negative Predictive Value
        'Accuracy': accuracy,    # 准确率（在不平衡数据集上可能误导）
        'Balanced_Acc': balanced_acc,  # 平衡准确率
        'detected_count': len(detected_names),
        'ground_truth_count': len(true_signals),
        'total_signals': all_signals_count
    }
'''
def get_value_from_list(list_numpy,topk=0.02):
    max_value = np.max(list_numpy)
    min_value = np.min(list_numpy)
    width = (max_value - min_value) #区间的部宽度
    #top_zone=width* topk
    top_val = max_value - width* topk   # 取总宽度的2%作为区间，并划定边界值
    top_num = np.sum(list_numpy >= top_val)

    top_val=max(0.94,top_val)#这里的0.94是个待定值。
    return max_value, min_value, top_val, top_num
'''

time_0=time_module.perf_counter()
# 如果没有命令行参数，使用默认配置
if len(sys.argv) == 1:
    cfg = Config(['--yaml_path', 'example_gnn4tj.yaml'])
else:
    cfg = Config(sys.argv[1:])

'''数据集选择配置：0=TJ-RTL-toy(测试集), 1=AEStest(验证集)'''
DATASET_CHOICE = 4  # 修改此处切换数据集：0使用TJRTL，1使用AEStest，2使用ALLRTL，3使用NEWRTL



'''嵌入方法选择配置：0=GraphWalk, 1=GNN, 2=GraphMatching'''
EMBEDDING_METHOD = 0  # 修改此处切换方法：0使用GraphWalk，1使用GNN，2使用图匹配

#'''比对模式配置：0=与所有基准电路逐个比对, 1=仅与对应基准电路比对'''#改为直接在循环中过滤即可，便于验证修改。
#COMPARE_MODE = 1  # 0=全基准比对, 1=仅对应基准（如RS232-T100只与RS232比对）

'''存储模式配置：0=传统单pkl模式, 1=按电路分存pkl模式（NTL风格）'''
STORAGE_MODE = 1  # 修改此处切换存储模式：0使用传统单pkl，1使用按电路分存

# 项目根目录（examples/ 的上级目录）
_PROJECT_ROOT = Path(__file__).resolve().parent.parent
_ASSETS_DIR = _PROJECT_ROOT / "assets"

# 数据集配置字典
dataset_configs = {
    0: {
        'name': 'TJRTL',  # 用于文件命名前缀
        'path': str(_ASSETS_DIR / "TJ-RTL-toy"),
        'desc': '测试集目录，共9+18个电路文件'
    },
    1: {
        'name': 'AESRTL',  # 修改为AESRTL保持命名一致性
        'path': str(_ASSETS_DIR / "AEStest"),
        'desc': '验证集目录，共1+27个电路文件'
    },
    2: {
        'name': 'ALLRTL',
        'path': str(_ASSETS_DIR / "ALLRTL"),
        'desc': '全数据目录，共10+45个电路文件'
    },
    3: { #全部数据集
        'name': 'NEWRTL',
        'path': str(_ASSETS_DIR / "NEWRTL"),
        'desc': '全数据目录，共55+45个电路文件'
    },
    4: { #扩展数据集（TjFree降为45个，TjIn仍为3类45个，TjIn2为16类90个）
        'name': 'EXTRTL',
        'path': str(_ASSETS_DIR / "EXTRTL"),
        'desc': '扩展数据集（TjFree+TjIn+TjIn2），共45+45+90个变体电路'
    }
}

# 获取当前数据集配置
current_dataset = dataset_configs[DATASET_CHOICE]
dir_all = current_dataset['path']
file_prefix = current_dataset['name']  # 用于中间文件命名前缀

# 按电路分存模式的输出目录（assets/rtl_dfg_graphs_full）
RTL_OUTPUT_DIR = _ASSETS_DIR / "rtl_dfg_graphs_full"

RTL_OUTPUT_DIR.mkdir(parents=True, exist_ok=True)

print(f"数据集: {current_dataset['desc']}")
print(f"data assets:{dir_all}")
print(f"存储模式: {'按电路分存pkl' if STORAGE_MODE == 1 else '传统单pkl模式'}")
if STORAGE_MODE == 1:
    print(f"输出目录: {RTL_OUTPUT_DIR}")

'''加载真实的改动信号（ground truth）用于后续评估'''
ground_truth_signals = load_ground_truth_signals('EXTRTL_dataset.csv')

name_count = defaultdict(int)
nx_graphs_all= []
nx_subgraphs_all=[]  #保存所有子图的Network图
nx_subgraphs_free=[] #保存TjFree的所有子图的NetworkX图。name=nx_graphs.name,首个信号名=next(iter(nx_graph))
nx_subgraphs_in=[]   #保存TjIn的所有子图的NetworkX图。name=nx_graphs.name,首个信号名=next(iter(nx_graph))


if 0:
    ''' converting graph using hw2graph '''
    # 输入源码目录，生成nx格式的数据流图和子图列表nx_subgraphs[],
    cfg.raw_dataset_path = Path(dir_all).resolve()  # 设置源码目录
    hw2graph = HW2GRAPH(cfg)
    '''生成源码的整体数据流图和每个信号的子图，分别写入文件中。'''
    
    # 按电路分存模式：每个电路单独处理并保存
    if STORAGE_MODE == 1:
        print(f"\n=== 按电路分存模式（NTL风格） ===")
        circuit_count = 0
        failed_circuits = []
                
        for hw_project_path in hw2graph.find_hw_project_folders():
            circuit_name = hw_project_path.name
                    
            circuit_count += 1
            print(f"\n[{circuit_count}] 处理电路: {circuit_name}")
            
            try:
                t_circuit_start = time_module.perf_counter()
                # 20260529修改：接收signal_to_nodes返回值
                nx_graph, sub_nx_graphs, signal_to_nodes = hw2graph.code2graph(hw_project_path)
                
                # 提取电路类型（TjFree/TjIn）
                circuit_type = 'Unknown'
                if 'TjFree' in str(hw_project_path):
                    circuit_type = 'TjFree'
                elif 'TjIn' in str(hw_project_path):
                    circuit_type = 'TjIn'
                
                # 保存该电路的子图数据到独立pkl
                out_pkl = RTL_OUTPUT_DIR / f"{file_prefix}_{circuit_name}.pkl"
                with open(out_pkl, 'wb') as f:
                    pickle.dump({
                        'circuit_name': circuit_name,
                        'subset': circuit_type,
                        'nx_graph': nx_graph,
                        'nx_subgraphs': sub_nx_graphs,
                        'signal_to_nodes': signal_to_nodes,  # 20260529新增：保存信号到整图节点的映射
                        'n_subgraphs': len(sub_nx_graphs),
                        'n_nodes': nx_graph.number_of_nodes(),
                        'n_edges': nx_graph.number_of_edges(),
                    }, f)
                
                t_circuit_end = time_module.perf_counter()
                print(f"  [OK] nodes={nx_graph.number_of_nodes():5d} edges={nx_graph.number_of_edges():5d} "
                      f"subs={len(sub_nx_graphs):4d} time={t_circuit_end - t_circuit_start:.1f}s -> {out_pkl.name}")
                
                # 同时将子图添加到全局列表（用于后续处理）
                nx_subgraphs_all.extend(sub_nx_graphs)
                nx_graphs_all.append(nx_graph)
                
            except Exception as e:
                print(f"  [FAIL] {type(e).__name__}: {str(e)[:100]}")
                failed_circuits.append({'name': circuit_name, 'error': str(e)})
        
        print(f"\n=== 按电路分存完成 ===")
        print(f"处理: {circuit_count} 个电路")
        print(f"失败电路: {len(failed_circuits)} 个")
        if failed_circuits:
            print(f"失败列表: {[c['name'] for c in failed_circuits]}")
        
        # 保存/更新全局索引文件（记录所有电路的pkl路径）
        index_pkl = RTL_OUTPUT_DIR / f"{file_prefix}_0_index.pkl"
        index_data = {
            'dataset': file_prefix,
            'total_circuits': circuit_count,
            'processed_circuits': circuit_count,
            'failed_circuits': failed_circuits,
            'pkl_directory': str(RTL_OUTPUT_DIR),
        }
        with open(index_pkl, 'wb') as f:
            pickle.dump(index_data, f)
        print(f"索引文件已保存: {index_pkl}")
    
    else:
        # 传统单pkl模式
        for hw_project_path in hw2graph.find_hw_project_folders():
            #print(f"file= {hw_project_path}")
            #if 'memctrl' in hw_project_path.name:# or 'wb_conmax' in hw_project_path.name:#wb_conmax
            #if 'wb_conmax' not in hw_project_path.name:
            #if hw_project_path.name !='RS232':
            # if 'PIC16F84' not in hw_project_path.name:
            #    continue
            # 20260529修改：接收signal_to_nodes返回值
            nx_graph, sub_nx_graphs, signal_to_nodes = hw2graph.code2graph(hw_project_path)
            nx_subgraphs_all.extend(sub_nx_graphs)
            nx_graphs_all.append(nx_graph)
            # 可选：保存signal_to_nodes到全局列表
            # signal_to_nodes_all.append(signal_to_nodes)

        with open(f"case6.6_{file_prefix}_nx_graphs_all.pkl", "wb") as f:  # 将nx_graphs写入文件
            pickle.dump(nx_graphs_all, f)
        with open(f"case6.6_{file_prefix}_nx_subgraphs_all.pkl", "wb") as f:  # 将nx_subgraphs写入文件
            pickle.dump(nx_subgraphs_all, f)

else:
    ''' reading graph data from cache '''
    cfg.raw_dataset_path = Path(dir_all).resolve()  # 设置源码目录
    
    if STORAGE_MODE == 1:
        # === 全量模式：直接从输出目录加载所有电路（含TjFree、TjIn、TjIn2）===
        _already_loaded = set()  # 用于去重
        index_pkl = RTL_OUTPUT_DIR / f"{file_prefix}_0_index.pkl"
        if index_pkl.exists():
            with open(index_pkl, 'rb') as f:
                index_data = pickle.load(f)
            print(f"\n从索引文件加载: {index_pkl}")
            print(f"总电路数: {index_data['total_circuits']}")
            
            for pkl_file in RTL_OUTPUT_DIR.glob(f"{file_prefix}_*.pkl"):
                if pkl_file.name.endswith('_index.pkl'):
                    continue
                if 'detection_results' in pkl_file.name:
                    continue
                try:
                    with open(pkl_file, 'rb') as f:
                        circuit_data = pickle.load(f)
                    # 跳过已在TjFree中加载的电路（理论上TjIn2名称含-Txxx不会冲突）
                    if circuit_data['circuit_name'] in _already_loaded:
                        continue
                    nx_subgraphs_all.extend(circuit_data['nx_subgraphs'])
                    nx_graphs_all.append(circuit_data['nx_graph'])
                except Exception as e:
                    print(f"加载 {pkl_file.name} 失败: {e}")
            
            print(f"已加载: 共 {len(nx_graphs_all)} 个电路，{len(nx_subgraphs_all)} 个子图")
        else:
            print(f"未找到索引文件 {index_pkl}，请先将 if 0: 改为 if 1: 重新生成TjIn2数据")
    else:
        # 传统单pkl模式
        try:
            with open(f"case6.6_{file_prefix}_nx_graphs_all.pkl", "rb") as f:
                nx_graphs_all = pickle.load(f)
            with open(f"case6.6_{file_prefix}_nx_subgraphs_all.pkl", "rb") as f:
                nx_subgraphs_all = pickle.load(f)
        except:
            print(f"未找到 case6.6_{file_prefix}_*.pkl 文件，请先将 if 0: 改为 if 1: 重新生成数据")

#提取所需的free和in子图，这里可以切换选择全图或子图。
#for i, nx_subgraph in enumerate(nx_graphs_all):
for i, nx_subgraph in enumerate(nx_subgraphs_all):
    freein_type=nx_subgraph.type#TjFree、TjIn两类
    graph_name=nx_subgraph.name#源码文件所在的目录名，如RS232-T100，而不是topmodule.v
    name_count[graph_name] += 1#统计各个电路出现的次数

# 按键排序（字母顺序）
name_count = dict(sorted(name_count.items(), key=lambda x: x[0]))
name_count_free_dict={key:value for key,value in name_count.items() if '-T' not in key}
name_count_in_dict  ={key:value for key,value in name_count.items() if '-T' in key}
#print(f"name_count={dict(name_count)}")  # 转换为普通字典输出
#print(f"name_count_free_dict={name_count_free_dict}")
#print(f"name_count_in_dict  ={name_count_in_dict}")


'''GNN model configuration'''#需要时展开
''''''
model = GRAPH2VEC(cfg)
if cfg.model_path != "":
    model_path = Path(cfg.model_path)
    if model_path.exists():
        model.load_model(str(model_path/"model.cfg"), str(model_path/"model.pth"))
else:   #默认使用的是这个分支
    convs = [
        GRAPH_CONV("gcn", 37, cfg.hidden),
        GRAPH_CONV("gcn", cfg.hidden, cfg.hidden)  #20251130:改为1层GCN。
        #GRAPH_CONV("gcn", cfg.hidden, cfg.embed_dim)  #20251217+输出维度和下面GRAPH_POOL()的in_channels相同。
    ]
    model.set_graph_conv(convs)

    #pool = GRAPH_POOL("sagpool", cfg.hidden, cfg.poolratio)
    pool = GRAPH_POOL("topkpool", cfg.hidden, cfg.poolratio)
    #pool = GRAPH_POOL("topkpool", cfg.embed_dim, cfg.poolratio)#20251217+此处的cfg.embed_dim为输出向量的维度，需与卷积层最后一层的输出维度保持相同。
    model.set_graph_pool(pool)

    #readout = GRAPH_READOUT("max")#max mean sum
    readout = GRAPH_READOUT("max")
    #readout = GRAPH_READOUT("concat", ["max", "mean", "sum"])  # 拼接三种池化结果
    #readout = GRAPH_READOUT("concat")

    model.set_graph_readout(readout)

    output = nn.Linear(cfg.hidden, cfg.embed_dim)
    model.set_output_layer(output)

model.to(cfg.device)
trainer = PairwiseGraphTrainer(cfg) #继承自基类BaseTrainer
trainer.build(model)

time_1=time_module.perf_counter()


graph_embds_free = []
graph_embds_in = []
graph_embds_0 = []  # 存放正常电路的子图嵌入向量，包含free和 in中的正常部分
graph_embds_1 = []  # 存放木马电路的子图嵌入向量，标准为与free中无高相似度的子图嵌入向量
nx_subgraphs_0= [] #存放正常电路的子图，包含free和 in中的正常部分
nx_subgraphs_1= [] #存放木马电路的子图，标准为与free中无高相似度的子图嵌入向量
_seen_normal_set = set()  # 用于去重：记录已加入正常集的子图id
'''所有向量，两两比较计算相似度，并将结果输出到文件中。'''  # 20251226+改用pytorch进行批量计算。
similarities=[]  # 所有子图的相似度列表
similarities_0 = []  # 正常子图的最大相似度列表，与nx_subgraphs_0对应
similarities_1 = []  # 木马子图的最大相似度列表，与nx_subgraphs_1对应
output_lines_row = []  # 保存相似度矩阵中的各行输出
output_lines_pair = []  # 保存两两向量之间的相似度输出，用于最后写入文件中
count_pair = 0  # 计数符合条件的结果。
drawer = GraphDrawer()
''''''
time_2 = time_module.perf_counter()
# === 预计算：按电路名分组子图（避免在每个变体循环中重复扫描） ===
base_circuits_all = {}  # {基准电路名: [子图列表]}，全局不变
trojan_circuits_all = {}  # {木马电路名: [子图列表]}，全局不变
for nx_subgraph in nx_subgraphs_all:
    if nx_subgraph.type == 'TjFree':
        if nx_subgraph.name not in ('wb_conmax',):
            base_circuits_all.setdefault(nx_subgraph.name, []).append(nx_subgraph)
    elif '-T' in nx_subgraph.name:
        trojan_circuits_all.setdefault(nx_subgraph.name, []).append(nx_subgraph)
print(f"\n预计算完成: {len(base_circuits_all)} 个基准电路, {len(trojan_circuits_all)} 个木马变体")
_normal_base_done = set()  # 记录已添加正常集的基准电路名，避免跨变体重复添加

#木马文件逐个与正常电路比较
method_name = "GraphWalk"  # 默认值
print(f"\n=== 使用 {['GraphWalk', 'GNN', '图匹配(GraphMatching)'][EMBEDDING_METHOD]} 方法生成子图嵌入 ===")
time_embedding_start = time_module.perf_counter()
# 预计算实际待处理的变体列表（与循环内的过滤条件一致）
_variant_queue = []
for key, value in name_count_in_dict.items():
    #if 'wb_conmax' in key:
    #    continue
    #if 'PIC16F84' not in key:  #此处可以添加过滤条件，指定或排除要检测的变体电路。
    #if 'AES-T1100' not in key: 
    #if 'AES' in key and 'AES-T1100' not in key:
    #    continue
    _variant_queue.append((key, value))
_variant_total = len(_variant_queue)
_variant_idx = 0

for key, value in _variant_queue:   #可以在上面筛选木马电路
    # 1. 从预计算字典取木马电路的子图
    _variant_idx += 1
    trojan_subgraphs = trojan_circuits_all.get(key, [])
    n_in_orig = len(trojan_subgraphs)
    if n_in_orig == 0:
        continue
    nx_subgraphs_in = list(trojan_subgraphs)  # 工作副本（可能被扩展）
    if n_in_orig == 1:
        nx_subgraphs_in.append(nx_subgraphs_in[0])

    line = f"[{_variant_idx}/{_variant_total}] {key}:{value:4d} len_in={n_in_orig:4d} "
    output_lines_row.append(line)
    print(line)

    # 3. === 7.2逐个比对策略 ===
    # 对每个基准电路：单独训练嵌入 + 计算相似度 + 统计
    # 避免众多电路合并后，单独的节点嵌入被稀释，影响子图的相似度计算
    merged_max_per_in = np.full(n_in_orig, -1.0)  # 每个木马子图的合并最大相似度（跨基准取最大）
    all_similarities = []  # 收集所有比对的相似度值（用于最终直方图）
    last_tjdet = None  # 保留最后一个Tjdet用于合并分类

    # 提取当前变体的基准电路名（如 RS232-T100 -> RS232）
    variant_base = key.rsplit('-T', 1)[0] if '-T' in key else key

    for base_name, base_free_subgraphs in base_circuits_all.items():
        # 仅对应基准模式：跳过非对应基准电路
        if base_name != variant_base:#此处控制比对的对象，是对应基准电路，还是所有基准电路。
            continue
        # 基准子图只有1个时扩展为2（避免矩阵退化）
        if len(base_free_subgraphs) == 1:
            base_free_subgraphs = base_free_subgraphs + base_free_subgraphs

        # 对当前基准电路生成嵌入向量并计算相似度
        Tjdet = TJDetection(cfg)
        Tjdet.load_graphs(base_free_subgraphs, nx_subgraphs_in)

        if EMBEDDING_METHOD == 0:
            Tjdet.graph_embds_GW()
            method_name = "GraphWalk"
            use_gm_matrix = False
        elif EMBEDDING_METHOD == 1:
            Tjdet.graph_embds_GNN(trainer, use_hgw=True)
            method_name = "GNN"
            use_gm_matrix = False
        else:
            Tjdet.graph_embds_GM(method='similarity')
            method_name = "图匹配(GraphMatching)"
            use_gm_matrix = True
        last_tjdet = Tjdet

        # 计算当前基准的相似度矩阵
        if use_gm_matrix and hasattr(Tjdet, 'similarity_matrix_gm'):
            sim_matrix = np.array(Tjdet.similarity_matrix_gm)
        else:
            embds_in_tensor = torch.stack(Tjdet.graph_embds_in)
            embds_free_tensor = torch.stack(Tjdet.graph_embds_free)
            sim_matrix = torch.cosine_similarity(
                embds_in_tensor.unsqueeze(1),
                embds_free_tensor.unsqueeze(0),
                dim=-1
            ).squeeze(-1).detach().cpu().numpy()

        # 更新每个木马子图对该基准的最大相似度（跨基准取最大值）
        for i in range(n_in_orig):
            base_max = np.max(sim_matrix[i, :])
            merged_max_per_in[i] = max(merged_max_per_in[i], base_max)

        # 累积当前基准的相似度值（用于直方图）
        all_similarities.extend(sim_matrix.flatten().tolist())

        # 将当前基准电路子图添加到全局正常集（仅首次添加，后续变体跳过）
        if base_name not in _normal_base_done:
            _normal_base_done.add(base_name)
            for emb, sg in zip(Tjdet.graph_embds_free, base_free_subgraphs):
                sg_id = id(sg)
                if sg_id not in _seen_normal_set:
                    _seen_normal_set.add(sg_id)
                    graph_embds_0.append(emb)
                    nx_subgraphs_0.append(sg)

    # 4. 合并判定：基于跨基准的最大相似度进行木马/正常分类
    merged_max_list = merged_max_per_in.tolist()
    tj_wz = []
    for i in range(n_in_orig):
        simRow_vals = [v for v in merged_max_list if v >= 0]  # 仅用有效值计算阈值
        _, _, top_val, _ = get_value_from_list(simRow_vals) if simRow_vals else (0, 0, 0.98, 0)
        if merged_max_list[i] >= top_val:
            graph_embds_0.append(last_tjdet.graph_embds_in[i])
            nx_subgraphs_0.append(trojan_subgraphs[i])
        else:
            graph_embds_1.append(last_tjdet.graph_embds_in[i])
            nx_subgraphs_1.append(trojan_subgraphs[i])
            tj_wz.append(i)

    # 输出逐个比对的基准电路统计
    #base_info = ', '.join([f'{name}({len(sgs)})' for name, sgs in base_circuits_all.items()])
    #output_lines_row.append(f"  逐个比对: {base_info}")

    # 保存木马子图的相似度值
    similarities_1.extend([merged_max_list[i] for i in tj_wz])

    # 输出木马子图详情
    for idx_in, i in enumerate(tj_wz):
        subgraph = trojan_subgraphs[i]
        first_node = next(iter(subgraph.nodes()))
        output_lines_row.append(
            f"    {i:4d}   {subgraph.number_of_nodes():4d} {subgraph.number_of_edges():4d} "
            f"{merged_max_list[i]:6.3f} {first_node}")

    # 统计当前变体的相似度信息
    variant_stat = drawer.calc_list_statistics(all_similarities, prn='off')
    output_lines_row.append(variant_stat)
    print(f"  {variant_stat}")#此处添加输出每次比对的统计信息
    similarities.extend(all_similarities)

    time_2 = time_module.perf_counter()
    print(f"      [{method_name}] len(graph_embds_1): 当前={len(tj_wz):3d} 累计={len(graph_embds_1):5d}, time={time_2-time_1:7.3f} s [{key}]")
    #break

# 2026-05-11: 修复独立基准电路子图未进入正常集的问题
# 找出所有独立基准电路（无对应变体的TjFree电路）
variant_base_names = set()
for key in name_count_in_dict.keys():
    base_name = key.split('-')[0]
    variant_base_names.add(base_name)

independent_free_subgraphs = []
for sg in nx_subgraphs_all:
    if sg.type == 'TjFree' and sg.name not in variant_base_names:
        independent_free_subgraphs.append(sg)

if independent_free_subgraphs:
    print(f"\n=== 处理独立基准电路: {len(independent_free_subgraphs)} 个子图 ===")
    if EMBEDDING_METHOD == 0:
        from hw2vec.TJDetection import graph_embds_GraphWalk
        # 为子图添加节点类型属性（GraphWalk需要'x'属性）
        data_proc_ind = DataProcessor(cfg)
        for sg in independent_free_subgraphs:
            data_proc_ind.process(sg)
        graph_embds_ind, _, _ = graph_embds_GraphWalk(
            independent_free_subgraphs, [],
            walk_length=0, vector_size=128, window=3, sg=0, seed=42
        )
    elif EMBEDDING_METHOD == 1:
        Tjdet_ind = TJDetection(cfg)
        Tjdet_ind.load_graphs(independent_free_subgraphs, independent_free_subgraphs)
        Tjdet_ind.graph_embds_GNN(trainer, use_hgw=True)
        graph_embds_ind = Tjdet_ind.graph_embds_free
    else:
        Tjdet_ind = TJDetection(cfg)
        Tjdet_ind.load_graphs(independent_free_subgraphs, independent_free_subgraphs)
        Tjdet_ind.graph_embds_GM(method='similarity')
        graph_embds_ind = Tjdet_ind.graph_embds_free
    
    for emb, sg in zip(graph_embds_ind, independent_free_subgraphs):
        sg_id = id(sg)
        if sg_id not in _seen_normal_set:
            _seen_normal_set.add(sg_id)
            graph_embds_0.append(emb)
            nx_subgraphs_0.append(sg)
    print(f"独立基准电路子图已加入正常集，当前正常集总数: {len(nx_subgraphs_0)}")

time_embedding_end = time_module.perf_counter()
print(f"\n[{method_name}] 嵌入生成总耗时: {time_embedding_end - time_embedding_start:.3f} 秒")


#输出检测到的疑似木马子图情况
line=f"[{method_name}] 整体统计：正常子图总数(含in中的高相似度子图)={len(graph_embds_0)}，疑似木马子图总数={len(graph_embds_1)}："
output_lines_row.append(line)
print(line)

# 定义辅助函数：清理信号名（去掉_rn_0后缀，提取模块名.实例名.信号名）
def clean_signal_name(node_name):
    # 去掉_rn_X后缀
    if '_rn_' in node_name:
        node_name = node_name[:node_name.index('_rn_')]
    # 提取层次化名称（假设格式为：模块名.实例名.信号名）
    return node_name

# 定义辅助函数：从subgraph中提取电路名
def extract_circuit_name(subgraph):
    # 优先使用subgraph.name属性（在hw2graph.py中设置）
    if hasattr(subgraph, 'name') and subgraph.name:
        return subgraph.name
    # 备用：从字符串表示中提取
    subgraph_str = str(subgraph)
    if "'" in subgraph_str:
        return subgraph_str.split("'")[0]
    return 'unknown'

# 格式1：简洁格式（序列、节点数、边数、电路名、信号名）
output_lines_row.append("\n=== 检测到的改动信号（简洁格式）===")
output_lines_row.append(f"{'序列':<6}{'节点数':<8}{'边数':<8}{'电路名':<20}{'信号名'}")
output_lines_row.append("-" * 80)
for idx, subgraph in enumerate(nx_subgraphs_1):
    first_node = next(iter(subgraph.nodes()))
    signal_name = clean_signal_name(first_node)
    # 从subgraph中提取电路名
    circuit_name = extract_circuit_name(subgraph)
    line = f"{idx:<6}{subgraph.number_of_nodes():<8}{subgraph.number_of_edges():<8}{circuit_name:<20}{signal_name}"
    output_lines_row.append(line)
    #print(line) #屏幕上暂不输出
'''
# 格式2：数据集格式（便于后续打标签） -> 在simRow.txt中打印
# 格式：序号|电路名|信号名|节点数|边数|相似度|标签(0=正常,1=木马)|备注
output_lines_row.append("\n=== 数据集格式（便于后续打标签）===")
output_lines_row.append("# 格式：序号|电路名|信号名|节点数|边数|相似度|标签(0=正常,1=木马)|备注")
output_lines_row.append("# 说明：标签列初始为空，需要人工标注后填充")
output_lines_row.append(f"{'序号':<6}|{'电路名':<20}|{'信号名':<40}|{'节点数':<8}|{'边数':<8}|{'相似度':<10}|{'标签':<6}|{'备注'}")
output_lines_row.append("-" * 120)
for idx, subgraph in enumerate(nx_subgraphs_1):
    first_node = next(iter(subgraph.nodes()))
    signal_name = clean_signal_name(first_node)
    circuit_name = extract_circuit_name(subgraph)
    # 使用similarities_1获取对应的最大相似度值
    sim_val = similarities_1[idx] if idx < len(similarities_1) else 0.0
    line = f"{idx:<6}|{circuit_name:<20}|{signal_name:<40}|{subgraph.number_of_nodes():<8}|{subgraph.number_of_edges():<8}|{sim_val:<10.4f}|{'':<6}|{'待标注'}"
    output_lines_row.append(line)
'''
# 格式3：CSV格式（便于Excel/数据分析工具处理）
csv_lines = []
csv_lines.append("idx,circuit_name,signal_name,node_count,edge_count,similarity,label,label_by,notes")
csv_lines.append("# 说明：label列初始为空，0=正常，1=木马；label_by标注者；notes备注")
for idx, subgraph in enumerate(nx_subgraphs_1):
    first_node = next(iter(subgraph.nodes()))
    signal_name = clean_signal_name(first_node)
    circuit_name = extract_circuit_name(subgraph)
    # 使用similarities_1获取对应的最大相似度值
    sim_val = similarities_1[idx] if idx < len(similarities_1) else 0.0
    # CSV格式：用逗号分隔，字符串用引号包裹
    csv_line = f'{idx},"{circuit_name}","{signal_name}",{subgraph.number_of_nodes()},{subgraph.number_of_edges()},{sim_val:.4f},,"","待标注"'
    csv_lines.append(csv_line)

# 保存CSV文件
csv_filename = f"rsl_{file_prefix}_dataset.csv"
with open(csv_filename, "w", encoding="utf-8") as f:
    f.write("\n".join(csv_lines))
output_lines_row.append(f"\n=== CSV格式文件已保存 ===")
output_lines_row.append(f"CSV文件路径: {csv_filename}")
output_lines_row.append(f"总行数（含表头）: {len(csv_lines)}")
print(f"\nCSV格式数据集已保存到: {csv_filename}")

'''评估检测结果与真实标签的对比'''
if ground_truth_signals:
    # 构建检测到的信号列表
    detected_signals = []
    for idx, subgraph in enumerate(nx_subgraphs_1):
        first_node = next(iter(subgraph.nodes()))
        signal_name = clean_signal_name(first_node)
        circuit_name = extract_circuit_name(subgraph)
        sim_val = similarities_1[idx] if idx < len(similarities_1) else 0.0
        detected_signals.append((circuit_name, signal_name, sim_val))
    
    # 统计每个电路的总子图数（从nx_subgraphs_all中获取）
    circuit_total_signals = {}
    for subgraph in nx_subgraphs_all:
        cname = extract_circuit_name(subgraph)
        if cname not in circuit_total_signals:
            circuit_total_signals[cname] = 0
        circuit_total_signals[cname] += 1
    
    # 按电路分别评估
    output_lines_row.append("\n=== 检测结果评估（按电路）===")
    output_lines_row.append("格式: 电路名 | TP/FP/TN/FN | Precision/Recall/F1 | FPR/TNR/FDR | 总信号数/改动数/检测数")
    output_lines_row.append("-" * 120)
    print("\n=== 检测结果评估（按电路）===")
    print("格式: 电路名 | TP/FP/TN/FN | Precision/Recall/F1 | FPR/TNR/FDR | 总信号数/改动数/检测数")
    print("-" * 120)
    
    # 获取所有涉及的电路
    all_circuits = set()
    for circuit_name, _, _ in detected_signals:
        all_circuits.add(circuit_name)
    for circuit_name in ground_truth_signals.keys():
        all_circuits.add(circuit_name)
    
    total_TP = total_FP = total_TN = total_FN = 0
    
    for circuit in sorted(all_circuits):
        # 获取该电路检测到的信号
        circuit_detected = [(s, sim) for c, s, sim in detected_signals if c == circuit]
        # 获取该电路的总子图数
        total_signals = circuit_total_signals.get(circuit, 0)
        # 评估
        result = evaluate_detection_results(circuit_detected, ground_truth_signals, total_signals, circuit)
        if result:
            total_TP += result['TP']
            total_FP += result['FP']
            total_TN += result['TN']
            total_FN += result['FN']
            line = f"{circuit:<18}: " \
                   f"TP={result['TP']:2d} FP={result['FP']:2d} TN={result['TN']:4d} FN={result['FN']:2d} | " \
                   f"P={result['Precision']:.3f} R={result['Recall']:.3f} F1={result['F1']:.3f} | " \
                   f"FPR={result['FPR']:.4f} TNR={result['TNR']:.3f} FDR={result['FDR']:.3f} | " \
                   f"({result['total_signals']}/{result['ground_truth_count']}/{result['detected_count']})"
            output_lines_row.append(line)
            print(line)
    
    # 总体评估
    total_precision = total_TP / (total_TP + total_FP) if (total_TP + total_FP) > 0 else 0
    total_recall = total_TP / (total_TP + total_FN) if (total_TP + total_FN) > 0 else 0
    total_f1 = 2 * total_precision * total_recall / (total_precision + total_recall) if (total_precision + total_recall) > 0 else 0
    total_fpr = total_FP / (total_FP + total_TN) if (total_FP + total_TN) > 0 else 0
    total_tnr = total_TN / (total_TN + total_FP) if (total_TN + total_FP) > 0 else 0
    total_fdr = total_FP / (total_TP + total_FP) if (total_TP + total_FP) > 0 else 0
    total_accuracy = (total_TP + total_TN) / (total_TP + total_TN + total_FP + total_FN) if (total_TP + total_TN + total_FP + total_FN) > 0 else 0
    
    output_lines_row.append("-" * 120)
    output_lines_row.append("\n=== 总体评估结果 ===")
    output_lines_row.append(f"混淆矩阵: TP={total_TP}, FP={total_FP}, TN={total_TN}, FN={total_FN}")
    output_lines_row.append(f"基础指标: Precision={total_precision:.4f}, Recall={total_recall:.4f}, F1={total_f1:.4f}")
    output_lines_row.append(f"新增指标: FPR={total_fpr:.4f}({total_fpr*100:.2f}%), TNR={total_tnr:.4f}, FDR={total_fdr:.4f}")
    output_lines_row.append(f"其他指标: Accuracy={total_accuracy:.4f} (注意: 不平衡数据集上Accuracy可能误导)")
    output_lines_row.append(f"\n指标说明:")
    output_lines_row.append(f"  FPR(False Positive Rate): 假正率 = FP/(FP+TN), 正常信号被误报的比例")
    output_lines_row.append(f"  TNR(True Negative Rate):  真负率 = TN/(TN+FP), 正常信号被正确识别的比例")
    output_lines_row.append(f"  FDR(False Discovery Rate): 错误发现率 = FP/(TP+FP), 检测结果中误报的比例")
    
    print("-" * 120)
    print("\n=== 总体评估结果 ===")
    print(f"混淆矩阵: TP={total_TP}, FP={total_FP}, TN={total_TN}, FN={total_FN}")
    print(f"基础指标: Precision={total_precision:.4f}, Recall={total_recall:.4f}, F1={total_f1:.4f}")
    print(f"新增指标: FPR={total_fpr:.4f}({total_fpr*100:.2f}%), TNR={total_tnr:.4f}, FDR={total_fdr:.4f}")
    print(f"其他指标: Accuracy={total_accuracy:.4f} (注意: 不平衡数据集上Accuracy可能误导)")
    print(f"\n指标说明:")
    print(f"  FPR(False Positive Rate): 假正率 = FP/(FP+TN), 正常信号被误报的比例")
    print(f"  TNR(True Negative Rate):  真负率 = TN/(TN+FP), 正常信号被正确识别的比例")
    print(f"  FDR(False Discovery Rate): 错误发现率 = FP/(TP+FP), 检测结果中误报的比例")

#输出整体统计信息，绘制直方图

stat_result = drawer.calc_list_statistics(similarities)  # 统计整体信息
if stat_result is not None:
    output_lines_row.append(stat_result)
drawer.draw_histogram_graph(similarities, title="similarity", savepath="")  #整体直方图
line=f"[{method_name}] total time = {time_2-time_0:7.3f} s"
output_lines_row.append(line)
print(line)

#将所有输出结果保存到文件中.
#with open(f"rsl_{file_prefix}_simPair.txt", "w", encoding="utf-8") as f:
#    f.write("\n".join(output_lines_pair))

with open(f"rsl_{file_prefix}_simRow.txt", "w", encoding="utf-8") as f:
    # 过滤掉None值，确保所有元素都是字符串
    valid_lines = [line for line in output_lines_row if line is not None]
    f.write("\n".join(valid_lines))

write_file(f"case6.6_{file_prefix}_graph_embds_0.pkl",graph_embds_0,'wb')
write_file(f"case6.6_{file_prefix}_graph_embds_1.pkl",graph_embds_1,'wb')
write_file(f"case6.6_{file_prefix}_nx_subgraphs_0.pkl",nx_subgraphs_0,'wb')
write_file(f"case6.6_{file_prefix}_nx_subgraphs_1.pkl",nx_subgraphs_1,'wb')

# 如果使用按电路分存模式，也保存检测结果到独立文件
if STORAGE_MODE == 1:
    detection_pkl = RTL_OUTPUT_DIR / f"{file_prefix}_0_detection_results.pkl"
    with open(detection_pkl, 'wb') as f:
        pickle.dump({
            'graph_embds_0': graph_embds_0,
            'graph_embds_1': graph_embds_1,
            'nx_subgraphs_0': nx_subgraphs_0,
            'nx_subgraphs_1': nx_subgraphs_1,
            'similarities_0': similarities_0,
            'similarities_1': similarities_1,
            'similarities': similarities,
        }, f)
    print(f"\n检测结果已保存: {detection_pkl}")

time_2=time_module.perf_counter()
print(f"total time={time_2-time_0:.3f}秒")
''''''
# evaluating and inspecting 
#trainer.evaluate(cfg.epochs, train_loader, test_loader)
#vis_loader = DataLoader(data_proc.get_graphs(), shuffle=False, batch_size=1)
#trainer.visualize_embeddings(vis_loader, "./")

#分别生成每个文件的子图png图、节点名
for key,value in name_count.items():
    continue
    #if key=='PIC16F84' or key=='PIC16F84-T100' or key=='PIC16F84-T200':
    #if key!='PIC16F84-T100':
    if 'wb_conmax' in key or key=='RC5' or 'PIC16F84' in key:
        continue
    if key=='RS232-T600' or key=='RS232-T2100':
        continue
    #if 'RS232-T' not in key:
    #    continue
    nx_subgraphs_in.clear()
    output_lines_row.clear()
    for i,nx_subgraph in enumerate(nx_subgraphs_all):
        if nx_subgraph.name == key:
            nx_subgraphs_in.append(nx_subgraph)
    path='./子图PNG示例/png_'+key+'/'
    print(f"path={path}")
    os.makedirs(path, exist_ok=True)  # 自动创建多级目录

    for idx, nx_graph_tmp in enumerate(nx_subgraphs_in):
        #if idx!=89:
        #if idx<1106:
        #    continue
        #if (idx+1)%100==0:
        #    os.execl(sys.executable, sys.executable, *sys.argv)
        #drawer.draw_graph_pydot(idx, nx_graph_tmp, path,fast_mode=False)  # fast_mode=False可以进入完整模式，生成在子图放在 ./nx_subgraphs_PNG/ 目录中。
        line=f"子图{idx:3d}: 节点数{nx_graph_tmp.number_of_nodes():03d}, 边数{nx_graph_tmp.number_of_edges():03d}"
        #line=line+f" 节点:{nx_graph_tmp.nodesd()}\n   边:{nx_graph_tmp.edges()}"
        line = line + f" 节点:{nx_graph_tmp.nodes()}\n                              边:{nx_graph_tmp.edges()}"
        output_lines_row.append(line)

    with open(path +'info_'+key+'.txt', 'w') as f:
        f.write("\n".join(output_lines_row))

