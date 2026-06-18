#20260111：graph walk算法相关的函数，在./hw2vec/graphwalk.py中，包括随机游走过程、游走序列、子图节点集等函数，待后续再修改优化。

import networkx as nx
import numpy as np

'''DFG图中各类节点的权重值'''
DFG_node_weight_map_0 = { #老的权重表，比新的权重表效果更好一些。
    'concat': 1.5,      'input': 1.0,       'unand': 2.5,    'unor': 2.5,    'uxor': 2.5,
    'signal': 1.0,      'uand': 2.5,       'ulnot': 2.5,    'uxnor': 2.5,   'numeric': 0.5,
    'partselect': 0.5,  'and': 3.0,        'unot': 2.5,     'branch': 1.0,  'or': 3.0,
    'uor': 2.5,        'output': 1.0,     'plus': 2.0,     'eq': 2.0,      'minus': 2.0,
    'xor': 3.0,        'lor': 2.5,        'noteq': 2.0,    'land': 2.5,    'greatereq': 2.0,
    'greaterthan': 2.0,'sll': 1.5,        'lessthan': 2.0, 'times': 2.0,    'srl': 1.5,
    'pointer': 1.5,    'mod': 2.0,        'divide': 2.0,    'sra': 1.5,     'sla': 1.5,
    'xnor': 3.0,       'lesseq': 2.0
}
DFG_node_weight_map = {
    'concat': 2.0,     'input': 1.0,  'unand': 1.5,    'unor': 1.5,    'uxor': 1.5,
    'signal': 1.0,     'uand': 1.5,   'ulnot': 1.5,    'uxnor': 1.5,   'numeric': 1,
    'partselect': 2.0, 'and': 1.5,    'unot': 1.5,     'branch': 3.0,  'or': 1.5,
    'uor': 1.5,        'output': 1.0, 'plus': 3.0,     'eq': 2.0,      'minus': 3.0,
    'xor': 1.5,        'lor': 2.5,    'noteq': 2.0,    'land': 2.5,    'greatereq': 2.0,
    'greaterthan': 2.0,'sll': 2.0,    'lessthan': 2.0, 'times': 3.0,   'srl': 2.0,
    'pointer': 1.5,    'mod': 3.0,    'divide': 3.0,   'sra': 2.0,     'sla': 2.0,
    'xnor': 1.5,       'lesseq': 2.0
}
DFG_node_type_list=list(DFG_node_weight_map.keys())
DFG_node_weight_list = list(DFG_node_weight_map.values())#[val for val in DFG_node_weight_map.values() ]#weight_map.values().list()
#print(f"DFG_node_weight_list={DFG_node_weight_list}")
DFG_node_weight_list_ave = [1 for i in range(37) ]#设置各节点为平均权重1
#print(f"DFG_node_weight_list_ave={DFG_node_weight_list_ave}")
type_counts_zero={type:0 for type in DFG_node_type_list}
#print(f"type_counts_zero={type_counts_zero}")

#对数列中的数值元素进行概率概率归一化，使得概率总和为1。
def list_normalize(data_list):
    if np.sum(data_list)==0:
        return [0.0 for _ in data_list]
    if len(data_list)>0:
        # 确保概率和为1
        data_array=np.array(data_list)
        data_array=data_array/np.sum(data_array)
        # 处理浮点数精度问题
        data_array = np.clip(data_array, 0, 1)
        # 再次确保和为1
        weight_sum = np.sum(data_array)
        if abs(weight_sum - 1.0) > 1e-10:
            data_array = data_array / weight_sum
        return data_array

