`timescale 1ns / 1ps
module ALU(
    input [7:0] a,
    input [7:0] b,
    output [7:0] result,
    input [2:0] opalu,
	 output zero, carry
    );

reg [7:0] resu;

always@*
	case (opalu)
		0: resu <= ~a;
		1: resu <= a & b;
		2: resu <= a ^ b;
		3: resu <= a | b;
		4: resu <= a;
		5: resu <= a + b;
		6: resu <= a - b;
		default: resu <= a + 1;
	endcase
	
assign zero=(resu==0);
assign result=resu;
assign carry=(a<b);
		

endmodule


`timescale 1ns / 1ps
module control_unit(
    input clk,
    input rst,
    input [15:0] instruction,
    input z,
    input c,
    output reg [7:0] port_addr,
    output reg write_e,
    output reg read_e,
    output reg insel,
    output reg we,
    output reg [2:0] raa,
    output reg [2:0] rab,
    output reg [2:0] wa,
    output reg [2:0] opalu,
    output reg [2:0] sh,
    output reg selpc,
    output reg ldpc,
    output reg ldflag,
    output reg [10:0] naddress,
    output reg selk,
    output reg [7:0] KTE,
	 input [10:0] stack_addr,
	 output reg wr_en, rd_en,
	 output reg [7:0] imm,
	 output reg selimm
    );


parameter fetch=	5'd0;
parameter decode=	5'd1;

parameter ldi=		5'd2;
parameter ldm=		5'd3;
parameter stm=		5'd4;
parameter cmp=		5'd5;
parameter add=		5'd6;
parameter sub=		5'd7;
parameter andi=	5'd8;
parameter oor=		5'd9;
parameter xori=	5'd10;
parameter jmp=		5'd11;
parameter jpz=		5'd12;
parameter jnz=		5'd13;
parameter jpc=		5'd14;
parameter jnc=		5'd15;
parameter csr=		5'd16;
parameter ret=		5'd17;

parameter adi=		5'd18;
parameter csz=		5'd19;
parameter cnz=		5'd20;
parameter csc=		5'd21;
parameter cnc=		5'd22;
parameter sl0=		5'd23;
parameter sl1=		5'd24;
parameter sr0=		5'd25;
parameter sr1=		5'd26;
parameter rrl=		5'd27;
parameter rrr=		5'd28;
parameter noti=	5'd29;

parameter nop=		5'd30;

wire [4:0] opcode;
reg [4:0] state;

assign opcode=instruction[15:11];

always@(posedge clk or posedge rst)
	if (rst)
		state<=decode;
	else
		case (state)
			fetch: state<=decode;
			
			decode: case (opcode)
							2: 	state<=ldi;
							3:		state<=ldm;
							4:		state<=stm; 
							5:		state<=cmp;
							6:		state<=add;
							7:		state<=sub;
							8:		state<=andi;
							9:		state<=oor;
							10:	state<=xori;
							11:	state<=jmp;
							12:	state<=jpz;
							13:	state<=jnz;
							14:	state<=jpc;
							15:	state<=jnc;
							16:	state<=csr;
							17:	state<=ret;
							18:	state<=adi;
							19:	state<=csz;
							20:	state<=cnz;
							21:	state<=csc;
							22:	state<=cnc;
							23:	state<=sl0;
							24:	state<=sl1;
							25:	state<=sr0;
							26:	state<=sr1;
							27:	state<=rrl;
							28:	state<=rrr;
							29:	state<=noti;
							default:	state<=nop;
						endcase
			
			ldi:	state<=fetch;
					
			ldm:	state<=fetch;
					
			stm:	state<=fetch;
					
			cmp:	state<=fetch;
					
			add:	state<=fetch;
					
			sub:	state<=fetch;
					
			andi:	state<=fetch;
					
			oor:	state<=fetch;
					
			xori:	state<=fetch;
							
			jmp:	state<=fetch;
						
			jpz: 	state<=fetch;
			
			jnz: 	state<=fetch;
			
			jpc: 	state<=fetch;
			
			jnc: 	state<=fetch;
			
			csr: 	state<=fetch;
			
			ret: 	state<=fetch;
			
			adi:	state<=fetch;
			
			csz:	state<=fetch;
			
			cnz:	state<=fetch;
			
			csc:	state<=fetch;
			
			cnc:	state<=fetch;
			
			sl0:	state<=fetch;
			
			sl1:	state<=fetch;
			
			sr0:	state<=fetch;
			
			sr1:	state<=fetch;
			
			rrl:	state<=fetch;
			
			rrr:	state<=fetch;
			
			noti:	state<=fetch;
						
			nop: 	state<=fetch;
			endcase
	


