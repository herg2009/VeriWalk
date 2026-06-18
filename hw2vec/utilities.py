import cProfile
import pstats
import io
import os
import sys
from matplotlib import pylab
import matplotlib.pyplot as plt
import networkx as nx

from pyverilog.vparser.parser import VerilogCodeParser
from pyverilog.dataflow.modulevisitor import ModuleVisitor
from pyverilog.dataflow.signalvisitor import SignalVisitor
from pyverilog.dataflow.bindvisitor import BindVisitor

def profileit(func):
    def wrapper(*args, **kwargs):
        datafn = func.__name__ + ".txt" 
        last_time = 0
        count = 0
        if os.path.exists(datafn):
            with open(datafn, 'r') as f: 
                line = f.readline().split(" ")
                count = int(line[0])
                last_time = float(line[1])
        pr = cProfile.Profile()
        retval = pr.runcall(func, *args, **kwargs)
        st = io.StringIO()
        ps = pstats.Stats(pr, stream=st).sort_stats('tottime')
        ps.print_stats()

        with open(datafn, 'w+') as f:
            new_time = float(st.getvalue().split('\n')[0].split(' ')[-2]) + last_time
            f.write(str(count+1) + " " + str(new_time))
        return retval
    wrapper.unwrapped = func
    return wrapper

# profiler for graph extraction 
def profilegraph(func):
    def wrapper(*args, **kwargs):
        datafn = func.__name__ + ".txt" 
        #disable stdout
        f_null = open(os.devnull, 'w')
        sys.stdout = f_null
        
        pr = cProfile.Profile()
        pr.enable()

        result_graph = func(*args, **kwargs)

        pr.disable()
        # re-enable stdout
        sys.stdout = sys.__stdout__

        hardware_name = result_graph.name
        node_num = len(result_graph.nodes())
        edge_num = len(result_graph.edges())

        st = io.StringIO()
        ps = pstats.Stats(pr, stream=st).sort_stats('tottime')
        ps.print_stats()

        with open(datafn, 'a') as f:
            time = float(st.getvalue().split('\n')[0].split(' ')[-2])
            f.write(str(hardware_name) + " " + str(node_num) + " " + str(edge_num) + " " + str(time) + "\n")
        return result_graph
    wrapper.unwrapped = func
    return wrapper

#TODO; is this used anywhere?
# def save_graph(nxgraph, file_name):
#     plt.figure(num=None, figsize=(60, 60), dpi=80)
#     plt.axis('off')
#     fig = plt.figure(1)

#     pos = nx.nx_pydot.graphviz_layout(nxgraph, prog="dot")
#     nx.draw_networkx_nodes(nxgraph, pos, with_labels=False)
#     nx.draw_networkx_edges(nxgraph, pos)
#     labels = {}    
#     for node in nxgraph.nodes(data=True):
#         labels[node[0]] = node[1]['label']
#     nx.draw_networkx_labels(nxgraph, pos, labels)
#     plt.savefig(file_name, bbox_inches="tight")
#     pylab.close()
#     del fig

def isInt(s):
    try:
        int(s)
        return True
    except ValueError:
        return False
#VerilogDataflowAnalyzer类继承自VerilogCodeParser类，主要功能是对Verilog代码进行数据流分析，
# 提取出模块信息、信号、实例、常量以及数据流中的术语和绑定关系

