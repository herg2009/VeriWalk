本目录的aes相关源码与TjFree中一样，本木马作用是发送密钥，因此AES源码无需变化。
1.Home directory includes:

1.1 src
	---Codes for the AES algorithm, the test bench, and the Trojan

2.Trojan
Trojan Description
	The Trojan leaks the secret key from a cryptographic chip running the AES algorithm through a covert channel. 
	The channel adapts the concepts from spread spectrum communications (also known as Code-Division Multiple Access (CDMA)) 
	to distribute the leakage of single bits over many clock cycles. The Trojan employs this method by using 
	a pseudo-random number generator (PRNG) to create a CDMA code sequence, the PRNG initialized to a predefined value. 
	The code sequence is then used to XOR modulate the secret information bits. The modulated sequence is forwarded to 
	a leakage circuit (LC) to set up a covert CDMA channel in the power side-channel. The LC is realized by connecting 
	eight identical flip-flop elements to the single output of the XOR gate to mimic a large capacitance [1].
	
木马程序
木马程序描述
该木马程序通过隐蔽信道，从运行高级加密标准（AES）算法的加密芯片中泄露密钥。
该信道借鉴了扩频通信（也称为码分多址接入（CDMA））的概念，将单个比特的泄露分散到多个时钟周期中。
木马程序采用这种方法时，会使用伪随机数生成器（PRNG）生成一个CDMA码序列，且该伪随机数生成器初始化为一个预定义值。
然后，该码序列用于对密钥信息比特进行异或（XOR）调制。调制后的序列被转发到泄漏电路（LC），以便在电源侧信道中建立一个隐蔽的CDMA信道。
LC通过将八个相同的触发器元件连接到异或门的单个输出端来实现，以模拟大电容[1]。


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