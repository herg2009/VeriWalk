#20251130：添加了一个用于绘制各种图的类 class GraphDrawer，包含子图、t-SNE、热力图、直方图、网络图等。
#!/usr/bin/env python
#title           :hw2graph.py
#description     :This file includes the neccessary functions in hw2graph.
#author          :Rozhin
#date            :2021/03/05
#version         :0.2
#notes           :
#python_version  :3.6

#20260530：添加了信号到整图节点的映射关系，用于后续GT信号子图节点的快速提取，避免重新从Verilog生成。修改位置为346行开始。
#==============================================================================
from __future__ import absolute_import
from __future__ import print_function


import matplotlib.pyplot as plt
import pyverilog.utils.util as util
import networkx as nx
import itertools
import math
import pyverilog, pydot, json, os, sys, pickle, gc, re
sys.path.append(os.path.dirname(sys.path[0]))

from json import dumps
from collections import defaultdict
from pyverilog.dataflow.optimizer import VerilogDataflowOptimizer
from pyverilog.dataflow.graphgen import VerilogGraphGenerator
from pyverilog.controlflow.controlflow_analyzer import VerilogControlflowAnalyzer
from pyverilog.vparser.parser import parse
from sklearn.model_selection import train_test_split
from sklearn.manifold import TSNE
from glob import glob
from hw2vec.graph2vec.trainers import *
from hw2vec.utilities import *
from torch_geometric.utils.convert import from_networkx
from time import time
import seaborn as sns
import numpy as np
from scipy.stats import skew, kurtosis

#从节点名中获取原始的变量名，
def get_var_name(in_name:str=None):
    if '_rn_' in in_name:  # 去掉_graphrename后缀,原始代码中为_graphrename 改为_rn_
        in_name = in_name[:in_name.index('_rn_')]
    if '_rm_' in in_name:  # 去掉_rm_后缀,pyverilog.dataflow.bindvisitor.BindVisitor.renameVar()中对var重命名时，添加的标志
        in_name = in_name[:in_name.index('_rm_')]  # 20260201添加
    if '.' in in_name:  # 根据.或_分割名称，取最后一部分作为类型标签（如module.singal -> signal)
        out_name = in_name.split('.')[-1]
    elif '_' in in_name:
        out_name = in_name.split('_')[-1]
    else:
        out_name = in_name.lower()
    return out_name


import networkx as nx

'''
def clone_and_rename_graph(source_graph, suffix='_rn_x'):
    # 创建目标图副本
    target_graph = source_graph.copy()
    # 创建新图容器
    renamed_graph = nx.DiGraph()
    # 生成节点重命名映射
    # #根节点要单独重命名，要改成和叶节点相同的名字，因此要先去掉名字中的_rn_0，再添加_rn_x
    rename_map=dict()
    for i,node in enumerate(target_graph.nodes()):
        if i != 0:
            rename_map[node] = node+suffix
        else:
            rename_map[node] = node[:node.index('_rn_')]+suffix

    #rename_map = {node: node+suffix for node in target_graph.nodes()}

    # 复制节点并保留属性
    for node, attrs in target_graph.nodes(data=True):
        renamed_graph.add_node(rename_map[node], **attrs)

    # 复制边并更新连接关系
    for src, dst, edge_attrs in target_graph.edges(data=True):
        renamed_graph.add_edge(
            rename_map[src],
            rename_map[dst],
            **edge_attrs
        )

    return renamed_graph, rename_map


def merge_nxgraphs(G_target0, G_source):# S+T->T
    """
    合并规则：
    1. 节点属性：保留目标图原始属性，仅添加源图新增属性
    2. 边属性：保留目标图原始边属性，源图新增边直接添加
    3. 冲突处理：属性名冲突时优先保留目标图属性
    """
    name=list(G_source.nodes())[0]
    name=name[name.index('_rn_'):]
    #print(f"name={name}")
    # 执行克隆与重命名
    G_target, rename_map = clone_and_rename_graph(G_target0, suffix=name)#name='_rn_x'
    # 节点合并
    for node, attrs in G_source.nodes.items():
        if node in G_target.nodes:
            # 仅添加源图中目标图不存在的属性
            for k, v in attrs.items():
                if k not in G_target.nodes[node]:
                    G_target.nodes[node][k] = v
        else:
            G_target.add_node(node, **attrs)

    # 边合并
    for edge, attrs in G_source.edges.items():
        src, dst = edge
        if G_target.has_edge(src, dst):
            # 保留目标图原始边属性
            for k, v in attrs.items():
                if k not in G_target.edges[(src, dst)]:
                    G_target.edges[(src, dst)][k] = v
        else:
            G_target.add_edge(src, dst, **attrs)
'''
class DataProcessor:
    def __init__(self, cfg):
        self.cfg = cfg
        self.graph_data = []#在process()中生成，以列表的形式分别保存节点、边的属性
        self.graph_pair_data = []

        #定义了一个包含AST节点类型的列表。这些类型可能代表了AST中不同类型的节点（如变量名、操作符、语句等）
        self.global_type2idx_AST_list = ['names','always','none','senslist','sens','identifier','nonblockingsubstitution',
                                         'lvalue','rvalue','intconst','pointer','ifstatement','pure numeric','assign','cond',
                                         'unot','plus','land','reg','partselect','eq','lessthan','greaterthan','decl','wire',
                                         'width','output','input','moduledef','portarg','instancelist','source','description',
                                         'port','portlist','ulnot','instance','or','and','lor','block','xor','ioport',
                                         'blockingsubstitution','minus','times','casestatement','case','parameter','sll','srl',
                                         'sra','divide','systemcall','singlestatement','stringconst','noteq','concat','repeat',
                                         'integer','xnor','dimensions','length','lconcat','uminus','greatereq','initial','uor',
                                         'casexstatement','forstatement','localparam','eventstatement','mod','delaystatement',
                                         'floatconst','task','paramarg', 'paramlist', 'inout']
        #通过字典推导式，将 global_type2idx_AST_list 中的元素作为值，它们的索引（即枚举值）作为键，创建了一个从类型到索引的映射字典。
        #这个字典允许通过类型名快速查找对应的索引。
        self.global_type2idx_AST = {v:k for k, v in enumerate(self.global_type2idx_AST_list)}
                                        #   1        2       3      4          5            6       7         8       9       10
        self.global_type2idx_DFG_list = ['concat','input','unand','unor',  'uxor',   'signal',    'uand','ulnot',   'uxnor','numeric',
                                     'partselect','and',  'unot', 'branch','or',     'uor',     'output','plus',    'eq',   'minus',
                                         'xor',   'lor',  'noteq','land','greatereq','greaterthan','sll','lessthan','times','srl',
                                         'pointer','mod', 'divide','sra',  'sla',    'xnor',    'lesseq']

        self.global_type2idx_DFG = {v:k for k, v in enumerate(self.global_type2idx_DFG_list)}

    #主要目的是接收一个 NetworkX 图对象，对其进行标准化处理，将其转换为另一种格式，
    # 并保留原始图的名称和类型信息，然后将转换后的数据添加到实例的某个集合中。
    def process(self, nx_graph):
        #print(type(nx_graph))
        self.normalize(nx_graph)#归一化，添加节点类型编号'x'
        #CFG：添加nx_graph判断
        #if nx_graph is None:
        #    raise ValueError("输入图像为None，请检查上游处理流程")
        #if nx_graph.nodes():
        #    raise ValueError("输入图没有节点，请检查硬件设计解析结果")
        data = from_networkx(nx_graph)#提取节点和边的属性，提取边的src和dst，分别组成数组，然后转化为PyTorch Geometric的Data对象。
        data.hw_name = nx_graph.name
        data.hw_type = nx_graph.type
        self.graph_data.append(data)

    #这段代码定义了一个名为 normalize 的方法，它用于根据图（nx_graph）的类型（DFG 或 AST）来归一化图中节点的标签。
    # 归一化的过程是将节点的标签或名称替换为更高级别的类型表示，并将这些类型映射到全局的索引字典中。
    def normalize(self, nx_graph):
        ''' 
            Normalization is a step to replace the label of a node to a value -> replace all the variable name and numeric values with a high-level type.
        '''
        if self.cfg.graph_type == 'DFG': # normalize for DFG
            #这是一个列表推导式，它遍历nx_graph.in_degree()返回的迭代器，每次迭代都从元组中提取出val（即节点的入度值），并将这些值收集到一个新的列表中。
            #这行代码的作用是提取nx_graph图中所有节点的入度值，并将这些值存储在一个名为in_degrees的列表中。
            in_degrees = [val for (node, val) in nx_graph.in_degree()]
            out_degrees = [val for (node, val) in nx_graph.out_degree()]
            for idx, node in enumerate(nx_graph.nodes(data=True)):#下面的循环是给节点添加一个节点类型编号的字典属性'x',指示该节点的类型编号
                #node是一个元组(节点名称，节点属性字典)，因此node[0]就是节点的名称
                node_name = node[0]
                if '_rn' in node_name:#20251207:原为_graphrename
                    node_name = node_name[:node_name.index('_rn')] #如果节点名包含 _graphrename，则截断掉这部分以保留原始名称。

                if '\'d' in node_name or '\'b' in node_name or '\'o' in node_name or '\'h' in node_name:#如果节点名包含进制表示（如 'd, 'b, 'o, 'h），将其归类为 "numeric"（数字常量）
                    type_of_node = "numeric"
                elif in_degrees[idx] == 0:
                    type_of_node = "output"
                elif out_degrees[idx] == 0:
                    type_of_node = "input"
                elif '.' in node_name or '_' in node_name:#如果节点名包含 [.] 或 _，归类为 "signal"（信号）。
                    type_of_node = "signal"
                else:
                    type_of_node = node_name.lower()

                if type_of_node not in self.global_type2idx_DFG:
                    print("----------"+type_of_node+"-------------")
                    raise Exception("The operation is not in the global_type2idx_DFG table, please report the error to " +   
                                "https://github.com/louisccc/hw2vec/issues")

                #节点的数据中的 'x' 键设置为该节点类型在 self.global_type2idx_DFG 字典中对应的索引值。
                node[1]['x'] = self.global_type2idx_DFG[type_of_node]#这个node指向nx_graph.node中元素，相当于直接修改nx_graph.node。
                node[1]['type']=type_of_node #20260201+添加节点类型名称。
            #强行给边添加权重属性。格式为(src,des,dict{})

            #for idx, edge in enumerate(nx_graph.edges(data=True)):
            #    edge[2]['edge_attr']=1
            self.num_node_labels = len(self.global_type2idx_DFG)
            self.cfg.num_feature_dim = self.num_node_labels
        
        elif self.cfg.graph_type == "AST": # normalize for AST
            #out_degrees是一个列表，存放每个节点的出席值。
            out_degrees = [val for (node, val) in nx_graph.out_degree()]
            for idx, node in enumerate(nx_graph.nodes(data=True)):
                label = node[1]['label']
                if out_degrees[idx] == 0 and not isInt(label):
                    type_of_node = "names"
                elif isInt(label):
                    type_of_node = "pure numeric"
                else:
                    type_of_node = label.lower()
                
                if type_of_node not in self.global_type2idx_AST:
                    print("----------"+type_of_node+"-------------")
                    raise Exception("The operation is not in the global_type2idx_AST table, please report the error to " +   
                                "https://github.com/louisccc/hw2vec/issues")
                
                node[1]['x'] = self.global_type2idx_AST[type_of_node]
            self.num_node_labels = len(self.global_type2idx_AST)
            self.cfg.num_feature_dim = self.num_node_labels

    #方法的目的是从类的某个属性 self.graph_data 中生成所有可能的图对（graph pairs），并将这些图对存储在另一个属性 self.graph_pair_data 中。
    # self.graph_data 应该是一个包含图数据的列表，其中每个元素代表一个图。
    #这段代码的主要功能是生成并存储一个图中所有可能的图对，这可能用于图比较、图匹配、图神经网络的数据准备等场景
    def generate_pairs(self):
        self.graph_pair_data = []
        #这行代码使用了 itertools.combinations 函数来遍历 self.graph_data 中所有可能的两个元素的组合。
        # range(len(self.graph_data)) 生成一个从 0 到 len(self.graph_data)-1 的序列，这个序列代表了 self.graph_data 中每个元素的索引。
        # itertools.combinations 函数从这个索引序列中选取所有可能的两个元素的组合，每次迭代返回两个索引（idx_graph_a 和 idx_graph_b），这两个索引分别代表 self.graph_data 中两个不同的图。
        for idx_graph_a, idx_graph_b in itertools.combinations(range(len(self.graph_data)), 2):
            #在每次迭代中，根据当前的两个索引 idx_graph_a 和 idx_graph_b，从 self.graph_data 中取出对应的两个图，并将它们作为一个元组添加到 self.graph_pair_data 列表中。
            # 这样，最终 self.graph_pair_data 将包含 self.graph_data 中所有可能的图对
            self.graph_pair_data.append((self.graph_data[idx_graph_a], self.graph_data[idx_graph_b]))
        #TODO: different sampling technique?
        #可能还有其他的采样技术。
    
    def get_graphs(self):
        return self.graph_data
    
    def get_pairs(self):
        if len(self.graph_pair_data) == 0:
            raise Exception("you have to genearte pairs first!")
        return self.graph_pair_data

    #目的是将一个给定的数据集 dataset 根据某个比例 ratio 分割成训练集和测试集，同时保证分割时能够按照某种标签（相似或不同）的分布进行分层抽样（stratified sampling）。
    def split_dataset(self, ratio, seed, dataset):
        #将原来的0/1标签改为-1/1，放到sim_diff_label中
        sim_diff_label = []

        for data in dataset:
            #print(f"type(data)= {type(data)}") 下面执行else处
            if type(data) == tuple:
                if data[2] == 1:
                    sim_diff_label.append(1)
                else:
                    sim_diff_label.append(-1)
            else:
                if data.label == 1:
                    sim_diff_label.append(1)
                else:
                    sim_diff_label.append(-1)
        #print(sim_diff_label)
        print(f"ratio={ratio},len={len(dataset)},size={int(len(dataset) * ratio)}")
        return train_test_split(dataset, train_size = int(len(dataset) * ratio), shuffle = True, stratify=sim_diff_label, random_state=seed)

    #方法的目的是计算训练数据集 train_graphs 中每个类别的权重，以便在训练神经网络时可以平衡不同类别之间的样本数量差异。
    # 这种方法在处理不平衡数据集时特别有用，因为它可以帮助模型更加关注于那些数量较少的类别，从而提高整体性能。
    def get_class_weights(self, train_graphs):
        training_labels = [data.label for data in train_graphs]
