


module atahost_controller (clk, nReset, rst, irq, IDEctrl_rst, IDEctrl_IDEen, 
			PIO_cmdport_T1, PIO_cmdport_T2, PIO_cmdport_T4, PIO_cmdport_Teoc, PIO_cmdport_IORDYen, 
			PIOreq, PIOack, PIOa, PIOd, PIOq, PIOwe, 
			RESETn, DDi, DDo, DDoe, DA, CS0n, CS1n, DIORn, DIOWn, IORDY, INTRQ);
	
	
	
	parameter TWIDTH = 8;              
	
	parameter PIO_mode0_T1   = 6;      
	parameter PIO_mode0_T2   = 28;     
	parameter PIO_mode0_T4   = 2;      
	parameter PIO_mode0_Teoc = 23;     
	
	
	
	input  clk; 
	input  nReset; 
	input  rst; 
	
	output irq; 
	reg irq;
	
	
	input  IDEctrl_rst;
	input  IDEctrl_IDEen;

	
	input  [7:0] PIO_cmdport_T1;
	input  [7:0] PIO_cmdport_T2;
	input  [7:0] PIO_cmdport_T4;
	input  [7:0] PIO_cmdport_Teoc;
	input        PIO_cmdport_IORDYen;

	
	input         PIOreq; 
	output        PIOack; 
	input  [ 3:0] PIOa;   
	input  [15:0] PIOd;   
	output [15:0] PIOq;   
	input         PIOwe;  

	reg [15:0] PIOq;
	reg PIOack;

	
	output        RESETn;
	input  [15:0] DDi;
	output [15:0] DDo;
	output        DDoe;
	output [ 2:0] DA;
	output        CS0n;
	output        CS1n;
	output        DIORn;
	output        DIOWn;
	input         IORDY;
	input         INTRQ;

	reg        RESETn;
	reg [15:0] DDo;
	reg        DDoe;
	reg [ 2:0] DA;
	reg        CS0n;
	reg        CS1n;
	reg        DIORn;
	reg        DIOWn;

	
	
	

	reg dPIOreq;
	reg PIOgo;   
	wire PIOdone; 

	
	wire PIOdior, PIOdiow;
	wire PIOoe;

	
	wire              dstrb;
	wire [TWIDTH-1:0] T1, T2, T4, Teoc;
	wire              IORDYen;

	
	reg sIORDY;

	
	
	


	
	reg cIORDY;                               
	reg cINTRQ;                               

	always@(posedge clk)
	begin : synch_incoming
		cIORDY <= #1 IORDY;
		cINTRQ <= #1 INTRQ;

		sIORDY <= #1 cIORDY;
		irq    <= #1 cINTRQ;
	end

	
	always@(posedge clk or negedge nReset)
		if (~nReset)
			begin
				RESETn <= #1 1'b0;
				DIORn  <= #1 1'b1;
				DIOWn  <= #1 1'b1;
				DA     <= #1 0;
				CS0n	  <= #1 1'b1;
				CS1n	  <= #1 1'b1;
				DDo    <= #1 0;
				DDoe   <= #1 1'b0;
			end
		else if (rst)
			begin
				RESETn <= #1 1'b0;
				DIORn  <= #1 1'b1;
				DIOWn  <= #1 1'b1;
				DA     <= #1 0;
				CS0n	  <= #1 1'b1;
				CS1n	  <= #1 1'b1;
				DDo    <= #1 0;
				DDoe   <= #1 1'b0;
			end
		else
			begin
				RESETn <= #1 !IDEctrl_rst;
				DA     <= #1 PIOa[2:0];
				CS0n   <= #1 !( !PIOa[3] & PIOreq); 
				CS1n   <= #1 !(  PIOa[3] & PIOreq); 

				DDo    <= #1 PIOd;
				DDoe   <= #1 PIOoe;
				DIORn  <= #1 !PIOdior;
				DIOWn  <= #1 !PIOdiow;
			end


	
	
	
	
	
	
	always@(posedge clk)
		if (dstrb)
			PIOq <= #1 DDi;

	
	always @(posedge clk or negedge nReset)
		if (~nReset)
			begin
				dPIOreq <= #1 1'b0;
				PIOgo   <= #1 1'b0;
			end
		else if (rst)
			begin
				dPIOreq <= #1 1'b0;
				PIOgo   <= #1 1'b0;
			end
		else
			begin
				dPIOreq <= #1 PIOreq & !PIOack;
				PIOgo   <= #1 (PIOreq & !dPIOreq) & IDEctrl_IDEen;
			end

	
	assign T1      = PIO_cmdport_T1;
	assign T2      = PIO_cmdport_T2;
	assign T4      = PIO_cmdport_T4;
	assign Teoc    = PIO_cmdport_Teoc;
	assign IORDYen = PIO_cmdport_IORDYen;

	
	atahost_pio_tctrl #(TWIDTH, PIO_mode0_T1, PIO_mode0_T2, PIO_mode0_T4, PIO_mode0_Teoc)
		PIO_timing_controller (
			.clk(clk),
			.nReset(nReset),
			.rst(rst),
			.IORDY_en(IORDYen),
			.T1(T1),
			.T2(T2),
			.T4(T4),
			.Teoc(Teoc),
			.go(PIOgo),
			.we(PIOwe),
			.oe(PIOoe),
			.done(PIOdone),
			.dstrb(dstrb),
			.DIOR(PIOdior),
			.DIOW(PIOdiow),
			.IORDY(sIORDY)
		);

	always@(posedge clk)
		PIOack <= #1 PIOdone | (PIOreq & !IDEctrl_IDEen); 

