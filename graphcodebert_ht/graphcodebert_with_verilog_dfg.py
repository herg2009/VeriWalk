"""
GraphCodeBERT + 已有Verilog DFG 融合方案

核心思路：
1. 利用已有的Verilog DFG数据（dfg_sub_rtl.pkl等）
2. 跳过GraphCodeBERT的tree-sitter解析步骤
3. 直接将DFG数据注入GraphCodeBERT模型
4. 实现"文本+数据流"的增强代码表示

优势：
✅ 无需Verilog解析器（tree-sitter不支持Verilog）
✅ 利用已有的高质量DFG数据
✅ 结合预训练模型的语义理解能力
✅ 可能超越纯文本方法（CodeBERT）
"""

import torch
import pickle
import numpy as np
from transformers import AutoTokenizer, AutoModel
from sklearn.metrics.pairwise import cosine_similarity
from pathlib import Path


class GraphCodeBERT_VerilogDFG:
    """
    GraphCodeBERT + Verilog DFG 融合模型
    
    工作流程：
    1. 使用CodeBERT tokenizer处理Verilog文本
    2. 从已有DFG数据中提取数据流信息
    3. 将数据流信息编码为特殊token序列
    4. 输入GraphCodeBERT获取增强表示
    """
    
    def __init__(self, model_name="microsoft/graphcodebert-base", use_gpu=True):
        """
        初始化模型
        
        Args:
            model_name: 预训练模型名称
            use_gpu: 是否使用GPU
        """
        print(f"[1/3] 加载预训练模型: {model_name}")
        
        self.device = torch.device("cuda" if use_gpu and torch.cuda.is_available() else "cpu")
        print(f"  ✓ 使用设备: {self.device}")
        
        # 加载tokenizer和模型
        self.tokenizer = AutoTokenizer.from_pretrained(model_name)
        self.model = AutoModel.from_pretrained(model_name)
        self.model.to(self.device)
        self.model.eval()
        
        print(f"  ✓ 模型加载完成")
        
        # DFG数据缓存
        self.dfg_cache = {}
    
    def load_dfg_data(self, dfg_file):
        """
        加载已有的Verilog DFG数据
        
        Args:
            dfg_file: DFG数据文件路径（.pkl）
        
        Returns:
            dict: DFG数据字典
        """
        print(f"\n[2/3] 加载DFG数据: {dfg_file}")
        
        with open(dfg_file, 'rb') as f:
            dfg_data = pickle.load(f)
        
        print(f"  ✓ 加载成功，包含 {len(dfg_data)} 个DFG子图")
        
        # 缓存DFG数据
        if isinstance(dfg_data, dict):
            self.dfg_cache.update(dfg_data)
        elif isinstance(dfg_data, list):
            for i, dfg in enumerate(dfg_data):
                self.dfg_cache[i] = dfg
        
        return dfg_data
    
    def extract_dataflow_from_dfg(self, dfg_graph):
        """
        从DFG图中提取数据流信息
        
        Args:
            dfg_graph: NetworkX图对象或DFG数据结构
        
        Returns:
            list: 数据流边列表 [(source, target), ...]
        """
        dataflow_edges = []
        
        # 根据你的DFG数据结构调整这里的解析逻辑
        # 以下是示例代码，需要根据实际DFG格式修改
        
        try:
            # 如果dfg_graph是NetworkX图
            import networkx as nx
            if isinstance(dfg_graph, nx.DiGraph):
                for u, v, data in dfg_graph.edges(data=True):
                    edge_type = data.get('type', 'dataflow')
                    if edge_type in ['dataflow', 'data_dependency', 'flow']:
                        dataflow_edges.append((u, v))
            
            # 如果dfg_graph是字典
            elif isinstance(dfg_graph, dict):
                if 'edges' in dfg_graph:
                    for edge in dfg_graph['edges']:
                        if edge.get('type') in ['dataflow', 'data_dependency']:
                            dataflow_edges.append((edge['source'], edge['target']))
                
                elif 'dataflow' in dfg_graph:
                    dataflow_edges = dfg_graph['dataflow']
            
            # 如果是列表
            elif isinstance(dfg_graph, list):
                dataflow_edges = dfg_graph
            
        except Exception as e:
            print(f"  ⚠️ DFG解析警告: {e}")
            # 降级方案：返回空列表
            dataflow_edges = []
        
        return dataflow_edges
    
    def encode_dataflow_to_text(self, code_text, dataflow_edges):
        """
        将数据流信息编码为文本，附加到代码后面
        
        策略：使用特殊标记包装数据流信息
        
        Args:
            code_text: Verilog代码文本
            dataflow_edges: 数据流边列表
        
        Returns:
            str: 增强后的文本（代码 + 数据流）
        """
        # 方案1：简单附加数据流边
        # 例如：[DATAFLOW] a->out, b->out, clk->always [/DATAFLOW]
        
        if not dataflow_edges:
            return code_text
        
        # 转换为字符串表示
        dataflow_str = ", ".join([f"{src}->{tgt}" for src, tgt in dataflow_edges[:50]])  # 限制长度
        
        # 使用特殊标记
        enhanced_text = f"{code_text}\n\n[DATAFLOW] {dataflow_str} [/DATAFLOW]"
        
        return enhanced_text
    
    def get_code_embedding(self, code_text, dfg_key=None):
        """
        获取代码的嵌入向量（使用DFG增强）
        
        Args:
            code_text: Verilog代码文本
            dfg_key: DFG数据中的键（用于查找对应的DFG）
        
        Returns:
            numpy.ndarray: 768维嵌入向量
        """
        # 1. 尝试获取DFG数据
        dataflow_edges = []
        if dfg_key and dfg_key in self.dfg_cache:
            dfg_graph = self.dfg_cache[dfg_key]
            dataflow_edges = self.extract_dataflow_from_dfg(dfg_graph)
            print(f"  ✓ 提取到 {len(dataflow_edges)} 条数据流边")
        
        # 2. 编码数据流到文本
        enhanced_text = self.encode_dataflow_to_text(code_text, dataflow_edges)
        
        # 3. Tokenize
        tokens = self.tokenizer.tokenize(enhanced_text)
        
        # GraphCodeBERT的最大长度：512 code + 128 dataflow = 640
        # 但我们需要截断到512（tokenizer的限制）
        if len(tokens) > 512:
            # 保留开头和结尾，截断中间
            tokens = tokens[:256] + tokens[-256:]
        
        tokens_ids = self.tokenizer.convert_tokens_to_ids(tokens)
        tokens_tensor = torch.tensor([tokens_ids]).to(self.device)
        
        # 4. 获取嵌入
        with torch.no_grad():
            outputs = self.model(tokens_tensor)
            # 使用[CLS] token的表示
            cls_embedding = outputs.last_hidden_state[:, 0, :].cpu().numpy()
        
        return cls_embedding
    
    def calculate_similarity(self, code1, code2, dfg_key1=None, dfg_key2=None):
        """
        计算两段Verilog代码的相似度（使用DFG增强）
        
        Args:
            code1: 第一段代码
            code2: 第二段代码
            dfg_key1: 第一段代码的DFG键
            dfg_key2: 第二段代码的DFG键
        
        Returns:
            float: 相似度分数 [0, 1]
        """
        emb1 = self.get_code_embedding(code1, dfg_key1)
        emb2 = self.get_code_embedding(code2, dfg_key2)
        
        similarity = cosine_similarity(emb1, emb2)[0][0]
        return similarity
    
    def detect_changes(self, free_code, in_code, free_dfg_key=None, in_dfg_key=None, threshold=0.85):
        """
        检测代码改动
        
        Args:
            free_code: 基准代码
            in_code: 变体代码
            free_dfg_key: 基准代码的DFG键
            in_dfg_key: 变体代码的DFG键
            threshold: 相似度阈值（低于此值认为有改动）
        
        Returns:
            dict: 检测结果
        """
        similarity = self.calculate_similarity(free_code, in_code, free_dfg_key, in_dfg_key)
        
        has_change = similarity < threshold
        
        return {
            'similarity': similarity,
            'has_change': has_change,
            'threshold': threshold,
            'confidence': abs(similarity - threshold)
        }


