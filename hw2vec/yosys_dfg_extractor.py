"""
YosysDFGSubgraphExtractor - 基于Yosys的信号级DFG子图提取器

功能:
1. 使用Yosys综合Verilog并输出JSON格式
2. 从Yosys JSON构建完整的信号级DFG
3. 按信号溯源提取子图(与Pyverilog版DFGGenerator兼容)
4. 节点类型映射到37种DFG标准类型,兼容graphwalk.py

与现有hw2graph.DFGGenerator的区别:
- 使用Yosys代替Pyverilog作为解析引擎(更稳定、支持更广)
- 子图提取方式: 从输出信号反向溯源(与Pyverilog的正向遍历等价)
- 输出格式完全兼容: 子图具备name/type/x/varname属性

作者: hw4vec项目
日期: 2026-04-22
"""

import subprocess
import json
import os
import sys
import pickle
import tempfile
import networkx as nx
import numpy as np
from pathlib import Path
from collections import defaultdict
from glob import glob


# ============== Yosys cell类型 → DFG节点类型映射 ==============

# DFG标准37种节点类型(与hw2graph.py中global_type2idx_DFG_list一致)
DFG_NODE_TYPE_LIST = [
    'concat', 'input', 'unand', 'unor', 'uxor', 'signal', 'uand', 'ulnot', 'uxnor', 'numeric',
    'partselect', 'and', 'unot', 'branch', 'or', 'uor', 'output', 'plus', 'eq', 'minus',
    'xor', 'lor', 'noteq', 'land', 'greatereq', 'greaterthan', 'sll', 'lessthan', 'times', 'srl',
    'pointer', 'mod', 'divide', 'sra', 'sla', 'xnor', 'lesseq'
]

DFG_TYPE2IDX = {v: k for k, v in enumerate(DFG_NODE_TYPE_LIST)}

# Yosys cell类型到DFG节点类型的映射
YOSYS_CELL_TYPE_MAP = {
    # 基本逻辑门
    '$_AND_': 'and', '$_NAND_': 'unand', '$_OR_': 'or', '$_NOR_': 'unor',
    '$_NOT_': 'unot', '$_XOR_': 'xor', '$_XNOR_': 'xnor',
    # 多输入逻辑门(Yosys内部命名)
    '$and': 'and', '$nand': 'unand', '$or': 'or', '$nor': 'unor',
    '$not': 'unot', '$xor': 'xor', '$xnor': 'xnor',
    '$logic_and': 'land', '$logic_or': 'lor', '$logic_not': 'ulnot',
    # 比较操作
    '$eq': 'eq', '$ne': 'noteq', '$gt': 'greaterthan', '$ge': 'greatereq',
    '$lt': 'lessthan', '$le': 'lesseq',
    # 算术操作
    '$add': 'plus', '$sub': 'minus', '$mul': 'times', '$mod': 'mod', '$div': 'divide',
    # 移位操作
    '$sshl': 'sll', '$sshr': 'sra', '$shl': 'sll', '$shr': 'srl',
    '$shift': 'srl', '$shiftx': 'srl',
    # 多路选择
    '$mux': 'branch', '$pmux': 'branch',
    '$_MUX_': 'branch',
    # 位操作
    '$pos': 'signal', '$neg': 'minus',
    # 位拼接/选择
    '$concat': 'concat', '$slice': 'partselect',
    # 触发器/寄存器
    '$_DFF_P_': 'signal', '$_DFF_N_': 'signal',
    '$_DFF_PP0_': 'signal', '$_DFF_PP1_': 'signal',
    '$_DFF_PN0_': 'signal', '$_DFF_PN1_': 'signal',
    '$_DFF_NP0_': 'signal', '$_DFF_NN0_': 'signal',
    '$dff': 'signal', '$adff': 'signal', '$dffe': 'signal',
    '$sr': 'signal', '$dlatch': 'signal',
    # 存储器
    '$memrd': 'signal', '$memwr': 'signal', '$meminit': 'signal',
    # 其他
    '$assert': 'signal', '$assume': 'signal',
}