endmodule






module atahost_pio_tctrl(clk, nReset, rst, IORDY_en, T1, T2, T4, Teoc, go, we, oe, done, dstrb, DIOR, DIOW, IORDY);
	
	parameter TWIDTH = 8;
	parameter PIO_MODE0_T1   =  6;             
	parameter PIO_MODE0_T2   = 28;             
	parameter PIO_MODE0_T4   =  2;             
	parameter PIO_MODE0_Teoc = 23;             
	
	
	input clk; 
	input nReset; 
	input rst; 
	
	
	input IORDY_en;          
	input [TWIDTH-1:0] T1;   
	input [TWIDTH-1:0] T2;   
	input [TWIDTH-1:0] T4;   
	input [TWIDTH-1:0] Teoc; 

	
	input go; 
	input we; 

	
	output oe; 
	reg oe;
	output done; 
	output dstrb; 
	reg dstrb;

	
	output DIOR; 
	reg DIOR;
	output DIOW; 
	reg DIOW;
	input  IORDY; 


	
	
	
	
	wire [TWIDTH-1:0] T1_m0   = PIO_MODE0_T1;
	wire [TWIDTH-1:0] T2_m0   = PIO_MODE0_T2;
	wire [TWIDTH-1:0] T4_m0   = PIO_MODE0_T4;
	wire [TWIDTH-1:0] Teoc_m0 = PIO_MODE0_Teoc;

	
	
	
	reg busy, hold_go;
	wire igo;
	wire T1done, T2done, T4done, Teoc_done, IORDY_done;
	reg hT2done;

	
	
	

	
	
	always@(posedge clk or negedge nReset)
		if (~nReset)
			begin
				busy    <= #1 1'b0;
				hold_go <= #1 1'b0;
			end
		else if (rst)
			begin
				busy    <= #1 1'b0;
				hold_go <= #1 1'b0;
			end
		else
			begin
				busy    <= #1 (igo | busy) & !Teoc_done;
				hold_go <= #1 (go | (hold_go & busy)) & !igo;
			end

	assign igo = (go | hold_go) & !busy;

	
	ro_cnt #(TWIDTH, 1'b0, PIO_MODE0_T1)
		t1_cnt(
			.clk(clk),
			.rst(rst),
			.nReset(nReset),
			.cnt_en(1'b1),
			.go(igo),
			.d(T1),
			.q(),
			.done(T1done)
		);

	
	always@(posedge clk or negedge nReset)
		if (~nReset)
			begin
				DIOR <= #1 1'b0;
				DIOW <= #1 1'b0;
				oe   <= #1 1'b0;
			end
		else if (rst)
			begin
				DIOR <= #1 1'b0;
				DIOW <= #1 1'b0;
				oe   <= #1 1'b0;
			end
		else
			begin
				DIOR <= #1 (!we & T1done) | (DIOR & !IORDY_done);
				DIOW <= #1 ( we & T1done) | (DIOW & !IORDY_done);
				oe   <= #1 ( (we & igo) | oe) & !T4done;           
			end

	
	ro_cnt #(TWIDTH, 1'b0, PIO_MODE0_T2)
		t2_cnt(
			.clk(clk),
			.rst(rst),
			.nReset(nReset),
			.cnt_en(1'b1),
			.go(T1done),
			.d(T2),
			.q(),
			.done(T2done)
		);

	
	
	always@(posedge clk or negedge nReset)
		if (~nReset)
			hT2done <= #1 1'b0;
		else if (rst)
			hT2done <= #1 1'b0;
		else
			hT2done <= #1 (T2done | hT2done) & !IORDY_done;

	assign IORDY_done = (T2done | hT2done) & (IORDY | !IORDY_en);

	
	always@(posedge clk)
		dstrb <= #1 IORDY_done;

	
	ro_cnt #(TWIDTH, 1'b0, PIO_MODE0_T4)
		dhold_cnt(
			.clk(clk),
			.rst(rst),
			.nReset(nReset),
			.cnt_en(1'b1),
			.go(IORDY_done),
			.d(T4),
			.q(),
			.done(T4done)
		);

	assign done = T4done; 
                        

	
	ro_cnt #(TWIDTH, 1'b0, PIO_MODE0_Teoc)
		eoc_cnt(
			.clk(clk),
			.rst(rst),
			.nReset(nReset),
			.cnt_en(1'b1),
			.go(IORDY_done),
			.d(Teoc),
			.q(),
			.done(Teoc_done)
		);

endmodule






module top (wb_clk_i, arst_i, wb_rst_i, wb_cyc_i, wb_stb_i, wb_ack_o, wb_err_o,
		wb_adr_i, wb_dat_i, wb_dat_o, wb_sel_i, wb_we_i, wb_inta_o,
		resetn_pad_o, dd_pad_i, dd_pad_o, dd_padoe_o, da_pad_o, cs0n_pad_o,
		cs1n_pad_o, diorn_pad_o, diown_pad_o, iordy_pad_i, intrq_pad_i);
	
	
	
	parameter ARST_LVL = 1'b0;                    

	parameter TWIDTH = 8;                         
	
	parameter PIO_mode0_T1   =  6;                
	parameter PIO_mode0_T2   = 28;                
	parameter PIO_mode0_T4   =  2;                
	parameter PIO_mode0_Teoc = 23;                

	
	
	

	
	input wb_clk_i;                               
	input arst_i;                                 
	input wb_rst_i;                               

	
	input        wb_cyc_i;                        
	input        wb_stb_i;                        
	output       wb_ack_o;                        
	output       wb_err_o;                        
	input  [6:2] wb_adr_i;                        
	                                              
	                                              
	                                              
	input  [31:0] wb_dat_i;                       
	output [31:0] wb_dat_o;                       
	input  [ 3:0] wb_sel_i;                       
	input         wb_we_i;                        
	output        wb_inta_o;                      

	
	output        resetn_pad_o;
	input  [15:0] dd_pad_i;
	output [15:0] dd_pad_o;
	output        dd_padoe_o;
	output [ 2:0] da_pad_o;
	output        cs0n_pad_o;
	output        cs1n_pad_o;

	output        diorn_pad_o;
	output        diown_pad_o;
	input         iordy_pad_i;
	input         intrq_pad_i;

	
	
	
	parameter [3:0] DeviceId = 4'h1;
	parameter [3:0] RevisionNo = 4'h0;

	
	
	

	
	wire        IDEctrl_IDEen, IDEctrl_rst;
	wire [ 7:0] PIO_cmdport_T1, PIO_cmdport_T2, PIO_cmdport_T4, PIO_cmdport_Teoc;
	wire        PIO_cmdport_IORDYen;

	wire        PIOack;
	wire [15:0] PIOq;

	wire irq; 


	
	
	

	
	
	wire arst_signal = arst_i ^ ARST_LVL;

	
	
	
	atahost_wb_slave #(DeviceId, RevisionNo, PIO_mode0_T1, 
			PIO_mode0_T2, PIO_mode0_T4, PIO_mode0_Teoc, 0, 0, 0)
	u0 (
		
		.clk_i(wb_clk_i),
		.arst_i(arst_signal),
		.rst_i(wb_rst_i),

		
		.cyc_i(wb_cyc_i),
		.stb_i(wb_stb_i),
		.ack_o(wb_ack_o),
		.rty_o(),
		.err_o(wb_err_o),
		.adr_i(wb_adr_i),
		.dat_i(wb_dat_i),
		.dat_o(wb_dat_o),
		.sel_i(wb_sel_i),
		.we_i(wb_we_i),
		.inta_o(wb_inta_o),

		
		.PIOsel(PIOsel),
			
			
			
		.PIOtip(1'b0),
		.PIOack(PIOack),
		.PIOq(PIOq),
		.PIOpp_full(1'b0), 
		.irq(irq),

		
		.DMAsel(),
		.DMAtip(1'b0),
		.DMAack(1'b0),
		.DMARxEmpty(1'b0),
		.DMATxFull(1'b0),
		.DMA_dmarq(1'b0),
		.DMAq(32'h0),

		
		
		.IDEctrl_rst(IDEctrl_rst),
		.IDEctrl_IDEen(IDEctrl_IDEen),
		.IDEctrl_FATR0(),
		.IDEctrl_FATR1(),
		.IDEctrl_ppen(),

		.DMActrl_DMAen(),
		.DMActrl_dir(),
		.DMActrl_BeLeC0(),
		.DMActrl_BeLeC1(),

		
		.PIO_cmdport_T1(PIO_cmdport_T1),
		.PIO_cmdport_T2(PIO_cmdport_T2),
		.PIO_cmdport_T4(PIO_cmdport_T4),
		.PIO_cmdport_Teoc(PIO_cmdport_Teoc),
		.PIO_cmdport_IORDYen(PIO_cmdport_IORDYen),

		
		.PIO_dport0_T1(),
		.PIO_dport0_T2(),
		.PIO_dport0_T4(),
		.PIO_dport0_Teoc(),
		.PIO_dport0_IORDYen(),

		
		.PIO_dport1_T1(),
		.PIO_dport1_T2(),
		.PIO_dport1_T4(),
		.PIO_dport1_Teoc(),
		.PIO_dport1_IORDYen(),

		
		.DMA_dev0_Tm(),
		.DMA_dev0_Td(),
		.DMA_dev0_Teoc(),

		
		.DMA_dev1_Tm(),
		.DMA_dev1_Td(),
		.DMA_dev1_Teoc()
	);


	
	
	
	atahost_controller #(TWIDTH, PIO_mode0_T1, PIO_mode0_T2, PIO_mode0_T4, PIO_mode0_Teoc)
		u1 (
			.clk(wb_clk_i),
			.nReset(arst_signal),
			.rst(wb_rst_i),
			.irq(irq),
			.IDEctrl_rst(IDEctrl_rst),
			.IDEctrl_IDEen(IDEctrl_IDEen),
			.PIO_cmdport_T1(PIO_cmdport_T1),
			.PIO_cmdport_T2(PIO_cmdport_T2),
			.PIO_cmdport_T4(PIO_cmdport_T4),
			.PIO_cmdport_Teoc(PIO_cmdport_Teoc),
			.PIO_cmdport_IORDYen(PIO_cmdport_IORDYen),
			.PIOreq(PIOsel),
			.PIOack(PIOack),
			.PIOa(wb_adr_i[5:2]),
			.PIOd(wb_dat_i[15:0]),
			.PIOq(PIOq),
			.PIOwe(wb_we_i),
			.RESETn(resetn_pad_o),
			.DDi(dd_pad_i),
			.DDo(dd_pad_o),
			.DDoe(dd_padoe_o),
			.DA(da_pad_o),
			.CS0n(cs0n_pad_o),
			.CS1n(cs1n_pad_o),
			.DIORn(diorn_pad_o),
			.DIOWn(diown_pad_o),
			.IORDY(iordy_pad_i),
			.INTRQ(intrq_pad_i)
		);

endmodule




module atahost_wb_slave (
		clk_i, arst_i, rst_i, cyc_i, stb_i, ack_o, rty_o, err_o, adr_i,	dat_i, dat_o, sel_i, we_i, inta_o,
		PIOsel, PIOtip, PIOack, PIOq, PIOpp_full, irq,
		DMAsel, DMAtip, DMAack, DMARxEmpty, DMATxFull, DMA_dmarq, DMAq,
		IDEctrl_rst, IDEctrl_IDEen, IDEctrl_FATR1, IDEctrl_FATR0, IDEctrl_ppen,
		DMActrl_DMAen, DMActrl_dir, DMActrl_BeLeC0, DMActrl_BeLeC1,
		PIO_cmdport_T1, PIO_cmdport_T2, PIO_cmdport_T4, PIO_cmdport_Teoc, PIO_cmdport_IORDYen,
		PIO_dport0_T1, PIO_dport0_T2, PIO_dport0_T4, PIO_dport0_Teoc, PIO_dport0_IORDYen,
		PIO_dport1_T1, PIO_dport1_T2, PIO_dport1_T4, PIO_dport1_Teoc, PIO_dport1_IORDYen,
		DMA_dev0_Tm, DMA_dev0_Td, DMA_dev0_Teoc, DMA_dev1_Tm, DMA_dev1_Td, DMA_dev1_Teoc
	);

	
	
	
	parameter DeviceId   = 4'h0;
	parameter RevisionNo = 4'h0;

	
	parameter PIO_mode0_T1   =  6;                
	parameter PIO_mode0_T2   = 28;                
	parameter PIO_mode0_T4   =  2;                
	parameter PIO_mode0_Teoc = 23;                

	
	parameter DMA_mode0_Tm   =  6;                
	parameter DMA_mode0_Td   = 21;                
	parameter DMA_mode0_Teoc = 21;                

	
	
	
	
	
	input clk_i;                                
	input arst_i;                               
	input rst_i;                                

	
	input       cyc_i;                          
	input       stb_i;                          
	output      ack_o;                          
	output      rty_o;                          
	output      err_o;                          
	input [6:2] adr_i;                          
	                                            
	                                            
	                                            
	input  [31:0] dat_i;                        
	output [31:0] dat_o;                        
	input  [ 3:0] sel_i;                        
	input         we_i;                         
	output        inta_o;                       

	
	output        PIOsel;
	input         PIOtip;                       
	input         PIOack;                       
	input  [15:0] PIOq;                         
	input         PIOpp_full;                   
	input         irq;                          

	
	output       DMAsel;
	input        DMAtip;                        
	input        DMAack;                        
	input        DMARxEmpty;                    
	input        DMATxFull;                     
	input        DMA_dmarq;                     
	input [31:0] DMAq;

	
	
	output IDEctrl_rst;
	output IDEctrl_IDEen;
	output IDEctrl_FATR1;
	output IDEctrl_FATR0;
	output IDEctrl_ppen;
	output DMActrl_DMAen;
	output DMActrl_dir;
	output DMActrl_BeLeC0;
	output DMActrl_BeLeC1;

	
	output [7:0] PIO_cmdport_T1,
	             PIO_cmdport_T2,
	             PIO_cmdport_T4,
	             PIO_cmdport_Teoc;
	output       PIO_cmdport_IORDYen;

	reg [7:0] PIO_cmdport_T1,
	          PIO_cmdport_T2,
	          PIO_cmdport_T4,
	          PIO_cmdport_Teoc;

	
	output [7:0] PIO_dport0_T1,
	             PIO_dport0_T2,
	             PIO_dport0_T4,
	             PIO_dport0_Teoc;
	output       PIO_dport0_IORDYen;

	reg [7:0] PIO_dport0_T1,
	          PIO_dport0_T2,
	          PIO_dport0_T4,
	          PIO_dport0_Teoc;

	
	output [7:0] PIO_dport1_T1,
	             PIO_dport1_T2,
	             PIO_dport1_T4,
	             PIO_dport1_Teoc;
	output       PIO_dport1_IORDYen;

	reg [7:0] PIO_dport1_T1,
	          PIO_dport1_T2,
	          PIO_dport1_T4,
	          PIO_dport1_Teoc;

	
	output [7:0] DMA_dev0_Tm,
	             DMA_dev0_Td,
	             DMA_dev0_Teoc;

	reg [7:0] DMA_dev0_Tm,
	          DMA_dev0_Td,
	          DMA_dev0_Teoc;

	
	output [7:0] DMA_dev1_Tm,
	             DMA_dev1_Td,
	             DMA_dev1_Teoc;

	reg [7:0] DMA_dev1_Tm,
	          DMA_dev1_Td,
	          DMA_dev1_Teoc;


	
	
	

	
	`define ATA_DEV_ADR adr_i[6]
	`define ATA_ADR     adr_i[5:2]

	`define ATA_CTRL_REG 4'b0000
	`define ATA_STAT_REG 4'b0001
	`define ATA_PIO_CMD  4'b0010
	`define ATA_PIO_DP0  4'b0011
	`define ATA_PIO_DP1  4'b0100
	`define ATA_DMA_DEV0 4'b0101
	`define ATA_DMA_DEV1 4'b0110
	
	`define ATA_DMA_PORT 4'b1111


	
	
	

	
	reg  [31:0] CtrlReg; 
	wire [31:0] StatReg; 

	
	reg store_pp_full;


	
	
	
	wire w_acc  = &sel_i[1:0];                        
	wire dw_acc = &sel_i;                             

	
	wire berr = `ATA_DEV_ADR ? !w_acc : !dw_acc;

	
	wire PIOsel = cyc_i & stb_i & `ATA_DEV_ADR & w_acc & !(DMAtip | store_pp_full);

	
	wire CONsel = cyc_i & stb_i & !(`ATA_DEV_ADR) & dw_acc;
	wire DMAsel = CONsel & (`ATA_ADR == `ATA_DMA_PORT);

	
	
	always@(posedge clk_i)
		if (!PIOsel)
			store_pp_full <= #1 PIOpp_full;

	wire brty = (`ATA_DEV_ADR & w_acc) & (DMAtip | store_pp_full);

	
	
	

	
	wire sel_ctrl        = CONsel & we_i & (`ATA_ADR == `ATA_CTRL_REG);
	wire sel_stat        = CONsel & we_i & (`ATA_ADR == `ATA_STAT_REG);
	wire sel_PIO_cmdport = CONsel & we_i & (`ATA_ADR == `ATA_PIO_CMD);
	wire sel_PIO_dport0  = CONsel & we_i & (`ATA_ADR == `ATA_PIO_DP0);
	wire sel_PIO_dport1  = CONsel & we_i & (`ATA_ADR == `ATA_PIO_DP1);
	wire sel_DMA_dev0    = CONsel & we_i & (`ATA_ADR == `ATA_DMA_DEV0);
	wire sel_DMA_dev1    = CONsel & we_i & (`ATA_ADR == `ATA_DMA_DEV1);
	
	


	
	always@(posedge clk_i or negedge arst_i)
		if (~arst_i)
			begin
				CtrlReg[31:1] <= #1 0;
				CtrlReg[0]    <= #1 1'b1; 
			end
		else if (rst_i)
			begin
				CtrlReg[31:1] <= #1 0;
				CtrlReg[0]    <= #1 1'b1; 
			end
		else if (sel_ctrl)
			CtrlReg <= #1 dat_i;

	
	assign DMActrl_DMAen        = CtrlReg[15];
	assign DMActrl_dir          = CtrlReg[13];
	assign DMActrl_BeLeC1       = CtrlReg[9];
	assign DMActrl_BeLeC0       = CtrlReg[8];
	assign IDEctrl_IDEen        = CtrlReg[7];
	assign IDEctrl_FATR1        = CtrlReg[6];
	assign IDEctrl_FATR0        = CtrlReg[5];
	assign IDEctrl_ppen         = CtrlReg[4];
	assign PIO_dport1_IORDYen   = CtrlReg[3];
	assign PIO_dport0_IORDYen   = CtrlReg[2];
	assign PIO_cmdport_IORDYen  = CtrlReg[1];
	assign IDEctrl_rst          = CtrlReg[0];


	
	reg dirq, int;
	
	always@(posedge clk_i or negedge arst_i)
		if (~arst_i)
			begin
				int  <= #1 1'b0;
				dirq <= #1 1'b0;
			end
		else if (rst_i)
			begin
				int  <= #1 1'b0;
				dirq <= #1 1'b0;
			end
		else
			begin
				int  <= #1 (int | (irq & !dirq)) & !(sel_stat & !dat_i[0]);
				dirq <= #1 irq;
			end

	
	assign StatReg[31:28] = DeviceId;   
	assign StatReg[27:24] = RevisionNo; 
	assign StatReg[23:16] = 0;          
	assign StatReg[15]    = DMAtip;
	assign StatReg[14:11] = 0;
	assign StatReg[10]    = DMARxEmpty;
	assign StatReg[9]     = DMATxFull;
	assign StatReg[8]     = DMA_dmarq;
	assign StatReg[7]     = PIOtip;
	assign StatReg[6]     = PIOpp_full;
	assign StatReg[5:1]   = 0;          
	assign StatReg[0]     = int;


	
	always@(posedge clk_i or negedge arst_i)
		if (~arst_i)
			begin
				PIO_cmdport_T1   <= #1 PIO_mode0_T1;
				PIO_cmdport_T2   <= #1 PIO_mode0_T2;
				PIO_cmdport_T4   <= #1 PIO_mode0_T4;
				PIO_cmdport_Teoc <= #1 PIO_mode0_Teoc;
			end
		else if (rst_i)
			begin
				PIO_cmdport_T1   <= #1 PIO_mode0_T1;
				PIO_cmdport_T2   <= #1 PIO_mode0_T2;
				PIO_cmdport_T4   <= #1 PIO_mode0_T4;
				PIO_cmdport_Teoc <= #1 PIO_mode0_Teoc;
			end
		else if(sel_PIO_cmdport)
			begin
				PIO_cmdport_T1   <= #1 dat_i[ 7: 0];
				PIO_cmdport_T2   <= #1 dat_i[15: 8];
				PIO_cmdport_T4   <= #1 dat_i[23:16];
				PIO_cmdport_Teoc <= #1 dat_i[31:24];
			end

	
	always@(posedge clk_i or negedge arst_i)
		if (~arst_i)
			begin
				PIO_dport0_T1   <= #1 PIO_mode0_T1;
				PIO_dport0_T2   <= #1 PIO_mode0_T2;
				PIO_dport0_T4   <= #1 PIO_mode0_T4;
				PIO_dport0_Teoc <= #1 PIO_mode0_Teoc;
			end
		else if (rst_i)
			begin
				PIO_dport0_T1   <= #1 PIO_mode0_T1;
				PIO_dport0_T2   <= #1 PIO_mode0_T2;
				PIO_dport0_T4   <= #1 PIO_mode0_T4;
				PIO_dport0_Teoc <= #1 PIO_mode0_Teoc;
			end
		else if(sel_PIO_dport0)
			begin
				PIO_dport0_T1   <= #1 dat_i[ 7: 0];
				PIO_dport0_T2   <= #1 dat_i[15: 8];
				PIO_dport0_T4   <= #1 dat_i[23:16];
				PIO_dport0_Teoc <= #1 dat_i[31:24];
			end

	
	always@(posedge clk_i or negedge arst_i)
		if (~arst_i)
			begin
				PIO_dport1_T1   <= #1 PIO_mode0_T1;
				PIO_dport1_T2   <= #1 PIO_mode0_T2;
				PIO_dport1_T4   <= #1 PIO_mode0_T4;
				PIO_dport1_Teoc <= #1 PIO_mode0_Teoc;
			end
		else if (rst_i)
			begin
				PIO_dport1_T1   <= #1 PIO_mode0_T1;
				PIO_dport1_T2   <= #1 PIO_mode0_T2;
				PIO_dport1_T4   <= #1 PIO_mode0_T4;
				PIO_dport1_Teoc <= #1 PIO_mode0_Teoc;
			end
		else if(sel_PIO_dport1)
			begin
				PIO_dport1_T1   <= #1 dat_i[ 7: 0];
				PIO_dport1_T2   <= #1 dat_i[15: 8];
				PIO_dport1_T4   <= #1 dat_i[23:16];
				PIO_dport1_Teoc <= #1 dat_i[31:24];
			end

	
	always@(posedge clk_i or negedge arst_i)
		if (~arst_i)
			begin
				DMA_dev0_Tm   <= #1 DMA_mode0_Tm;
				DMA_dev0_Td   <= #1 DMA_mode0_Td;
				DMA_dev0_Teoc <= #1 DMA_mode0_Teoc;
			end
		else if (rst_i)
			begin
				DMA_dev0_Tm   <= #1 DMA_mode0_Tm;
				DMA_dev0_Td   <= #1 DMA_mode0_Td;
				DMA_dev0_Teoc <= #1 DMA_mode0_Teoc;
			end
		else if(sel_DMA_dev0)
			begin
				DMA_dev0_Tm   <= #1 dat_i[ 7: 0];
				DMA_dev0_Td   <= #1 dat_i[15: 8];
				DMA_dev0_Teoc <= #1 dat_i[31:24];
			end

	
	always@(posedge clk_i or negedge arst_i)
		if (~arst_i)
			begin
				DMA_dev1_Tm   <= #1 DMA_mode0_Tm;
				DMA_dev1_Td   <= #1 DMA_mode0_Td;
				DMA_dev1_Teoc <= #1 DMA_mode0_Teoc;
			end
		else if (rst_i)
			begin
				DMA_dev1_Tm   <= #1 DMA_mode0_Tm;
				DMA_dev1_Td   <= #1 DMA_mode0_Td;
				DMA_dev1_Teoc <= #1 DMA_mode0_Teoc;
			end
		else if(sel_DMA_dev1)
			begin
				DMA_dev1_Tm   <= #1 dat_i[ 7: 0];
				DMA_dev1_Td   <= #1 dat_i[15: 8];
				DMA_dev1_Teoc <= #1 dat_i[31:24];
			end

	
	
	
	reg [31:0] Q;

	
	assign ack_o = PIOack | CONsel; 

	
	assign err_o = cyc_i & stb_i & berr;

	
	assign rty_o = cyc_i & stb_i & brty;

	
	assign inta_o = StatReg[0];
	
	
	always@(`ATA_ADR or CtrlReg or StatReg or 
			PIO_cmdport_T1 or PIO_cmdport_T2 or PIO_cmdport_T4 or PIO_cmdport_Teoc or
			PIO_dport0_T1 or PIO_dport0_T2 or PIO_dport0_T4 or PIO_dport0_Teoc or
			PIO_dport1_T1 or PIO_dport1_T2 or PIO_dport1_T4 or PIO_dport1_Teoc or
			DMA_dev0_Tm or DMA_dev0_Td or DMA_dev0_Teoc or
			DMA_dev1_Tm or DMA_dev1_Td or DMA_dev1_Teoc or
			DMAq
		)
		case (`ATA_ADR) 
			`ATA_CTRL_REG: Q = CtrlReg;
			`ATA_STAT_REG: Q = StatReg;
			`ATA_PIO_CMD : Q = {PIO_cmdport_Teoc, PIO_cmdport_T4, PIO_cmdport_T2, PIO_cmdport_T1};
			`ATA_PIO_DP0 : Q = {PIO_dport0_Teoc, PIO_dport0_T4, PIO_dport0_T2, PIO_dport0_T1};
			`ATA_PIO_DP1 : Q = {PIO_dport1_Teoc, PIO_dport1_T4, PIO_dport1_T2, PIO_dport1_T1};
			`ATA_DMA_DEV0: Q = {DMA_dev0_Teoc, 8'h0, DMA_dev0_Td, DMA_dev0_Tm};
			`ATA_DMA_DEV1: Q = {DMA_dev1_Teoc, 8'h0, DMA_dev1_Td, DMA_dev1_Tm};
			`ATA_DMA_PORT: Q = DMAq;
			default: Q = 0;
		endcase

	
	assign dat_o = `ATA_DEV_ADR ? {16'h0, PIOq} : Q;

endmodule







module ro_cnt (clk, nReset, rst, cnt_en, go, done, d, q);

	
	parameter SIZE = 8;

	parameter UD = 1'b0;         
	parameter ID = {SIZE{1'b0}}; 

	
	input  clk;           
	input  nReset;        
	input  rst;           
	input  cnt_en;        
	input  go;            
	output done;          
	input  [SIZE-1:0] d;  
	output [SIZE-1:0] q;  

	
	reg rci;
	wire nld, rco;

	
	
	

	always@(posedge clk or negedge nReset)
		if (~nReset)
			rci <= #1 1'b0;
		else if (rst)
			rci <= #1 1'b0;
		else 
			rci <= #1 go | (rci & !rco);

	assign nld = !go;

	
	ud_cnt #(SIZE, ID) cnt (.clk(clk), .nReset(nReset), .rst(rst), .cnt_en(cnt_en),
		.ud(UD), .nld(nld), .d(d), .q(q), .rci(rci), .rco(rco));


	

	assign done = rco;

endmodule




`timescale 1ns / 10ps







module ud_cnt (clk, nReset, rst, cnt_en, ud, nld, d, q, rci, rco);
	
	parameter SIZE  = 8;
	parameter RESD  = {SIZE{1'b0}}; 

	
	input             clk;    
	input             nReset; 
	input             rst;    
	input             cnt_en; 
	input             ud;     
	input             nld;    
	input  [SIZE-1:0] d;      
	output [SIZE-1:0] q;      
	input             rci;    
	output            rco;    

	
	reg  [SIZE-1:0] Qi;  
	wire [SIZE:0]   val; 

	
	
	

	assign val = ud ? ( {1'b0, Qi} + rci) : ( {1'b0, Qi} - rci);

	always@(posedge clk or negedge nReset)
	begin
		if (~nReset)
			Qi <= #1 RESD;
		else if (rst)
			Qi <= #1 RESD;
		else	if (~nld)
			Qi <= #1 d;
		else if (cnt_en)
			Qi <= #1 val[SIZE-1:0];
	end

	
	assign q = Qi;
	assign rco = val[SIZE];
endmodule