#        print(np.unique(training_labels))
#        print(f"train_labels = {training_labels}")

        #20240831hgw+ 在 PyTorch 的较新版本中（特别是从 PyTorch 1.2 开始），compute_class_weight 函数的用法已经改变。
        # 这个函数不再直接接受三个位置参数（如 'balanced', np.unique(training_labels), training_labels），而是通过一个参数 kwargs 来接收这些参数。
        #class_weights = torch.from_numpy(compute_class_weight('balanced', np.unique(training_labels), training_labels))

        #改为如下的调用方式：
        unique_labels = np.unique(training_labels)
        class_weights = torch.from_numpy(compute_class_weight('balanced', classes=unique_labels, y=training_labels))
        #使用 np.unique(training_labels) 获取 training_labels 中所有唯一类别的数组。这个数组对于确定训练集中有多少个不同的类别是必要的。
        #调用 compute_class_weight 函数来计算每个类别的权重。
        #第一个参数 'balanced' 指示我们希望得到一个“平衡”的权重，即权重与每个类别的逆频率成比例，以便在训练过程中给予少数类别更多的重视。
        #第二个参数是类别的唯一数组，第三个参数是训练标签的数组。
        #compute_class_weight 函数返回一个包含每个类别权重的 NumPy 数组。
        #使用 torch.from_numpy 将 NumPy 数组转换为 PyTorch 张量（Tensor），以便在 PyTorch 的训练过程中使用这些权重。
        return class_weights

    #这段代码的主要作用是将一个对象的图数据（或其他复杂数据结构）保存到磁盘上，以便将来可以快速重新加载。
    # 通过使用 pickle 模块，Python 对象可以被转换成字节流，并存储到文件中。
    # 当需要时，可以使用 pickle.load 函数从文件中读取并反序列化这些数据，以恢复原始对象。
    def cache_graph_data(self, data_pkl_path):
        with open(data_pkl_path, 'wb+') as f:
            #使用 pickle 模块的 dump 函数将 self.graph_data（当前对象的 graph_data 属性）序列化并写入到之前打开的文件 f 中。
            # pickle.dump 函数接受两个主要参数：要序列化的对象和一个文件对象（在这个例子中是 f），用于写入序列化后的数据。
            pickle.dump(self.graph_data, f)

    #该方法的主要目的是从缓存文件中读取图数据，并根据图类型设置相关的配置信息（如节点标签数量和特征维度）。
    # 这对于需要处理不同类型图数据的图神经网络（GNN）或其他图处理算法来说是非常有用的。
    def read_graph_data_from_cache(self, data_pkl_path):
        #print(f"data_pkl_path = {data_pkl_path}")
        with open(data_pkl_path, 'rb') as f:
            #self.graph_data = pickle.load(f)：使用 pickle 模块的 load 函数从文件 f 中读取并反序列化数据，
            # 然后将结果赋值给当前对象的 graph_data 属性。这样，self.graph_data 就包含了从文件中加载的图数据。
            self.graph_data = pickle.load(f)

        if self.cfg.graph_type == 'DFG':
            self.num_node_labels = len(self.global_type2idx_DFG)
            self.cfg.num_feature_dim = self.num_node_labels
        elif self.cfg.graph_type == 'AST':
            self.num_node_labels = len(self.global_type2idx_AST)
            self.cfg.num_feature_dim = self.num_node_labels
        #TODO: creating pairs or blah blah blah.

