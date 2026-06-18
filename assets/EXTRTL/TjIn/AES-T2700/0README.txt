1. This directory includes:

1.1 src
	---Codes for the AES algorithm, the test bench, and the Trojan

2.Trojan
Trojan Description
    The Trojan trigger is dependent on a 4-bit asynchronous counter, which is in turn contingent on a 4-bit synchronous counter (both inserted into the AES-128 block cipher). After each successive encryption, the synchronous counter is increased by 1. The asynchronous counter is also incremented provided that the fourth bit of the synchronous counter is high. The Trojan is active when the fourth bit of the asynchronous counter is high. When triggered, the Trojan attacks encryption by flipping the least significant bit of the existing encrypted output.

Trojan Taxonomy
	Insertion phase: Design
	Abstraction level: Register Transfer
	Activation mechanism: Both Physical-Condition and Time-Based
	Effects: Change Functionality
	Physical characteristics: Functional

木马程序
木马程序描述
该木马程序的触发机制依赖于一个4位异步计数器，而该异步计数器又受制于一个4位同步计数器（两者均嵌入在AES-128分组密码中）。
每次连续完成一次加密操作后，同步计数器数值增加1。只有当同步计数器的第4位为高电平时，异步计数器才会随之递增。
当异步计数器的第4位为高电平时，木马程序被激活。
一旦触发，木马程序会通过翻转现有加密输出结果的最低有效位来破坏加密过程。

木马程序分类

插入阶段：设计阶段
抽象级别：寄存器传输级
激活机制：基于物理条件与时间双重触发
影响：改变功能
物理特性：功能性