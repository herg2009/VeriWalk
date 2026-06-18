#!/usr/bin/env python
#title           :models.py
#description     :This file includes the models of hw2vec.
#author          :Shih-Yuan Yu
#date            :2021/03/05
#version         :0.2
#notes           :
#python_version  :3.6
#==============================================================================
import json
from pathlib import Path
import torch
import torch.nn as nn
import torch.nn.functional as F

from torch.nn import Linear, ReLU
from torch_geometric.nn import GCNConv, GINConv,GATConv    #不同GNN的本质区别是消息传递机制不同，如GCN/GraphSAGE/GIN/GAT等，只需要修改层的名称即可。
from torch_geometric.nn import global_add_pool, global_mean_pool, global_max_pool #全局池化直接对图中所有节点特征进行聚合，生成图级别的表示，适用于图分类、图回归等任务。,GlobalAttentionPooling
from torch_geometric.nn import SAGPooling, TopKPooling #分层池化通过逐步合并节点或超级节点，保留图的层次结构信息，适用于复杂图分析。 EdgePooling,ASAPooling,dense_mincut_pool

class GRAPH_CONV(nn.Module):
    def __init__(self, type, in_channels, out_channels):
        super(GRAPH_CONV, self).__init__()#作用：显示调用父类（基类）的构造函数，确保父类的初始化逻辑被正确执行。当子类继承父类时，父类的 __init__ 方法不会自动调用
        self.type = type
        self.in_channels = in_channels
        self.out_channels = out_channels
        if type == "gcn":
            self.graph_conv = GCNConv(in_channels, out_channels)
        elif type == "gin":
            self.graph_conv = GINConv(Linear(in_channels, out_channels))
        elif type == "gat":
            self.graph_conv = GATConv(in_channels, out_channels)

    def forward(self, x, edge_index):#PyTorch规定所有神经网络模块必须实现forward()方法，用于定义数据的前向传播逻辑。
        #print("Input feature shape:",x.shape)
        return self.graph_conv(x, edge_index)#当实例化一个模块并通过output = module(input)调用时，PyTorch会自动执行module.forward(input)。

class GRAPH_POOL(nn.Module):
    def __init__(self, type, in_channels, poolratio):
        super(GRAPH_POOL, self).__init__()
        self.type = type
        self.in_channels = in_channels  #输入节点特征的通道数（即每个节点的特征维度）。
        self.poolratio = poolratio      #池化比例，控制保留的节点比例（例如 0.8 表示保留 80% 的节点）
        if self.type == "sagpool":      #池化类型，可选值为 "sagpool"（基于自注意力的图池化）或 "topkpool"（基于 Top-K 选择的图池化）。
            self.graph_pool = SAGPooling(in_channels, ratio=poolratio)
        elif self.type == "topkpool":
            self.graph_pool = TopKPooling(in_channels, ratio=poolratio)
        #elif self.type==mean max add等三种方法都在Readout()中。
        #

    '''前向传播方法 forward
    输入：
        x (Tensor): 节点特征矩阵，形状为 [num_nodes, in_channels]。
        edge_index (Tensor): 图的边索引，形状为 [2, num_edges]。
        batch (Tensor, 可选): 批处理向量，形状为 [num_nodes]（用于多图批处理）。
    输出：
        返回池化后的节点特征、边索引和批处理向量（具体格式由底层池化层决定）。
    操作：
        直接调用底层池化层（self.graph_pool）的前向传播方法。
    '''
    def forward(self, x, edge_index, batch):#前向传播方法
        return self.graph_pool(x, edge_index, batch=batch)

class GRAPH_READOUT(nn.Module):
    def __init__(self, type):
        super(GRAPH_READOUT, self).__init__()
        self.type = type
    
    def forward(self, x, batch):
        if self.type == "max":
            return global_max_pool(x, batch)
        elif self.type == "mean":
            return global_mean_pool(x, batch)
        elif self.type == "add":
            return global_add_pool(x, batch)