#这段代码定义了一个名为 DFGGenerator 的类，其主要目的是从一个 Verilog 文件中提取数据流信息，
#并基于这些信息生成一个数据流图（DFG）。这个过程涉及到几个关键步骤，包括数据流分析、优化，以及最终图的生成。
class DFGGenerator:
    def __init__(self):
        pass
    #本例中，verilog_file = E:\PRO\Python\HT\hw2vec\assets\TJ-RTL-toy\TjFree\det_1011\topModule.v
    def process(self, verilog_file, preprocess_include=None, enable_signal_to_nodes=True):
        dataflow_analyzer = VerilogDataflowAnalyzer(verilog_file, "top", preprocess_include=preprocess_include) #生成.frametable、.terms、.binddict
        #print(f"flag0:hw2graph.py:DFGGenerator.process()")
        dataflow_analyzer.generate()    #这里面生成AST，分析文件并生成数据流信息(.frametable、.terms、.binddict 等中间文件)
        #print(f"flag1:hw2graph.py:DFGGenerator.process()")
        binddict = dataflow_analyzer.getBinddict()  #获取绑定字典和项列表,信号绑定字典（信号名到内部标识的映射）
        terms = dataflow_analyzer.getTerms()#信号项列表（所有信号的集合）
        #print(f"Binddict={binddict}")
        #print(f"terms={terms}")

        dataflow_optimizer = VerilogDataflowOptimizer(terms, binddict)  #创建实例，用于优化数据流信息。
        dataflow_optimizer.resolveConstant()#解析常量传播（如wire a = 1'b1)。
        resolved_terms = dataflow_optimizer.getResolvedTerms()  #获取优化后的项列表、绑定字典和常量列表
        resolved_binddict = dataflow_optimizer.getResolvedBinddict()
        constlist = dataflow_optimizer.getConstlist()
        #上述信息用于生成数据流图，这里指定了输出PDF文件的路径
        #20251118注释掉该行，改为在循环中定义，保存每个信号的子图节点
        dfg_graph_generator = VerilogGraphGenerator("top", terms, binddict, resolved_terms,
                                                    resolved_binddict, constlist, './seperate_modules.pdf')
        dfg_graph_subs = [] #DFG_graph类型，定义一个列表，用于存储每个信号的子图节点。
        
        # 20260529新增：保存信号到整图节点的映射关系，# 用于后续GT信号子图节点的快速提取，避免重新从Verilog生成
        # 20260529修改：enable_signal_to_nodes 通过参数传入
        ENABLE_SIGNAL_TO_NODES = enable_signal_to_nodes  # 从函数参数获取
        signal_to_nodes = {}  # 格式: {signal_name: set(整图节点名), ...}   
        #数据流图的生成和优化，遍历所有信号，为每个信号生成独立的数据流图
        # 特别是，对于输入度为 0 的节点（即没有前驱节点的节点），会检查是否存在一个仅通过下划线 _ 和点 . 差异而不同的节点。
        # 如果存在，将当前节点删除，并将其前驱节点连接到这个“相似”的节点上。
        # binddict with string keys
        #signals = [str(bind) for bind in dfg_graph_generator.binddict] #原始语句
        signals = [str(bind) for bind in dfg_graph_generator.binddict if '_rm_' not in str(bind)]#20260311+这里直接过滤掉_rm_的信号，因此已经包含在对应的原始信号子图中。

        #遍历binddict中的信号，为每个信号生成单独的数据流图。每个节点会重新命名。
        
        # ========== 方案D（终极优化）：延迟提取，只记录counter范围 ==========
        # 核心思路：不在循环中提取节点，只记录每个signal的counter范围
        # 最后一次性遍历整图，根据counter范围分配到各个signal
        signal_counter_ranges = {}  # {signal: (counter_before, counter_after)}
        
        for num, signal in enumerate(sorted(signals, key=str.casefold), start=1):
            # 记录调用前的 counter 值（O(1)操作）
            if ENABLE_SIGNAL_TO_NODES:
                counter_before = dfg_graph_generator.renamecounter
            
            dfg_graph_generator.generate(signal, walk=False)    #累加到整图

            # 记录调用后的 counter 值（O(1)操作）
            if ENABLE_SIGNAL_TO_NODES:
                counter_after = dfg_graph_generator.renamecounter
                signal_counter_ranges[str(signal)] = (counter_before, counter_after)
            
            # ========== 方案C（已注释）：记录节点集合 ==========
            # if ENABLE_SIGNAL_TO_NODES:
            #     nodes_before = set(dfg_graph_generator.graph.nodes_iter())
            #     dfg_graph_generator.generate(signal, walk=False)
            #     nodes_after = set(dfg_graph_generator.graph.nodes_iter())
            #     new_nodes = nodes_after - nodes_before
            #     signal_to_nodes[str(signal)] = set(str(n) for n in new_nodes)
            
            # ========== 方案A（已注释）：使用 renamecounter 范围提取新增节点 ==========
            # if ENABLE_SIGNAL_TO_NODES:
            #     counter_before = dfg_graph_generator.renamecounter
            #     dfg_graph_generator.generate(signal, walk=False)
            #     counter_after = dfg_graph_generator.renamecounter
            #     new_nodes = set()
            #     for node in dfg_graph_generator.graph.nodes():
            #         node_str = str(node)
            #         if '_rn_' in node_str:
            #             try:
            #                 node_num = int(node_str.split('_rn_')[-1])
            #                 if counter_before <= node_num < counter_after:
            #                     new_nodes.add(node_str)
            #             except ValueError:
            #                 pass
            #     signal_to_nodes[str(signal)] = new_nodes
            
            # ========== 方案B（已注释）：使用集合差集提取新增节点（低性能） ==========
            # if ENABLE_SIGNAL_TO_NODES:
            #     num_nodes_before = dfg_graph_generator.graph.number_of_nodes()
            #     dfg_graph_generator.generate(signal, walk=False)
            #     num_nodes_after = dfg_graph_generator.graph.number_of_nodes()
            #     if num_nodes_after > num_nodes_before:
            #         all_nodes = list(dfg_graph_generator.graph.nodes())
            #         new_nodes = set(str(n) for n in all_nodes[num_nodes_before:])
            #         signal_to_nodes[str(signal)] = new_nodes
            #     else:
            #         signal_to_nodes[str(signal)] = set()
            
            #另行创建一个临时的DFG生成器，用于生成每个信号的DFG，并添加到子图列表中。
            dfg_graph_generator_tmp = VerilogGraphGenerator("top", terms, binddict, resolved_terms, resolved_binddict, constlist, './seperate_modules.pdf')
            dfg_graph_generator_tmp.generate(signal, walk=False)#在这里生成每个信号的DFG,放到graph{}中！！！！！walk=false表示不递归遍历子模块
            if dfg_graph_generator_tmp.graph.number_of_nodes() >= 3:#20251226+仅记录3点以上的子图
                dfg_graph_subs.append(dfg_graph_generator_tmp.graph)    #添加到子图列表中，注意，这里存的是.graph，而不是dfg_graph_generator_tmp!!!
        
        # ========== 方案D：最后一次性提取所有节点 ==========
        if ENABLE_SIGNAL_TO_NODES and signal_counter_ranges:
            # 只遍历一次整图（8342个节点）
            for node in dfg_graph_generator.graph.nodes():
                node_str = str(node)
                if '_rn_' in node_str:
                    try:
                        node_num = int(node_str.split('_rn_')[-1])
                        # 查找这个节点属于哪个 signal
                        for signal_name, (c_before, c_after) in signal_counter_ranges.items():
                            if c_before <= node_num < c_after:
                                if signal_name not in signal_to_nodes:
                                    signal_to_nodes[signal_name] = set()
                                signal_to_nodes[signal_name].add(node_str)
                                break  # 找到后跳出，避免重复
                    except ValueError:
                        pass

        for idx,dfg_graph_sub in enumerate(dfg_graph_subs):#列表中存放的是Agraph对象!!!
            continue
            print(f"子图{idx}：节点数：{len(dfg_graph_sub.nodes())}，边数：{len(dfg_graph_sub.edges())}")
            print(f" 节点:{list(dfg_graph_sub.nodes())}")
            print(f"  边:{list(dfg_graph_sub.edges())}")

        ''''''
        #以整体图进行节点合并优化，合并输入度为0的相似节点（通过_和.差异判断），例如节点a_b和a.b会被合并，前者的父节点直接连接到后者。
        label_to_node = dict()
        for node in dfg_graph_generator.graph.nodes():
            if dfg_graph_generator.graph.in_degree(node) == 0:
                label = node.attr['label'] if node.attr['label'] != '\\N' else str(node)
                label_to_node[label] = node
        
        num_nodes = len(dfg_graph_generator.graph.nodes())
        merged_count = 0
        for num, node in enumerate(dfg_graph_generator.graph.nodes(), start=1):#这里未生效，没有满足条件的情况
            label = node.attr['label'] if node.attr['label'] != '\\N' else str(node)
            if '_' in label and label.replace('_', '.') in label_to_node:
                parents = dfg_graph_generator.graph.predecessors(node)
                #print(f'Progress : {num} / {num_nodes}')
                dfg_graph_generator.graph.delete_node(node)
                merged_count += 1
                for parent in parents:
                    dfg_graph_generator.graph.add_edge(parent, label_to_node[label.replace('_', '.')])

        nx_graph = nx.DiGraph() #NetworkX类型，创建一个新的 NetworkX 有向图 (nx.DiGraph) 实例，用于存储优化后的数据流图。
        #遍历 VerilogGraphGenerator 生成的图的节点，根据节点名称添加节点到 NetworkX 图中，
        # 并根据节点名称中的特定模式（如 . 或 _）为节点添加类型标签。
        for node in dfg_graph_generator.graph.nodes():
            #node_name = node.name
            #if '_graphrename' in node.name:     #去掉_graphrename后缀
            #if '_rn_' in node_name:  # 去掉_graphrename后缀,原始代码中为_graphrename 改为_rn_
            #    node_name = node_name[:node_name.index('_rn_')]
            #if '_rm_' in node_name:  # 去掉_rm_后缀,pyverilog.dataflow.bindvisitor.BindVisitor.renameVar()中对var重命名时，添加的标志
            #    node_name = node_name[:node_name.index('_rm_')]#20260201添加
            #
            #if '.' in node_name:                #根据.或_分割名称，取最后一部分作为类型标签（如module.singal -> signal)
            #    type_of_node = node_name.split('.')[-1]
            #elif '_' in node_name:
            #    type_of_node = node_name.split('_')[-1]
            #else:
            #    type_of_node = node_name.lower()
            var_name=get_var_name(node.name)#从节点名中获取原始的变量名(不含所在的模块、函数名，如top.Module.var)
            nx_graph.add_node(node.name, varname=var_name)#这里还可以添加其他属性值，属性名和值可以自定义##################################
            #添加边到 NetworkX 图中，以表示数据流图中的连接关系。
            for child in dfg_graph_generator.graph.successors(node):
                edge_label = dfg_graph_generator.graph.get_edge(node, child).attr['label']
                #edge_attrs = dfg_graph_generator.graph.get_edge(node, child).attr # **edge_attrs 获取边所有属性
                nx_graph.add_edge(node.name, child.name,label=edge_label)#同理这里也可以添加边的其他属性
        #print(f"1-{type(nx_graph)}-是否有type:{hasattr(nx_graph,'type')}")
        #print("\n")
        #print(f"子图 整体: 节点数{nx_graph.number_of_nodes()}, 边数{nx_graph.number_of_edges()}")
        #print(f" 节点:{nx_graph.nodes()}")
        #print(f" 边:{nx_graph.edges()}")
        #print("\n")

        #生成每个子图的 NetworkX 图，放入nx_graphs列表中
        nx_graphs=[]    #在后面添加.type属性，未添加.name
        for idx, dfg_graph_sub in enumerate(dfg_graph_subs):
            nx_graph_tmp=nx.DiGraph()
            for node in dfg_graph_sub.nodes():
                #node_name = node.name
                #if '_rn_' in node.name:
                #    node_name = node.name[:node.name.index('_rn_')]
                #if '_rm_' in node_name:  # 去掉_rm_后缀,pyverilog.dataflow.bindvisitor.BindVisitor.renameVar()中对var重命名时，添加的标志
                #    node_name = node_name[:node.name.index('_rm_')]  # 20260201添加
                #if '.' in node_name:
                #    type_of_node = node_name.split('.')[-1]
                #elif '_' in node_name:
                #    type_of_node = node_name.split('_')[-1]
                #else:
                #    type_of_node = node_name.lower()
                var_name=get_var_name(node.name)
                nx_graph_tmp.add_node(node.name,varname=var_name)
                for child in dfg_graph_sub.successors(node):
                    edge_label = dfg_graph_sub.get_edge(node, child).attr['label']
                    nx_graph_tmp.add_edge(node.name,child.name,label=edge_label)
            #print(f"2-{type(nx_graph_tmp)}-是否有type:{hasattr(nx_graph_tmp, 'type')}")
            nx_graphs.append(nx_graph_tmp)
        
        '''#合并一些子图，那A图的叶节点和B图的根节点相同时，可以将B图合并到A图中。先造一个根节点字典，#实际是不行的，会存在循环的情况
        root_list=[]
        idx_graph=dict()
        for i,sub in enumerate(nx_graphs):
            node_name=list(sub.nodes())[0]# 获取第一个节点，即为根节点，基于Python字典插入顺序
            node_name=node_name[:node_name.index('_rn_')]
            root_list.append(node_name)#首节点的名称中均含有_rn_0，
            idx_graph[node_name]=i
        print(f"root_list = {root_list}")
        print(f"idx_graph = {idx_graph}")

        for i,g_src in enumerate(nx_graphs):
            #先取出所有叶节点
            out_degrees=dict(g_src.out_degree())
            leaf_nodes=[node for node in g_src.nodes() if out_degrees[node] == 0]
            print(f"g_src={g_src}: leaf={leaf_nodes}")
            for node_name in leaf_nodes:#为叶节点，节点名中含有'_rn_x'，这里的x!=0
                if '_rn_' in node_name:
                    node_name=node_name[:node_name.index('_rn_')]#取出不含_rn_的节点名
                print(f"0 node_name={node_name}")
                if node_name in root_list:
                    g_dst=nx_graphs[ idx_graph[node_name] ]
                    print(f"g_dst={g_dst}")
                    #对g_dst进行改名，在名称中加上_rn_x
                    merge_nxgraphs(g_dst,g_src)

                print(f"")
        '''

        #输出每个子图的可视化图png
        drawer=GraphDrawer()
        for idx, nx_graph_tmp in enumerate(nx_graphs):
            #drawer.draw_graph_drymatic(idx,nx_graph_tmp)
            #drawer.draw_graph(idx, nx_graph_tmp,savepath='./子图PNG示例/')#使用这个画图
            continue
            print(f"子图{idx}: 节点数{nx_graph_tmp.number_of_nodes()}, 边数{nx_graph_tmp.number_of_edges()}")
            print(f" 节点:{nx_graph_tmp.nodes()}")
            print(f" 边:{nx_graph_tmp.edges()}")

        #
        #drawer = GraphDrawer()
        #for idx, nx_graph in enumerate(nx_graphs):
        #    drawer.draw_graph_pydot(idx, nx_graph)

        return nx_graph,nx_graphs,signal_to_nodes #返回值：nx_graph是整体图的nx图,nx_graphs是所有子图的nx图。signal_to_nodes是信号到节点的映射关系

