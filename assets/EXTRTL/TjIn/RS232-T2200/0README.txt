1. This directory includes:

1.1 src
	---Codes for the micro-UART core, the test bench, and the Trojan

2.Trojan
Trojan Description
    The Trojan trigger is a state machine within the receiver part of the micro-UART core. The Trojan is activated at a predefined state (r_SAMPLE in the u_rec module) and forces the rec_readyH output signal to be '0'.

Trojan Taxonomy
	Insertion phase: Design
	Abstraction level: Register-transfer level (RTL)
	Activation mechanism: Physical-condition-based
	Effects: Denial of service
	Physical characteristics: Functional

木马程序
木马程序描述
该木马程序的触发器是微UART核心接收端中的一个状态机。木马在预设状态（u_rec模块中的r_SAMPLE状态）被激活，并强制将rec_readyH输出信号置为'0'。
木马程序分类

插入阶段：设计阶段
抽象级别：寄存器传输级（RTL）
激活机制：基于物理条件触发
影响：拒绝服务
物理特性：功能性