#根据图规模动态调整walk_length的改进方案如下，采用对数尺度自适应+密度修正策略：
def calc_walk_length_0(graph,base_length=5,density_factor=0.2):#20260206+停用，计算出来的值不符合实际情况，一是walk值太大，二是实际DFG的密度基本在0.15以下，图越大密度越低。
    # 动态计算子图规模参数
    num_nodes = graph.number_of_nodes()    #len(subgraph_nodes)
    num_edges = graph.number_of_edges()    #sum([len(graph.successors(n)) for n in subgraph_nodes])
    # 对数尺度自适应 (防止小图过短/大图过长)
    log_scale = max(1, np.log10(num_nodes))  # 10节点内按1处理
    adaptive_length = int(base_length * log_scale)
    # 密度修正 (稀疏图延长游走)
    if num_nodes > 0:
        density = num_edges / (num_nodes * (num_nodes - 1))  # 有向图密度
        adaptive_length = max(base_length, int(adaptive_length * (1 + density_factor * (1 - density))) )
    # 最终长度约束 (确保合理范围)
    walk_length = min(max(base_length, adaptive_length), 25)  # 限制在5-25范围内
    return walk_length

#20260206+使用该函数，改为仅与节点数相关，因为DFG图的密度均处于0.15以下，没有拉开差距，参考意义不大。
def calc_walk_length(graph,base_length=3):
    # 动态计算子图规模参数
    num_nodes = graph.number_of_nodes()    #len(subgraph_nodes)
     # 对数尺度自适应 (防止小图过短/大图过长)
    log_scale = max(1, np.log10(num_nodes))  # 10节点内按1处理
    adaptive_length = int(base_length * log_scale)
    # 最终长度约束 (确保合理范围)
    walk_length = min(max(base_length, adaptive_length), 10)  # 限制在5-15范围内
    return walk_length