#代码功能：这是一个用于将Verilog代码转换为抽象语法树（AST）并生成网络图（NetworkX DiGraph）的工具类。主要功能包括：
#解析Verilog代码生成AST，将AST转换为嵌套字典结构，将字典结构转换为带标签的有向图
class ASTGenerator:
    def __init__(self):
        # 需要生成字典结构（键值对结构）的节点类型，如端口声明
        self.DICTIONARY_GEN = \
            ["Source","Description","Ioport","Decl","Lvalue"]
        # 需要生成数组结构的节点类型，如模块定义、参数列表
        self.ARRAY_GEN = \
            ["ModuleDef","Paramlist","Portlist","Input","Width","Reg","Wire","Rvalue","ParseSelect",
             "Uplus","Uminus","Ulnot","Unot","Uand","Unand","Uor","Unor","Uxnor","Power","Times","Divide","Mod","Plus",
             "Minus","Sll","Srl","Sla","Sra","LessThan","GreaterThan","LessEq","GreaterEq","Eq","Eql","NotEq","Eql","NotEql",
             "And","Xor","Xnor","Or","Land","Lor","Cond","Assign","Always","AlwaysFF","AlwaysComb","AlwaysLatch",
             "SensList","Sens","Substitution","BlockingSubstitution","NonblockingSubstitution","IfStatement","Block",
             "Initial","Plus","Output","Partselect","Port","InstanceList","Instance","PortArg","Pointer","Concat", "Parameter", 
             "SystemCall", "CaseStatement", "Case", "Function", "CasezStatement", "FunctionCall", "Dimensions", "Length", 
             "LConcat", "Concat", "SingleStatement", "Repeat", "Integer", "CasexStatement", "ForStatement", "Localparam",
             "EventStatement", "DelayStatement", "Task", "ParamArg", "Inout"]
        # 存储常量类型节点，如标识符、数值常量。
        self.CONST_DICTIONARY_GEN = \
            ["IntConst","FloatConst","StringConst","Identifier"]
        self.count = 0

    #方法功能：使用pyverilog的parse函数时行解析，通过_generate_ast_dict将AST转换为嵌套字典，使用networkX构建 带标签的有向图
    def process(self, verilog_file):
        #when generating AST, determines which substructure (dictionary/array) to generate
        #before converting the json-like structure into actual json
        
        self.ast, _ = parse([verilog_file], debug=False)#解析verilog文件
        ast_dict = self._generate_ast_dict(self.ast)#转换为字典结构

        nx_graph = nx.DiGraph()
        for key in ast_dict.keys():
            self._add_node(nx_graph, 'None', key, ast_dict[key])#递归添加节点

        return nx_graph

    #generates nested dictionary for conversion to json (AST helper)
    def _generate_ast_dict(self, ast_node):
        class_name = ast_node.__class__.__name__
        structure = {}
        #based on the token class_name, determine the value type of class_name
        if class_name in self.ARRAY_GEN:# 处理数组类型节点（如模块定义、参数列表），收集属性值并递归处理子节点
            structure[class_name] = [getattr(ast_node, n) for n in ast_node.attr_names] if ast_node.attr_names else []
            for c in ast_node.children():
                structure[class_name].append(self._generate_ast_dict(c))
        elif class_name in self.DICTIONARY_GEN: # 处理字典类型节点（如端口声明），只处理第一个子节点
            structure[class_name] = self._generate_ast_dict(ast_node.children()[0])
        elif class_name in self.CONST_DICTIONARY_GEN:# 处理常量节点（如标识符、数值），直接存储属性值
            structure = {}
            structure[class_name] = getattr(ast_node,ast_node.attr_names[0])
            return structure
        else:
            raise Exception(f"Error. Token name {class_name} is invalid or has not yet been supported")
        return structure

    #_add_node方法负责将字典结构转换为图中的节点和边。使用计数器为每个节点生成唯一索引，添加节点标签，并根据父子关系添加边。
    # 这里处理了字典、列表和其他类型的数据，递归地添加子节点。
    def _add_node(self, graph, parent, child, cur_dict):
        index = self.count
        graph.add_nodes_from([(index, {"label": str(child)})])# 添加当前节点
        if parent != 'None':
            graph.add_edge(parent, index)# 添加父子边
        self.count = self.count + 1
        # 类型处理：递归处理子结构
        if type(cur_dict) == dict:#字典：递归处理每个键值对
            for key in cur_dict.keys():
                self._add_node(graph, index, key, cur_dict[key])
        elif type(cur_dict) == list:#列表：处理元素或递归处理字典元素
            for ele in cur_dict:
                if type(ele) == dict:
                    self._add_node(graph, index, 'None', ele)
                elif ele is not None:
                    graph.add_nodes_from([(self.count, {"label": str(ele)})])
                    graph.add_edge(index, self.count)
                    self.count = self.count + 1
        else:#其他类型：直接作为叶子节点
            graph.add_nodes_from([(self.count, {"label": str(cur_dict)})])
            graph.add_edge(index, self.count)
            self.count = self.count + 1

class CFGGenerator:
    def __init__(self):
        pass

    #def process(self, verilog_file):
    def process(self, verilog_file,output):#函数定义时，添加第三个参数output='graph'
        fsm_vars = tuple(['fsm', 'state', 'count', 'cnt', 'step', 'mode'])
        #dataflow_analyzer = VerilogDataflowAnalyzer(self.verilog_file, "top")#原文报错，注释掉
        dataflow_analyzer = VerilogDataflowAnalyzer(verilog_file, "top")
        dataflow_analyzer.generate()
        binddict = dataflow_analyzer.getBinddict()
        terms = dataflow_analyzer.getTerms()
        
        dataflow_optimizer = VerilogDataflowOptimizer(terms, binddict)
        dataflow_optimizer.resolveConstant()
        resolved_terms = dataflow_optimizer.getResolvedTerms()
        resolved_binddict = dataflow_optimizer.getResolvedBinddict()
        constlist = dataflow_optimizer.getConstlist()
        cfg_graph_generator = VerilogControlflowAnalyzer("top", terms, binddict, resolved_terms, resolved_binddict, constlist, fsm_vars)
        fsms = cfg_graph_generator.getFiniteStateMachines()#此处为FSM的生成函数！！！！！！！

        print("VIEWING FSM's")#FSM的可视化，包括文件打印和状态转移图。
        print("LENGTH OF FSM: ", len(fsms))
        for signame, fsm in fsms.items():
            print('# SIGNAL NAME: %s' % signame)
            print('# DELAY CNT: %d' % fsm.delaycnt)
            fsm.view()#打印文本形式的状态转移及条件，对应pyverilog论文中的图5
            fsm.tograph(filename=util.toFlatname(signame) + '.png', nolabel=False)#会生成相应的状态转移图

        graph = pydot.graph_from_dot_file("./file.dot")[0]
        print(f"node_list={graph.get_node_list()}")

        nodes = [node.get_name() for node in graph.get_node_list()]
        root_nodes = [node.get_name() for node in graph.get_node_list() if node.obj_dict['parent_graph'] == None]
        edges = [[edge.get_source(),edge.get_destination(),edge.obj_dict['attributes']['label']] for edge in graph.get_edge_list()]
        #topModule = defaultdict([])
        topModule = defaultdict(list)

        for edge in edges:
            if edge[2] == 'None':
                topModule[edge[0]].append("")
            else:
                topModule[edge[0]].append(edge[2])#记录当前状态的转移条件，如'0':'Ulnot','GreaterThan'等

        #会在 E:\PRO\python\HT\hw2vec\examples 目录下生成4个*.json文件，记录节点、边、根节点等信息，
        # 这些信息都来自于前面的graph对象，可在调试窗口中复制查看内容。
    #if (output=='roots'):#这个if条件不需要了。
        print(f'Saving all {len(root_nodes)} nodes as root_nodes.json')
        with open('./root_nodes.json', 'w') as f:
            f.write(dumps(root_nodes, indent=4))
        #print('List of root nodes saved in root_nodes.json.\n')
        #f.close()

    #elif (output=='nodes'):
        print(f'Saving all {len(nodes)} nodes as all_nodes.json')
        with open('./all_nodes.json', 'w') as f:
            f.write(dumps(nodes, indent=4))
        #print('List of nodes saved in all_nodes.json.\n')
        #f.close()

    #elif (output=='edges'):
        print(f'Saving all {len(edges)} edges as all_edges.json')
        with open('./all_edges.json', 'w') as f:
            f.write(dumps(edges, indent=4))
        #print('List of edges saved in all_edges.json.\n')
        #f.close()

    #elif (output=='graph'):
        print(f'Saving cfg graph dictionary as a topModule.json')
        with open('./topModule.json', 'w') as f:
            f.write(dumps(topModule, indent=4))
        #print('Saving cfg graph dictionary as a json.\n')
        #f.close()
        #print('The graph is saved as topModule.json.\n')

        return None#注意，这里返回的是None，因为CFG的功能到此就结束了，已经获取了状态转移图及其条件等。


