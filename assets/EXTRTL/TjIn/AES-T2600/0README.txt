1. This directory includes:

1.1 src
	---Codes for the AES algorithm, the test bench, and the Trojan

2.Trojan
Trojan Description
    The Trojan trigger is a 4-bit asynchronous counter inserted into the AES-128 block cipher. The counter is increased by 1 after each successive encryption if the value of a predetermined signal (s3[122] within the aes_128 module) is 1. The Trojan is active when the fourth bit of the counter is high. When triggered, the Trojan attacks encryption by flipping the least significant bit of the existing encrypted output.

Trojan Taxonomy
	Insertion phase: Design
	Abstraction level: Register Transfer
	Activation mechanism: Both Physical-Condition and Time-Based
	Effects: Change Functionality
	Physical characteristics: Functional
	
	木马程序
木马程序描述
该木马程序的触发器是一个嵌入在AES-128分组密码中的4位异步计数器。
若aes_128模块内预定义信号s3[122]的值为1，则每次连续完成一次加密操作后，计数器数值增加1。当计数器的第4位为高电平时，木马程序被激活。
一旦触发，木马程序会通过翻转现有加密输出结果的最低有效位来破坏加密过程。

木马程序分类

插入阶段：设计阶段
抽象级别：寄存器传输级
激活机制：基于物理条件与时间双重触发
影响：改变功能
物理特性：功能性