def test_with_existing_dfg():
    """
    使用已有的DFG数据测试GraphCodeBERT
    """
    print("="*80)
    print("GraphCodeBERT + Verilog DFG 融合测试")
    print("="*80)
    
    # 1. 初始化模型
    model = GraphCodeBERT_VerilogDFG(use_gpu=True)
    
    # 2. 加载已有的DFG数据
    # 根据你的实际文件路径修改
    dfg_files = [
        "e:/PRO/python/HT/hw4vec/examples/dfg_sub_rtl.pkl",
        "e:/PRO/python/HT/hw4vec/examples/dfg_tj_rtl.pkl",
        "e:/PRO/python/HT/hw4vec/examples/case4_dfg_sub_rtl.pkl"
    ]
    
    for dfg_file in dfg_files:
        if Path(dfg_file).exists():
            model.load_dfg_data(dfg_file)
            break
    
    # 3. 测试ALLRTL数据集
    test_dir = Path("e:/PRO/python/HT/hw4vec/assets/ALLRTL")
    
    # 测试一对电路
    free_file = test_dir / "TjFree" / "AES" / "topModule.v"
    in_file = test_dir / "TjIn" / "AES-T100" / "topModule.v"
    
    if free_file.exists() and in_file.exists():
        free_code = free_file.read_text()
        in_code = in_file.read_text()
        
        print(f"\n[3/3] 测试电路对: AES vs AES-T100")
        
        # 不使用DFG（纯文本）
        print("\n--- 纯文本模式 (CodeBERT) ---")
        sim_text = model.calculate_similarity(free_code, in_code)
        print(f"相似度: {sim_text:.4f}")
        
        # 使用DFG增强
        print("\n--- DFG增强模式 (GraphCodeBERT + Verilog DFG) ---")
        # 需要根据你的DFG数据结构设置正确的key
        sim_dfg = model.calculate_similarity(free_code, in_code, 
                                            dfg_key1="AES_free", 
                                            dfg_key2="AES-T100")
        print(f"相似度: {sim_dfg:.4f}")
        
        # 对比
        print(f"\n差异: {abs(sim_text - sim_dfg):.4f}")
        if sim_dfg < sim_text:
            print("✓ DFG增强检测到了更多差异（更好）")
        elif sim_dfg > sim_text:
            print("⚠️ DFG增强认为更相似（可能需要调整）")
        else:
            print("⚠️ DFG未生效（可能DFG key不匹配）")
    
    print("\n" + "="*80)
    print("测试完成")
    print("="*80)


if __name__ == "__main__":
    test_with_existing_dfg()
