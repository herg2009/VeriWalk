1.Home directory includes:

1.1 src
	---Codes for the AES algorithm, the test bench, and the Trojan

2.Trojan
Trojan Description
	After a specific number of encryptions, the Trojan leaks the secret key of AES-128 through the leakage 
	current. The leakage circuit (LC) consists of a shift register holding the secret key and two inverters. The least significant 
	bit of the shift register is connected to one inverter whose output connected to the input of the other inverter. 
	Whenever the least significant bit is '0', a direct path between power and ground composed by the PMOS of the first 
	inverter and the NMOS of the second inverter is created for a limited time. Therefore, the secret key can be retrieved 
	by measuring the leakage current.


Trojan Taxonomy
	Insertion phase: Design
	Abstraction level: Register Transfer level  
	Activation mechanism: Internally conditionally triggered
	Effects: Leak Information
 	Location: Processor
	Physical characteristics: Functional
	
	木马程序
木马程序描述
在完成特定次数的加密操作后，该木马程序会通过泄漏电流泄露AES-128的密钥。
泄漏电路（LC）由一个存储密钥的移位寄存器和两个反相器构成。移位寄存器的最低有效位连接至其中一个反相器，该反相器的输出再连接至另一个反相器的输入。
每当最低有效位为“0”时，由第一个反相器的PMOS晶体管和第二个反相器的NMOS晶体管组成的电源与地之间的直接通路会在有限时间内导通。
因此，通过测量泄漏电流即可获取密钥。

木马程序分类

插入阶段：设计阶段
抽象级别：寄存器传输级
激活机制：内部条件触发
影响：信息泄露
位置：处理器
物理特性：功能性