class HW2GRAPH:
    
    '''
        The main class of hw2graph consists of two components:
        1. preprocess (flatten, remove comment, ...)
        2. processs (call backend graph geenration and acquire the nx graph instances.)

        Currently HW2GRAPH can process Verilog files in RTL (Register Transfer Level) and GLN (Gate-Level Netlist).
    ''' 

    def __init__(self, cfg):
        self.cfg = cfg

    #在指定的原始数据集路径中搜索所有包含 .v（Verilog文件）的文件夹，并将这些文件夹作为项目文件夹返回。
    def find_hw_project_folders(self):        
        projects = set()

        for verilog_path in glob("%s/**/*.v" % str(self.cfg.raw_dataset_path), recursive=True):
            folder_name = Path(verilog_path).parent
            projects.add(folder_name)

        return list(projects)

    #将指定目录下（input_path）的所有 Verilog 文件（扩展名为 .v）的内容合并到一个新的文件中（flattened_hw_path）
    def flatten(self, input_path, flattened_hw_path):
        flatten_content = ""
        all_containing_files = [Path(x).name for x in glob(fr'{input_path}/*.v', recursive=True)]   #优：这里使用Path().rglob()更好，不需要fr前缀。
        # 注释掉：强制每次重新生成 topModule.v
        #if "topModule.v" in all_containing_files:
        #    return
        
        #首先收集所有 .h 和 .v 文件中的宏定义 (parameter 和 `define)
        macro_dict = {}  # 存储宏名 -> 宏值
        header_content = ""
        
        #处理 .h 头文件中的宏定义
        for header_file in glob(fr'{input_path}/*.h'):
            with open(header_file, "r") as infile:
                header_content += infile.read() + "\n"
        
        #处理 .v 文件中的宏定义文件（如 defines.v）
        for verilog_file in glob(fr'{input_path}/*.v'):
            name = str(verilog_file).split("\\")[-1]
            if "define" in name.lower() or "defs" in name.lower() or "include" in name.lower():
                with open(verilog_file, "r") as infile:
                    header_content += infile.read() + "\n"
        
        #解析宏定义：parameter NAME = VALUE; 或 `define NAME VALUE
        #处理多行 parameter 定义（逗号分隔）
        #首先找到所有 parameter 块（从 parameter 关键字开始到分号结束）
        param_block_pattern = r'parameter\s+(?:\[[^\]]+\]\s+)?([^;]+);'
        for block_match in re.finditer(param_block_pattern, header_content, re.DOTALL):
            param_block = block_match.group(1)
            #在多行块中解析每个 name = value 对
            #匹配格式：name = value（支持逗号或行尾结束）
            param_pair_pattern = r'(\w+)\s*=\s*([^,\n]+)'
            for pair_match in re.finditer(param_pair_pattern, param_block):
                macro_name = pair_match.group(1)
                macro_value = pair_match.group(2).strip()
                macro_dict[macro_name] = macro_value
        
        #处理条件宏定义：先处理 `ifdef 块，只提取实际生效的宏定义
        #递归处理 `ifdef 块，直到没有更多的 `ifdef
        max_iterations = 100  # 防止无限循环
        for _ in range(max_iterations):
            #处理 `ifdef 0 ... `else ... `endif：删除 `ifdef 0 部分，保留 `else 部分
            new_content = re.sub(
                r'`ifdef\s+0\s*(.*?)`else\s*(.*?)`endif',
                r'\2',
                header_content,
                flags=re.DOTALL
            )
            #处理 `ifdef 0 ... `endif（没有 `else）：删除内容
            new_content = re.sub(
                r'`ifdef\s+0\s*(.*?)`endif',
                '',
                new_content,
                flags=re.DOTALL
            )
            #处理 `ifdef 1 ... `else ... `endif：保留 `ifdef 1 部分，删除 `else 部分
            new_content = re.sub(
                r'`ifdef\s+1\s*(.*?)`else\s*(.*?)`endif',
                r'\1',
                new_content,
                flags=re.DOTALL
            )
            #处理 `ifdef 1 ... `endif（没有 `else）：保留内容
            new_content = re.sub(
                r'`ifdef\s+1\s*(.*?)`endif',
                r'\1',
                new_content,
                flags=re.DOTALL
            )
            #处理未定义的宏（如 `ifdef RUDIS_TB）：如果 RUDIS_TB 不在 macro_dict 中，则删除整个块
            #先找到所有 `ifdef 宏名 块
            ifdef_pattern = r'`ifdef\s+(\w+)\s*(.*?)`endif'
            for match in re.finditer(ifdef_pattern, new_content, re.DOTALL):
                macro_name = match.group(1)
                #如果宏名不是 0 或 1，且不在 macro_dict 中，则删除整个块
                if macro_name not in ['0', '1'] and macro_name not in macro_dict:
                    new_content = new_content.replace(match.group(0), '')
            
            if new_content == header_content:
                break  # 没有更多变化，退出循环
            header_content = new_content
        
        #匹配 `define 定义（确保不是注释掉的）
        #使用多行模式，匹配行首不是 // 的 `define
        lines = header_content.split('\n')
        for line in lines:
            # 跳过注释行（行首是 //）
            stripped = line.strip()
            if stripped.startswith('//'):
                continue
            # 检查行中是否有 `define，但前面有 //（即被注释掉的）
            # 例如：//`define RUDIS_TB 1
            if re.search(r'//\s*`define', stripped):
                continue
            # 匹配 `define 宏名 值
            define_match = re.match(r'`define\s+(\w+)\s+(.+)', stripped)
            if define_match:
                macro_name = define_match.group(1)
                macro_value = define_match.group(2).strip()
                # 移除行尾注释
                if '//' in macro_value:
                    macro_value = macro_value[:macro_value.index('//')].strip()
                macro_dict[macro_name] = macro_value
        
        #收集主内容（非宏定义文件）
        #检查是否是 memctrl 设计，如果是则使用指定的文件合并顺序
        input_path_str = str(input_path).lower()
        if 'memctrl' in input_path_str:
            # memctrl 设计：按照依赖顺序合并文件
            file_order = [
                # 基础模块（无依赖）
                'mc_incn_r.v',
                'mc_rd_fifo.v',
                # 下一层模块
                'mc_cs_rf.v',  # 包含 mc_cs_rf 和 mc_cs_rf_dummy
                'mc_obct.v',   # 包含 mc_obct 和 mc_obct_dummy
                'mc_dp.v',
                'mc_refresh.v',
                'mc_wb_if.v',
                'mc_mem_if.v',
                # 中间层模块（依赖基础模块）
                'mc_adr_sel.v',
                'mc_obct_top.v',
                'mc_rf.v',
                # 复杂模块
                'mc_timing.v',
                # 顶层模块（最后）
                'mc_top.v'
            ]
            
            main_content = ""
            for fname in file_order:
                fpath = input_path / fname
                if fpath.exists():
                    with open(fpath, "r") as infile:
                        main_content += infile.read() + "\n"
        else:
            # 其他设计：使用原来的逻辑
            main_files = []
            top_module_file = None
            for verilog_file in glob(fr'{input_path}/*.v'):
                name = str(verilog_file).split("\\")[-1]
                if "test_" in name:
                    continue
                if "define" in name.lower() or "defs" in name.lower() or "include" in name.lower():
                    continue
                if name.lower() == "topmodule.v":
                    continue
                with open(verilog_file, "r") as f:
                    content = f.read()
                    if 'module mc_top' in content or 'module top' in content:
                        top_module_file = verilog_file
                    else:
                        main_files.append(verilog_file)
            
            main_content = ""
            for verilog_file in main_files:
                with open(verilog_file, "r") as infile:
                    main_content += infile.read() + "\n"
            if top_module_file:
                with open(top_module_file, "r") as infile:
                    main_content += infile.read() + "\n"
        
        flatten_content = main_content
        
        #删除 `include 语句
        flatten_content = re.sub(r'`include\s+"[^"]+"\s*\n?', '\n', flatten_content)
        
        #保护 `ifdef 和 `ifndef 块中的宏名不被替换
        #使用占位符来临时替换这些宏名
        protected_macros = {}
        placeholder_counter = 0
        
        def protect_ifdef_macros(content):
            nonlocal placeholder_counter
            #匹配 `ifdef 宏名 或 `ifndef 宏名
            pattern = r'(`ifdef\s+|`ifndef\s+)(\w+)'
            
            def replace_macro(match):
                nonlocal placeholder_counter
                prefix = match.group(1)
                macro_name = match.group(2)
                if macro_name in macro_dict:
                    placeholder = f"__PROTECTED_MACRO_{placeholder_counter}__"
                    placeholder_counter += 1
                    protected_macros[placeholder] = macro_name
                    return prefix + placeholder
                return match.group(0)
            
            return re.sub(pattern, replace_macro, content)
        
        flatten_content = protect_ifdef_macros(flatten_content)
        
        #宏展开：将宏名替换为宏值（按宏名长度降序，避免部分替换）
        #例如：先替换 x_STARTbit 再替换 x_START，避免错误
        sorted_macros = sorted(macro_dict.items(), key=lambda x: len(x[0]), reverse=True)
        for macro_name, macro_value in sorted_macros:
            #使用单词边界匹配，确保只替换完整的宏名
            pattern = r'\b' + re.escape(macro_name) + r'\b'
            flatten_content = re.sub(pattern, macro_value, flatten_content)
        
        #恢复被保护的宏名
        for placeholder, macro_name in protected_macros.items():
            flatten_content = flatten_content.replace(placeholder, macro_name)
        
        #修复空端口连接：将 ",   ," 替换为 ", __EMPTY_PORT_\d__ ,"
        #并使用虚拟 wire 声明替代，避免 Pyverilog 不支持 1'b0 的问题
        empty_port_counter = 0
        def replace_empty_port(match):
            nonlocal empty_port_counter
            port_name = f"__EMPTY_PORT_{empty_port_counter}__"
            empty_port_counter += 1
            return f", {port_name} ,"
        
        flatten_content = re.sub(r',\s*,', replace_empty_port, flatten_content)
        
        #为每个包含空端口的模块添加虚拟 wire 声明
        #匹配 module 定义并在其中添加 wire 声明
        def add_dummy_wires_to_module(match):
            module_header = match.group(1)
            module_body = match.group(2)
            module_end = match.group(3)
            
            #查找模块中使用的所有 __EMPTY_PORT_\d__
            empty_ports = re.findall(r'__EMPTY_PORT_\d+__', module_body)
            if empty_ports:
                #去重并生成 wire 声明
                unique_ports = sorted(set(empty_ports))
                wire_declarations = '\n    '.join([f"wire [127:0] {port};  // dummy wire for empty port" for port in unique_ports])
                #在 module 体的适当位置插入 wire 声明
                #找到第一个 wire/reg/assign/always 之前的位置插入
                insert_pos = len(module_header)
                return f"{module_header}\n    {wire_declarations}{module_body[insert_pos-len(module_header):]}{module_end}"
            return match.group(0)
        
        #匹配 module ... endmodule 结构
        flatten_content = re.sub(
            r'(module\s+\w+\s*\([^)]*\);)(.*?)(endmodule)',
            add_dummy_wires_to_module,
            flatten_content,
            flags=re.DOTALL
        )
        
        #修复数字常量中的空格：如 34'b 0011... 改为 34'b0011...
        flatten_content = re.sub(r"(\d+'[bhd])\s+([0-9a-fA-F_xzXZ]+)", r'\1\2', flatten_content)
        
        #注意：不再处理 `ifdef 块，因为 mc_defines.v 已经通过预处理程序清理
        #如果需要在代码中处理 `ifdef 块，请确保正则表达式不会匹配过多的内容
        
        #修复非法的宏引用：如 `3'h0 改为 3'h0（删除前面的 `）
        flatten_content = re.sub(r'`(\d+\'h[0-9a-fA-F]+)', r'\1', flatten_content)
        
        #修复非法的宏引用：如 `(expr) 改为 (expr)（删除前面的 `）
        flatten_content = re.sub(r'`\(', '(', flatten_content)
        
        #修复非法的宏引用：如 `4'b0111 改为 4'b0111（删除前面的 `）
        flatten_content = re.sub(r"`(\d+'b[0-1]+)", r'\1', flatten_content)
        
        with open(flattened_hw_path, "w") as outfile:
            outfile.write(flatten_content)

    #从给定的硬件描述文件（hw_path）中移除单行注释（以 // 开头的部分）
    #这里，还要再去掉/**/形式的多行注释
    def remove_comments(self, hw_path):
        with open(hw_path,'r') as file_in:
            lines = file_in.read().split("\n")
    
        #TODO; right now this part is a rule-based method, we will consider using AST to remove comments in the future.
        with open(hw_path, "w") as file_out:
            for line in lines:
                idx = line.find('//')
                if idx == 0:
                    continue
                elif idx == -1:
                    file_out.write(line+'\n')
                else:
                    file_out.write(line[:idx]+'\n')

    #从给定路径（hw_path）的文件中移除所有的下划线（_）字符  #这样处理合理吗，有可能造成重名。
    def remove_underscores(self, hw_path):
        with open(hw_path, 'r') as file_in:
            lines = file_in.read().replace('_', '')

        with open(hw_path, "w") as file_out:
            file_out.write(lines)

    #旨在将指定硬件描述文件（hw_path）中的顶级模块名称替换为 'top'，方法：先扫描统计所有module后跟的模块名，再扫描统计所有模块名出现的次数，然后将出现次数为1的模块名替换为 'top'
    def rename_topModule(self, hw_path):
        #TODO; right now this part is a rule-based method, we will consider using AST to parse the flattened code in the future.

        with open(hw_path,'r') as file_in:
            content = file_in.read()
            lines = content.split("\n")
    
        modules_dic={}
        for line in lines:
            words = line.split()
            for word_idx, word in enumerate(words):
                if word == 'module':
                    #如首行为module top( input clk,，则module_name=top(，下面再去掉'('
                    module_name = words[word_idx+1]
                    if '(' in module_name:
                        idx = module_name.find('(')
                        module_name = module_name[:idx]
                        modules_dic[module_name]= 1

                    else:
                        modules_dic[module_name]= 0
                    
        for line in lines:
            words = line.split()
            for word in words:
                if word in modules_dic.keys():
                    modules_dic[word] += 1
    
        # 找到所有出现次数为 1 的模块（候选顶层模块）
        candidates = [m for m in modules_dic if modules_dic[m] == 1]
        
        if not candidates:
            print("警告: 未找到顶层模块")
            return
        
        # 在文件列表中查找最后一个候选模块的位置
        # 正确的顶层模块通常是文件列表中最后定义的模块
        last_candidate = None
        last_index = -1
        for i, line in enumerate(lines):
            for candidate in candidates:
                if f'module {candidate}' in line:
                    if i > last_index:
                        last_index = i
                        last_candidate = candidate
        
        top_module = last_candidate if last_candidate else candidates[0]
        
        print(f'top module is {top_module}')
        
        # 收集顶层模块需要的 parameter（去重）
        import re
        # 只收集特定于顶层模块的 parameter：dw, aw, sw, rf_addr, pri_sel0-15
        top_params = {}
        
        # 匹配 parameter 定义
        param_pattern = r'parameter\s+(?:\[[\d:]+\]\s+)?(\w+)\s*=\s*([^;]+);'
        for match in re.finditer(param_pattern, content):
            param_name = match.group(1)
            param_value = match.group(2).strip()
            # 获取完整定义（包括位宽）
            full_match = re.search(rf'parameter\s+(\[[\d:]+\]\s+)?{param_name}\s*=', content[match.start()-50:match.start()+50])
            width = ''
            if full_match:
                width = full_match.group(1) or ''
            
            # 只保留需要的 parameter（避免重复）
            if param_name not in top_params:
                top_params[param_name] = (width, param_value)
        
        # 构建 parameter 声明字符串（只包含特定的参数）
        # 顶层模块需要的参数：dw, aw, sw, rf_addr, pri_sel0-15
        required_params = ['dw', 'aw', 'sw', 'rf_addr'] + [f'pri_sel{i}' for i in range(16)]
        param_declarations = []
        for param_name in required_params:
            if param_name in top_params:
                width, param_value = top_params[param_name]
                param_declarations.append(f"\tparameter\t{width}\t{param_name} = {param_value},")
        
        # 移除最后一个逗号
        if param_declarations:
            param_declarations[-1] = param_declarations[-1].rstrip(',')
        
        # 替换模块名并添加 parameter 声明
        output_lines = []
        for line in lines:
            # 替换模块名 - 只替换模块定义和实例化时的模块名，避免替换端口名和信号名
            # 使用单词边界匹配，确保只替换完整的模块名
            import re
            new_line = re.sub(r'\b' + re.escape(top_module) + r'\b', 'top', line)
            
            # 检测顶层模块定义行，只有在有 parameter 声明时才修改
            if param_declarations and re.match(rf'^\s*module\s+top\s*\(', new_line):
                # 修改 module 定义行，添加 #(
                new_line = re.sub(r'(module\s+top)\s*\(', r'\1 #(\n', new_line)
                output_lines.append(new_line)
                # 添加 parameter 声明
                for decl in param_declarations:
                    output_lines.append(decl + '\n')
                # 添加 ) 来结束 parameter 列表
                output_lines.append(')(\n')
            else:
                output_lines.append(new_line + '\n')
        
        content = ''.join(output_lines)
        
        # 修复未声明的信号：自动添加缺失的 wire 声明
        # 这些信号在原始代码中被使用但没有声明
        missing_signals = ['mc_sts_ir', 'cs_le_d']  # 可以根据需要添加更多
        for signal in missing_signals:
            if signal in content:
                # 检查是否已经在 top 模块中声明（只检查 module top 内部）
                # 提取 module top 的内容
                top_match = re.search(r'module\s+top\s*\(.*?\)\s*;(.*?)endmodule', content, re.DOTALL)
                if top_match:
                    top_content = top_match.group(1)
                    if not re.search(rf'\b(wire|reg|input|output)\s+(\[\d+:\d+\]\s+)?{signal}\b', top_content):
                        # 在 module top 后的第一个 wire/input/output 声明前添加
                        # 找到 module top 后的第一个声明
                        content = re.sub(
                            r'(module\s+top\s*\([^)]*\)\s*;\s*)(input|output|wire)',
                            rf'\1wire\t\t{signal};\n\2',
                            content,
                            count=1,
                            flags=re.DOTALL
                        )
        
        with open(hw_path, "w") as file_out:
            file_out.write(content)

    #verilog -> DFG图 -> NetworkX图
    def code2graph(self, verilog_dir, profile=True):#输入verilog文件路径，返回NetworkX图，包括整体图及子图列表nx_graphs[]
        if profile:
            start = time()

        code_path = self.preprocess(verilog_dir)
        
        # 20260529修改：根据graph_type接收不同数量的返回值
        if self.cfg.graph_type == "DFG":
            hw_graph,nx_graphs,signal_to_nodes = self.process(str(code_path))#返回NetworkX图，包括整体图及子图列表nx_graphs[]和信号映射
        else:
            hw_graph,nx_graphs = self.process(str(code_path))
            signal_to_nodes = None
        
        if profile:
            end = time()
            print(f"子图数={len(nx_graphs):3d},nodes={len(hw_graph.nodes):4d},edges={len(hw_graph.edges):4d},time={(end-start):6.2f}s,{str(code_path)}")
            #print(str(code_path), ",    子图数=",len(nx_graphs),",nodes=",len(hw_graph.nodes), ",edges=", len(hw_graph.edges), ",time=", end-start)
        
        # 20260529修改：DFG模式返回3个值
        if self.cfg.graph_type == "DFG":
            return hw_graph,nx_graphs,signal_to_nodes
        else:
            return hw_graph,nx_graphs

    #主要目的是对指定目录（verilog_dir）中的Verilog代码进行预处理，以确保存在一个特定的文件（topModule.v），
    #该文件包含了一个经过一系列处理的Verilog代码版本，这些处理包括扁平化（flattening）、移除注释、移除下划线以及重命名顶级模块。
    def preprocess(self, verilog_dir):
        #无论topModule.v是否存在，都将返回flattened_hw_path值。如果文件已经存在且没有修改，这实际上是一个指向已存在文件的路径
        #如果文件不存在且经过了一系列预处理步骤后被创建，这也是指向新创建文件的路径。
        flattened_hw_path = verilog_dir / "topModule.v"
        # 一个列表，包含 verilog_dir 目录下所有 .v 扩展名文件的文件名（不包括路径和子目录，只有文件名）。
        all_verilog_files = [Path(x).name for x in glob("%s/*.v"%str(verilog_dir))]

        #检查topModule.v是否存在且包含module top定义，且没有语法错误
        need_preprocess = True
        if "topModule.v" in all_verilog_files:
            #检查文件内容是否包含 module top
            with open(flattened_hw_path, 'r') as f:
                content = f.read()
                if 'module top' in content:
                    need_preprocess = False
        #need_preprocess = True  #强制重新生成topModule.v用于前期调试，后面可注释掉
        if need_preprocess:
            #对 verilog_dir 目录中的Verilog代码进行扁平化处理，并将结果保存到 flattened_hw_path 指定的位置。
            #扁平化通常指的是将多个Verilog文件合并为一个文件，以便更容易地进行后续处理
            self.flatten(verilog_dir, flattened_hw_path)
            self.remove_comments(flattened_hw_path)
            #self.remove_underscores(flattened_hw_path)#20260113+ 注释掉该行，不能删除变量名中的'_'
            self.rename_topModule(flattened_hw_path)

        #print(f"flattened_hw_path = {flattened_hw_path}")
        return flattened_hw_path
        #flattened_hw_path = ..\assets\TJ-RTL-toy\TjFree\det_1011\topModule.v

    # @profilegraph
    #这里的hw_path是一个合并的文件，是某个目录下.v文件的合并。
    #配合中hw_path=E:\PRO\Python\HT\hw2vec\assets\TJ-RTL-toy\TjFree\det_1011\topModule.v
    def process(self, hw_path):
        if self.cfg.graph_type == "CFG":
            generator = CFGGenerator()
            #这里的返回值没有给nx_graph？
            return_obj = generator.process(hw_path,'graph')#返回值return_obj = None
            nx_graph = None
        
        elif self.cfg.graph_type == "AST":
            generator = ASTGenerator()
            nx_graph = generator.process(hw_path)

        elif self.cfg.graph_type == "DFG":
            generator = DFGGenerator()  #20241201hgw+ line 220处
            #print(f"hw_path={hw_path}")
            hw_dir = str(Path(hw_path).parent)  # 获取文件所在目录
            # 20260529修改：接收signal_to_nodes返回值，并传递enable_signal_to_nodes参数
            enable_signal = getattr(self.cfg, 'enable_signal_to_nodes', True)
            nx_graph,nx_graphs,signal_to_nodes = generator.process(hw_path, preprocess_include=[hw_dir], enable_signal_to_nodes=enable_signal)#20251118添加nx_graphs返回值
            #nx_graph = generator.process(hw_path, preprocess_include=[hw_dir])
            #print("test1")
            #print(type(nx_graph))
        
        else:
            pass
            
        for file in ['file.dot','parser.out','parsetab.py','top_state.png']:
            try:
                os.remove(file)
            except FileNotFoundError:
                pass

        if nx_graph != None:
            # NOTE: this is creating a limitation of how users should form their dataset. (TODO: we have to provide a tutorial in readme.)
            #print(hw_path)
            #parts = str(hw_path).split("\\")
            #print(f"parts = {parts}")
            #改动：下面语句中的"\\"原为"/"，而hw_path = ..\assets\TJ-RTL-toy\TjFree\det_1011\topModule.v，导致无法识别。
            nx_graph.name = str(hw_path).split("\\")[-2]
            nx_graph.type = str(hw_path).split("\\")[-3]
            #print(f"name = {nx_graph.name},type = {nx_graph.type}")
            #这里为每个子图添加.type属性
            for nx_graph_tmp in nx_graphs:
                nx_graph_tmp.name = nx_graph.name
                nx_graph_tmp.type = nx_graph.type
            
        # 20260529修改：DFG模式下返回signal_to_nodes
        if self.cfg.graph_type == "DFG":
            return nx_graph,nx_graphs,signal_to_nodes
        else:
            return nx_graph,nx_graphs