# DFG节点权重映射(与graphwalk.py中DFG_node_weight_map一致)
DFG_NODE_WEIGHT_MAP = {
    'concat': 2.0, 'input': 1.0, 'unand': 1.5, 'unor': 1.5, 'uxor': 1.5,
    'signal': 1.0, 'uand': 1.5, 'ulnot': 1.5, 'uxnor': 1.5, 'numeric': 1,
    'partselect': 2.0, 'and': 1.5, 'unot': 1.5, 'branch': 3.0, 'or': 1.5,
    'uor': 1.5, 'output': 1.0, 'plus': 3.0, 'eq': 2.0, 'minus': 3.0,
    'xor': 1.5, 'lor': 2.5, 'noteq': 2.0, 'land': 2.5, 'greatereq': 2.0,
    'greaterthan': 2.0, 'sll': 2.0, 'lessthan': 2.0, 'times': 3.0, 'srl': 2.0,
    'pointer': 1.5, 'mod': 3.0, 'divide': 3.0, 'sra': 2.0, 'sla': 2.0,
    'xnor': 1.5, 'lesseq': 2.0
}


def get_var_name(node_name: str) -> str:
    """从节点名中提取变量名(与hw2graph.py中get_var_name一致)"""
    if '_rn_' in node_name:
        node_name = node_name[:node_name.index('_rn_')]
    if '_rm_' in node_name:
        node_name = node_name[:node_name.index('_rm_')]
    if '.' in node_name:
        out_name = node_name.split('.')[-1]
    elif '_' in node_name:
        out_name = node_name.split('_')[-1]
    else:
        out_name = node_name.lower()
    return out_name


def classify_node_type(node_name: str, in_degree: int, out_degree: int) -> str:
    """
    根据节点名称和度数分类节点类型(与DataProcessor.normalize逻辑一致)

    Args:
        node_name: 节点名称
        in_degree: 入度
        out_degree: 出度

    Returns:
        DFG节点类型名称
    """
    clean_name = node_name
    if '_rn' in clean_name:
        clean_name = clean_name[:clean_name.index('_rn')]

    # 数值常量
    if any(p in clean_name for p in ["'d", "'b", "'o", "'h"]):
        return "numeric"

    # 入度为0 = 输出端口(数据流出模块)
    if in_degree == 0:
        return "output"
    # 出度为0 = 输入端口(数据流入模块)
    if out_degree == 0:
        return "input"

    # 含.或_的为信号
    if '.' in clean_name or '_' in clean_name:
        return "signal"

    # 其他: 操作符
    return clean_name.lower()


def map_yosys_cell_type(yosys_type: str) -> str:
    """将Yosys cell类型映射到DFG节点类型"""
    # 先查精确匹配
    if yosys_type in YOSYS_CELL_TYPE_MAP:
        return YOSYS_CELL_TYPE_MAP[yosys_type]

    # 尝试去除前缀$后的匹配
    bare_type = yosys_type.lstrip('$').lstrip('_').lower()
    type_aliases = {
        'and': 'and', 'nand': 'unand', 'or': 'or', 'nor': 'unor',
        'not': 'unot', 'xor': 'xor', 'xnor': 'xnor',
        'mux': 'branch', 'dff': 'signal', 'latch': 'signal',
        'add': 'plus', 'sub': 'minus', 'mul': 'times',
    }
    for alias, dfg_type in type_aliases.items():
        if alias in bare_type:
            return dfg_type

    # 默认: signal
    return 'signal'


