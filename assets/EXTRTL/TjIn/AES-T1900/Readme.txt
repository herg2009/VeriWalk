1.Home directory includes:

1.1 src
	---Codes for the AES algorithm, the test bench, and the Trojan

2.Trojan
Trojan Description
	At the core of lightweight applications, such as medical implant devices,are the batteries that power them and 
	the success of the device restsheavily on them. This Trojan drains the battery once it is activated. The Trojan 
	gets activated after 128'hFFFF_FFFF_FFFF_FFFF_FFFF_FFFF_FFFF_FFFF encryptions. The Trojan payload is a shift 
	register which continuously rotates after Trojan activation. The Trojan increases the power consumption and hence 
	decreases the expected lifetime of the battery. 



Trojan Taxonomy
	Insertion phase: Design
	Abstraction level: Register Transfer level  
	Activation mechanism: Internally conditionally triggered
	Effects: Denial of Service
 	Location: Processor
	Physical characteristics: Functional
	
木马程序
木马程序描述
在诸如医用植入设备等轻型应用中，为其供电的电池是核心部件，设备的成功运行在很大程度上依赖于这些电池。
该木马程序一旦被激活，便会耗尽电池电量。在完成128个十六进制值“FFFF_FFFF_FFFF_FFFF_FFFF_FFFF_FFFF_FFFF”的加密操作后，木马程序将被激活。
其有效载荷是一个移位寄存器，在木马程序激活后会持续循环运转。木马程序会增加功耗，从而缩短电池的预期使用寿命。

木马程序分类

插入阶段：设计阶段
抽象级别：寄存器传输级
激活机制：内部条件触发
影响：拒绝服务（通过耗尽电池电量使设备无法正常工作，属于拒绝服务攻击的一种形式 ）
位置：处理器
物理特性：功能性