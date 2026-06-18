"""
JPlag风格的Verilog代码相似度检测器（纯Python实现）
无需Java环境，直接对ALLRTL数据集进行改动分析
"""

import os
import re
import json
import pandas as pd
from pathlib import Path
from typing import Dict, List, Tuple
from collections import Counter

class VerilogTokenExtractor:
    """Verilog代码Token提取器（模拟JPlag的Verilog模块）"""
    
    # Token模式定义
    TOKEN_PATTERNS = {
        'MODULE_DECL': re.compile(r'\bmodule\s+(\w+)', re.IGNORECASE),
        'ENDMODULE': re.compile(r'\bendmodule\b', re.IGNORECASE),
        'PORT_INPUT': re.compile(r'\binput\b', re.IGNORECASE),
        'PORT_OUTPUT': re.compile(r'\boutput\b', re.IGNORECASE),
        'PORT_INOUT': re.compile(r'\binout\b', re.IGNORECASE),
        'DECL_WIRE': re.compile(r'\bwire\b', re.IGNORECASE),
        'DECL_REG': re.compile(r'\breg\b', re.IGNORECASE),
        'DECL_PARAM': re.compile(r'\bparameter\b', re.IGNORECASE),
        'DECL_INTEGER': re.compile(r'\binteger\b', re.IGNORECASE),
        'ASSIGN_CONT': re.compile(r'\bassign\b', re.IGNORECASE),
        'BLOCK_ALWAYS': re.compile(r'\balways\b', re.IGNORECASE),
        'BLOCK_INITIAL': re.compile(r'\binitial\b', re.IGNORECASE),
        'BLOCK_BEGIN': re.compile(r'\bbegin\b', re.IGNORECASE),
        'BLOCK_END': re.compile(r'\bend\b', re.IGNORECASE),
        'COND_IF': re.compile(r'\bif\b', re.IGNORECASE),
        'COND_ELSE': re.compile(r'\belse\b', re.IGNORECASE),
        'COND_CASE': re.compile(r'\bcase\b', re.IGNORECASE),
        'ENDCASE': re.compile(r'\bendcase\b', re.IGNORECASE),
        'COND_DEFAULT': re.compile(r'\bdefault\b', re.IGNORECASE),
        'LOOP_FOR': re.compile(r'\bfor\b', re.IGNORECASE),
        'LOOP_WHILE': re.compile(r'\bwhile\b', re.IGNORECASE),
        'INST_MODULE': re.compile(r'^\s*(\w+)\s+#?\s*\(', re.MULTILINE),
    }
    
    def extract_tokens(self, file_path: str) -> List[str]:
        """
        从Verilog文件中提取Token序列
        
        Args:
            file_path: Verilog文件路径
            
        Returns:
            Token列表
        """
        tokens = []
        
        try:
            with open(file_path, 'r', encoding='utf-8', errors='ignore') as f:
                lines = f.readlines()
            
            for line_num, line in enumerate(lines, 1):
                # 跳过注释和空行
                stripped = line.strip()
                if not stripped or stripped.startswith('//') or stripped.startswith('/*'):
                    continue
                
                # 提取Token
                for token_type, pattern in self.TOKEN_PATTERNS.items():
                    if pattern.search(line):
                        tokens.append(token_type)
        
        except Exception as e:
            print(f"警告: 读取文件 {file_path} 失败: {e}")
        
        return tokens
    
    def get_token_stats(self, tokens: List[str]) -> Dict:
        """获取Token统计信息"""
        counter = Counter(tokens)
        return {
            'total_tokens': len(tokens),
            'unique_tokens': len(counter),
            'token_distribution': dict(counter)
        }


class JPlagSimilarityCalculator:
    """JPlag相似度计算器（Greedy String Tiling简化版）"""
    
    def __init__(self, min_token_match: int = 6):
        """
        Args:
            min_token_match: 最小匹配Token数
        """
        self.min_token_match = min_token_match
    
    def calculate_similarity(self, tokens1: List[str], tokens2: List[str]) -> float:
        """
        计算两个Token序列的相似度
        
        Args:
            tokens1: 第一个文件的Token序列
            tokens2: 第二个文件的Token序列
            
        Returns:
            相似度分数 [0.0, 1.0]
        """
        if not tokens1 or not tokens2:
            return 0.0
        
        # 简化版Greedy String Tiling
        matched_count = self._greedy_matching(tokens1, tokens2)
        
        # 相似度 = 匹配Token数 / 较长序列的Token数
        max_len = max(len(tokens1), len(tokens2))
        similarity = matched_count / max_len if max_len > 0 else 0.0
        
        return min(similarity, 1.0)
    
    def _greedy_matching(self, seq1: List[str], seq2: List[str]) -> int:
        """贪心匹配算法"""
        matched = 0
        marked1 = set()
        marked2 = set()
        
        # 寻找最长匹配
        while True:
            best_match = self._find_longest_match(
                seq1, seq2, marked1, marked2
            )
            
            if best_match is None or best_match[0] < self.min_token_match:
                break
            
            length, start1, start2 = best_match
            matched += length
            
            # 标记已匹配的位置
            for i in range(length):
                marked1.add(start1 + i)
                marked2.add(start2 + i)
        
        return matched
    
    def _find_longest_match(self, seq1, seq2, marked1, marked2):
        """寻找最长未标记匹配序列"""
        best_length = 0
        best_start1 = -1
        best_start2 = -1
        
        # 简化的最长匹配查找
        for i in range(len(seq1)):
            if i in marked1:
                continue
            
            for j in range(len(seq2)):
                if j in marked2:
                    continue
                
                if seq1[i] == seq2[j]:
                    # 计算匹配长度
                    length = 0
                    while (i + length < len(seq1) and 
                           j + length < len(seq2) and
                           seq1[i + length] == seq2[j + length] and
                           (i + length) not in marked1 and
                           (j + length) not in marked2):
                        length += 1
                    
                    if length > best_length:
                        best_length = length
                        best_start1 = i
                        best_start2 = j
        
        if best_length >= self.min_token_match:
            return (best_length, best_start1, best_start2)
        return None


