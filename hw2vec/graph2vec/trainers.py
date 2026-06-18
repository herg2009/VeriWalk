#!/usr/bin/env python
#title           :trainers.py
#description     :This file includes the trainers of hw2vec.
#author          :Shih-Yuan Yu
#date            :2021/03/05
#version         :0.2
#notes           :
#python_version  :3.6
#==============================================================================
import os, sys
sys.path.append(os.path.dirname(sys.path[0]))

import random
import torch
import torch.nn.functional as F
import torch.optim as optim
import numpy as np
import pickle as pkl

import warnings
warnings.filterwarnings('ignore')

from pathlib import Path
from tqdm import tqdm

from torch_geometric.data import Data, DataLoader
from sklearn.utils.class_weight import compute_class_weight
from sklearn.metrics import accuracy_score, f1_score, confusion_matrix, precision_score, recall_score, roc_auc_score, roc_curve

from hw2vec.graph2vec.models import *
from hw2vec.utilities import *

class BaseTrainer:
    def __init__(self, cfg):
        self.config = cfg
        self.min_test_loss = np.Inf
        self.task = None
        self.metrics = {}
        self.model = None
        np.random.seed(self.config.seed)
        torch.manual_seed(self.config.seed)
    #build() 方法是训练流程的初始化入口，负责将模型与训练器绑定，并基于配置和模型参数构建优化器，为后续的 train()、validate() 等方法提供基础运行环境。
    def build(self, model, path=None):
        self.model = model
        self.optimizer = optim.Adam(model.parameters(), lr=self.config.learning_rate, weight_decay=5e-4)#初始化优化器

    def visualize_embeddings(self, data_loader, path=None):#生成TensorBoard可读的嵌入向量文件（vectors.tsv/metadata.tsv）
        save_path = "./visualize_embeddings/" if path is None else Path(path)
        save_path.mkdir(parents=True, exist_ok=True)

        embeddings, hw_names = self.get_embeddings(data_loader)

        with open(str(save_path / "vectors.tsv"), "w") as vectors_file, \
             open(str(save_path / "metadata.tsv"), "w") as metadata_file:#在example目录下创建vectors.tsv和metadata.tsv文件。

            for embed, name in zip(embeddings, hw_names):
                vectors_file.write("\t".join([str(x) for x in embed.detach().cpu().numpy()[0]]) + "\n")
                metadata_file.write(name+"\n")

    #此函数可以直接计算一批数据的图嵌入向量。使用评估模式
    def get_embeddings(self, data_loader):#获取数据加载器（data_loader）的图嵌入向量
        embeds = []
        hw_names = []

        with torch.no_grad():
            self.model.eval()

            for data in data_loader:
                data.to(self.config.device)
                embed_x, _ = self.model.embed_graph(data.x, data.edge_index, data.batch)
                embeds.append(embed_x)
                hw_names += data.hw_name

        return embeds, hw_names

    def get_embeddings_hgw(self, data_loader):#20251130同上，修改为使用自定义的embd_graph_hgw()
        embeds = []
        hw_names = []

        with torch.no_grad():
            self.model.eval()

            for data in data_loader:
                data.to(self.config.device)
                embed_x, _ = self.model.embed_graph_hgw(data.x, data.edge_index, edge_weight=data.edge_attr, batch=data.batch)
                embeds.append(embed_x)
                hw_names += data.hw_name

        return embeds, hw_names

    def metric_calc(self, loss, labels, preds, header):#计算并打印准确率、F1、混淆矩阵等指标，保存最佳测试结果
        acc = accuracy_score(labels, preds)
        f1 = f1_score(labels, preds, average="binary")
        conf_mtx = str(confusion_matrix(labels, preds)).replace('\n', ',')
        precision = precision_score(labels, preds, average="binary")
        recall = recall_score(labels, preds, average="binary")

        self.metric_print(loss, acc, f1, conf_mtx, precision, recall, header)

        if header == "test " and (self.min_test_loss >= loss):
            self.min_test_loss = loss
            self.metrics["acc"] = acc
            self.metrics["f1"] = f1
            self.metrics["conf_mtx"] = conf_mtx
            self.metrics["precision"] = precision
            self.metrics["recall"] = recall

    def metric_print(self, loss, acc, f1, conf_mtx, precision, recall, header):
        print("%s loss: %4f" % (header, loss) +
            ", %s accuracy: %.4f" % (header, acc) +
            ", %s f1 score: %.4f" % (header, f1) +
            ", %s confusion_matrix: %s" % (header, conf_mtx) +
            ", %s precision: %.4f" % (header, precision) +
            ", %s recall: %.4f" % (header, recall))