'''
def extract_subgraphs_by_structure(dfg):
    # 创建无向图用于连通分量分析
    undir_graph = dfg.to_undirected()

    # 识别强连通分量（对应循环结构）# 第一步：强连通分量（SCC）提取
    scc = list(nx.strongly_connected_components(dfg))

    # 识别桥接边（boundry edges）,第二步：桥接边检测与扩展
    #bridges = list(nx.bridges(undir_graph))
    bridges = {(u, v) for u, v in dfg.edges() if not nx.is_simple_path(dfg, [u, v])}

    # 第三步：节点集合合并策略
    subgraph_nodes = []
    for component in scc:
        # 扩展包含桥接边的组件
        extended_component = set(component)
        for node in component:
            for neighbor in dfg.successors(node):
                if (node, neighbor) in bridges:
                    extended_component.add(neighbor)
        # 过滤碎片化子图（保留节点数≥2的集合）
        if len(extended_component) > 1:
            subgraph_nodes.append(extended_component)

    return subgraph_nodes
'''
'''
for subg in nx_subgraphs_free:
    subgraph_nodes = extract_subgraphs_by_structure(subg)#结构为：[{"a"},{"a","b"},...],len=len(subg)
    print(f"len(subg)={len(subg)} -> len(subgraph_nodes)={len(subgraph_nodes)}")
    print(f"subg={subg} -> subgraph_nodes={subgraph_nodes}")
    node_labels={node:data['x'] for node,data in subg.nodes.items()}
    for node,label in node_labels.items():
        print(f"{node}:{label} -> {DFG_node_type_list[label]}:{DFG_node_weight_list[label]}")
    #for nodes in subgraph_nodes:
    #    print(nodes.)
    #print(f"subgraph_nodes={subgraph_nodes}")
'''
'''
def dfg_enhanced_walk_subnodes(graph, start_node, subgraph_nodes,
                      alpha=0.65, node_weights=None,
                      base_length=15, density_factor=0.2):
    # 动态计算子图规模参数
    num_nodes = len(subgraph_nodes)
    num_edges = sum([len(graph.successors(n)) for n in subgraph_nodes])
    # 对数尺度自适应 (防止小图过短/大图过长)
    log_scale = max(1, np.log10(num_nodes))  # 10节点内按1处理
    adaptive_length = int(base_length * log_scale)
    # 密度修正 (稀疏图延长游走)
    if num_nodes > 0:
        density = num_edges / (num_nodes * (num_nodes - 1))  # 有向图密度
        adaptive_length = max(5, int(adaptive_length * (1 + density_factor * (1 - density))) )
    # 最终长度约束 (确保合理范围)
    walk_length = min(max(5, adaptive_length), 50)  # 限制在5-50范围内

    # 原双向游走逻辑 (保持核心算法)
    walk = [start_node]
    current = start_node
    for _ in range(walk_length - 1):
        # 双向邻居收集
        neighbors = []
        out_edges = [n for n in graph.successors(current) if n in subgraph_nodes]
        in_edges = [n for n in graph.predecessors(current) if n in subgraph_nodes]

        if out_edges:
            out_weights = [node_weights[n] * alpha for n in out_edges]
            neighbors.extend(out_edges)
        if in_edges:
            in_weights = [node_weights[n] * (1 - alpha) for n in in_edges]
            neighbors.extend(in_edges)

        if not neighbors:
            break

        # 语义加权选择
        combined_weights = [node_weights[n] for n in neighbors]
        next_node = np.random.choices(neighbors, weights=combined_weights, k=1)[0]

        walk.append(next_node)
        current = next_node
    return walk
'''
'''
#双向游走
def dfg_enhanced_walk(graph, start_node,walk_length=5,alpha=0.7, node_weights=None):#base_length=5, density_factor=0.2):
    #获取节点名称对应的类型编号，用于后面查询节点权重。
    node_labels={node:data['x'] for node,data in graph.nodes.items()}#{'node_name':label,'node_name2':label,....}
    if node_weights is None:
        node_weights=DFG_node_weight_list

    #walk_length = calc_walk_length(graph)#放到函数外面进行预计算。

    # 原双向游走逻辑 (保持核心算法)
    walk = [start_node]
    current = start_node
    for _ in range(walk_length - 1):
        # 双向邻居收集
        combined_weights= []
        neighbors = []
        out_edges = [n for n in graph.successors(current) ]#if n in graph.nodes()
        in_edges = [n for n in graph.predecessors(current)]# if n in graph.nodes()
        #if alpha==1 and not out_edges:#当alpha=1时，只考虑出度。此时如果out_edges为空，则直接结束。
        if not out_edges:
            break;

        if out_edges:
            out_weights = [node_weights[ node_labels[n] ] * alpha for n in out_edges]#n为节点名称 -> 对应的类型编号 -> 查询节点权重值
            combined_weights.extend(out_weights)
            neighbors.extend(out_edges)
        if in_edges:
            in_weights = [node_weights[ node_labels[n] ] * (1 - alpha) for n in in_edges]
            combined_weights.extend(in_weights)
            neighbors.extend(in_edges)

        if not neighbors:
            break
        #print(f"neighbors={neighbors}\ncombined_={combined_weights}")
        print(f"neighbors={out_edges}+{in_edges}\ncombined_={combined_weights}")
        # 语义加权选择
        #combined_weights = [node_weights[ node_labels[n] ] for n in neighbors]
        combined_weights=list_normalize(combined_weights)
        #if np.sum(combined_weights)<0.5:#当权重之和小于0.5时(实际上是全0，当alpha=1时会出现这种情况)，则停止游走。
        #    break;
        print(f"combined_={combined_weights}")
        #if len(combined_weights)>0:#不会出现combind_weights为空的情况。因为neighbors不为空。
        #next_node = np.random.choices(neighbors, weights=combined_weights, k=1)[0]
        retries=0
        select_bz=False
        #选取下一个节点，检测到回溯时重新选择，只到选出一个不重复的节点时结束。或者重试次数达到5次时结束。
        while retries<5 and not select_bz:# in walk[-2:]:
            next_node = np.random.choice(neighbors, size=1, p=combined_weights)[0]
            if len(walk) >= 2 and next_node in walk[-2:]:
                retries+=1
                continue
            else:
                select_bz=True# 成功选择有效节点

        if not select_bz:
            break  # 重试耗尽仍无有效选择，终止游走

        walk.append(next_node)
        current = next_node
    return walk
    '''
