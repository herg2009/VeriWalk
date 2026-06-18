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
'''改动处：
1、E:\PRO\python\HT\hw3vec\hw2vec\graph2vec\models.py:class GRAPH2VEC(nn.Module):def embed_graph()中x = F.dropout()中的参数training由self.training改为False，使其不再随机丢弃
   此处仅用于平时试验调试，可保持生成的嵌入向量的稳定性，后面实际运行时需改回去。
'''
import os, sys, itertools
import time as time_module
import torch
import networkx as nx
import pandas as pd
import numpy as np
import matplotlib.pyplot as plt
import seaborn as sns


import matplotlib.pyplot as plt

sys.path.append(os.path.dirname(sys.path[0]))
from hw2vec.config import Config
from hw2vec.hw2graph import *
from hw2vec.graphwalk import *
from gensim.models import Word2Vec
from collections import defaultdict

def write_file(data_path, data,wr='wb'):
    with open(data_path, wr) as f:
        pickle.dump(data, f)

#20260130+标准定为1%
def get_value_from_list(list_numpy,topk=0.01):#取0.01，超参数消融时置为0.85
    max_value = np.max(list_numpy)
    min_value = np.min(list_numpy)
    top_zone = (max_value - min_value) * topk  # 取总宽度的2%作为区间
    top_val = max_value - top_zone
    top_num = np.sum(list_numpy >= top_val)
    top_val=max(0.98,top_val)#202601321+top1%对应的最低阈值为0.98（仅当总区间为[-1,1]），//20260614临时改为0.99,超参数消融时置为0.85
    return max_value, min_value, top_val, top_num


def graph_embds_GraphWalk(nx_subgraphs_free, nx_subgraphs_in, walk_length=3, vector_size=128, window=3, sg=0, seed=42):
    """
    Graph Walk 生成子图嵌入向量
    参数:
        walk_length: 游走长度，0表示使用自适应长度
        vector_size: Word2Vec向量维度
        window: Word2Vec窗口大小
        sg: 训练模式，0=CBOW, 1=Skip-gram
        seed: 随机种子，用于保证结果可重复
    """
    # GW2:为所有子图生成游走序列，#分别生成_free和_in的游走序列，并合并在一个列表中。
    all_walks = []
    all_walks.extend(generate_all_walks(nx_subgraphs_free, walk_length=walk_length))
    all_walks.extend(generate_all_walks(nx_subgraphs_in, walk_length=walk_length))
    if not all_walks:
        print("未生成有效游走序列")
        return None, None, None

    # GW2.5: 训练Word2Vec模型（添加seed参数保证可重复性）
    modelWG = Word2Vec(sentences=all_walks, vector_size=vector_size, window=window, 
                       min_count=1, workers=1, sg=sg, seed=seed)
    # vector_size: 指定嵌入向量的维度，128表示每个节点的嵌入向量的维度为128维。
    # window: 指定窗口大小，窗口大小为3，表示每个节点的输入向量将考虑其前3个和后3个节点。
    # min_count: 指定最小词频，低于此频率的词将被忽略。
    # workers:使用多个工作线程来训练模型（在多核机器上训练速度更快）。
    # sg: 指定训练模式，0表示CBOW（Continuous Bag-of-Words），1表示skip-gram。默认为0
    # hs: 指定是否使用Hierarchical Softmax，默认为0，表示不使用。
    # negative: 负采样参数，表示使用负采样来提高训练效果。
    # ns_exponent: 负采样的指数参数，表示使用多少个负样本。用于塑造负采样分布的指数。值为1.0时，采样比例与频率完全一致；0.0时，所有单词采样概率相同；而负值则会使低频单词的采样概率高于高频单词。原始Word2Vec论文选择了0.75这一广受欢迎的默认值。
    # cbow_mean: 指定是否使用CBOW平均值，默认为1，表示使用。 如果为0，则使用上下文词向量的和。如果为1，则使用平均值，仅在使用CBOW时适用。
    # alpha: 训练过程中学习率，默认值为0.025。
    # min_alpha: 训练过程中最小学习率，默认值为0.0001。随着训练的进行，学习率将线性下降至min_alpha

    # GW3.1:计算子图嵌入
    graph_embds_free = []
    for i, subg in enumerate(nx_subgraphs_free):
        node_vectors = [modelWG.wv[str(node)] for node in subg.nodes() if str(node) in modelWG.wv]
        if node_vectors:  #
            tmp = sum(node_vectors) / len(node_vectors)  # 使用平均值作为子图嵌入,此为numpy.ndarray类型，需要转换成torch.Tensor
            graph_embds_free.append(torch.from_numpy(tmp))
        else:
            graph_embds_free.append(torch.from_numpy(np.array([0.0] * vector_size)))
    # GW3.2:计算子图嵌入
    graph_embds_in = []
    for i, subg in enumerate(nx_subgraphs_in):
        node_vectors = [modelWG.wv[str(node)] for node in subg.nodes() if str(node) in modelWG.wv]
        if node_vectors:  #
            tmp = sum(node_vectors) / len(node_vectors)  # 使用平均值作为子图嵌入,此为numpy.ndarray类型，需要转换成torch.Tensor
            graph_embds_in.append(torch.from_numpy(tmp))
        else:
            graph_embds_in.append(torch.from_numpy(np.array([0.0] * vector_size)))
    '''#GW4:输出所有嵌入向量
    for i, g_embd in enumerate(graph_embds_free):
        a_vals = ','.join([f"{x * 100:6.3f}" for x in g_embd.detach().numpy().tolist()])
        print(f"fr子图{i:3d}的嵌入向量：{a_vals} -> {nx_subgraphs_free[i]}")
    for i, g_embd in enumerate(graph_embds_in):
        a_vals = ','.join([f"{x * 100:6.3f}" for x in g_embd.detach().numpy().tolist()])
        print(f"in子图{i:3d}的嵌入向量：{a_vals} -> {nx_subgraphs_in[i]}")
    '''
    return graph_embds_free, graph_embds_in, modelWG