class PairwiseGraphTrainer(BaseTrainer):#图分类任务，任务类型：IP(硬件描述图相似性判断)，在use_case_3.py中使用。
    ''' trainer for graph classification ''' 
    def __init__(self, cfg):
        super().__init__(cfg)
        self.task = "IP"
        self.cos_sim = torch.nn.CosineSimilarity(dim=-1, eps=1e-08).to(self.config.device)
        self.cos_loss = torch.nn.CosineEmbeddingLoss(margin=0.5).to(self.config.device)#使用余弦相似度损失（CosineEmbeddingLoss）
    
    def train(self, train_loader, test_loader):
        tqdm_bar = tqdm(range(self.config.epochs))

        for epoch_idx in tqdm_bar:
            self.model.train()
            acc_loss_train = 0
            #train_loader中有168对，下面的for循环是循环五3次，每次训练64对。是不是每次只取1对进行训练
            for data in train_loader:#train_loader中共有168对，每次训练取batch_size=64对，故for循环3次，分别为64+64+40个
                self.optimizer.zero_grad()
                graph1, graph2, labels = data[0].to(self.config.device), data[1].to(self.config.device), data[2].to(self.config.device)
                #graph1和graph2都是64维的数组，含有64个元素。下面是对这两个数组的元素进行对位比较。

                loss_train = self.train_epoch_ip(graph1, graph2, labels)
                loss_train.backward()
                self.optimizer.step()

                acc_loss_train += loss_train.detach().cpu().numpy()

            tqdm_bar.set_description('Epoch: {:04d}, loss_train: {:.4f}'.format(epoch_idx, acc_loss_train))

            if epoch_idx % self.config.test_step == 0:
                self.evaluate(epoch_idx, train_loader, test_loader)
    
    # @profileit
    def train_epoch_ip(self, graph1, graph2, labels):#获取两图嵌入 → MLP处理 → 计算余弦损失
        g_emb_1, _ = self.model.embed_graph(graph1.x, graph1.edge_index, batch=graph1.batch)
        g_emb_2, _ = self.model.embed_graph(graph2.x, graph2.edge_index, batch=graph2.batch)
        
        g_emb_1 = self.model.mlp(g_emb_1)#多层感知机，可用于更新向量。（还有线性变换等其他作用）
        g_emb_2 = self.model.mlp(g_emb_2)
        #计算余弦嵌入损失，常用于衡量两个输入向量在目标标签指导下的相似度差异，结合目标标签调整优化方向
        loss_train = self.cos_loss(g_emb_1, g_emb_2, labels)#底层为torch.cosine_embedding_loss(input1, input2, target, margin=0.5, reduction_enum=1)
        return loss_train

    # @profileit
    def inference_epoch_ip(self, graph1, graph2):#计算嵌入相似度 → 二分类输出
        g_emb_1, _ = self.model.embed_graph(graph1.x, graph1.edge_index, batch=graph1.batch)
        g_emb_2, _ = self.model.embed_graph(graph2.x, graph2.edge_index, batch=graph2.batch)
        #g_emb_1和g_emb_2都是[n,16]的数组，n为每批次的个数，64或40。
        g_emb_1 = self.model.mlp(g_emb_1)#这里的mlp()的作用包括：特征变换与维度对齐、归一化与相似度稳定性等作用。
        g_emb_2 = self.model.mlp(g_emb_2)

        similarity = self.cos_sim(g_emb_1, g_emb_2)#计算2个向量的余弦相似性。这里实际上是对n对元素分别计算相似度值，因此similarity也是个数组。
        return g_emb_1, g_emb_2, similarity

    def inference(self, data_loader):
        labels = []
        outputs = []
        total_loss = 0
        similaritys=[]#202509927+ 记录三元组(graph_name1,graph_name2,similarity)
        with torch.no_grad():
            self.model.eval()
            
            for data in data_loader:
                graph1, graph2, labels_batch = data[0].to(self.config.device), data[1].to(self.config.device), data[2].to(self.config.device)
                    
                g_emb_1, g_emb_2, similarity = self.inference_epoch_ip(graph1, graph2)
                loss = self.cos_loss(g_emb_1, g_emb_2, labels_batch)#底层为cosine_embedding_loss()

                total_loss += loss.detach().cpu().numpy()#loss=tensor(0.3516) -> total_loss=0.35155
                outputs.append(similarity.detach().cpu())

                labels += np.split(labels_batch.detach().cpu().numpy(), len(labels_batch.detach().cpu().numpy()))

            outputs = torch.cat(outputs).detach()
            avg_loss = total_loss / (len(data_loader))

            labels_tensor = (torch.LongTensor(labels)> 0).detach() 
            outputs_tensor = torch.FloatTensor(outputs).detach()
            preds = (outputs > 0.5).detach()

        return avg_loss, labels_tensor, outputs_tensor, preds
    
    def evaluate(self, epoch_idx, train_loader, test_loader):
        train_loss, train_labels, _, train_preds = self.inference(train_loader)
        test_loss, test_labels, _, test_preds = self.inference(test_loader)

        print("")
        print("Mini Test for Epochs %d:"%epoch_idx)

        self.metric_calc(train_loss, train_labels, train_preds, header="train")
        self.metric_calc(test_loss,  test_labels,  test_preds,  header="test ")

        if self.min_test_loss >= test_loss:
            self.model.save_model(str(self.config.model_path_obj/"case3_model.cfg"), str(self.config.model_path_obj/"case3_model.pth"))

        # on final evaluate call
        if(epoch_idx==self.config.epochs):
            self.metric_print(self.min_test_loss, **self.metrics, header="best ")

    #20251129+
    def calc_graph_embeding(self, graph1):#计算单个图的图嵌入向量
        g_emb_1, _ = self.model.embed_graph(graph1.x, graph1.edge_index, batch=graph1.batch)
        g_emb_1 = self.model.mlp(g_emb_1)#这里的mlp()的作用包括：特征变换与维度对齐、归一化与相似度稳定性等作用。
        return g_emb_1#, g_emb_2, similarity