'''
#带权重的单向游走函数，适合有向图
def dfg_enhanced_walk_direct(graph, start_node,walk_length=5, node_weights=None):#base_length=5, density_factor=0.2):
    #获取节点名称对应的类型编号，用于后面查询节点权重。
    node_labels={node:data['x'] for node,data in graph.nodes.items()}#{'node_name':label,'node_name2':label,....}
    #node_type = {node:data['x'] for node, data in graph.nodes.items()}  # {'node_name':label,'node_name2':label,....}
    if node_weights is None:
        node_weights=DFG_node_weight_list

    #walk_length = calc_walk_length(graph)#放到函数外面进行预计算。

    walk = [start_node]
    current = start_node
    for _ in range(walk_length - 1):
        out_edges = [n for n in graph.successors(current) ]#if n in graph.nodes()
        if not out_edges:
            break;
        # 生成权重数列，并进行概率归一化，使其总和为1。
        combined_weights = [node_weights[ node_labels[n] ] for n in out_edges]#n为节点名称 -> 对应的类型编号 -> 查询节点权重值
        #print(f"neighbors={out_edges}\ncombined_={combined_weights}")
        combined_weights=list_normalize(combined_weights)
        #print(f"combined_={combined_weights}")

        # 语义加权选择
        next_node = np.random.choice(out_edges, size=1, p=combined_weights)[0]

        label=node_labels[next_node]
        #print(f"next_node={next_node}:label={} -> type={DFG_node_type_list[node_type[next_node]]}")
        node_type=DFG_node_type_list[label]
        walk.append(node_type)#20260116+改为节点类型
        #walk.append(next_node)#原来是按节点名称进行游走
        current = next_node
        #print(f"len={walk_length} walk={walk}", end='\n')
    return walk
'''
#带权重的单向游走函数，适合有向图
#以dfg_enhanced_walk_direct()为基础，将添加节点类型改为添加节点类型+编号，以区分相同类型的多个变量
def dfg_enhanced_walk_direct_bh(graph, start_node,walk_length=5, node_weights=None):#base_length=5, density_factor=0.2):
    #获取节点名称对应的类型编号，用于后面查询节点权重。
    node_labels={node:data['x'] for node,data in graph.nodes.items()}#{'node_name':label,'node_name2':label,....}
    #node_type = {node:data['x'] for node, data in graph.nodes.items()}  # {'node_name':label,'node_name2':label,....}
    type_counts={type:0 for type in DFG_node_type_list}#{'node_name':0,'node_name2':0,....},用于记录节点出现的次数
    if node_weights is None:
        node_weights=DFG_node_weight_list

    #walk_length = calc_walk_length(graph)#放到函数外面进行预计算。

    label=node_labels[start_node]
    node_type=DFG_node_type_list[label]
    name=node_type+str(type_counts[node_type])
    type_counts[node_type]+=1
    #walk = [name]#20260120+改为节点类型+编号
    #walk = [node_type]
    walk = [start_node]#原来是直接添加节点。
    current = start_node
    for idx in range(walk_length-1):
        out_edges = [n for n in graph.successors(current) ]#if n in graph.nodes()
        if not out_edges:
            break;
        # 生成权重数列，并进行概率归一化，使其总和为1。
        combined_weights = [node_weights[ node_labels[n] ] for n in out_edges]#n为节点名称 -> 对应的类型编号 -> 查询节点权重值
        #print(f"neighbors={out_edges}\ncombined_={combined_weights}")
        combined_weights=list_normalize(combined_weights)
        #print(f"combined_={combined_weights}")

        # 语义加权选择
        next_node = np.random.choice(out_edges, size=1, p=combined_weights)[0]#1 获取下一个节点

        label=node_labels[next_node]#2 获取节点类型编号
        #print(f"next_node={next_node}:label={} -> type={DFG_node_type_list[node_type[next_node]]}")
        node_type=DFG_node_type_list[label]#3 获取节点类型
        name=node_type+str(type_counts[node_type])#4 获取节点类型+编号
        #name=node_type+str(idx)
        type_counts[node_type]+=1#5 节点出现的次数加1

        #walk.append(next_node)#原来是按节点名称进行游走
        #walk.append(node_type)  # 20260116+改为节点类型
        walk.append(name)#20260120+改为节点类型+编号
        current = next_node

    #print(f"len={walk_length} walk={walk}",end=' -> ')
    #print(', '.join(f"{key}={value}" for key, value in type_counts.items() if value > 0))
    return walk