class GraphDrawer:
    """
    图可视化绘制器类。
    
    提供多种图可视化功能，包括：
    - 子图绘制（spring_layout和graphviz_layout两种布局）
    - t-SNE降维可视化
    - 热力图绘制
    - 直方图绘制
    - 网络图绘制
    - 列表统计分析
    
    主要解决pygraphviz批量绘图时的253次调用限制问题，
    通过命令行dot工具替代Python绑定层实现稳定批量绘图。
    """
    
    def __init__(self):
        """初始化GraphDrawer实例。"""
        pass

    def draw_graph(self, idx: int, nx_graph: nx.Graph, savepath: str = None):
        """
        使用spring_layout布局绘制NetworkX图并保存为PNG。
        
        采用力导向布局算法，适合展示图的整体结构。
        节点使用天蓝色填充，边为灰色细线。
        
        Args:
            idx: 图的索引，用于文件名和标题（如：0017）
            nx_graph: NetworkX图对象
            savepath: 保存目录路径，默认为当前目录
            
        生成的文件名格式：graph_{idx:04d}_n{节点数:03d}_e{边数:03d}.png
        标题格式：Graph_{idx:04d}_n{节点数:03d}_e{边数:03d}: {图名}: {首个节点名}
        """
        # 创建画布（10x8英寸，足够容纳长标签）
        plt.figure(figsize=(10, 8))

        # 使用spring_layout生成力导向布局
        # k=0.4控制节点间距，seed=42固定布局确保可重复
        pos = nx.spring_layout(nx_graph, k=0.4, seed=42)

        # 绘制节点：天蓝色填充，较大尺寸容纳标签
        nx.draw_networkx_nodes(nx_graph, pos, node_size=500, node_color='skyblue')
        
        # 绘制边：灰色细线，避免干扰节点视觉
        nx.draw_networkx_edges(nx_graph, pos, edge_color='gray', width=1.5)
        
        # 绘制节点标签：粗体无衬线字体，10号大小
        nx.draw_networkx_labels(
            nx_graph, pos,
            font_size=10,
            font_weight='bold',
            font_family='sans-serif'
        )

        # 添加标题：包含序号、节点数、边数、图名、首个节点名
        first_node = next(iter(nx_graph)) if nx_graph else "empty"
        plt.title(
            f'Graph_{idx:04d}_n{nx_graph.number_of_nodes():03d}_'
            f'e{nx_graph.number_of_edges():03d}: {nx_graph.name}: {first_node}',
            fontsize=16
        )

        # 自动调整布局，防止标签/标题被截断
        plt.tight_layout()

        # 保存图片，bbox_inches='tight'确保包含所有元素
        plt.savefig(
            f"{savepath}graph_{idx:04d}_n{nx_graph.number_of_nodes():03d}_"
            f"e{nx_graph.number_of_edges():03d}.png",
            bbox_inches='tight'
        )

        # 关闭画布，释放内存
        plt.close()

    #绘制graphviz带层级的布局图，跟前面的spring_layout()差别非常大。
    # 类级别的计数器，用于跟踪调用次数
    _graphviz_call_count = 0
    
    def _get_layout_with_dot_cmd(self, nx_graph):
        """
        使用命令行dot工具获取节点布局坐标。
        
        原理：通过subprocess调用系统dot命令，避免pygraphviz的Python绑定层资源泄漏。
        pygraphviz在多次调用后会出现约253次的累积限制，而命令行方式每次独立进程，
        进程结束后资源完全释放，可突破此限制。
        
        Args:
            nx_graph: NetworkX图对象
            
        Returns:
            dict: 节点到坐标位置的字典 {node_name: (x, y)}
            
        Raises:
            RuntimeError: dot命令执行失败时抛出
        """
        import subprocess
        import tempfile
        import os
        
        # 创建临时dot文件存储图结构
        with tempfile.NamedTemporaryFile(mode='w', suffix='.dot', delete=False) as f:
            dot_file = f.name
            # 写入有向图定义
            f.write('digraph G {\n')
            for node in nx_graph.nodes():
                # 转义节点名中的双引号，避免dot语法错误
                node_str = str(node).replace('"', '\\"')
                f.write(f'  "{node_str}";\n')
            for edge in nx_graph.edges():
                src = str(edge[0]).replace('"', '\\"')
                dst = str(edge[1]).replace('"', '\\"')
                f.write(f'  "{src}" -> "{dst}";\n')
            f.write('}\n')
        
        try:
            # 调用dot命令获取plain文本格式的布局结果
            # -Tplain: 输出简单文本格式，包含节点坐标
            result = subprocess.run(
                ['dot', '-Tplain', dot_file],
                capture_output=True,
                text=True,
                timeout=10
            )
            
            if result.returncode != 0:
                raise RuntimeError(f"dot命令失败: {result.stderr}")
            
            # 解析dot输出获取节点位置
            # plain格式每行: node "name" x y width height label style shape color fillcolor
            pos = {}
            for line in result.stdout.split('\n'):
                parts = line.split()
                if len(parts) >= 4 and parts[0] == 'node':
                    node_name = parts[1].strip('"')
                    x, y = float(parts[2]), float(parts[3])
                    pos[node_name] = (x, y)
            
            return pos
        finally:
            # 确保删除临时文件，避免磁盘垃圾
            try:
                os.unlink(dot_file)
            except:
                pass
    
    def draw_graph_pydot(self, idx: int, nx_graph: nx.Graph, savepath: str = None, fast_mode: bool = True):
        """
        使用Graphviz的dot布局绘制NetworkX图并保存为PNG。
        
        提供两种模式：
        - 快速模式(fast_mode=True): 小画布、简化绘制、资源占用低，适合批量处理
        - 完整模式(fast_mode=False): 大画布、完整标签、细节丰富，适合单图展示
        
        使用命令行dot工具替代nx.nx_agraph.graphviz_layout，避免pygraphviz的253次调用限制。
        
        Args:
            idx: 子图索引，用于文件名和标题
            nx_graph: NetworkX图对象
            savepath: 保存目录路径
            fast_mode: 是否使用快速模式，默认True
            
        Raises:
            Exception: 绘图过程中发生错误时抛出，包含详细的错误信息
        """
        import gc
        
        # 每50个图打印进度信息
        GraphDrawer._graphviz_call_count += 1
        #if GraphDrawer._graphviz_call_count % 50 == 0:
        #    print(f"  [信息] 已处理 {GraphDrawer._graphviz_call_count} 个图...")
        
        try:
            if fast_mode:
                # ========== 快速模式 ==========
                # 小画布、低DPI，减少内存占用和文件大小
                plt.figure(figsize=(6, 5), dpi=80)
                
                # 使用命令行dot工具获取布局（关键：避免pygraphviz资源泄漏）
                pos = self._get_layout_with_dot_cmd(nx_graph)
                
                # 简化绘制：填充节点、无边标签、无箭头
                nx.draw_networkx_nodes(nx_graph, pos, node_size=150, 
                                       node_color='lightblue',
                                       edgecolors='blue', linewidths=0.5)
                nx.draw_networkx_edges(nx_graph, pos, edge_color='gray', 
                                       width=0.8, arrows=False)
                
                # 简化节点标签：只显示最后一部分，限制15字符
                node_labels = {node: str(node).split('.')[-1][:15] 
                              for node in nx_graph.nodes()}
                nx.draw_networkx_labels(nx_graph, pos, labels=node_labels, 
                                        font_size=8, font_weight='normal')
                
                # 简化标题：只显示索引和节点数
                plt.title(f'G{idx:04d}_n{nx_graph.number_of_nodes():03d}', 
                         fontsize=10)
                plt.axis('off')  # 关闭坐标轴，减少视觉干扰
                
                # 保存图片，使用较小的pad_inches
                plt.savefig(f"{savepath}graph_{idx:04d}.png", 
                           bbox_inches='tight', pad_inches=0.1, dpi=80)
                           
            else:
                # ========== 完整模式 ==========
                # 大画布、默认DPI，展示完整细节
                plt.figure(figsize=(10, 8))
                
                # 同样使用命令行dot工具（完整模式也需要突破253次限制）
                pos = self._get_layout_with_dot_cmd(nx_graph)
                
                # 详细绘制：透明节点、显示边标签、有箭头
                nx.draw_networkx_nodes(nx_graph, pos, node_size=300, 
                                       node_color='none',
                                       edgecolors=(0,0,1,0.4))
                
                # 绘制边标签（如信号名等）
                edge_labels = nx.get_edge_attributes(nx_graph, 'label')
                nx.draw_networkx_edge_labels(nx_graph, pos, 
                                            edge_labels=edge_labels, 
                                            font_size=7, font_color='black')
                
                nx.draw_networkx_edges(nx_graph, pos, edge_color='gray', 
                                       width=1.5)
                
                # 完整节点标签：显示varname属性或节点名
                node_names = {node: nx_graph.nodes[node].get('varname', node) 
                             for node in nx_graph.nodes}
                nx.draw_networkx_labels(nx_graph, pos, labels=node_names,
                                        font_size=12, font_weight='bold')
                
                # 完整标题：包含索引、节点数、边数、图名、首个节点名
                first_node = next(iter(nx_graph)) if nx_graph else "empty"
                plt.title(f'Graph_{idx:04d}_n{nx_graph.number_of_nodes():03d}_'
                         f'e{nx_graph.number_of_edges():03d}: {nx_graph.name}: '
                         f'{first_node}', fontsize=16)
                plt.tight_layout()
                
                # 保存图片，文件名包含详细信息
                plt.savefig(f"{savepath}graph_{idx:04d}_n{nx_graph.number_of_nodes():03d}_"
                           f"e{nx_graph.number_of_edges():03d}.png",
                           bbox_inches='tight')
                           
        except Exception as e:
            print(f"\n[错误] 绘制子图 {idx} 时出错: {e}")
            print(f"[错误] 子图信息: 节点数={nx_graph.number_of_nodes()}, "
                  f"边数={nx_graph.number_of_edges()}, 名称={nx_graph.name}")
            raise
        finally:
            # 清理matplotlib资源，防止内存泄漏
            plt.clf()
            plt.close('all')
            gc.collect()

    def draw_graph_pydot_fixed(self, idx: int, nx_graph: nx.Graph, savepath: str = None):
        """
        [已废弃] 原始的graphviz_layout绘制函数，保留供参考。
        
        注意：此函数使用nx.nx_agraph.graphviz_layout，存在253次调用限制，
        建议使用draw_graph_pydot替代。
        
        Args:
            idx: 子图索引
            nx_graph: NetworkX图对象
            savepath: 保存路径
        """
        # 使用with语句管理资源
        plt.figure(figsize=(10, 8))
        try:
            pos = nx.nx_agraph.graphviz_layout(nx_graph, prog='dot')

            # 分批处理边标签，每批50条边
            edge_labels = nx.get_edge_attributes(nx_graph, 'label')
            batch_size = 50
            for i in range(0, len(edge_labels), batch_size):
                batch = dict(list(edge_labels.items())[i:i + batch_size])
                nx.draw_networkx_edge_labels(
                    nx_graph, pos, edge_labels=batch, font_size=7
                )

            # 强制垃圾回收
            import gc
            gc.collect()

        except Exception as e:
            pass

    def draw_TSNE_graph(self, matrix_numpy, title: str = "", savepath: str = ""):
        """
        使用t-SNE算法将高维向量降维到2D并可视化。
        
        适合展示图嵌入向量的分布情况，观察相似子图的聚类效果。
        
        Args:
            matrix_numpy: 输入矩阵，形状为(n_samples, n_features)的numpy数组
            title: 图表标题，用于文件名标识
            savepath: 保存目录路径
            
        生成的文件名：tsne_{title}.png
        
        注意：
        - 输入如果不是2D会自动展平
        - 使用PCA初始化，random_state=0确保结果可重复
        """
        # 确保输入是二维数组，如果不是则展平
        if matrix_numpy.ndim != 2:
            matrix_numpy = matrix_numpy.reshape(matrix_numpy.shape[0], -1)
        
        # 使用t-SNE降维到2D，PCA初始化，固定随机种子
        tsne = TSNE(n_components=2, init='pca', random_state=0)
        X_tsne = tsne.fit_transform(matrix_numpy)
        
        # 绘制散点图
        plt.figure(figsize=(10, 8))
        plt.scatter(X_tsne[:, 0], X_tsne[:, 1], alpha=0.6)
        plt.title(f't-SNE: {title}')
        plt.xlabel('Dimension 1')
        plt.ylabel('Dimension 2')
        plt.grid(True)
        plt.savefig(
            f"{savepath}tsne_{title}.png",
            bbox_inches='tight'
        )
        plt.close()

    def draw_heatmap_graph(self, matrix_numpy, title: str = "", savepath: str = ""):
        """
        绘制相似度矩阵的热力图。
        
        自动将矩阵对称化（取平均值）并设置对角线为1，适合展示子图间的相似度关系。
        
        Args:
            matrix_numpy: 相似度矩阵，形状为(n, n)的numpy数组
            title: 图表标题
            savepath: 保存目录路径
            
        生成的文件名：heatmap_{title}.png
        
        注意：
        - 矩阵会被对称化：(matrix + matrix.T) / 2
        - 对角线自动填充为1（自身相似度）
        - 使用viridis颜色映射，600 DPI高分辨率
        """
        # 对称化矩阵，确保相似度矩阵的对称性
        matrix_numpy = (matrix_numpy + matrix_numpy.T) / 2
        np.fill_diagonal(matrix_numpy, 1)  # 对角线为自身，相似度为1

        # 绘制热力图
        plt.figure(figsize=(12, 10))
        sns.heatmap(
            matrix_numpy,
            cmap='viridis',  # 颜色映射：viridis
            xticklabels=False,  # 隐藏刻度标签
            yticklabels=False
        )
        plt.title(f'Heatmap:{title}')
        plt.savefig(
            f"{savepath}heatmap_{title}.png",
            dpi=600,  # 高分辨率
            bbox_inches='tight'
        )
        plt.close()

    def draw_histogram_graph(self, list_numpy, title: str = "", savepath: str = ""):
        """
        绘制数据分布直方图，并在每个柱子上显示频数值。
        
        适合分析相似度分布、距离分布等统计特征。
        
        Args:
            list_numpy: 输入数据列表或一维numpy数组
            title: 图表标题，也作为x轴标签
            savepath: 保存目录路径
            
        生成的文件名：histogram_{title}.png
        
        特点：
        - 50个分箱（bins=50）
        - 每个柱子上方显示垂直的频数值标签
        - 半透明填充（alpha=0.7）
        """
        plt.figure(figsize=(10, 8))
        
        # 绘制直方图，返回频数和柱子对象
        n, bins, patches = plt.hist(list_numpy, bins=50, 
                                    edgecolor='black', alpha=0.7)

        # 在每个柱子上添加频数标签
        for rect in patches:
            height = rect.get_height()
            plt.text(
                rect.get_x() + rect.get_width() / 2,  # 横坐标居中
                height + max(n) * 0.04,  # 动态调整标签位置
                f'{int(height)}' if height.is_integer() else f'{height:.1f}',
                rotation=90,  # 文本垂直旋转
                ha='center', va='center',
                fontsize=8
            )
        
        plt.title(f'histogram:{title}')
        plt.xlabel(f'{title}')
        plt.ylabel('Frequency')
        plt.grid(axis='y', alpha=0.75)
        plt.savefig(
            f"{savepath}histogram_{title}.png",
            bbox_inches='tight'
        )
        plt.close()

    def draw_network_graph(self, matrix_numpy, threshold: float, 
                           title: str = "", savepath: str = ""):
        """
        根据相似度矩阵绘制网络图，只显示权重超过阈值的边。
        
        适合可视化高相似度子图之间的连接关系。
        
        Args:
            matrix_numpy: 相似度矩阵，形状为(n, n)
            threshold: 边权重阈值，只有大于此值的边才会显示
            title: 图表标题
            savepath: 保存目录路径
            
        生成的文件名：network_{title}.png
        
        特点：
        - 使用spring_layout布局，连接紧密的节点聚在一起
        - 节点大小20，无标签
        - 600 DPI高分辨率
        """
        num_of_row = matrix_numpy.shape[0]
        G = nx.Graph()

        # 添加节点
        G.add_nodes_from(range(num_of_row))

        # 添加边（只添加权重超过阈值的边，避免图过于密集）
        for i in range(num_of_row):
            for j in range(i + 1, num_of_row):
                if matrix_numpy[i, j] > threshold:
                    G.add_edge(i, j, weight=matrix_numpy[i, j])

        # 绘制网络图
        plt.figure(figsize=(15, 15))
        pos = nx.spring_layout(G, k=0.5, iterations=50)
        nx.draw(G, pos, with_labels=False, node_size=20, edge_color='gray')
        plt.title(f'Network Graph:{title} (> {threshold})')
        plt.savefig(
            f"{savepath}network_{title}.png",
            dpi=600,
            bbox_inches='tight'
        )
        plt.close()

    def calc_list_statistics(self, list_numpy, topk: float = 0.01, prn: str = 'on'):
        """
        计算并返回列表的详细统计信息。
        
        包括基本统计量（均值、方差等）、四分位数、偏度、峰度，
        以及前topk%区间的数据统计。
        
        Args:
            list_numpy: 输入数据列表或numpy数组
            topk: 前百分之几的区间宽度，默认0.01（即1%）
            prn: 是否打印输出，'on'为打印，其他值不打印
            
        Returns:
            str: 格式化的统计信息字符串
            
        统计信息包括：
        - 样本个数、最大值、最小值
        - 总和、均值、方差、标准差
        - 中位数、Q1、Q3、IQR
        - 偏度、峰度
        - 前topk%区间的阈值和样本数
        """
        if len(list_numpy) == 0:
            print("calc_list_statistics()：输入列表为空")
            return
        list_numpy = np.array(list_numpy)
        
        # 基本统计量
        length = len(list_numpy)
        max_value = np.max(list_numpy)
        min_value = np.min(list_numpy)
        total = np.sum(list_numpy)
        mean = np.mean(list_numpy)
        variance = np.var(list_numpy)
        std_dev = np.std(list_numpy)
        median = np.median(list_numpy)

        # 四分位数
        q1 = np.percentile(list_numpy, 25)
        q3 = np.percentile(list_numpy, 75)
        iqr = q3 - q1

        # 偏度和峰度
        skewness = skew(list_numpy)
        kurt = kurtosis(list_numpy)
        
        # 前topk%区间的统计
        top_zone = (max_value - min_value) * topk
        top_val = max_value - top_zone
        #top_val=0.995
        top_num = np.sum(list_numpy >= top_val)

        # 格式化输出字符串
        print_line = (
            f"    个数:{length:7d},"
            f"top{topk*100:.0f}%=({top_val:5.3f}:{top_num:5d}),"
            f"区间[{min_value:6.3f}-{max_value:6.3f}],"
            f"sum={total:9.1f},mean={mean:6.3f},"
            f"方差={variance:.4f},标准差={std_dev:.4f}"
            #f" -> 中位数={median:6.3f},q1={q1:6.3f},q3={q3:6.3f},IQR={iqr:6.3f},"
            #f"偏度={skewness:7.3f},峰度={kurt:7.3f}"
        )

        #打印结果
        if prn=='on':
            print(print_line)
        #以字符串形式返回打印结果
        return print_line