always@(*)
	begin
		port_addr<=0;
		write_e<=0;
		read_e<=0;
		insel<=0;
		we<=0;
		raa<=0;
		rab<=0;
		wa<=0;
		opalu<=4;
		sh<=4;
		selpc<=0;
		ldpc<=1;
		ldflag<=0;
		naddress<=0;
		selk<=0;
		KTE<=0;
		wr_en<=0;
		rd_en<=0;
		imm<=0;
		selimm<=0;
		
		case (state)
			fetch: ldpc<=0;
					
			decode:  begin
							ldpc<=0;
							if (opcode==stm)
								begin
									raa<=instruction[10:8];
									port_addr<=instruction[7:0];
								end
							else if (opcode==ldm)
								begin
									wa<=instruction[10:8];
									port_addr<=instruction[7:0];
								end
							else if (opcode==ret)
								begin
									rd_en<=1;
								end
						end
				
			ldi:	begin
						selk<=1;
						KTE<=instruction[7:0];
						we<=1;
						wa<=instruction[10:8];
					end
					
			ldm:	begin
						wa<=instruction[10:8];
						we<=1;
						read_e<=1;
						port_addr<=instruction[7:0];
					end
					
			stm:	begin
						raa<=instruction[10:8];
						write_e<=1;
						port_addr<=instruction[7:0];
					end
					
			cmp:	begin
						ldflag<=1;
						raa<=instruction[10:8];
						rab<=instruction[7:5];
						opalu<=6;
					end
					
			add:	begin
						raa<=instruction[10:8];
						rab<=instruction[7:5];
						wa<=instruction[10:8];
						insel<=1;
						opalu<=5;
						we<=1;
					end
					
			sub:	begin
						raa<=instruction[10:8];
						rab<=instruction[7:5];
						wa<=instruction[10:8];
						insel<=1;
						opalu<=6;
						we<=1;
					end
					
			andi:	begin
						raa<=instruction[10:8];
						rab<=instruction[7:5];
						wa<=instruction[10:8];
						insel<=1;
						opalu<=1;
						we<=1;
					end
					
			oor:	begin
						raa<=instruction[10:8];
						rab<=instruction[7:5];
						wa<=instruction[10:8];
						insel<=1;
						opalu<=3;
						we<=1;
					end
					
			xori:	begin
						raa<=instruction[10:8];
						rab<=instruction[7:5];
						wa<=instruction[10:8];
						insel<=1;
						opalu<=2;
						we<=1;
					end
					
			jmp:	begin
						naddress<=instruction[10:0];
						selpc<=1;
						ldpc<=1;
					end
					
			jpz:		if (z)
						begin
							naddress<=instruction[10:0];
							selpc<=1;
							ldpc<=1;
						end
										
			jnz:		if (!z)
							begin
								naddress<=instruction[10:0];
								selpc<=1;
								ldpc<=1;
							end
						
					
			jpc:	if (c)
							begin
								naddress<=instruction[10:0];
								selpc<=1;
								ldpc<=1;
							end
						
					
			jnc:	if (!c)
							begin
								naddress<=instruction[10:0];
								selpc<=1;
								ldpc<=1;
							end
							
			csr:	begin
						naddress<=instruction[10:0];
						selpc<=1;
						ldpc<=1;
						wr_en<=1;
					end
					
			ret:	begin
						naddress<=stack_addr;
						selpc<=1;
						ldpc<=1;
					end
					
			adi:	begin
						raa<=instruction[10:8];
						wa<=instruction[10:8];
						imm<=instruction[7:0];
						selimm<=1;
						insel<=1;
						opalu<=5;
						we<=1;
					end	
					
			csz:	if (z)
						begin
							naddress<=instruction[10:0];
							selpc<=1;
							ldpc<=1;
							wr_en<=1;
						end
						
			cnz:	if (!z)
						begin
							naddress<=instruction[10:0];
							selpc<=1;
							ldpc<=1;
							wr_en<=1;
						end
						
			csc:	if (c)
						begin
							naddress<=instruction[10:0];
							selpc<=1;
							ldpc<=1;
							wr_en<=1;
						end
						
			cnc:	if (!c)
						begin
							naddress<=instruction[10:0];
							selpc<=1;
							ldpc<=1;
							wr_en<=1;
						end
			
			sl0:	begin	
						raa<=instruction[10:8];
						wa<=instruction[10:8];
						insel<=1;
						sh<=0;
						we<=1;
					end
					
			sl1:	begin	
						raa<=instruction[10:8];
						wa<=instruction[10:8];
						insel<=1;
						sh<=5;
						we<=1;
					end
					
			sr0:	begin	
						raa<=instruction[10:8];
						wa<=instruction[10:8];
						insel<=1;
						sh<=2;
						we<=1;
					end
					
			sr1:	begin	
						raa<=instruction[10:8];
						wa<=instruction[10:8];
						insel<=1;
						sh<=6;
						we<=1;
					end	

			rrl:	begin	
						raa<=instruction[10:8];
						wa<=instruction[10:8];
						insel<=1;
						sh<=1;
						we<=1;
					end						
					
			rrr:	begin	
						raa<=instruction[10:8];
						wa<=instruction[10:8];
						insel<=1;
						sh<=3;
						we<=1;
					end
					
			noti:	begin
						raa<=instruction[10:8];
						wa<=instruction[10:8];
						insel<=1;
						opalu<=0;
						we<=1;
					end

			nop:	opalu<=4;
						
		endcase
	end
			

