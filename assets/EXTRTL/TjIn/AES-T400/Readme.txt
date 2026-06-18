1.Home directory includes:

1.1 src
	---Codes for the AES algorithm, the test bench, and the Trojan

2.Trojan
Trojan Description
	Modulating an (unused) pin on a chip generates an RF signal. This signal can be used to transmit the key bits. 
	This attack is performed at 1560 KHz and can be received with an ordinary AM radio. The data carried by 
	the AM signal needs to be easily interpreted by a human. A beep scheme is utilized where a single beep followed 
	by a pause represents a ?0? and a double beep followed by a pause represents a ?1?. A description on detail 
	implementation of AM transmission can be found at [1]. In this implementation, the Trojan gets activated when a
	predefined input plaintext is observed. 


Trojan Taxonomy
	Insertion phase: Design
	Abstraction level: Register Transfer level  
	Activation mechanism: Internally conditionally triggered
	Effects: Leak Information
 	Location: Processor
	Physical characteristics: Functional

木马程序
木马程序描述
对芯片上的一个（未使用的）引脚进行调制可产生射频（RF）信号。该信号可用于传输密钥比特。
这种攻击在1560千赫兹（KHz）的频率下进行，可用普通调幅（AM）收音机接收。调幅信号所携带的数据需便于人类解读。
采用了一种蜂鸣方案，即单个蜂鸣声后接一段停顿表示“0”，两个连续蜂鸣声后接一段停顿表示“1”。关于调幅传输的详细实现描述，可参见文献[1]。
在此实现中，当观察到预定义的输入明文时，木马程序会被激活。

木马程序分类
插入阶段：设计阶段
抽象级别：寄存器传输级
激活机制：内部条件触发
影响：泄露信息
位置：处理器
物理特性：功能性

[1] Alex Baumgarten, Michael Steffen, Matthew Clausman, Joseph Zambreno, 
"A case study in hardware Trojan design and implementation," 
International Journal of Information Security, Volume 10, Issue 1, pp 1-14, 2011