#总结：VerilogDataflowAnalyzer类通过解析Verilog代码，使用访问者模式（Visitor Pattern）遍历抽象语法树，
# 提取出模块、信号、实例和常量的信息，并进一步进行绑定操作，生成数据流中的术语和绑定关系。
# 这个类可以用于Verilog代码的数据流分析，支持自定义顶层模块名称、是否重新排序信号和是否进行绑定操作等选项。
class VerilogDataflowAnalyzer(VerilogCodeParser):
    #本例中 filelist = verilog_file = E:\PRO\Python\HT\hw2vec\assets\TJ-RTL-toy\TjFree\det_1011\topModule.v
    def __init__(self, filelist, topmodule='TOP', noreorder=False, nobind=False,
                 preprocess_include=None,
                 preprocess_define=None):
        self.topmodule = topmodule
        self.terms = {}         #存储解析得到的术语（变量/信号定义）
        self.binddict = {}      #存储信号绑定关系（信号名到节点的映射
        self.frametable = None  # 帧表（存储作用域/层次信息）
        #检查filelist是否为元组或列表类型，如果不是，则将其转换为一个只包含单个元素的列表。这是为了确保filelist总是以列表的形式传递给基类
        #print(f"files0={filelist}")
        files = filelist if isinstance(filelist, tuple) or isinstance(
            filelist, list) else [filelist]
        #本例中，至此处，files被转换为列表，首个元素即为自身...\topModule.v。
        #print(f"files1={files}")

        VerilogCodeParser.__init__(self, files,
                                   preprocess_include=preprocess_include,
                                   preprocess_define=preprocess_define)
#                                   preprocess_define=preprocess_define, debug=False)
        self.noreorder = noreorder
        self.nobind = nobind
    #流程：ast -> module_visitor -> signal_visitor -> bind_visitor
    def generate(self):
        #print("ast=self.parse()")
        ast = self.parse()  #解析Verilog代码生成抽象语法树（AST）。在这里可以相看AST的结构体内容!!!!!!!!!!!!!!系统函数，无需进入查看
        # pyverilog.vparser.parser.VerilogCodeParser.parse()
        #self继承了VerilogCodeParser类，其中包含.parse()函数，因此这里可以直接调用self.parse()

        module_visitor = ModuleVisitor()    #使用ModuleVisitor访问AST，获取模块名称和模块信息表。
        module_visitor.visit(ast)#在sat结构体中definitions的基础上，又提取了参数、常量、信号等作为结构体的一些对象。简单说，就是对从ast中提取了一些信息，便于后续使用。
        #print(f"module_visitor={module_visitor}")
        modulenames = module_visitor.get_modulenames()
        #print(modulenames)
        moduleinfotable = module_visitor.get_moduleinfotable()
        #print(f"moduleinfotable ={moduleinfotable}")
        #print("Ultilities.py:VerilogDataflowAnalyzer.generate:ast=self.parse()")

        #使用SignalVisitor根据模块信息表和顶层模块名称，开始访问并生成帧表（包含信号、实例等信息）。
        # 构造链式结构frame，为每个信号添加previous和next节点，便于后面Bind_visitor中构造信号的tree。
        signal_visitor = SignalVisitor(moduleinfotable, self.topmodule)
        #print(111)
        signal_visitor.start_visit()#生成signal_visitor.frames.dict[29],元素均为Frame也更新labels{}
        #print(222)
        frametable = signal_visitor.getFrameTable()
        #print(f"frametable.dict = {frametable.current}")
        #如果设置了nobind为True，则直接返回帧表；
        # 否则，使用BindVisitor进行绑定操作，生成数据流信息，并更新帧表、术语和绑定字典。
        if self.nobind:
            self.frametable = frametable
            return
        #根据frame中的信号链，构造每个信号的tree。后面用来遍历node和edge及其属性。
        bind_visitor = BindVisitor(moduleinfotable, self.topmodule, frametable,
                                   noreorder=self.noreorder)

        bind_visitor.start_visit()
        dataflow = bind_visitor.getDataflows()
        #print(f"dataflow.terms={dataflow.terms}")


        self.frametable = bind_visitor.getFrameTable()
        self.terms = dataflow.getTerms()#
        self.binddict = dataflow.getBinddict()

    def getFrameTable(self):
        return self.frametable

    # -------------------------------------------------------------------------
    def getInstances(self):
        if self.frametable is None:
            return ()
        return self.frametable.getAllInstances()

    def getSignals(self):
        if self.frametable is None:
            return ()
        return self.frametable.getAllSignals()

    def getConsts(self):
        if self.frametable is None:
            return ()
        return self.frametable.getAllConsts()

    def getTerms(self):
        return self.terms

    def getBinddict(self):
        return self.binddict