class GraphTrainer(BaseTrainer):
    ''' trainer for graph classification ''' 
    def __init__(self, cfg, class_weights=None):
        super().__init__(cfg)
        self.task = "TJ"
        if class_weights.shape[0] < 2:  #类别权重检查，损失函数优化：
            self.loss_func = nn.CrossEntropyLoss()#默认交叉熵损失，适用于分类任务，输入为单个向量，输出为该向量对应的标量损失。
        else:    
            self.loss_func = nn.CrossEntropyLoss(weight=class_weights.float().to(cfg.device))#权重版支持多分类

    # @profileit
    def train_epoch_tj(self, data):#图嵌入 → MLP分类 → 交叉熵损失
        output, _ = self.model.embed_graph(data.x, data.edge_index, data.batch)
        output = self.model.mlp(output)
        #output = F.log_softmax(output, dim=1)#0914：删除，保留模型原始输出，后续使用F.softmax()获取概率值，而不是对数概率

        loss_train = self.loss_func(output, data.label)#在init中定义了交叉熵损失函数
        return loss_train

    # @profileit
    def inference_epoch_tj(self, data):#返回节点级注意力权重（用于可视化）
        output, attn = self.model.embed_graph(data.x, data.edge_index, data.batch)
        output = self.model.mlp(output)
        #output = F.log_softmax(output, dim=1)#0914：删除，保留模型原始输出，后续使用F.softmax()获取概率值，而不是对数概率

        loss = self.loss_func(output, data.label)
        return loss, output, attn   #这里的output是原始输出，而不是概率。
                
    def inference(self, data_loader):#模型评估函数
        labels = []
        outputs = []
        node_attns = []
        total_loss = 0
        folder_names = []
        probabilities = []
        
        with torch.no_grad():#评估模式下，禁用梯度计算。
            self.model.eval()#使用推理模式
            for i, data in enumerate(data_loader):
                data.to(self.config.device)

                loss, output, attn = self.inference_epoch_tj(data)#修改后的loss为原始概率，而不是对数概率。
                total_loss += loss.detach().cpu().numpy()

                #0914：计算概率：对原始输出应用softmax
                probs=torch.softmax(output,dim=1).cpu()
                probabilities.append(probs)#保存概率


                outputs.append(output.cpu())
                
                if 'pool_score' in attn:#注意力权重处理
                    node_attn = {}
                    node_attn["original_batch"] = data.batch.detach().cpu().numpy().tolist()
                    node_attn["pool_perm"] = attn['pool_perm'].detach().cpu().numpy().tolist()
                    node_attn["pool_batch"] = attn['batch'].detach().cpu().numpy().tolist()
                    node_attn["pool_score"] = attn['pool_score'].detach().cpu().numpy().tolist()
                    node_attns.append(node_attn)

                labels += np.split(data.label.cpu().numpy(), len(data.label.cpu().numpy()))

            outputs = torch.cat(outputs).reshape(-1,2).detach()
            avg_loss = total_loss / (len(data_loader))#计算平均损失

            labels_tensor = torch.LongTensor(labels).detach()
            outputs_tensor = torch.FloatTensor(outputs).detach()
            preds = outputs_tensor.max(1)[1].type_as(labels_tensor).detach()

        #拼接所有概率张量
        probabilities = torch.cat(probabilities).detach()
        return avg_loss, labels_tensor, outputs_tensor, preds, node_attns, probabilities    #新增返回probabilities

    def evaluate(self, epoch_idx, data_loader, valid_data_loader):
        train_loss, train_labels, _, train_preds, train_node_attns, train_probs = self.inference(data_loader)#获取训练集损失、标签、预测结果、节点级注意力权重、概率
        test_loss, test_labels, _, test_preds, test_node_attns, test_probs = self.inference(valid_data_loader)#获取测试集损失、标签、预测结果、节点级注意力权重、概率

        print("")
        print("Mini Test for Epochs %d:"%epoch_idx)

        #打印验证集每个数据的概率
        #print("validation probabilities:")
        #print(list(test_probs))

        self.metric_calc(train_loss, train_labels, train_preds, header="train")
        self.metric_calc(test_loss,  test_labels,  test_preds,  header="test ")

        if self.min_test_loss >= test_loss:#cfg文件（配置）+ pth文件（权重）
            self.model.save_model(str(self.config.model_path_obj/"case2_model.cfg"), str(self.config.model_path_obj/"case2_model.pth"))

            #TODO: store the attn_weights right here. 未完成的功能。

        # on final evaluate call
        if(epoch_idx==self.config.epochs):
            self.metric_print(self.min_test_loss, **self.metrics, header="best ")

    def train(self, data_loader, valid_data_loader):
        tqdm_bar = tqdm(range(self.config.epochs))

        for epoch_idx in tqdm_bar:
            self.model.train()
            acc_loss_train = 0

            for data in data_loader:
                self.optimizer.zero_grad()  #必备函数，清空梯度
                data.to(self.config.device)

                loss_train = self.train_epoch_tj(data)
                loss_train.backward()#必备函数，自动微分函数
                self.optimizer.step()#必备函数
                acc_loss_train += loss_train.detach().cpu().numpy()

            tqdm_bar.set_description('Epoch: {:04d}, loss_train: {:.4f}'.format(epoch_idx, acc_loss_train))

            if epoch_idx % self.config.test_step == 0:
                self.evaluate(epoch_idx, data_loader, valid_data_loader)


class Evaluator(BaseTrainer):
    def __init__(self, cfg, task):
        super().__init__(cfg)
        self.task = task