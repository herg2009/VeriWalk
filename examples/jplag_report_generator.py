"""
JPlag Verilog相似度分析报告生成器
生成可视化图表和详细分析报告
"""

import pandas as pd
import matplotlib.pyplot as plt
import matplotlib
import numpy as np
import json
from pathlib import Path

# 设置中文字体
matplotlib.rcParams['font.sans-serif'] = ['SimHei', 'Microsoft YaHei', 'Arial Unicode MS']
matplotlib.rcParams['axes.unicode_minus'] = False

class JPlagReportGenerator:
    """JPlag分析报告生成器"""
    
    def __init__(self, results_dir: str):
        self.results_dir = Path(results_dir)
        self.csv_path = self.results_dir / "similarity_results.csv"
        self.json_path = self.results_dir / "detailed_results.json"
        
        # 加载数据
        self.df = pd.read_csv(self.csv_path)
        with open(self.json_path, 'r', encoding='utf-8') as f:
            self.detailed_data = json.load(f)
    
    def generate_all_plots(self, output_dir: str = None):
        """生成所有图表"""
        if output_dir is None:
            output_dir = self.results_dir
        else:
            output_dir = Path(output_dir)
        
        output_dir.mkdir(parents=True, exist_ok=True)
        
        print("生成图表中...")
        
        # 1. 相似度分布直方图
        self.plot_similarity_histogram(output_dir / "similarity_distribution.png")
        
        # 2. 相似度散点图（按电路类型）
        self.plot_similarity_scatter(output_dir / "similarity_by_circuit.png")
        
        # 3. 文件大小变化 vs 相似度
        self.plot_size_vs_similarity(output_dir / "size_vs_similarity.png")
        
        # 4. Token数量对比
        self.plot_token_comparison(output_dir / "token_comparison.png")
        
        # 5. 各电路类型统计
        self.plot_circuit_type_stats(output_dir / "circuit_type_stats.png")
        
        # 6. Top10改动最大电路
        self.plot_top_changes(output_dir / "top10_changes.png")
        
        print(f"\n所有图表已保存到: {output_dir}")
    
    def plot_similarity_histogram(self, output_path: Path):
        """相似度分布直方图"""
        fig, ax = plt.subplots(figsize=(10, 6))
        
        ax.hist(self.df['similarity'], bins=15, color='steelblue', edgecolor='black', alpha=0.7)
        ax.axvline(self.df['similarity'].mean(), color='red', linestyle='--', 
                   linewidth=2, label=f"平均值: {self.df['similarity'].mean():.4f}")
        ax.axvline(self.df['similarity'].median(), color='green', linestyle='--',
                   linewidth=2, label=f"中位数: {self.df['similarity'].median():.4f}")
        
        ax.set_xlabel('JPlag相似度分数', fontsize=12, fontweight='bold')
        ax.set_ylabel('电路数量', fontsize=12, fontweight='bold')
        ax.set_title('ALLRTL数据集 JPlag相似度分布', fontsize=14, fontweight='bold')
        ax.legend(fontsize=11)
        ax.grid(True, alpha=0.3)
        
        plt.tight_layout()
        plt.savefig(output_path, dpi=300, bbox_inches='tight')
        plt.close()
        print(f"✓ 相似度分布图: {output_path.name}")
    
    def plot_similarity_scatter(self, output_path: Path):
        """按电路类型的相似度散点图"""
        fig, ax = plt.subplots(figsize=(12, 6))
        
        # 分类
        aes_data = self.df[self.df['circuit_name'].str.startswith('AES')]
        pic_data = self.df[self.df['circuit_name'].str.startswith('PIC')]
        rs232_data = self.df[self.df['circuit_name'].str.startswith('RS232')]
        
        ax.scatter(range(len(aes_data)), aes_data['similarity'], 
                  c='red', alpha=0.6, s=100, label='AES', marker='o')
        ax.scatter(range(len(pic_data)), pic_data['similarity'],
                  c='blue', alpha=0.6, s=100, label='PIC16F84', marker='s')
        ax.scatter(range(len(rs232_data)), rs232_data['similarity'],
                  c='green', alpha=0.6, s=100, label='RS232', marker='^')
        
        ax.set_xlabel('电路样本', fontsize=12, fontweight='bold')
        ax.set_ylabel('JPlag相似度分数', fontsize=12, fontweight='bold')
        ax.set_title('不同电路类型的JPlag相似度对比', fontsize=14, fontweight='bold')
        ax.legend(fontsize=11)
        ax.grid(True, alpha=0.3)
        ax.set_ylim(0.4, 1.0)
        
        plt.tight_layout()
        plt.savefig(output_path, dpi=300, bbox_inches='tight')
        plt.close()
        print(f"✓ 电路类型对比图: {output_path.name}")
    
    def plot_size_vs_similarity(self, output_path: Path):
        """文件大小变化与相似度关系"""
        fig, ax = plt.subplots(figsize=(10, 6))
        
        scatter = ax.scatter(self.df['size_change_percent'], self.df['similarity'],
                           c=self.df['similarity'], cmap='RdYlGn_r', 
                           s=100, alpha=0.7, edgecolors='black', linewidth=0.5)
        
        # 添加趋势线
        z = np.polyfit(self.df['size_change_percent'], self.df['similarity'], 1)
        p = np.poly1d(z)
        x_line = np.linspace(self.df['size_change_percent'].min(), 
                            self.df['size_change_percent'].max(), 100)
        ax.plot(x_line, p(x_line), "r--", alpha=0.8, linewidth=2, 
               label=f'趋势线 (斜率: {z[0]:.4f})')
        
        ax.set_xlabel('文件大小变化 (%)', fontsize=12, fontweight='bold')
        ax.set_ylabel('JPlag相似度分数', fontsize=12, fontweight='bold')
        ax.set_title('代码大小变化与相似度的关系', fontsize=14, fontweight='bold')
        ax.legend(fontsize=11)
        ax.grid(True, alpha=0.3)
        
        plt.colorbar(scatter, ax=ax, label='相似度')
        plt.tight_layout()
        plt.savefig(output_path, dpi=300, bbox_inches='tight')
        plt.close()
        print(f"✓ 大小-相似度关系图: {output_path.name}")
    
    def plot_token_comparison(self, output_path: Path):
        """Token数量对比条形图"""
        fig, ax = plt.subplots(figsize=(14, 8))
        
        # 选择前20个电路
        df_sorted = self.df.nlargest(20, 'similarity')
        
        x = range(len(df_sorted))
        width = 0.35
        
        bars1 = ax.bar([i - width/2 for i in x], df_sorted['free_total_tokens'],
                      width, label='基准电路', alpha=0.7, color='steelblue')
        bars2 = ax.bar([i + width/2 for i in x], df_sorted['in_total_tokens'],
                      width, label='变体电路', alpha=0.7, color='coral')
        
        ax.set_xlabel('电路名称', fontsize=12, fontweight='bold')
        ax.set_ylabel('Token数量', fontsize=12, fontweight='bold')
        ax.set_title('基准电路与变体电路Token数量对比（Top20）', fontsize=14, fontweight='bold')
        ax.set_xticks(x)
        ax.set_xticklabels(df_sorted['circuit_name'], rotation=45, ha='right', fontsize=8)
        ax.legend(fontsize=11)
        ax.grid(True, alpha=0.3, axis='y')
        
        plt.tight_layout()
        plt.savefig(output_path, dpi=300, bbox_inches='tight')
        plt.close()
        print(f"✓ Token对比图: {output_path.name}")
    
    def plot_circuit_type_stats(self, output_path: Path):
        """各电路类型统计对比"""
        fig, axes = plt.subplots(1, 3, figsize=(15, 5))
        
        # 按类型分组
        groups = {
            'AES': self.df[self.df['circuit_name'].str.startswith('AES')],
            'PIC16F84': self.df[self.df['circuit_name'].str.startswith('PIC')],
            'RS232': self.df[self.df['circuit_name'].str.startswith('RS232')]
        }
        
        colors = ['#FF6B6B', '#4ECDC4', '#45B7D1']
        
        for idx, (name, group) in enumerate(groups.items()):
            ax = axes[idx]
            
            stats = [
                group['similarity'].mean(),
                group['size_change_percent'].mean(),
                group['in_total_tokens'].mean() - group['free_total_tokens'].mean()
            ]
            
            bars = ax.bar(['平均相似度', '平均大小变化(%)', '平均Token增加'],
                         stats, color=colors[idx], alpha=0.7, edgecolor='black')
            
            ax.set_title(name, fontsize=13, fontweight='bold')
            ax.grid(True, alpha=0.3, axis='y')
            
            # 添加数值标签
            for bar, value in zip(bars, stats):
                ax.text(bar.get_x() + bar.get_width()/2., bar.get_height(),
                       f'{value:.2f}', ha='center', va='bottom', fontsize=9, fontweight='bold')
        
        plt.suptitle('不同电路类型统计特征对比', fontsize=15, fontweight='bold', y=1.02)
        plt.tight_layout()
        plt.savefig(output_path, dpi=300, bbox_inches='tight')
        plt.close()
        print(f"✓ 电路类型统计图: {output_path.name}")
    
    def plot_top_changes(self, output_path: Path):
        """Top10改动最大电路"""
        fig, ax = plt.subplots(figsize=(10, 6))
        
        top10 = self.df.nsmallest(10, 'similarity')
        
        colors = plt.cm.RdYlGn_r(top10['similarity'])
        bars = ax.barh(range(len(top10)), top10['similarity'], color=colors, 
                      edgecolor='black', alpha=0.8)
        
        ax.set_yticks(range(len(top10)))
        ax.set_yticklabels(top10['circuit_name'], fontsize=10)
        ax.set_xlabel('JPlag相似度分数', fontsize=12, fontweight='bold')
        ax.set_title('改动最大的10个电路（相似度最低）', fontsize=14, fontweight='bold')
        ax.set_xlim(0.4, 0.7)
        ax.grid(True, alpha=0.3, axis='x')
        
        # 添加数值标签
        for i, (bar, sim) in enumerate(zip(bars, top10['similarity'])):
            ax.text(bar.get_width() + 0.005, bar.get_y() + bar.get_height()/2.,
                   f'{sim:.4f}', va='center', fontsize=10, fontweight='bold')
        
        plt.tight_layout()
        plt.savefig(output_path, dpi=300, bbox_inches='tight')
        plt.close()
        print(f"✓ Top10改动图: {output_path.name}")
    
    def generate_text_report(self, output_path: Path):
        """生成文本分析报告"""
        with open(output_path, 'w', encoding='utf-8') as f:
            f.write("=" * 80 + "\n")
            f.write("JPlag Verilog代码相似度分析报告\n")
            f.write("=" * 80 + "\n\n")
            
            f.write("1. 数据集概述\n")
            f.write("-" * 80 + "\n")
            f.write(f"数据集: ALLRTL\n")
            f.write(f"基准电路数: {self.df['circuit_name'].nunique()}\n")
            f.write(f"分析的电路对: {len(self.df)}\n\n")
            
            f.write("2. 整体统计\n")
            f.write("-" * 80 + "\n")
            f.write(f"平均相似度: {self.df['similarity'].mean():.4f}\n")
            f.write(f"中位数相似度: {self.df['similarity'].median():.4f}\n")
            f.write(f"最高相似度: {self.df['similarity'].max():.4f}\n")
            f.write(f"最低相似度: {self.df['similarity'].min():.4f}\n")
            f.write(f"标准差: {self.df['similarity'].std():.4f}\n\n")
            
            f.write("3. 相似度分布\n")
            f.write("-" * 80 + "\n")
            high = len(self.df[self.df['similarity'] >= 0.9])
            medium = len(self.df[(self.df['similarity'] >= 0.7) & (self.df['similarity'] < 0.9)])
            low = len(self.df[self.df['similarity'] < 0.7])
            f.write(f"高相似度 (>=0.9): {high} 个 ({high/len(self.df)*100:.1f}%)\n")
            f.write(f"中相似度 (0.7-0.9): {medium} 个 ({medium/len(self.df)*100:.1f}%)\n")
            f.write(f"低相似度 (<0.7): {low} 个 ({low/len(self.df)*100:.1f}%)\n\n")
            
            f.write("4. 按电路类型统计\n")
            f.write("-" * 80 + "\n")
            for prefix, name in [('AES', 'AES'), ('PIC', 'PIC16F84'), ('RS232', 'RS232')]:
                group = self.df[self.df['circuit_name'].str.startswith(prefix)]
                f.write(f"\n{name}:\n")
                f.write(f"  电路数: {len(group)}\n")
                f.write(f"  平均相似度: {group['similarity'].mean():.4f}\n")
                f.write(f"  平均大小变化: {group['size_change_percent'].mean():.2f}%\n")
            
            f.write("\n\n5. 改动最大的10个电路\n")
            f.write("-" * 80 + "\n")
            top10 = self.df.nsmallest(10, 'similarity')
            for i, (_, row) in enumerate(top10.iterrows(), 1):
                f.write(f"{i:2d}. {row['circuit_name']:20s} "
                       f"相似度: {row['similarity']:.4f}  "
                       f"大小变化: {row['size_change_percent']:+.2f}%\n")
            
            f.write("\n\n6. 改动最小的10个电路\n")
            f.write("-" * 80 + "\n")
            top10_sim = self.df.nlargest(10, 'similarity')
            for i, (_, row) in enumerate(top10_sim.iterrows(), 1):
                f.write(f"{i:2d}. {row['circuit_name']:20s} "
                       f"相似度: {row['similarity']:.4f}  "
                       f"大小变化: {row['size_change_percent']:+.2f}%\n")
            
            f.write("\n\n" + "=" * 80 + "\n")
            f.write("报告生成完成\n")
            f.write("=" * 80 + "\n")
        
        print(f"✓ 文本报告: {output_path.name}")


def main():
    """主函数"""
    results_dir = r"e:\PRO\python\HT\hw4vec\examples\jplag_analysis_results"
    
    # 生成报告
    generator = JPlagReportGenerator(results_dir)
    
    # 生成所有图表
    generator.generate_all_plots()
    
    # 生成文本报告
    generator.generate_text_report(Path(results_dir) / "analysis_report.txt")
    
    print("\n✅ 所有报告和图表生成完成！")
    print(f"输出目录: {results_dir}")


if __name__ == "__main__":
    main()