class TJDetection:
    def __init__(self, cfg):
        self.cfg = cfg
        #self.trainer = PairwiseGraphTrainer(self.cfg)
        self.drawer = GraphDrawer()

    def load_graphs(self,nx_subgraphs_free,nx_subgraphs_in):
        '''
        load graphs from cache
        '''
        self.nx_subgraphs_free=nx_subgraphs_free
        self.nx_subgraphs_in=nx_subgraphs_in
        data_proc_free = DataProcessor(self.cfg)
        for nx_subgraph in nx_subgraphs_free:
            data_proc_free.process(nx_subgraph)
        self.vis_loader_free = DataLoader(data_proc_free.get_graphs(),batch_size=1,shuffle=False)#此处，vis_loader的大小为data_proc_subs的大小，即数据集大小。

        data_proc = DataProcessor(self.cfg)
        for nx_subgraph in nx_subgraphs_in:
            data_proc.process(nx_subgraph)
        self.vis_loader_in = DataLoader(data_proc.get_graphs(),batch_size=1,shuffle=False)

        if not hasattr(data_proc, 'num_node_labels'):
            print(f"未找到 data_proc.num_node_labels，请检查是否修改代码的配置命令!")

        '''#输出nx_subgraphs[]中的各个networkx图信息，平时不需要
        for idx, nx_graph_tmp in enumerate(nx_subgraphs_free):
            #continue
            print(f"子图{idx}: 节点数{nx_graph_tmp.number_of_nodes()}, 边数{nx_graph_tmp.number_of_edges()}")
            print(f" 节点:{nx_graph_tmp.nodes()}")
            print(f" 边:{nx_graph_tmp.edges()}")
        '''

        '''#可视化：输出每个子图的可视化图png,速度比较慢，不再每次运行
        #for idx, nx_graph_tmp in enumerate(nx_subgraphs_free):
        #    self.drawer.draw_graph(idx, nx_graph_tmp,'./子图PNG示例/png/')#生成在子图放在 ./nx_subgraphs_PNG/ 目录中。
        #for idx, nx_graph_tmp in enumerate(nx_subgraphs_in):
        #    self.drawer.draw_graph(idx, nx_graph_tmp,'./子图PNG示例/pngT/')#生成在子图放在 ./nx_subgraphs_PNG/ 目录中。
        '''

    def graph_embds_GNN(self, trainer, use_hgw=True):
        """
        使用GNN模型生成子图嵌入向量
        参数:
            trainer: PairwiseGraphTrainer实例，包含已配置的GNN模型
            use_hgw: 是否使用改进版的embed_graph_hgw（默认True，更稳定）
        """
        # 使用GNN模型生成free子图的嵌入向量
        if use_hgw:
            graph_embds_free, _ = trainer.get_embeddings_hgw(self.vis_loader_free)
            graph_embds_in, _ = trainer.get_embeddings_hgw(self.vis_loader_in)
        else:
            graph_embds_free, _ = trainer.get_embeddings(self.vis_loader_free)
            graph_embds_in, _ = trainer.get_embeddings(self.vis_loader_in)

        self.graph_embds_free = graph_embds_free
        self.graph_embds_in   = graph_embds_in
        #print(f"GNN方法: len(graph_embds_free)={len(graph_embds_free)}, len(graph_embds_in)={len(graph_embds_in)}")

    def graph_embds_GM(self, method='graph_edit', timeout_per_pair=10):
        """
        使用图匹配方法计算子图相似度（不使用嵌入向量）
        参数:
            method: 匹配方法
                - 'graph_edit': 图编辑距离（Graph Edit Distance）
                - 'isomorphism': 图同构匹配（Graph Isomorphism）
                - 'similarity': 图相似度（Graph Similarity）
            timeout_per_pair: 每对图匹配的超时时间（秒）
        """
        import networkx.algorithms.isomorphism as iso
        from networkx.algorithms import similarity as graph_sim
        
        self.graph_embds_free = []  # 图匹配不使用嵌入向量，置为空
        self.graph_embds_in = []
        self.similarity_matrix_gm = []  # 存储图匹配相似度矩阵
        
        print(f"  使用图匹配方法: {method}")
        print(f"  Free子图数: {len(self.nx_subgraphs_free)}, In子图数: {len(self.nx_subgraphs_in)}")
        
        # 对每个in子图，与所有free子图进行匹配
        total_in = len(self.nx_subgraphs_in)
        for i, graph_in in enumerate(self.nx_subgraphs_in):
            # 每200个子图输出一次进度
            if i % 200 == 0 and i > 0:
                print(f"  处理进度: {i}/{total_in} ({i*100//total_in}%)")
            
            sim_scores = []
            for j, graph_free in enumerate(self.nx_subgraphs_free):
                try:
                    if method == 'graph_edit':
                        # 图编辑距离（越小越相似，需转换为相似度）
                        # 使用简化版：只考虑节点和边的数量差异
                        node_diff = abs(graph_in.number_of_nodes() - graph_free.number_of_nodes())
                        edge_diff = abs(graph_in.number_of_edges() - graph_free.number_of_edges())
                        max_nodes = max(graph_in.number_of_nodes(), graph_free.number_of_nodes(), 1)
                        max_edges = max(graph_in.number_of_edges(), graph_free.number_of_edges(), 1)
                        
                        # 归一化差异
                        norm_diff = (node_diff / max_nodes + edge_diff / max_edges) / 2
                        sim_score = 1.0 - norm_diff  # 转换为相似度 [0, 1]
                        
                    elif method == 'isomorphism':
                        # 图同构匹配
                        GM = iso.GraphMatcher(graph_in, graph_free)
                        if GM.is_isomorphic():
                            sim_score = 1.0  # 完全同构
                        else:
                            # 计算最大公共子图的大小作为相似度
                            # 使用快速近似：比较节点度和边的分布
                            degree_sim = self._compute_degree_similarity(graph_in, graph_free)
                            sim_score = degree_sim
                            
                    elif method == 'similarity':
                        # 图相似度（使用Graph Edit Distance的近似）
                        # 使用更精确的节点/边匹配
                        sim_score = self._compute_graph_similarity_fast(graph_in, graph_free)
                    else:
                        sim_score = 0.0
                        
                    sim_scores.append(sim_score)
                    
                except Exception as e:
                    # 如果匹配失败（如超时或内存不足），使用0作为相似度
                    sim_scores.append(0.0)
            
            self.similarity_matrix_gm.append(sim_scores)
        
        # 将相似度矩阵转换为类似嵌入向量的格式（用于后续Graph_similarity处理）
        # 这里我们直接使用相似度值作为"伪嵌入"
        import torch
        self.graph_embds_free = [torch.tensor([1.0])] * len(self.nx_subgraphs_free)
        self.graph_embds_in = [torch.tensor([1.0])] * len(self.nx_subgraphs_in)
        
        print(f"  图匹配完成，生成相似度矩阵: {len(self.similarity_matrix_gm)} x {len(self.similarity_matrix_gm[0]) if self.similarity_matrix_gm else 0}")
    
    def _compute_degree_similarity(self, g1, g2):
        """计算两个图的度分布相似度"""
        degree1 = dict(g1.degree())
        degree2 = dict(g2.degree())
        
        # 获取度分布
        deg_seq1 = sorted(degree1.values())
        deg_seq2 = sorted(degree2.values())
        
        # 填充到相同长度
        max_len = max(len(deg_seq1), len(deg_seq2))
        deg_seq1.extend([0] * (max_len - len(deg_seq1)))
        deg_seq2.extend([0] * (max_len - len(deg_seq2)))
        
        # 计算余弦相似度
        import numpy as np
        v1 = np.array(deg_seq1, dtype=float)
        v2 = np.array(deg_seq2, dtype=float)
        
        norm1 = np.linalg.norm(v1)
        norm2 = np.linalg.norm(v2)
        
        if norm1 == 0 or norm2 == 0:
            return 0.0
        
        return float(np.dot(v1, v2) / (norm1 * norm2))
    
    def _compute_graph_similarity_fast(self, g1, g2):
        """快速计算图相似度（综合考虑多种特征）"""
        import numpy as np
        
        # 1. 节点数相似度
        n1, n2 = g1.number_of_nodes(), g2.number_of_nodes()
        node_sim = min(n1, n2) / max(n1, n2) if max(n1, n2) > 0 else 1.0
        
        # 2. 边数相似度
        e1, e2 = g1.number_of_edges(), g2.number_of_edges()
        edge_sim = min(e1, e2) / max(e1, e2) if max(e1, e2) > 0 else 1.0
        
        # 3. 度分布相似度
        degree_sim = self._compute_degree_similarity(g1, g2)
        
        # 4. 标签分布相似度（如果节点有标签）
        label_sim = 1.0
        if g1.nodes and g2.nodes:
            labels1 = set(g1.nodes.keys())
            labels2 = set(g2.nodes.keys())
            if labels1 or labels2:
                label_sim = len(labels1 & labels2) / len(labels1 | labels2) if (labels1 | labels2) else 1.0
        
        # 综合相似度（加权平均）
        similarity = 0.3 * node_sim + 0.3 * edge_sim + 0.3 * degree_sim + 0.1 * label_sim
        
        return similarity

    def graph_embds_GW(self, walk_length=0, vector_size=128, window=3, sg=0, seed=42):
        """
        使用Graph Walk生成子图嵌入向量
        参数:
            walk_length: 游走长度，0表示自适应长度
            vector_size: Word2Vec向量维度
            window: Word2Vec窗口大小
            sg: 0=CBOW, 1=Skip-gram
            seed: 随机种子，用于保证结果可重复
        """
        graph_embds_free, graph_embds_in, modelWG = graph_embds_GraphWalk(
            self.nx_subgraphs_free, self.nx_subgraphs_in,
            walk_length=walk_length, vector_size=vector_size, window=window, sg=sg, seed=seed
        )

        self.graph_embds_free = graph_embds_free
        self.graph_embds_in   = graph_embds_in
        self.modelWG          = modelWG        #所有的节点嵌入向量
        #print(f"len(modelWG.wv)={len(modelWG.wv)}")
        '''
        # 20260110:使用Word2Vec模型代替get_embeddings_hgw()来生成子图嵌入向量。
        # graph_embds_free,_ = trainer.get_embeddings_hgw(vis_loader_free)    #此处的_为每个子图的名称，但仅为设计文件的名称，不含信号名。
        #write_file("case6.4_graph_embds_free.pkl", graph_embds_free, 'wb')  # 记录下所有的子图嵌入向量，做为后续挑选使用。
        for idx, g_embd in enumerate(graph_embds_free):
            continue
            a_vals = ','.join([f"{x * 100:6.3f}" for x in g_embd[0].detach().numpy().tolist()])
            print(f"fr子图{idx:3d}的嵌入向量：{a_vals} -> {nx_subgraphs_free[idx]}")

        # graph_embds_in,_ = trainer.get_embeddings_hgw(vis_loader_in)    #此处的_为每个子图的名称，但仅为设计文件的名称，不含信号名。
        #write_file("case6.4_graph_embds_in.pkl", graph_embds_in, 'wb')  # 记录下所有的子图嵌入向量，做为后续挑选使用。
        for idx, g_embd in enumerate(graph_embds_in):
            continue
            a_vals = ','.join([f"{x * 100:6.3f}" for x in g_embd[0].detach().numpy().tolist()])
            print(f"in子图{idx:3d}的嵌入向量：{a_vals} -> {nx_subgraphs_in[idx]}")
        '''
        '''可视化1：生成 371个16维的子图嵌入向量的t-SNE降维可视化图，保存在程序目录下的tsne_visualization.png，同时备份到本机的E:\BaiduSyncdisk\SEARCH\图片\hw2vec\子图相似'''
        # 核心转换逻辑：将列表堆叠为矩阵并转置
        # graph_embds_all=graph_embds_free# + graph_embds_in
        # matrix_numpy = np.stack([vec.detach().numpy() for vec in graph_embds_all])
        # self.drawer.draw_TSNE_graph(matrix_numpy,title="graph_embds",savepath="")

        #return graph_embds_free, graph_embds_in

    def Graph_similarity(self,prnsimrow=False,prn='on', use_gm_matrix=False):#prnsimrow=False:默认不输出相似度矩阵
        """
        计算子图相似度
        参数:
            prnsimrow: 是否输出相似度矩阵行
            prn: 打印控制
            use_gm_matrix: 是否使用图匹配方法生成的相似度矩阵（graph_embds_GM）
        """
        import numpy as np  # 移到函数开头，确保所有分支都能使用
        
        self.graph_embds_0 = []  # 存放正常电路的子图嵌入向量，包含free和 in中的正常部分
        self.graph_embds_1 = []  # 存放木马电路的子图嵌入向量，标准为与free中无高相似度的子图嵌入向量
        self.nx_subgraphs_0= []
        self.nx_subgraphs_1= []

        max_list = []#存放graph_embds_in[i]与所有graph_embds_free[]的最大相似度值
        tj_wz = []  # 记录被检测出来的疑似木马位置
        node_num_list = [graph.number_of_nodes() for graph in self.nx_subgraphs_in]#各子图的节点数
        edge_num_list = [graph.number_of_edges() for graph in self.nx_subgraphs_in]#各子图的边数

        '''所有向量，两两比较计算相似度，并将结果输出到文件中。'''  # 20251226+改用pytorch进行批量计算。
        output_lines_row = []  # 保存相似度矩阵中的各行输出
        output_lines_pair = []  # 保存两两向量之间的相似度输出，用于最后写入文件中
        count_pair = 0  # 计数符合条件的结果。
        
        # 判断是否使用图匹配方法生成的相似度矩阵
        if use_gm_matrix and hasattr(self, 'similarity_matrix_gm'):
            # 使用图匹配方法直接生成的相似度矩阵
            similarity_matrix = np.array(self.similarity_matrix_gm)
            print(f"  使用图匹配相似度矩阵: {similarity_matrix.shape}")
        else:
            # 使用嵌入向量计算相似度（原有的GW和GNN方法）
            # 预计算所有向量对（避免重复计算），此处代替原来的双层循环计算
            embeddings_free_tensor = torch.stack(self.graph_embds_free)
            embeddings_in_tensor   = torch.stack(self.graph_embds_in)
            # 广播机制会自动将 x1_expanded 和 x2_expanded 扩展为 (N, M, D) 的形状进行比较
            similarity_matrix = torch.cosine_similarity(
                embeddings_in_tensor.unsqueeze(1),  # 扩展维度，从(N,D)->(N,1,D)
                embeddings_free_tensor.unsqueeze(0),  # 从(M,D)->(1,M,D)
                dim=-1)  # dim=-1表示取最后一个维度，此处为二维时相当亍dim=1。
        
            # print(f"形状: {similarity_matrix.shape}")
            # 此处similarity_matrix.shape=torch.Size([371, 371, 1])，type=<class 'torch.Tensor'>,需转化为numpy型的[371,371]矩阵
            similarity_matrix = similarity_matrix.squeeze(-1)  # 删除最后一维，即[371,371,1]变为[371,371]
            # print(f"similarity_matrix.shape={similarity_matrix.shape} type={type(similarity_matrix)}")
            similarity_matrix = similarity_matrix.detach().cpu().numpy()
            # print(f"similarity_matrix.shape={similarity_matrix.shape} type={type(similarity_matrix)}")

        for i in range(len(self.graph_embds_in)):
            #for j in range(len(self.graph_embds_free)):#20260308+不再记录两两的比较情况
            #    sim = similarity_matrix[i, j].item()
            #    output_lines_pair.append(
            #        f"count={count_pair:7d} cos_sim={sim:7.4f} i={i:5d}:{self.nx_subgraphs_in[i]}  || j={j:5d}:{self.nx_subgraphs_free[j]}")
            #    count_pair += 1
            # 输出每个in子图向量与所有fr子图向量的相似度
            simRow = similarity_matrix[i, :].tolist()  # 获取第i行数据
            # simRow=np.sort(simRow)[::-1]#降序排序
            max_val, _, top_val, _ = get_value_from_list(simRow)
            max_list.append(max_val)
            max_wz = np.argmax(simRow)
            if max_val >= top_val:  # top_val最低值为0.9 && max_val<0.98
                self.graph_embds_0.append(self.graph_embds_in[i])
                self.nx_subgraphs_0.append(self.nx_subgraphs_in[i])
            else: #max_val < top_val:
                self.graph_embds_1.append(self.graph_embds_in[i])
                self.nx_subgraphs_1.append(self.nx_subgraphs_in[i])
                tj_wz.append(i)
            if prnsimrow==True:#输出每行结果，即相似度矩阵
                signal_name = next(iter(self.nx_subgraphs_in[i].nodes()))  # 子图根节点信号名
                line = f"{i:4d}行："
                line = line + f"{node_num_list[i]:4d}n,{edge_num_list[i]:4d}e: max={max_val:6.3f} wz={max_wz:4d} {signal_name}"
                line = line + ':' + ','.join([f"{num:6.3f}" for num in simRow])
                line = line + '->' + f"max=({max_wz:4d},{max_val:6.3f})"
                line = line + ' ' + self.drawer.calc_list_statistics(simRow, prn='off')  # 统计结果只写入文件，不打印屏幕
                output_lines_row.append(line)

        '''将所有输出结果保存到文件中.
        with open("rsl_simPair.txt", "w", encoding="utf-8") as f:
            f.write("\n".join(output_lines_pair))

        with open("rsl_simRow.txt", "w", encoding="utf-8") as f:
            f.write("\n".join(output_lines_row))
        time_2 = time_module.perf_counter()'''

        #print(f"len(graph_embds_1)={len(self.graph_embds_1)}")
        #for idx, subgraph in enumerate(self.nx_subgraphs_1):
        #    #print(f"{idx:4d}行:{subgraph}")
        #output_lines_row.append(f"len(graph_embds_1)={len(self.graph_embds_1)}")
                
        # 保存每个子图的最大相似度值，与nx_subgraphs_0和nx_subgraphs_1对应
        self.similarities_0 = []  # 正常子图的相似度
        self.similarities_1 = []  # 木马子图的相似度
                
        for idx, subgraph in enumerate(self.nx_subgraphs_1):
            first_node = next(iter(subgraph))
            #output_lines_row.append(f"子图{tj_wz[idx]:4d}：{subgraph.number_of_nodes():4d}n,{subgraph.number_of_edges():4d}e: max={max_list[tj_wz[idx]]:6.3f} 信号名:{first_node}")
            output_lines_row.append(f"{tj_wz[idx]:4d}   {subgraph.number_of_nodes():4d} {subgraph.number_of_edges():4d} {max_list[tj_wz[idx]]:6.3f} {first_node}")
            #print(f"子图{tj_wz[idx]:4d}: {subgraph.number_of_nodes():4d}nodes,{subgraph.number_of_edges():4d}edges max={max_list[tj_wz[idx]]:6.3f} with name:")
            self.similarities_1.append(max_list[tj_wz[idx]])
                
        # 为正常子图也保存相似度值
        for i in range(len(self.nx_subgraphs_in)):
            if i not in tj_wz:
                self.similarities_0.append(max_list[i])

        '''可视化：生成相似度矩阵热力图'''
        # self.drawer.draw_heatmap_graph(similarity_matrix,title="similarity",savepath="")
        '''可视化：绘制相似度矩阵的网络图'''
        # self.drawer.draw_network_graph(similarity_matrix,threshold=0.7,title="similarity",savepath="")

        '''可视化：绘制相似度矩阵的直方图，输出统计信息'''
        similarities = similarity_matrix.flatten().tolist() #将矩阵展开成一维向量
        # similarities = similarities[similarities > 0]   #移除全0的元素
        output_lines_row.append( self.drawer.calc_list_statistics(similarities, prn=prn) )# 统计信息
        #output_lines_row.append( self.drawer.calc_list_statistics(max_list) )  # 统计最大值信息
        #self.drawer.draw_histogram_graph(similarities, title="similarity", savepath="")

        output_lines_row.append(f"")
        for idx, subgraph in enumerate(self.nx_subgraphs_1):
            # drawer.draw_graph(idx, nx_graph_tmp, path)  # 生成在子图放在 ./nx_subgraphs_PNG/ 目录中。
            line = f"子图{tj_wz[idx]:4d}: {subgraph.number_of_nodes():4d}n,{subgraph.number_of_edges():4d}e"
            # line=line+f" 节点:{nx_graph_tmp.nodes()}\n   边:{nx_graph_tmp.edges()}"
            line = line + f" node:{subgraph.nodes()}\n                      edge:{subgraph.edges()}"
            output_lines_row.append(line)

        output_lines_pair.append(f"")#添加一个换行
        output_lines_row.append(f"")
        return output_lines_pair,output_lines_row,similarities
