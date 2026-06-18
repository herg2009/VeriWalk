1.Home directory includes:

1.1 src
	---Codes for the AES algorithm, the test bench, and the Trojan

2.Trojan
Trojan Description
	The Trojan demonstrates an attack on the AES-128 block-cipher and its corresponding key schedule. 
	The idea is to artificially introduce leaking intermediate states in the key schedule that depend 
	on known input bits and key bits, but that naturally would not occur during regular processing of 
	the cipher. The Trojan uses AND conjunctions to pairwise combine each key bit with another input bit. 
	The output of the AND gates are then combined to the leaked intermediate value by XORing all of them. 
	The Trojan leaks one byte of the AES round key for each round of the key schedule. The leakage circuit (LC) 
	is a 16-bit shift register and loaded it with an initial alternating sequence of zeros and ones. 
	The shift register is only enabled in case the input to the leakage circuit is one, which results in 
	an additional dynamic power consumption [1].
	
木马程序
木马程序描述
该木马程序展示了一种针对AES-128分组密码及其相应密钥编排算法的攻击。
其思路是在密钥编排算法中人为引入依赖已知输入比特和密钥比特的泄露中间状态，而这些状态在密码的正常处理过程中自然不会出现。
木马程序使用与（AND）运算将每个密钥比特与另一个输入比特两两组合。然后，将与门的输出通过异或（XOR）运算全部组合起来，得到泄露的中间值。
在密钥编排算法的每一轮中，该木马程序都会泄露一个字节的AES轮密钥。泄露电路（LC）是一个16位移位寄存器，并为其加载了初始的零一交替序列。
只有当泄露电路的输入为1时，移位寄存器才会被启用，这会导致额外的动态功耗[1]。



Trojan Taxonomy
	Insertion phase: Design
	Abstraction level: Register Transfer level  
	Activation mechanism: Always on
	Effects: Leak Information
	Location: Processor
	Physical characteristics: Functional

木马程序分类
插入阶段：设计阶段
抽象级别：寄存器传输级
激活机制：始终开启
影响：泄露信息
位置：处理器
物理特性：功能性
[1] L. Lin, M. Kasper, T. G黱eysu, C. Paar and W. Burleson, "Trojan Side-Channels: Lightweight Hardware Trojans 
through Side-Channel Engineering," 11th International Workshop Cryptographic Hardware and Embedded Systems (CHES), 
pp.382-395, 2009.