#带权重的单向游走函数，权重计算方式：节点权重*节点出度。
def dfg_enhanced_walk_direct_bh_degree(graph, start_node,walk_length=5, node_weights=None):#base_length=5, density_factor=0.2):
    #获取节点名称对应的类型编号，用于后面查询节点权重。
    node_labels={node:data['x'] for node,data in graph.nodes.items()}#{'node_name':label,'node_name2':label,....}
    #node_type = {node:data['x'] for node, data in graph.nodes.items()}  # {'node_name':label,'node_name2':label,....}
    type_counts={type:0 for type in DFG_node_type_list}#{'node_name':0,'node_name2':0,....},用于记录节点出现的次数
    if node_weights is None:
        #node_weights=DFG_node_weight_list
        node_weights = DFG_node_weight_list_ave #采用平均权重。

    #计算节点的权重字典，。
    node_weight_dict={}
    out_degrees = dict(graph.out_degree())
    for key,value in out_degrees.items():
        #out_degrees[key] = node_weights[ node_labels[key] ] * value
        #node_weight_dict[key]=DFG_node_weight_list[node_labels[key]]*(1+(value))#节点权重*节点出度
        node_weight_dict[key] = DFG_node_weight_list_ave[node_labels[key]]#仅节点权重，不含出度
    #print(f"node_weight_dict={node_weight_dict}")
    #print(f"out_degrees={out_degrees}")
    #walk_length = calc_walk_length(graph)#放到函数外面进行预计算。

    label=node_labels[start_node]
    node_type=DFG_node_type_list[label]
    name=node_type+str(type_counts[node_type])
    type_counts[node_type]+=1
    #walk = [name]#20260120+改为节点类型+编号
    #walk = [node_type]
    walk = [start_node]#原来是直接添加节点。
    current = start_node
    for idx in range(walk_length):
        out_edges = [n for n in graph.successors(current) ]#if n in graph.nodes()
        if not out_edges:
            break;
        # 生成权重数列，并进行概率归一化，使其总和为1。
        #combined_weights = [node_weights[ node_labels[n] ] for n in out_edges]#n为节点名称 -> 对应的类型编号 -> 查询节点权重值
        combined_weights = [node_weight_dict[n] for n in out_edges]
        #print(f"neighbors={out_edges}\ncombined_={combined_weights}")
        combined_weights=list_normalize(combined_weights)
        print(f"combined_={combined_weights}")

        # 语义加权选择
        next_node = np.random.choice(out_edges, size=1, p=combined_weights)[0]#1 获取下一个节点

        label=node_labels[next_node]#2 获取节点类型编号
        #print(f"next_node={next_node}:label={} -> type={DFG_node_type_list[node_type[next_node]]}")
        node_type=DFG_node_type_list[label]#3 获取节点类型
        name=node_type+str(type_counts[node_type])#4 获取节点类型+编号
        type_counts[node_type]+=1#5 节点出现的次数加1

        #walk.append(next_node)#原来是按节点名称进行游走
        #walk.append(node_type)  # 20260116+改为节点类型
        walk.append(name)#20260120+改为节点类型+编号
        current = next_node

    #print(f"len={walk_length} walk={walk}",end=' -> ')
    #print(', '.join(f"{key}={value}" for key, value in type_counts.items() if value > 0))
    return walk