endmodule

`timescale 1ns / 1ps
module data_path(
    input clk,
    input rst,
    input [7:0] data_in,
    input insel,
    input we,
    input [2:0] raa,
    input [2:0] rab,
    input [2:0] wa,
    input [2:0] opalu,
    input [2:0] sh,
    input selpc,
	 input selk,
    input ldpc,
	 input ldflag,
	 input wr_en, rd_en,
	 input [10:0] ninst_addr,
	 input [7:0] kte,
	 input [7:0] imm,
	 input selimm,
    output [7:0] data_out,
    output [10:0] inst_addr,
	 output [10:0] stack_addr,
	 output reg z,c
    );

wire [7:0] regmux, muxkte, muximm;
wire [7:0] portA, portB;
wire [7:0] aluresu;
wire zero,carry;
wire [7:0] shiftout;

reg [10:0] PC;
wire [10:0] fifo_out;

regfile registros(regmux,clk,we,wa,raa,rab,portA,portB);
ALU alui(portA,muximm,aluresu,opalu,zero,carry);
shiftbyte shif_reg(aluresu,shiftout,sh);
LIFO LIFOi(clk,rst,wr_en,rd_en,PC,fifo_out);

assign stack_addr=fifo_out+1;
assign regmux=insel? shiftout : muxkte;
assign muxkte=selk? kte : data_in;
assign muximm=selimm? imm : portB;

always@(posedge clk or posedge rst)
	if (rst)
		begin
			z<=0;
			c<=0;
		end
	else
		if (ldflag)	
			begin
				z<=zero;
				c<=carry;
			end

always@(posedge clk or posedge rst)
	if (rst)
		PC<=0;
	else
		if (ldpc)	
			if(selpc)
				PC<=ninst_addr;
			else
				PC<=PC+1;

assign inst_addr=PC;
assign data_out=shiftout;

endmodule
`timescale 1ns / 1ps
module instruction_memory(
    input clk,
    input [10:0] address,
    output reg [15:0] instruction
    );

   
   (* RAM_STYLE="BLOCK" *)
   
	reg [15:0] rom [2047:0];
   wire we;
   initial
      $readmemh("instructions.mem", rom, 0, 2047);
		
	assign we=0;

   always @(posedge clk)
		if(we)
			rom[address]<=0;
		else
			instruction <= rom[address];
		
		
	

