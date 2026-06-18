"""
JPlag Verilog 相似度检测脚本
用于论文中的定量对比实验
"""

import os
import subprocess
import json
from pathlib import Path
import pandas as pd
from typing import Dict, List, Tuple

class JPlagVerilogDetector:
    """JPlag Verilog代码相似度检测器"""
    
    def __init__(self, jplag_jar_path: str = None):
        """
        初始化检测器
        
        Args:
            jplag_jar_path: JPlag JAR文件路径
        """
        if jplag_jar_path is None:
            # 默认路径
            jplag_jar_path = os.path.join(
                os.path.dirname(__file__), 
                "JPlag", "cli", "target", 
                "jplag-6.0.0-SNAPSHOT-jar-with-dependencies.jar"
            )
        
        self.jplag_jar = jplag_jar_path
        self.java_cmd = "java"
        
    def run_comparison(self, 
                      submission_dir: str,
                      output_dir: str = None,
                      min_similarity: float = 0.0,
                      min_tokens: int = 8,
                      export_csv: bool = True) -> Dict:
        """
        运行JPlag进行Verilog代码比对
        
        Args:
            submission_dir: 包含Verilog文件的目录
            output_dir: 输出目录
            min_similarity: 最小相似度阈值 [0.0-1.0]
            min_tokens: 最小token匹配数
            export_csv: 是否导出CSV结果
            
        Returns:
            检测结果字典
        """
        if output_dir is None:
            output_dir = os.path.join(submission_dir, "jplag_results")
        
        os.makedirs(output_dir, exist_ok=True)
        
        # 构建命令
        cmd = [
            self.java_cmd,
            "-jar", self.jplag_jar,
            "-l", "verilog",
            "-m", str(min_similarity),
            "-t", str(min_tokens),
            "-r", os.path.join(output_dir, "results"),
        ]
        
        if export_csv:
            cmd.append("--csv-export")
        
        cmd.append(submission_dir)
        
        print(f"运行JPlag命令: {' '.join(cmd)}")
        
        try:
            # 执行JPlag
            result = subprocess.run(
                cmd,
                capture_output=True,
                text=True,
                timeout=300  # 5分钟超时
            )
            
            if result.returncode != 0:
                print(f"JPlag执行错误: {result.stderr}")
                return {"error": result.stderr}
            
            # 解析结果
            output = {
                "stdout": result.stdout,
                "return_code": result.returncode,
                "output_dir": output_dir,
            }
            
            # 读取CSV结果（如果存在）
            csv_path = os.path.join(output_dir, "results.csv")
            if os.path.exists(csv_path):
                df = pd.read_csv(csv_path)
                output["similarity_matrix"] = df
                output["pairwise_scores"] = self._parse_csv(df)
            
            return output
            
        except subprocess.TimeoutExpired:
            return {"error": "JPlag执行超时"}
        except Exception as e:
            return {"error": str(e)}
    
    def _parse_csv(self, df: pd.DataFrame) -> List[Dict]:
        """解析CSV结果为成对相似度列表"""
        pairs = []
        for i in range(len(df)):
            for j in range(i+1, len(df)):
                pairs.append({
                    "file1": df.columns[i],
                    "file2": df.columns[j],
                    "similarity": df.iloc[i, j]
                })
        return sorted(pairs, key=lambda x: x["similarity"], reverse=True)
    
    def compare_with_hw2vec(self,
                           verilog_dir: str,
                           hw2vec_results: Dict,
                           output_file: str = "comparison_results.json") -> Dict:
        """
        将JPlag结果与HW2VEC结果进行对比
        
        Args:
            verilog_dir: Verilog文件目录
            hw2vec_results: HW2VEC的检测结果
            output_file: 对比结果输出文件
            
        Returns:
            对比分析结果
        """
        # 运行JPlag
        jplag_output = self.run_comparison(verilog_dir)
        
        if "error" in jplag_output:
            return {"error": f"JPlag执行失败: {jplag_output['error']}"}
        
        # 对比分析
        comparison = {
            "jplag_results": jplag_output.get("pairwise_scores", []),
            "hw2vec_results": hw2vec_results,
            "analysis": self._analyze_correlation(
                jplag_output.get("pairwise_scores", []),
                hw2vec_results
            )
        }
        
        # 保存结果
        with open(output_file, 'w', encoding='utf-8') as f:
            json.dump(comparison, f, indent=2, ensure_ascii=False)
        
        print(f"对比结果已保存到: {output_file}")
        return comparison
    
    def _analyze_correlation(self, 
                            jplag_pairs: List[Dict],
                            hw2vec_results: Dict) -> Dict:
        """分析JPlag和HW2VEC结果的相关性"""
        # 这里可以实现更复杂的相关性分析
        # 例如：计算Spearman相关系数、绘制散点图等
        
        analysis = {
            "jplag_pair_count": len(jplag_pairs),
            "hw2vec_pair_count": len(hw2vec_results.get("pairs", [])),
            "note": "需要实现相关性计算逻辑"
        }
        
        return analysis


def example_usage():
    """使用示例"""
    # 初始化检测器
    detector = JPlagVerilogDetector()
    
    # 示例1: 直接运行JPlag
    result = detector.run_comparison(
        submission_dir="e:/PRO/python/HT/hw4vec/assets/test/TjFree",
        output_dir="e:/PRO/python/HT/hw4vec/examples/jplag_results",
        min_similarity=0.3,
        min_tokens=6
    )
    
    if "error" not in result:
        print("JPlag运行成功！")
        print(f"输出目录: {result['output_dir']}")
        
        # 显示相似度矩阵
        if "similarity_matrix" in result:
            print("\n相似度矩阵:")
            print(result["similarity_matrix"])
    
    # 示例2: 与HW2VEC结果对比
    # hw2vec_results = {...}  # 从HW2VEC获取的结果
    # comparison = detector.compare_with_hw2vec(
    #     verilog_dir="path/to/verilog",
    #     hw2vec_results=hw2vec_results,
    #     output_file="comparison.json"
    # )


if __name__ == "__main__":
    example_usage()