class YosysDFGSubgraphExtractor:
    """
    基于Yosys的信号级DFG子图提取器

    使用方法:
        extractor = YosysDFGSubgraphExtractor()
        dfg, subgraphs = extractor.extract_from_dir(verilog_dir)

    输出格式与hw2graph.DFGGenerator完全兼容:
        - dfg: 整体DFG (nx.DiGraph), 带 name/type 属性
        - subgraphs: 信号子图列表, 每个子图带 name/type 属性
          节点属性: x(类型索引), type(类型名), varname(变量名)
    """

    def __init__(self, yosys_path: str = None, min_subgraph_nodes: int = 3):
        """
        初始化提取器

        Args:
            yosys_path: Yosys可执行文件路径(默认自动检测)
            min_subgraph_nodes: 子图最小节点数阈值(默认3,与DFGGenerator一致)
        """
        self.yosys_path = yosys_path or r"e:\PRO\python\tools\oss-cad-suite\bin\yosys.exe"
        self.min_subgraph_nodes = min_subgraph_nodes
        self.yosys_available = self._check_yosys()
        print(f"[YosysDFG] 初始化完成, Yosys可用: {self.yosys_available}")

    def _check_yosys(self) -> bool:
        """检查Yosys是否可用"""
        try:
            env = self._get_yosys_env()
            result = subprocess.run(
                [self.yosys_path, '-V'],
                capture_output=True, text=True, timeout=5, env=env
            )
            return result.returncode == 0
        except Exception:
            return False

    def _get_yosys_env(self) -> dict:
        """获取Yosys运行所需的环境变量"""
        env = os.environ.copy()
        oss_bin = r"e:\PRO\python\tools\oss-cad-suite\bin"
        oss_lib = r"e:\PRO\python\tools\oss-cad-suite\lib"
        env['PATH'] = f"{oss_bin};{oss_lib};{env.get('PATH', '')}"
        return env

    def _run_yosys(self, verilog_file: str, top_module: str = "top") -> dict:
        """
        运行Yosys提取JSON

        Args:
            verilog_file: Verilog文件路径
            top_module: 顶层模块名

        Returns:
            Yosys输出的JSON字典
        """
        # 创建临时文件
        script_fd, script_path = tempfile.mkstemp(suffix='.ys')
        json_fd, json_path = tempfile.mkstemp(suffix='.json')
        os.close(script_fd)
        os.close(json_fd)

        try:
            # 构建Yosys脚本
            yosys_script = (
                f"read_verilog {verilog_file}\n"
                f"hierarchy -top {top_module}\n"
                "proc\n"
                "opt\n"
                "fsm_detect\n"
                "opt\n"
                f"write_json {json_path}\n"
            )
            with open(script_path, 'w') as f:
                f.write(yosys_script)

            # 执行Yosys
            env = self._get_yosys_env()
            result = subprocess.run(
                [self.yosys_path, script_path],
                capture_output=True, text=True, env=env,
                timeout=120
            )

            if result.returncode != 0:
                raise RuntimeError(f"Yosys执行失败: {result.stderr[-500:]}")

            # 读取JSON结果
            with open(json_path, 'r', encoding='utf-8') as f:
                yosys_json = json.load(f)

            return yosys_json

        finally:
            # 清理临时文件
            for p in [script_path, json_path]:
                try:
                    os.remove(p)
                except:
                    pass

    def _parse_yosys_json(self, yosys_json: dict) -> nx.DiGraph:
        """
        从Yosys JSON构建完整信号级DFG

        构建策略:
        - 每个net(信号线)作为一个节点
        - 每个cell(逻辑操作)作为节点
        - 连接: net → cell(输入), cell → net(输出)

        Args:
            yosys_json: Yosys输出的JSON

        Returns:
            完整的DFG (nx.DiGraph)
        """
        G = nx.DiGraph()

        for mod_name, mod_data in yosys_json.get('modules', {}).items():
            # 收集所有net信息
            net_info = {}  # net_id -> {name, direction, bits}

            # 1. 处理端口 - 建立端口到net的映射
            port_to_nets = {}  # port_name -> [net_ids]
            for port_name, port_info in mod_data.get('ports', {}).items():
                direction = port_info.get('direction', 'unknown')
                bits = port_info.get('bits', [])
                port_to_nets[port_name] = bits
                for bit_idx, net_id in enumerate(bits):
                    if net_id not in net_info:
                        net_info[net_id] = {
                            'name': f"{port_name}[{bit_idx}]" if len(bits) > 1 else port_name,
                            'direction': direction,
                            'port_name': port_name,
                            'bit_idx': bit_idx
                        }
                    else:
                        # 多个端口可能连接同一net
                        net_info[net_id]['port_name'] = port_name

            # 2. 处理cells - 建立cell到net的连接
            cell_info = {}  # cell_name -> {type, inputs: [net_ids], outputs: [net_ids]}
            for cell_name, cell_data in mod_data.get('cells', {}).items():
                cell_type = cell_data.get('type', 'unknown')
                port_directions = cell_data.get('port_directions', {})
                connections = cell_data.get('connections', {})

                input_nets = []
                output_nets = []

                for port_name, signal_ids in connections.items():
                    direction = port_directions.get(port_name, 'unknown')

                    # 判断输入/输出方向
                    is_output = (
                        direction == 'output' or
                        port_name in ['Y', 'Q', 'A_Y', 'S_Y'] or
                        (cell_type.startswith('$_') and port_name == 'Y') or
                        (cell_type.startswith('$') and port_name == 'Y')
                    )

                    if is_output:
                        output_nets.extend(signal_ids)
                    else:
                        input_nets.extend(signal_ids)

                    # 记录net信息
                    for bit_idx, net_id in enumerate(signal_ids):
                        if net_id not in net_info:
                            net_info[net_id] = {
                                'name': f"net_{net_id}",
                                'direction': 'internal',
                                'port_name': None,
                                'bit_idx': bit_idx
                            }

                cell_info[cell_name] = {
                    'type': cell_type,
                    'inputs': input_nets,
                    'outputs': output_nets
                }

            # 3. 构建DFG图 - 添加net节点
            for net_id, info in net_info.items():
                net_name = info['name']
                # 判断net方向类型
                if info['direction'] == 'input':
                    node_type = 'input'
                elif info['direction'] == 'output':
                    node_type = 'output'
                else:
                    node_type = 'signal'

                G.add_node(net_name,
                           net_id=net_id,
                           node_category='net',
                           direction=info['direction'],
                           type=node_type,
                           varname=get_var_name(net_name))

            # 4. 添加cell节点和边
            for cell_name, cinfo in cell_info.items():
                dfg_type = map_yosys_cell_type(cinfo['type'])
                G.add_node(cell_name,
                           node_category='cell',
                           yosys_type=cinfo['type'],
                           type=dfg_type,
                           varname=get_var_name(cell_name))

                # 输入net → cell
                for net_id in cinfo['inputs']:
                    if net_id in net_info:
                        net_name = net_info[net_id]['name']
                        G.add_edge(net_name, cell_name)

                # cell → 输出net
                for net_id in cinfo['outputs']:
                    if net_id in net_info:
                        net_name = net_info[net_id]['name']
                        G.add_edge(cell_name, net_name)

        return G

    def _extract_signal_subgraphs(self, dfg: nx.DiGraph) -> list:
        """
        从完整DFG中提取信号级子图

        策略: 对每个输出节点(或入度为0的net节点)反向溯源,
        提取其驱动锥(cone of influence)作为子图

        Args:
            dfg: 完整DFG

        Returns:
            子图列表 [nx.DiGraph, ...]
        """
        subgraphs = []

        # 找到所有可以作为子图根节点的net节点
        # 优先: output方向端口; 其次: 入度为0的net(即输出端口)
        root_nodes = []
        for node, data in dfg.nodes(data=True):
            if data.get('node_category') == 'net':
                if data.get('direction') == 'output' or dfg.in_degree(node) == 0:
                    root_nodes.append(node)

        # 如果没有找到根节点,使用所有入度为0的节点
        if not root_nodes:
            root_nodes = [n for n in dfg.nodes() if dfg.in_degree(n) == 0]

        for root_node in root_nodes:
            # 反向溯源: 收集root_node的驱动锥中的所有节点
            subgraph_nodes = set()
            stack = [root_node]
            while stack:
                current = stack.pop()
                if current in subgraph_nodes:
                    continue
                subgraph_nodes.add(current)
                # 沿入边溯源(找前驱)
                for pred in dfg.predecessors(current):
                    if pred not in subgraph_nodes:
                        stack.append(pred)

            if len(subgraph_nodes) < self.min_subgraph_nodes:
                continue

            # 创建子图
            sub_nx = dfg.subgraph(subgraph_nodes).copy()

            # 设置子图根节点属性
            sub_nx.graph['root_node'] = root_node
            subgraphs.append(sub_nx)

        return subgraphs

    def _normalize_subgraphs(self, subgraphs: list) -> list:
        """
        对子图进行标准化,添加x类型索引属性(与DataProcessor.normalize兼容)

        Args:
            subgraphs: 子图列表

        Returns:
            标准化后的子图列表
        """
        normalized = []
        for subg in subgraphs:
            # 计算度数
            in_degrees = dict(subg.in_degree())
            out_degrees = dict(subg.out_degree())

            for node in subg.nodes():
                node_data = subg.nodes[node]
                node_category = node_data.get('node_category', 'net')

                if node_category == 'cell':
                    # cell节点: 使用已映射的DFG类型
                    dfg_type = node_data.get('type', 'signal')
                else:
                    # net节点: 根据名称和度数分类
                    dfg_type = classify_node_type(
                        node, in_degrees.get(node, 0), out_degrees.get(node, 0)
                    )

                # 映射到类型索引
                if dfg_type not in DFG_TYPE2IDX:
                    print(f"[WARNING] 未知DFG类型 '{dfg_type}' (节点: {node}), 使用'signal'")
                    dfg_type = 'signal'

                node_data['x'] = DFG_TYPE2IDX[dfg_type]
                node_data['type'] = dfg_type

                # 确保varname属性存在
                if 'varname' not in node_data:
                    node_data['varname'] = get_var_name(node)

            normalized.append(subg)

        return normalized

    def extract_from_file(self, verilog_file: str, top_module: str = "top",
                          circuit_name: str = None, circuit_type: str = None):
        """
        从单个Verilog文件提取DFG和子图

        Args:
            verilog_file: Verilog文件路径
            top_module: 顶层模块名
            circuit_name: 电路名称(默认从路径提取)
            circuit_type: 电路类型(TjFree/TjIn, 默认从路径提取)

        Returns:
            (dfg, subgraphs): 整体DFG和子图列表
        """
        if not self.yosys_available:
            raise RuntimeError("Yosys不可用,请检查安装")

        print(f"[YosysDFG] 提取: {verilog_file}")

        # 从路径自动提取circuit_name和type
        if circuit_name is None:
            circuit_name = Path(verilog_file).parent.name
        if circuit_type is None:
            parent_path = str(Path(verilog_file).parent.parent)
            if 'TjFree' in parent_path or 'TjIn' not in str(Path(verilog_file).parent.parent):
                # 检查直接父目录
                parent_name = Path(verilog_file).parent.parent.name
                circuit_type = 'TjIn' if 'TjIn' in parent_name else 'TjFree'
            else:
                circuit_type = 'TjFree'

        # 运行Yosys
        yosys_json = self._run_yosys(verilog_file, top_module)

        # 构建DFG
        dfg = self._parse_yosys_json(yosys_json)

        # 设置整体图属性
        dfg.name = circuit_name
        dfg.type = circuit_type

        # 提取子图
        subgraphs = self._extract_signal_subgraphs(dfg)

        # 标准化子图
        subgraphs = self._normalize_subgraphs(subgraphs)

        # 为每个子图设置name和type属性
        for subg in subgraphs:
            subg.name = circuit_name
            subg.type = circuit_type

        print(f"[YosysDFG] 完成: 整体图 {dfg.number_of_nodes()}节点/{dfg.number_of_edges()}边, "
              f"子图 {len(subgraphs)}个")

        return dfg, subgraphs

    def extract_from_dir(self, verilog_dir, top_module: str = "top"):
        """
        从Verilog目录提取DFG和子图(与HW2GRAPH.code2graph兼容)

        查找目录下的topModule.v文件,如不存在则查找所有.v文件

        Args:
            verilog_dir: Verilog文件所在目录
            top_module: 顶层模块名

        Returns:
            (dfg, subgraphs): 整体DFG和子图列表
        """
        verilog_dir = Path(verilog_dir)

        # 查找Verilog文件
        verilog_file = None
        top_module_v = verilog_dir / "topModule.v"
        if top_module_v.exists():
            verilog_file = str(top_module_v)
        else:
            v_files = list(verilog_dir.glob("*.v"))
            if v_files:
                verilog_file = str(v_files[0])
            else:
                raise FileNotFoundError(f"未找到Verilog文件: {verilog_dir}")

        # 从路径提取circuit_name和type
        circuit_name = verilog_dir.name
        parent_name = verilog_dir.parent.name
        circuit_type = 'TjIn' if 'TjIn' in parent_name else 'TjFree'

        return self.extract_from_file(
            verilog_file, top_module,
            circuit_name=circuit_name,
            circuit_type=circuit_type
        )

    def extract_dataset(self, dataset_path, exclude_patterns=None):
        """
        提取整个数据集的DFG和子图

        遍历TjFree和TjIn目录下的所有电路文件夹

        Args:
            dataset_path: 数据集根目录(如 assets/TJ-RTL-toy)
            exclude_patterns: 排除的电路名模式列表(如 ['wb_conmax'])

        Returns:
            (nx_graphs_all, nx_subgraphs_all): 所有整体图和子图列表
        """
        dataset_path = Path(dataset_path)
        exclude_patterns = exclude_patterns or []

        nx_graphs_all = []
        nx_subgraphs_all = []

        # 遍历TjFree和TjIn目录
        for type_dir_name in ['TjFree', 'TjIn']:
            type_dir = dataset_path / type_dir_name
            if not type_dir.exists():
                print(f"[YosysDFG] 目录不存在: {type_dir}")
                continue

            print(f"\n[YosysDFG] === 处理 {type_dir_name} 目录 ===")

            for circuit_dir in sorted(type_dir.iterdir()):
                if not circuit_dir.is_dir():
                    continue

                # 排除特定电路
                skip = False
                for pattern in exclude_patterns:
                    if pattern in circuit_dir.name:
                        skip = True
                        break
                if skip:
                    print(f"[YosysDFG] 跳过: {circuit_dir.name}")
                    continue

                try:
                    dfg, subgraphs = self.extract_from_dir(circuit_dir)
                    nx_graphs_all.append(dfg)
                    nx_subgraphs_all.extend(subgraphs)
                except Exception as e:
                    print(f"[YosysDFG] 错误: {circuit_dir.name} - {e}")
                    continue

        print(f"\n[YosysDFG] 数据集提取完成:")
        print(f"  整体图: {len(nx_graphs_all)}个")
        print(f"  子图: {len(nx_subgraphs_all)}个")

        return nx_graphs_all, nx_subgraphs_all


