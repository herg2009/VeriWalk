# graphgen_patch.py - 用于增强 VerilogGraphGenerator 的补丁
# 让 generate 方法返回新增节点

def patch_generate_method():
    """
    为 VerilogGraphGenerator 添加一个新的 generate_with_new_nodes 方法
    该方法会在 generate 后返回新增的节点集合
    """
    from pyverilog.dataflow.graphgen import VerilogGraphGenerator
    
    # 保存原始的 generate 方法
    original_generate = VerilogGraphGenerator.generate
    
    def generate_with_new_nodes(self, signalname, identical=False, walk=True, step=1, do_reorder=False, delay=False):
        """
        增强版 generate：返回新增节点集合
        """
        # 记录调用前的节点集合
        nodes_before = set(self.graph.nodes())
        
        # 调用原始 generate
        original_generate(self, signalname, identical, walk, step, do_reorder, delay)
        
        # 提取新增节点
        nodes_after = set(self.graph.nodes())
        new_nodes = nodes_after - nodes_before
        
        # 转换为字符串
        new_nodes_str = set(str(n) for n in new_nodes)
        
        return new_nodes_str
    
    # 添加新方法到类
    VerilogGraphGenerator.generate_with_new_nodes = generate_with_new_nodes
    
    return VerilogGraphGenerator

# 自动应用补丁
patch_generate_method()
