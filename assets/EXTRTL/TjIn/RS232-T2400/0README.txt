1. This directory includes:

1.1 src
	---Codes for the micro-UART core, the test bench, and the Trojan

2.Trojan
Trojan Description
    The Trojan trigger is dependent on a rare branch within the receiver part of the micro-UART core. The Trojan is activated after the predefined branch (line 115 in the u_rec module) is taken three times and forces the rec_readyH output signal to be '0'.

Trojan Taxonomy
	Insertion phase: Design
	Abstraction level: Register-transfer level (RTL)
	Activation mechanism: Physical-condition-based
	Effects: Denial of service
	Physical characteristics: Functional 
	
木马程序
木马程序描述
该木马程序的触发依赖于微UART核心接收端中的一个罕见分支。
当预设的分支（u_rec模块中的第115行）被执行三次后，木马被激活，并强制将rec_readyH输出信号置为'0'。
木马程序分类

插入阶段：设计阶段
抽象级别：寄存器传输级（RTL）
激活机制：基于物理条件触发
影响：拒绝服务
物理特性：功能性