class GraphWalkChangeDetector:
    """
    GraphWalk改动检测器

    使用GraphWalk(随机游走+Word2Vec)方法检测硬件木马改动信号

    流程:
    1. 加载/提取DFG子图数据
    2. 对木马电路的子图与正常电路的子图进行GraphWalk嵌入
    3. 计算余弦相似度
    4. 根据相似度阈值识别改动信号
    5. 评估检测结果
    """

    def __init__(self, walk_length=3, vector_size=128, window=3, sg=0, seed=42):
        """
        初始化检测器

        Args:
            walk_length: 游走长度(0=自适应)
            vector_size: Word2Vec向量维度
            window: Word2Vec窗口大小
            sg: 0=CBOW, 1=Skip-gram
            seed: 随机种子
        """
        self.walk_length = walk_length
        self.vector_size = vector_size
        self.window = window
        self.sg = sg
        self.seed = seed

        # 结果存储
        self.nx_subgraphs_free = []
        self.nx_subgraphs_in = []
        self.graph_embds_free = []
        self.graph_embds_in = []
        self.similarity_matrix = None

    def load_subgraphs(self, nx_subgraphs_free, nx_subgraphs_in):
        """
        加载子图数据

        Args:
            nx_subgraphs_free: 正常电路子图列表
            nx_subgraphs_in: 木马电路子图列表
        """
        self.nx_subgraphs_free = list(nx_subgraphs_free)
        self.nx_subgraphs_in = list(nx_subgraphs_in)
        print(f"[GW-Detect] 加载子图: free={len(self.nx_subgraphs_free)}, in={len(self.nx_subgraphs_in)}")

    def _generate_walks(self, graphs, walk_length=None):
        """
        为子图生成游走序列(与graphwalk.py中generate_all_walks兼容)

        Args:
            graphs: 子图列表
            walk_length: 游走长度

        Returns:
            游走序列列表
        """
        import torch
        walk_length = walk_length or self.walk_length
        all_walks = []

        for graph in graphs:
            if walk_length == 0:
                # 自适应长度
                num_nodes = graph.number_of_nodes()
                log_scale = max(1, np.log10(max(num_nodes, 1)))
                wl = min(max(3, int(3 * log_scale)), 10)
            else:
                wl = walk_length

            # 获取节点类型标签
            node_labels = {}
            for node, data in graph.nodes(data=True):
                if 'x' in data:
                    node_labels[node] = data['x']
                else:
                    node_labels[node] = DFG_TYPE2IDX.get(data.get('type', 'signal'), 5)

            type_counts = {t: 0 for t in DFG_NODE_TYPE_LIST}

            for start_node in graph.nodes():
                walk = [start_node]
                current = start_node
                for _ in range(wl - 1):
                    out_edges = list(graph.successors(current))
                    if not out_edges:
                        break

                    # 不加权随机选择(与dfg_walk_direct_ok一致)
                    next_node = np.random.choice(out_edges)

                    # 获取节点类型+编号
                    label = node_labels.get(next_node, 5)
                    node_type = DFG_NODE_TYPE_LIST[label] if label < len(DFG_NODE_TYPE_LIST) else 'signal'
                    name = node_type + str(type_counts[node_type])
                    type_counts[node_type] += 1

                    walk.append(name)
                    current = next_node

                all_walks.append(walk)

        return all_walks

    def compute_embeddings(self):
        """
        使用GraphWalk计算子图嵌入向量

        Returns:
            (graph_embds_free, graph_embds_in): 正常和木马子图的嵌入向量列表
        """
        try:
            import torch
            HAS_TORCH = True
        except ImportError:
            HAS_TORCH = False

        from gensim.models import Word2Vec

        # 生成游走序列
        all_walks = []
        all_walks.extend(self._generate_walks(self.nx_subgraphs_free))
        all_walks.extend(self._generate_walks(self.nx_subgraphs_in))

        if not all_walks:
            print("[GW-Detect] 未生成有效游走序列")
            return None, None

        print(f"[GW-Detect] 游走序列: {len(all_walks)}条")

        # 训练Word2Vec
        model_wv = Word2Vec(
            sentences=all_walks,
            vector_size=self.vector_size,
            window=self.window,
            min_count=1, workers=1,
            sg=self.sg, seed=self.seed
        )

        # 计算子图嵌入(平均池化)
        self.graph_embds_free = []
        for subg in self.nx_subgraphs_free:
            node_vectors = [model_wv.wv[str(node)] for node in subg.nodes() if str(node) in model_wv.wv]
            if node_vectors:
                tmp = sum(node_vectors) / len(node_vectors)
                self.graph_embds_free.append(torch.from_numpy(tmp) if HAS_TORCH else tmp)
            else:
                self.graph_embds_free.append(torch.from_numpy(np.zeros(self.vector_size)) if HAS_TORCH else np.zeros(self.vector_size))

        self.graph_embds_in = []
        for subg in self.nx_subgraphs_in:
            node_vectors = [model_wv.wv[str(node)] for node in subg.nodes() if str(node) in model_wv.wv]
            if node_vectors:
                tmp = sum(node_vectors) / len(node_vectors)
                self.graph_embds_in.append(torch.from_numpy(tmp) if HAS_TORCH else tmp)
            else:
                self.graph_embds_in.append(torch.from_numpy(np.zeros(self.vector_size)) if HAS_TORCH else np.zeros(self.vector_size))

        print(f"[GW-Detect] 嵌入完成: free={len(self.graph_embds_free)}, in={len(self.graph_embds_in)}")
        return self.graph_embds_free, self.graph_embds_in

    def compute_similarity(self):
        """
        计算free和in子图之间的余弦相似度矩阵

        Returns:
            similarity_matrix: numpy相似度矩阵 [n_in x n_free]
        """
        try:
            import torch
            HAS_TORCH = True
        except ImportError:
            HAS_TORCH = False

        if not self.graph_embds_free or not self.graph_embds_in:
            raise ValueError("请先调用compute_embeddings()")

        if HAS_TORCH:
            # 使用PyTorch批量计算余弦相似度
            if isinstance(self.graph_embds_free[0], torch.Tensor):
                emb_free = torch.stack(self.graph_embds_free)
                emb_in = torch.stack(self.graph_embds_in)
            else:
                emb_free = torch.from_numpy(np.stack(self.graph_embds_free))
                emb_in = torch.from_numpy(np.stack(self.graph_embds_in))

            sim_matrix = torch.cosine_similarity(
                emb_in.unsqueeze(1),   # [n_in, 1, dim]
                emb_free.unsqueeze(0), # [1, n_free, dim]
                dim=-1
            )

            if sim_matrix.dim() == 3:
                sim_matrix = sim_matrix.squeeze(-1)

            self.similarity_matrix = sim_matrix.detach().cpu().numpy()
        else:
            # numpy回退: 手动计算余弦相似度
            emb_free = np.stack(self.graph_embds_free)  # [n_free, dim]
            emb_in = np.stack(self.graph_embds_in)      # [n_in, dim]

            # 归一化
            free_norm = emb_free / (np.linalg.norm(emb_free, axis=1, keepdims=True) + 1e-8)
            in_norm = emb_in / (np.linalg.norm(emb_in, axis=1, keepdims=True) + 1e-8)

            # 余弦相似度 = in @ free.T
            self.similarity_matrix = in_norm @ free_norm.T

        print(f"[GW-Detect] 相似度矩阵: {self.similarity_matrix.shape}")
        return self.similarity_matrix

    def detect_changes(self, top_k_percent=0.01, min_threshold=0.98):
        """
        检测改动信号

        Args:
            top_k_percent: top-k百分比阈值(默认1%)
            min_threshold: 最低相似度阈值(默认0.98)

        Returns:
            (normal_indices, trojan_indices, max_similarities):
                正常/木马子图索引和每个in子图的最大相似度
        """
        if self.similarity_matrix is None:
            self.compute_similarity()

        max_similarities = np.max(self.similarity_matrix, axis=1)
        max_values = np.max(self.similarity_matrix)
        min_values = np.min(self.similarity_matrix)
        width = max_values - min_values

        # 计算top阈值
        top_val = max_values - width * top_k_percent
        top_val = max(min_threshold, top_val)

        normal_indices = []
        trojan_indices = []

        for i, max_sim in enumerate(max_similarities):
            if max_sim >= top_val:
                normal_indices.append(i)
            else:
                trojan_indices.append(i)

        print(f"[GW-Detect] 检测结果:")
        print(f"  阈值: {top_val:.4f}")
        print(f"  正常子图: {len(normal_indices)}个")
        print(f"  疑似木马子图: {len(trojan_indices)}个")

        return normal_indices, trojan_indices, max_similarities

    def evaluate(self, trojan_indices, ground_truth_signals=None, circuit_name=None):
        """
        评估检测结果

        Args:
            trojan_indices: 检测为木马的子图索引
            ground_truth_signals: 真实改动信号字典 {circuit_name: [signal_name, ...]}
            circuit_name: 当前电路名

        Returns:
            评估结果字典
        """
        if not ground_truth_signals:
            return None

        # 获取真实信号
        if circuit_name and circuit_name in ground_truth_signals:
            true_signals = set(ground_truth_signals[circuit_name])
        else:
            true_signals = set()
            for signals in ground_truth_signals.values():
                true_signals.update(signals)

        # 提取检测到的信号名
        detected_names = set()
        for idx in trojan_indices:
            if idx < len(self.nx_subgraphs_in):
                subg = self.nx_subgraphs_in[idx]
                first_node = next(iter(subg.nodes()), "unknown")
                signal_name = get_var_name(first_node)
                detected_names.add(signal_name)

        # 计算指标
        TP = len(detected_names & true_signals)
        FP = len(detected_names - true_signals)
        FN = len(true_signals - detected_names)
        total = len(self.nx_subgraphs_in)
        TN = max(0, total - TP - FP - FN)

        precision = TP / (TP + FP) if (TP + FP) > 0 else 0
        recall = TP / (TP + FN) if (TP + FN) > 0 else 0
        f1 = 2 * precision * recall / (precision + recall) if (precision + recall) > 0 else 0
        fpr = FP / (FP + TN) if (FP + TN) > 0 else 0

        result = {
            'TP': TP, 'FP': FP, 'TN': TN, 'FN': FN,
            'Precision': precision, 'Recall': recall, 'F1': f1,
            'FPR': fpr,
            'detected_count': len(detected_names),
            'ground_truth_count': len(true_signals)
        }

        print(f"[GW-Detect] 评估结果:")
        print(f"  TP={TP} FP={FP} TN={TN} FN={FN}")
        print(f"  Precision={precision:.4f} Recall={recall:.4f} F1={f1:.4f}")
        print(f"  FPR={fpr:.4f}")

        return result

    def run_detection(self, nx_subgraphs_free, nx_subgraphs_in,
                      ground_truth_signals=None, circuit_name=None):
        """
        完整的改动检测流程

        Args:
            nx_subgraphs_free: 正常电路子图
            nx_subgraphs_in: 木马电路子图
            ground_truth_signals: 真实改动信号
            circuit_name: 电路名

        Returns:
            检测结果字典
        """
        import time as time_module

        t0 = time_module.perf_counter()

        # 1. 加载子图
        self.load_subgraphs(nx_subgraphs_free, nx_subgraphs_in)

        # 2. 计算嵌入
        t1 = time_module.perf_counter()
        self.compute_embeddings()
        t2 = time_module.perf_counter()

        # 3. 计算相似度
        self.compute_similarity()
        t3 = time_module.perf_counter()

        # 4. 检测改动
        normal_idx, trojan_idx, max_sims = self.detect_changes()
        t4 = time_module.perf_counter()

        # 5. 评估
        eval_result = None
        if ground_truth_signals:
            eval_result = self.evaluate(trojan_idx, ground_truth_signals, circuit_name)

        # 收集检测结果
        detected_signals = []
        for idx in trojan_idx:
            if idx < len(self.nx_subgraphs_in):
                subg = self.nx_subgraphs_in[idx]
                first_node = next(iter(subg.nodes()), "unknown")
                detected_signals.append({
                    'index': idx,
                    'signal_name': get_var_name(first_node),
                    'nodes': subg.number_of_nodes(),
                    'edges': subg.number_of_edges(),
                    'max_similarity': float(max_sims[idx]) if idx < len(max_sims) else 0.0
                })

        result = {
            'circuit_name': circuit_name,
            'normal_count': len(normal_idx),
            'trojan_count': len(trojan_idx),
            'detected_signals': detected_signals,
            'max_similarities': max_sims.tolist(),
            'similarity_matrix_shape': self.similarity_matrix.shape if self.similarity_matrix is not None else None,
            'timing': {
                'embedding': t2 - t1,
                'similarity': t3 - t2,
                'detection': t4 - t3,
                'total': t4 - t0
            },
            'evaluation': eval_result
        }

        return result