class ALLRTLAnalyzer:
    """ALLRTL数据集分析器"""
    
    def __init__(self, dataset_dir: str):
        """
        Args:
            dataset_dir: ALLRTL数据集根目录
        """
        self.dataset_dir = Path(dataset_dir)
        self.tjfree_dir = self.dataset_dir / "TjFree"
        self.tjin_dir = self.dataset_dir / "TjIn"
        
        self.token_extractor = VerilogTokenExtractor()
        self.similarity_calculator = JPlagSimilarityCalculator(min_token_match=6)
        
        self.results = []
    
    def find_matching_pairs(self) -> List[Tuple[str, str, str]]:
        """
        查找TjFree和TjIn中匹配的电路对
        
        Returns:
            列表，每个元素为 (circuit_name, free_path, in_path)
        """
        pairs = []
        
        # 遍历TjIn中的所有电路
        for tjin_circuit in self.tjin_dir.iterdir():
            if not tjin_circuit.is_dir():
                continue
            
            circuit_name = tjin_circuit.name
            tjin_topmodule = tjin_circuit / "topModule.v"
            
            if not tjin_topmodule.exists():
                continue
            
            # 在TjFree中查找对应的基准电路
            # 提取基础电路名称（去掉-Txxx后缀）
            base_name = circuit_name.split('-')[0]
            tjfree_circuit_dir = self.tjfree_dir / base_name
            tjfree_topmodule = tjfree_circuit_dir / "topModule.v"
            
            if tjfree_topmodule.exists():
                pairs.append((
                    circuit_name,
                    str(tjfree_topmodule),
                    str(tjin_topmodule)
                ))
            else:
                print(f"警告: 未找到 {base_name} 的基准文件")
        
        return pairs
    
    def analyze_pair(self, circuit_name: str, free_path: str, in_path: str) -> Dict:
        """
        分析一对电路文件
        
        Args:
            circuit_name: 电路名称
            free_path: 基准文件路径
            in_path: 变体文件路径
            
        Returns:
            分析结果字典
        """
        print(f"分析: {circuit_name}")
        
        # 提取Token
        tokens_free = self.token_extractor.extract_tokens(free_path)
        tokens_in = self.token_extractor.extract_tokens(in_path)
        
        # 计算相似度
        similarity = self.similarity_calculator.calculate_similarity(
            tokens_free, tokens_in
        )
        
        # 获取统计信息
        stats_free = self.token_extractor.get_token_stats(tokens_free)
        stats_in = self.token_extractor.get_token_stats(tokens_in)
        
        # Token差异分析
        tokens_set_free = set(tokens_free)
        tokens_set_in = set(tokens_in)
        added_tokens = tokens_set_in - tokens_set_free
        removed_tokens = tokens_set_free - tokens_set_in
        
        # 文件大小
        size_free = os.path.getsize(free_path)
        size_in = os.path.getsize(in_path)
        
        result = {
            'circuit_name': circuit_name,
            'similarity': round(similarity, 4),
            'free_path': free_path,
            'in_path': in_path,
            'free_stats': stats_free,
            'in_stats': stats_in,
            'added_tokens': list(added_tokens),
            'removed_tokens': list(removed_tokens),
            'size_change': size_in - size_free,
            'size_change_percent': round((size_in - size_free) / size_free * 100, 2) if size_free > 0 else 0
        }
        
        return result
    
    def run_full_analysis(self, output_dir: str = None) -> pd.DataFrame:
        """
        运行完整的数据集分析
        
        Args:
            output_dir: 输出目录
            
        Returns:
            结果DataFrame
        """
        if output_dir is None:
            output_dir = self.dataset_dir / "jplag_analysis_results"
        else:
            output_dir = Path(output_dir)
        
        output_dir.mkdir(parents=True, exist_ok=True)
        
        print("=" * 60)
        print("JPlag风格 Verilog代码改动分析")
        print("=" * 60)
        print(f"数据集: {self.dataset_dir}")
        print(f"基准目录: {self.tjfree_dir}")
        print(f"变体目录: {self.tjin_dir}")
        print()
        
        # 查找匹配对
        pairs = self.find_matching_pairs()
        print(f"找到 {len(pairs)} 对匹配的电路\n")
        
        # 分析每对电路
        results = []
        for circuit_name, free_path, in_path in pairs:
            try:
                result = self.analyze_pair(circuit_name, free_path, in_path)
                results.append(result)
            except Exception as e:
                print(f"错误: 分析 {circuit_name} 失败 - {e}")
        
        # 转换为DataFrame
        df_results = pd.DataFrame(results)
        
        # 保存结果
        self._save_results(df_results, output_dir)
        
        # 打印汇总统计
        self._print_summary(df_results)
        
        return df_results
    
    def _save_results(self, df: pd.DataFrame, output_dir: Path):
        """保存分析结果"""
        # CSV文件
        csv_path = output_dir / "similarity_results.csv"
        # 展平嵌套字典
        df_flat = df.copy()
        df_flat['free_total_tokens'] = df['free_stats'].apply(lambda x: x['total_tokens'])
        df_flat['in_total_tokens'] = df['in_stats'].apply(lambda x: x['total_tokens'])
        
        df_flat[['circuit_name', 'similarity', 'size_change_percent', 
            'free_total_tokens', 'in_total_tokens']].to_csv(
                csv_path, index=False, encoding='utf-8-sig'
            )
        print(f"\n结果已保存: {csv_path}")
        
        # JSON详细结果
        json_path = output_dir / "detailed_results.json"
        df.to_json(json_path, orient='records', indent=2, force_ascii=False)
        print(f"详细结果: {json_path}")
        
        # 相似度矩阵
        matrix_data = {}
        for _, row in df.iterrows():
            matrix_data[row['circuit_name']] = {
                'similarity': row['similarity'],
                'tokens_free': row['free_stats']['total_tokens'],
                'tokens_in': row['in_stats']['total_tokens'],
                'token_diff': row['in_stats']['total_tokens'] - row['free_stats']['total_tokens']
            }
        
        matrix_path = output_dir / "similarity_matrix.json"
        with open(matrix_path, 'w', encoding='utf-8') as f:
            json.dump(matrix_data, f, indent=2, ensure_ascii=False)
        print(f"相似度矩阵: {matrix_path}")
    
    def _print_summary(self, df: pd.DataFrame):
        """打印汇总统计"""
        print("\n" + "=" * 60)
        print("分析结果汇总")
        print("=" * 60)
        
        if df.empty:
            print("无结果")
            return
        
        print(f"分析电路对数: {len(df)}")
        print(f"平均相似度: {df['similarity'].mean():.4f}")
        print(f"最高相似度: {df['similarity'].max():.4f}")
        print(f"最低相似度: {df['similarity'].min():.4f}")
        print(f"相似度中位数: {df['similarity'].median():.4f}")
        print()
        
        # 按相似度分组
        high_sim = df[df['similarity'] >= 0.9]
        medium_sim = df[(df['similarity'] >= 0.7) & (df['similarity'] < 0.9)]
        low_sim = df[df['similarity'] < 0.7]
        
        print(f"高相似度 (>=0.9): {len(high_sim)} 个电路")
        print(f"中相似度 (0.7-0.9): {len(medium_sim)} 个电路")
        print(f"低相似度 (<0.7): {len(low_sim)} 个电路")
        print()
        
        # 显示最低相似度的5个电路
        print("改动最大的5个电路（相似度最低）:")
        top5_changes = df.nsmallest(5, 'similarity')
        for _, row in top5_changes.iterrows():
            print(f"  {row['circuit_name']}: {row['similarity']:.4f} "
                  f"(大小变化: {row['size_change_percent']:+.2f}%)")
        
        # 显示最高相似度的5个电路
        print("\n改动最小的5个电路（相似度最高）:")
        top5_similar = df.nlargest(5, 'similarity')
        for _, row in top5_similar.iterrows():
            print(f"  {row['circuit_name']}: {row['similarity']:.4f} "
                  f"(大小变化: {row['size_change_percent']:+.2f}%)")


def main():
    """主函数"""
    # 设置数据集路径
    dataset_dir = r"e:\PRO\python\HT\hw4vec\assets\ALLRTL"
    
    # 创建分析器
    analyzer = ALLRTLAnalyzer(dataset_dir)
    
    # 运行分析
    results = analyzer.run_full_analysis(
        output_dir=r"e:\PRO\python\HT\hw4vec\examples\jplag_analysis_results"
    )
    
    print("\n分析完成！")
    print("请查看 examples/jplag_analysis_results 目录中的结果文件")
    
    return results


if __name__ == "__main__":
    main()