#加权随机游走函数，可设置不同的节点类型权重、出度权重，以进行试验
def dfg_walk_direct_test(graph, start_node,walk_length=5, node_weights=None):#base_length=5, density_factor=0.2):
    #获取节点名称对应的类型编号，用于后面查询节点权重。
    node_labels={node:data['x'] for node,data in graph.nodes.items()}#{'node_name':label,'node_name2':label,....}
    type_counts={type:0 for type in DFG_node_type_list}#{'node_name':0,'node_name2':0,....},用于记录节点出现的次数
    if node_weights is None:    #此处的node_weights不起作用了，下面直接使用DFG_node_weight_list与_ave。
        #node_weights=DFG_node_weight_list
        node_weights = DFG_node_weight_list_ave #采用平均权重。

    #计算节点的权重字典，。
    node_weight_dict={}
    out_degrees = dict(graph.out_degree())
    for key,value in out_degrees.items():
        #权重组合，设置类型权重(_ave)和出度权重(1+value)。
        node_weight_dict[key] = DFG_node_weight_list_ave[node_labels[key]]             #0 无权重。无类型权重（平均类型权重）、无出度
        #node_weight_dict[key] = DFG_node_weight_list[node_labels[key]]                 #1 仅类型权重、无出度
        #node_weight_dict[key] = DFG_node_weight_list_ave[node_labels[key]]*(1+(value)) #2 仅出度权重、无类型权重（_ave）
        #node_weight_dict[key] = DFG_node_weight_list[node_labels[key]]*(1+(value))     #3 双重权重
        

    #print(f"node_weight_dict={node_weight_dict}")
    #print(f"out_degrees={out_degrees}")

    label=node_labels[start_node]
    node_type=DFG_node_type_list[label]
    name=node_type+str(type_counts[node_type])
    type_counts[node_type]+=1
    #walk = [name]#20260120+改为节点类型+编号
    #walk = [node_type]
    walk = [start_node]#原来是直接添加节点。
    current = start_node
    for idx in range(walk_length-1):
        out_edges = [n for n in graph.successors(current) ]#if n in graph.nodes()
        if not out_edges:
            break;
        # 生成权重数列，并进行概率归一化，使其总和为1。
        #combined_weights = [node_weights[ node_labels[n] ] for n in out_edges]#n为节点名称 -> 对应的类型编号 -> 查询节点权重值
        combined_weights = [node_weight_dict[n] for n in out_edges]
        #print(f"neighbors={out_edges}\ncombined_={combined_weights}")
        combined_weights=list_normalize(combined_weights)
        #print(f"combined_={combined_weights}")

        # 语义加权选择
        next_node = np.random.choice(out_edges, size=1, p=combined_weights)[0]#1 获取下一个节点

        label=node_labels[next_node]                #2 获取节点类型编号
        #print(f"next_node={next_node}:label={} -> type={DFG_node_type_list[node_type[next_node]]}")
        node_type=DFG_node_type_list[label]         #3 获取节点类型
        name=node_type+str(type_counts[node_type])  #4 获取节点类型+编号
        #name=node_type+str(idx)#使用大编号
        type_counts[node_type]+=1                   #5 节点出现的次数加1

        #walk.append(next_node)#原来是按节点名称进行游走
        #walk.append(node_type)  # 20260116+改为节点类型
        walk.append(name)#20260120+改为节点类型+编号
        current = next_node

    #print(f"len={walk_length} walk={walk}",end=' -> ')
    #print(', '.join(f"{key}={value}" for key, value in type_counts.items() if value > 0))
    return walk

