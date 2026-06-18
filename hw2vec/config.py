#!/usr/bin/env python
#title           :config.py
#description     :This file includes the configs of hw2vec.
#author          :Qingrong Zhou
#date            :2021/03/05
#version         :0.2
#notes           :
#python_version  :3.6
#==============================================================================
import yaml, os, sys
sys.path.append(os.path.dirname(sys.path[0]))
from pathlib import Path
from argparse import ArgumentParser

class Config:
    def __init__(self, args):
        #print(f"args = {args}")
        ap = ArgumentParser(description='The parameters for general arguments.')
        #添加多个命令行参数
        ap.add_argument('--yaml_path', type=str, default="./example_gnn4tj.yaml", help="The path of yaml config file.")
        ap.add_argument('--raw_dataset_path', type=str, default="../../assets/data/TJ-RTL-toy/", help="The path to raw dataset for parsing.")
        ap.add_argument('--data_pkl_path', type=str, default="./DFG-TJ-RTL.pkl", help="The path to the pickle file storing the graph dataset.")
        ap.add_argument('--model_path', type=str, default="", help="Pretrained IP model ../assets/pretrained_ip_model/, Pretrained TJ model ../assets/pretrained_tj_model/")
        ap.add_argument('--graph_type', type=str, default="DFG", help="The graph type to retrieve for inspection or training/evaluating.")
        ap.add_argument('--device',    type=str, default="cpu", help="The device for training/evaluating.")
        #解析传入的args列表，并返回一个包含所有解析后的参数值的对象args_parsed
        #print(f"args={ap}")
        args_parsed = ap.parse_args(args)
        #print(f"args_parsed= {args_parsed}")
        #vars(args_parsed)返回一个字典，包含了args_parsed命名空间中的所有属性。这个循环遍历这个字典的键，即参数的名称。
        for arg_name in vars(args_parsed):
            #getattr(args_parsed, arg_name)用于获取args_parsed对象中名为arg_name的属性的值。
            # 然后，这个值被赋值给当前实例（self）的字典（__dict__）中对应键的值。
            # 这样，命令行参数就被存储为了实例的属性，可以通过self.arg_name的方式访问。
            #print(f"arg_name = {arg_name} -> {getattr(args_parsed, arg_name)}")
            self.__dict__[arg_name] = getattr(args_parsed, arg_name)
        #print(self.__dict__) -> {'yaml_path': './example_gnn4tj.yaml', 'raw_dataset_path': '../../assets/data/TJ-RTL-toy/', 'data_pkl_path': './DFG-TJ-RTL.pkl', 'model_path': '', 'graph_type': 'DFG', 'device': 'cpu'}

        #加载YAML配置文件，读取其中的配置参数，添加到字典self._dict__。
        #将yaml_path（YAML配置文件的路径）转换为绝对路径。
        self.yaml_path = Path(self.yaml_path).resolve()
        #print(f"yaml_path = {self.yaml_path}") -> yaml_path = E:\PRO\Python\HT\hw2vec\examples\example_gnn4tj.yaml
        with open(self.yaml_path, 'r') as f:
            yaml_configs = yaml.safe_load(f)
        #print(f"yaml_configs = {yaml_configs}")
        #-> yaml_path文件中的配置参数
        for arg_name, arg_value in yaml_configs.items():
            #print(f"arg_name= {arg_name}, arg_value = {arg_value}")
            self.__dict__[arg_name] = arg_value
        #print(self.__dict__)

        self.raw_dataset_path = Path(self.raw_dataset_path).resolve() 
        self.data_pkl_path = Path(self.data_pkl_path).resolve()
        self.model_path_obj = Path(self.model_path).resolve()
        #print(self.raw_dataset_path) -> E:\PRO\Python\HT\assets\data\TJ-RTL-toy
        #print(self.data_pkl_path)  -> E:\PRO\Python\HT\hw2vec\examples\DFG-TJ-RTL.pkl
        #print(self.model_path_obj) -> E:\PRO\Python\HT\hw2vec\examples