endmodule

`timescale 1ns / 1ps
module LIFO(
    input clk,
	 input rst,
    input wr_en,
    input rd_en,
    input [10:0] din,
    output [10:0] dout
    );


   (* RAM_STYLE="DISTRIBUTED" *)
   reg [3:0] addr;
	reg [10:0] ram [15:0];

   always@(posedge clk)
		if (rst)
			addr<=0;
		else 
			 begin 
			  if (wr_en==0 && rd_en==1)  
					if (addr>0)
						addr<=addr-1;
			  if (wr_en==1 && rd_en==0)  
					if (addr<15)
						addr<=addr+1;
			 end
		
	always @(posedge clk)
      if (wr_en)
         ram[addr] <= din;

   assign dout = ram[addr];   

endmodule

`timescale 1ns / 1ps
module memram(
    input clk,
    input [7:0] din,
    input [4:0] addr,
    output [7:0] dout,
    input we
    );

   (* RAM_STYLE="DISTRIBUTED" *)
   
	reg [7:0] ram [31:0];

   always @(posedge clk)
      if (we)
         ram[addr] <= din;

   assign dout = ram[addr];   
					

endmodule

`timescale 1ns / 1ps
module mem_video(
    input clk,
	 input we,
    input [12:0] addr_write,
    input [12:0] addr_read,
    input [3:0] din,
    output reg [3:0] dout
    );

	(* RAM_STYLE="BLOCK" *)
	 reg [3:0] ram_video [8191:0];
	
	  
   always @(posedge clk) 
		begin
			if (we)
				ram_video[addr_write] <= din;
			dout <= ram_video[addr_read];
		end
		
endmodule

`timescale 1ns / 1ps
module natalius_processor(
    input clk,
    input rst,
    output [7:0] port_addr,
    output read_e,
    output write_e,
    input [7:0] data_in,
    output [7:0] data_out    
    );

wire z,c;
wire insel;
wire we;
wire [2:0] raa;
wire [2:0] rab;
wire [2:0] wa;
wire [2:0] opalu;
wire [2:0] sh;
wire selpc;
wire ldpc;
wire ldflag;
wire [10:0] ninst_addr;
wire selk;
wire [7:0] KTE;
wire [10:0] stack_addr;
wire wr_en, rd_en;
wire [7:0] imm;
wire selimm;
wire [15:0] instruction;
wire [10:0] inst_addr;

control_unit control_unit_i(clk,rst,instruction,z,c,port_addr,write_e,read_e,insel,we,raa,rab,wa,opalu,sh,selpc,ldpc,ldflag,ninst_addr,selk,KTE,stack_addr,wr_en,rd_en,imm,selimm);
data_path data_path_i(clk,rst,data_in,insel,we,raa,rab,wa,opalu,sh,selpc,selk,ldpc,ldflag,wr_en,rd_en,ninst_addr,KTE,imm,selimm, data_out,inst_addr,stack_addr,z,c);
instruction_memory inst_mem(clk,inst_addr,instruction);

endmodule