class GRAPH2VEC(nn.Module):
    
    ''' 
        For users who want to develop their own network architecture, 
        you may use this graph2vec class as template and implement your architecture.
    '''

    def __init__(self, config):
        super(GRAPH2VEC, self).__init__()#确保父类的正确初始化
        self.config = config

    def save_model(self, model_config_path, model_weight_path):
        Path(model_config_path).parent.mkdir(parents=True, exist_ok=True)
        Path(model_weight_path).parent.mkdir(parents=True, exist_ok=True)
        model_configurations = {}

        convs = [] 
        for layer in self.layers:
            convs.append((layer.type, layer.in_channels, layer.out_channels))
        model_configurations['convs'] = convs

        model_configurations['pool'] = (self.pool1.type, self.pool1.in_channels, self.pool1.poolratio)
        model_configurations['readout'] = self.graph_readout.type
        model_configurations['fc'] = (self.fc.in_features, self.fc.out_features)
        with open(model_config_path, 'w') as f:
            json.dump(model_configurations, f)
        torch.save(self.state_dict(), model_weight_path)
        #print(self.state_dict())
#        print(self.state_dict['convs.0.weight'].shape)

    #这个方法通过解析 JSON 格式的模型配置文件和加载 PyTorch 兼容的权重文件来初始化或更新一个图神经网络模型的配置和权重。
    def load_model(self, model_config_path, model_weight_path):
        with open(model_config_path) as f:
            model_configuration = json.load(f)

        #解析并设置卷积层
        convs = [] 
        for setting in model_configuration['convs']:
            graph_conv_type, in_channels, out_channels = setting
            convs.append(GRAPH_CONV(graph_conv_type, int(in_channels), int(out_channels)))
        #将解析好的图卷积层配置应用到当前模型实例上。这个方法的具体实现不在此段代码中，但可以推测它负责根据提供的图卷积层配置来构建或更新模型的图卷积层部分。
        self.set_graph_conv(convs)

        #设置池化层
        pool_type, pool_in_channels, pool_ratio = model_configuration['pool']
        #将池化层配置应用到当前模型实例上
        self.set_graph_pool(GRAPH_POOL(pool_type, pool_in_channels, pool_ratio))

        #设置读出层，将读出层配置应用到当前模型实例上。
        self.set_graph_readout(GRAPH_READOUT(model_configuration['readout']))
        #设置全连接层，从 model_configuration['fc'] 中解析出全连接层的输入通道数 fc_in_channel 和输出通道数 fc_out_channel。
        #使用这些参数创建一个 PyTorch 的 nn.Linear 层的实例，该层作为模型的输出层。
        #调用 self.set_output_layer(...) 方法，将输出层配置应用到当前模型实例上。
        fc_in_channel, fc_out_channel = model_configuration['fc']
        self.set_output_layer(nn.Linear(fc_in_channel, fc_out_channel))

        #加载模型权重
        #print(f"model_weight_path={model_weight_path}")
        #下面语句默认调用cuda进行预训练模型的加载，会报错，需改为使用cpu加载
        #self.load_state_dict(torch.load(model_weight_path))
        #改动：修改为使用cpu加载预训练模型
        self.load_state_dict(torch.load(model_weight_path,map_location=torch.device('cpu')))
        
    def set_graph_conv(self, convs):
        self.layers = []
        
        for conv in convs:
            conv.to(self.config.device)
            self.layers.append(conv)
        self.layers = nn.ModuleList(self.layers)

    def set_graph_pool(self, pool_layer):
        self.pool1 = pool_layer.to(self.config.device)
            
    def set_graph_readout(self, typeofreadout):
        self.graph_readout = typeofreadout

    def set_output_layer(self, layer):
        self.fc = layer.to(self.config.device)
    #整体流程图示：输入图数据 → One-Hot编码 → 多层图卷积 → 池化 → 读出 → 图嵌入
    def embed_graph(self, x, edge_index, batch):#x为节点特征，形如[num_nodes, num_features],如[10,32]即表示每个节点有32维特征
        attn_weights = dict()
        #One-Hot 编码适用于离散型节点特征（如原子类型、类别标签），若特征为连续值，可直接使用 x.float() 跳过编码。
        x = F.one_hot(x, num_classes=self.config.num_feature_dim).float()
        #遍历 self.layers（假设是一个包含多个图神经网络层的列表），对节点特征 x 和边索引 edge_index 进行逐层处理。每一层的处理包括：
        #layer(x, edge_index)：通过图神经网络层更新节点特征。
        #F.relu(...)：应用 ReLU 激活函数。
        #F.dropout(..., p=self.config.dropout, training=self.training)：应用 Dropout 正则化，防止过拟合。
        for layer in self.layers:
            x = F.dropout(F.relu(layer(x, edge_index)), p=self.config.dropout, training=self.training)#处理动作：更新+激活+正则化
            #每层图卷积操作相当于x=GCNConv(37,200); x=F.relu(x); x=F,dropout(x,trainning=self.training); 共进行2层图卷积。
        x, edge_index, _, batch, attn_weights['pool_perm'], attn_weights['pool_score'] = \
            self.pool1(x, edge_index, batch=batch)#图池化操作，x为池化后的节点特征，edge_index为更新后的边索引。
        x = self.graph_readout(x, batch)#图读出层，将池化后的节点特征聚合为整个图的嵌入表示。输出形状为[batch_size,embedding_dim]的图嵌入向量。

        attn_weights['batch'] = batch
        return x, attn_weights

    #20251130改进的模型：1、F.dropout(training=True -> False),2、取消池化层
    def embed_graph_hgw(self, x, edge_index, edge_weight=None, batch=None):#x为节点特征，形如[num_nodes, num_features],如[10,32]即表示每个节点有32维特征
        attn_weights = dict()
        #One-Hot 编码适用于离散型节点特征（如原子类型、类别标签），若特征为连续值，可直接使用 x.float() 跳过编码。
        x = F.one_hot(x, num_classes=self.config.num_feature_dim).float()
        #遍历 self.layers（假设是一个包含多个图神经网络层的列表），对节点特征 x 和边索引 edge_index 进行逐层处理。每一层的处理包括：
        #layer(x, edge_index)：通过图神经网络层更新节点特征。
        #F.relu(...)：应用 ReLU 激活函数。
        #F.dropout(..., p=self.config.dropout, training=self.training)：应用 Dropout 正则化，防止过拟合。
        for layer in self.layers:
            x = F.dropout(F.relu(layer(x, edge_index)), p=self.config.dropout, training=self.training)#处理动作：更新+激活+正则化
            #x = F.dropout(F.relu(layer(x, edge_index,edge_weight=edge_weight)), p=self.config.dropout, training=False) #此处将training设置为False后，不会再随机丢弃神经元，目的是增加生成的图嵌入向量的稳定性
            #x = F.dropout(F.relu(layer(x, edge_index)), p=self.config.dropout, training=False)  # 20251215+不再使用weight参数
            #每层图卷积操作相当于x=GCNConv(37,200); x=F.relu(x); x=F,dropout(x,trainning=self.training); 共进行2层图卷积。

        #池化操作，暂时保留，去掉后效果更差。
        x, edge_index, _, batch, attn_weights['pool_perm'], attn_weights['pool_score'] = \
            self.pool1(x, edge_index, batch=batch)#图池化操作，x为池化后的节点特征，edge_index为更新后的边索引。

        x = self.graph_readout(x, batch)#图读出层，将池化后的节点特征聚合为整个图的嵌入表示。输出形状为[batch_size,embedding_dim]的图嵌入向量。


        attn_weights['batch'] = batch
        return x, attn_weights

    def embed_node(self, x, edge_index):
        x = F.one_hot(x, num_classes=self.config.num_feature_dim).float()
        for layer in self.layers:
            x = F.dropout(F.relu(layer(x, edge_index)), p=self.config.dropout, training=self.training)
        return x

    def mlp(self, x):
        return self.fc(x)