#20260206+以该函数为准，首节点为节点名称，其他节点为节点类型+小编号，不使用节点和边权重，
def dfg_walk_direct_ok(graph, start_node,walk_length=3):#base_length=5, density_factor=0.2):
    #获取节点名称对应的类型编号，用于后面查询节点权重。
    node_labels={node:data['x'] for node,data in graph.nodes.items()}#{'node_name':label,'node_name2':label,....}
    type_counts=type_counts_zero.copy()    #初使化为0，用于记录节点出现的次数
    #print(f"type_counts={type_counts}")

    label=node_labels[start_node]
    node_type=DFG_node_type_list[label]
    #name=node_type+str(type_counts[node_type])
    type_counts[node_type]+=1
    #walk = [name]#20260120+改为节点类型+编号 ->会退化
    #walk = [node_type]
    walk = [start_node]#原来是直接添加节点。此为正确选项
    current = start_node
    for idx in range(walk_length-1):#除了首节点外，还有len-1次游走
        out_edges = [n for n in graph.successors(current) ]
        if not out_edges:
            break;
        #next_node = np.random.choice(out_edges, size=1)[0]  # 1 获取下一个节点
        next_node = np.random.choice(out_edges)  # 1 获取下一个节点，不加权，与上面的

        label=node_labels[next_node]                #2 获取节点类型编号
        #print(f"next_node={next_node}:label={} -> type={DFG_node_type_list[node_type[next_node]]}")
        node_type=DFG_node_type_list[label]         #3 获取节点类型
        name=node_type+str(type_counts[node_type])  #4 获取节点类型+编号
        #name=node_type+str(idx)#使用大编号
        type_counts[node_type]+=1                   #5 节点出现的次数加1

        #walk.append(next_node)     #原来是按节点名称进行游走
        #walk.append(node_type)     #20260116+改为节点类型
        walk.append(name)           #20260120+改为节点类型+编号
        current = next_node

    #print(f"len={walk_length} walk={walk}",end=' -> ')
    #print(', '.join(f"{key}={value}" for key, value in type_counts.items() if value > 0))
    return walk

'''
# GW1:有向图随机游走过程，待改进。参与MD记录
def directed_random_walk(graph, start_node, walk_length=5):
    walk = [start_node]
    current = start_node
    for _ in range(walk_length-1):
        neighbors = list(graph.successors(current))#获取当前节点的邻接节点。
        if not neighbors:
            break
        next_node = np.random.choice(neighbors)#从邻接节点中随机选择一个节点作为下一步的游走节点。
        walk.append(next_node)
        current = next_node
    return walk

# GW2:为所有子图生成游走序列
#生成单个nx图的walk，graph仅为单个的nx图
def generate_one_walks(graph):
    walks = []
    for node in graph.nodes:
        walk = directed_random_walk(graph, node)
        # walk=dfg_enhanced_walk(subg,node,subgraph_nodes)#,node_weights=x
        walks.append(walk)
    return walks
'''
# 生成所有nx图的walk，graphs[]中包含多个nx图。可根据需要启用子图节点集合。
def generate_all_walks(graphs,walk_length=3):#游走长度walk_length=0时，自动计算游走长度
    all_walks = []
    for graph in graphs:
        # subgraph_nodes=extract_subgraphs_by_structure(subg)
        if walk_length==0:
            walk_length=calc_walk_length(graph)
        #walk_length=3
        #walk_length=6
        #nodes=graph.number_of_nodes()
        #edges=graph.number_of_edges()
        #print(f"walk_length={walk_length:02d} {edges/(nodes*(nodes-1)):0.3f}  {edges/nodes:0.3f} {graph}")
        #continue
        for node in graph.nodes:
            #walk = directed_random_walk(graph, node,walk_length)
            #walk=dfg_enhanced_walk(graph,node,walk_length=walk_length,alpha=0.9)#,node_weights=x
            #walk=dfg_enhanced_walk_direct(graph,node,walk_length=walk_length)#单向游走
            #walk = dfg_enhanced_walk_direct_bh(graph, node, walk_length=walk_length)  # 单向游走
            #walk = dfg_enhanced_walk_direct_bh_degree(graph, node, walk_length=walk_length)  # 单向游走
            #walk = dfg_walk_direct_test(graph, node, walk_length=walk_length)  #加权策略消融实验，里面有内置4种权重策略
            walk = dfg_walk_direct_ok(graph, node, walk_length=walk_length)
            all_walks.append(walk)

    return all_walks
#all_walks=generate_all_walks(nx_subgraphs_free)