`timescale 1ns / 1ps
module top(
    input clk,
    input rst,
	 input up1, down1, up2, down2,
	 output hs,vs,
	 output r,g,b
    );


wire [7:0] data_in;
wire [7:0] port_addr;
wire [7:0] data_out;
wire write_e;

reg [3:0] sw;
reg rst_ext;
reg [6:0] col;
reg [5:0] row;
reg [2:0] color;
reg we;

wire [12:0] addr_write, addr_read;
wire [3:0] doutb;
wire [2:0] color_out;
wire [7:0] mem_out;


always@(posedge clk)
	if (rst_ext==1 || rst==1)
		sw<=0;
	else
		begin
			if (up1) 	sw[0]<=1'b1;
			if (down1)  sw[1]<=1'b1;
			if (up2)    sw[2]<=1'b1;
			if (down2)  sw[3]<=1'b1;
		end 
		
always@(posedge clk or posedge rst)
	if (rst)
		col<=0;
	else
		if (port_addr[7:5]==3'b001 && write_e==1)
			col<=data_out[6:0];
			
			
always@(posedge clk or posedge rst)
	if (rst)
		row<=0;
	else
		if (port_addr[7:5]==3'b010 && write_e==1)
			row<=data_out[5:0];
			

always@(posedge clk or posedge rst)
	if (rst)
		color<=0;
	else
		if (port_addr[7:5]==3'b011 && write_e==1)
			color<=data_out[2:0];
			
always@(posedge clk or posedge rst)
	if (rst)
		we<=0;
	else
		if (port_addr[7:5]==3'b101 && write_e==1)
			we<=data_out[0];			
			
always@(posedge clk or posedge rst)
	if (rst)
		rst_ext<=0;
	else
		if (port_addr[7:5]==3'b100 && write_e==1)
			rst_ext<=data_out[0];

assign data_in=(port_addr[7:5]==000) ? mem_out : {4'b0000,sw}; 						

assign addr_write={row, col};

natalius_processor processor(clk,rst,port_addr,read_e,write_e,data_in,data_out);
memram ram_memory(clk,data_out,port_addr[4:0],mem_out,write_e);
mem_video video_mem(clk,we,addr_write,addr_read,{1'b0,color},doutb);
vga_control video_cntrl(clk,rst,doutb[2:0],hs,vs,color_out,addr_read);

assign r=color_out[2];
assign g=color_out[1];
assign b=color_out[0];

endmodule

`timescale 1ns / 1ps
module regfile(
    input [7:0] datain,
    input clk, we,
    input [2:0] wa,
    input [2:0] raa,
    input [2:0] rab,
    output [7:0] porta,
    output [7:0] portb
    );


reg [7:0] mem [7:0];

    always@(posedge clk)
	 begin
		 mem[0]<=0;
		 if(we) 
			mem[wa]<=datain;
	 end	 
	
assign porta=mem[raa];
assign portb=mem[rab];


endmodule


`timescale 1ns / 1ps
module shiftbyte(
    input [7:0] din,
    output reg [7:0] dshift,
    input [2:0] sh
    );

	always@*
		case (sh)
			0: dshift <= {din[6:0], 0};
			1: dshift <= {din[6:0], din[7]};
			2: dshift <= {0, din[7:1]};
			3: dshift <= {din[0], din[7:1]};
			4: dshift <= din;
			5: dshift <= {din[6:0], 1};
			6: dshift <= {1, din[7:1]};
			default: dshift <= din;
		endcase

endmodule

`timescale 1ns / 1ps
module vga_control(
    input clk,
    input rst,
	 input [2:0] ncolor,
    output reg hs, vs,
	 output [2:0] color,
    output [12:0] addrb
    );

reg [9:0] hcnt;
reg [8:0] vcnt;
reg clk25;

reg hsync, vsync;
wire [6:0] x;
wire [5:0] y;
wire blank;

always@(posedge clk or posedge rst)
	if (rst)
		clk25<=0;
	else
		clk25<=~clk25;

always@(posedge clk25 or posedge rst)
	if (rst)
		hcnt<=0;
	else
		if (hcnt<800)
			hcnt<=hcnt+1;
		else
			hcnt<=0;

always@(posedge clk25 or posedge rst)
	if (rst)
		vcnt<=0;
	else
		if (hcnt==0)
			if (vcnt<524)
				vcnt<=vcnt+1;
			else
			   vcnt<=0;

always@(posedge clk25 or posedge rst)
	if (rst)
		hsync<=1;
	else
		if (hcnt>=656 && hcnt<752)
			hsync<=0;
		else
			hsync<=1;

always@(posedge clk25 or posedge rst)
	if (rst)
		vsync<=1;
	else
		if (vcnt>=491 && vcnt<493)
			vsync<=0;
		else
			vsync<=1;

assign blank=(hcnt>=640 || vcnt>=480)? 1: 0;

always@(posedge clk or posedge rst)
	if (rst) 
		begin
			hs<=1;
			vs<=1; 
		end
	else 
		begin
			hs<=hsync;
			vs<=vsync;
		end

assign color=blank? 0: ncolor;
			
assign x=hcnt[9:3];
assign y=vcnt[8:3];
assign addrb={y, x};


endmodule



