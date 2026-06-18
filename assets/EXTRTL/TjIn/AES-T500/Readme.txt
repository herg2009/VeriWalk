1.Home directory includes:

1.1 src
	---Codes for the AES algorithm, the test bench, and the Trojan

2.Trojan
Trojan Description
	?At the core of lightweight applications, such as medical implant devices,are the batteries that power them and 
	the success of the device restsheavily on them. This Trojan drains the battery once it is activated. The Trojan 
	gets activated after observing a specific sequence of the input plain text. The Trojan payload is a shift register 
	which continuously rotates after Trojan activation. The Trojan increases the power consumption and hence decreases 
	the expected lifetime of the battery.



Trojan Taxonomy
	Insertion phase: Design
	Abstraction level: Register Transfer level  
	Activation mechanism: Internally conditionally triggered
	Effects: Leak Information
 	Location: Processor
	Physical characteristics: Functional
	
木马程序
木马程序描述
在诸如医用植入设备等轻型应用的核心，是为其供电的电池，设备的成功在很大程度上取决于这些电池。
此木马程序一旦被激活，便会耗尽电池电量。该木马程序在观察到特定的输入明文序列后会被激活。
木马的有效载荷是一个移位寄存器，在木马激活后会持续循环移位。木马程序会增加功耗，从而缩短电池的预期使用寿命。

木马程序分类
插入阶段：设计阶段
抽象级别：寄存器传输级
激活机制：内部条件触发
影响：泄露信息（此处“Leak Information”按原文翻译，但根据描述此木马主要影响是耗电缩短电池寿命，若需更准确对应功能，也可考虑表述为“造成功耗异常/影响设备续航”等类似意思 ）
位置：处理器
物理特性：功能性