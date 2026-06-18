1.Home directory includes:

1.1 src
	---Codes for the AES algorithm, the test bench, and the Trojan

2.Trojan
Trojan Description
	Whenever a predefined input plaintext is observed, the Trojan demonstrates an attack on the AES-128 
	block-cipher and its corresponding key schedule. The idea is to artificially introduce leaking intermediate 
	states in the key schedule that depend on known input bits and key bits, but that naturally would not 
	occur during regular processing of the cipher. The Trojan uses AND conjunctions to pairwise combine each 
	key bit with another input bit. The output of the AND gates are then combined to the leaked intermediate 
	value by XORing all of them. The Trojan leaks one byte of the AES round key for each round of the key schedule. 
	The leakage circuit (LC) is a 16-bit shift register and loaded it with an initial alternating sequence 
	of zeros and ones. The shift register is only enabled in case the input to the leakage circuit is one, 
	which results in an additional dynamic power consumption [1].


Trojan Taxonomy
	Insertion phase: Design
	Abstraction level: Register Transfer level  
	Activation mechanism: Triggered Internally
	Effects: Leak Information
	Location: Processor
	Physical characteristics: Functional

木马程序
木马程序描述
每当检测到预定义的输入明文时，该木马程序便会对AES-128分组密码及其对应的密钥编排算法发起攻击。
其思路是在密钥编排过程中人为引入依赖于已知输入比特和密钥比特的中间状态泄露，而这些状态在密码的正常处理过程中本不会自然出现。
木马程序利用与（AND）运算，将每个密钥比特与另一个输入比特逐一组合。然后，将所有与门的输出通过异或（XOR）运算组合成泄露的中间值。
该木马程序在密钥编排的每一轮中，都会泄露一个字节的AES轮密钥。泄露电路（LC）是一个16位移位寄存器，并加载了由0和1交替组成的初始序列。
仅当泄露电路的输入为1时，移位寄存器才会被激活，这会导致额外的动态功耗消耗[1]。

木马程序分类

插入阶段：设计阶段
抽象级别：寄存器传输级
激活机制：内部触发
影响：信息泄露
位置：处理器
物理特性：功能性

[1] L. Lin, M. Kasper, T. G黱eysu, C. Paar and W. Burleson, "Trojan Side-Channels: Lightweight Hardware Trojans 
through Side-Channel Engineering," 11th International Workshop Cryptographic Hardware and Embedded Systems (CHES), 
pp.382-395, 2009.
