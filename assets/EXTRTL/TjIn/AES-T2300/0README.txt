1. This directory includes:

1.1 src
	---Codes for the AES algorithm, the test bench, and the Trojan

2.Trojan
Trojan Description
    The Trojan is triggered whenever two predefined rare signals (s2[89] and s5[121] of the aes_128 module) in the AES-128 block cipher are simultaneously high. Upon activation, the Trojan attacks encryption by flipping the least significant bit of the existing encrypted output.

Trojan Taxonomy
	Insertion phase: Design
	Abstraction level: Register Transfer
	Activation mechanism: Physical-Condition Based
	Effects: Change Functionality
	Physical characteristics: Functional
	
	木马程序
木马程序描述
在AES-128分组密码中，当两个预定义的罕见信号（aes_128模块的s2[89]和s5[121]）同时为高电平时，该木马程序即被触发。
一旦激活，木马程序会通过翻转现有加密输出结果的最低有效位来对加密过程发起攻击。

木马程序分类

插入阶段：设计阶段
抽象级别：寄存器传输级
激活机制：基于物理条件触发
影响：改变功能
物理特性：功能性
