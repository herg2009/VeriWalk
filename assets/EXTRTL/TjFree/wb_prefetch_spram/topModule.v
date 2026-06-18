

module generic_spram(
	
	clk, rst, ce, we, oe, addr, di, do
);

parameter aw = 13;
parameter dw = 32;

input			clk;	
input			rst;	
input			ce;	
input			we;	
input			oe;	
input 	[aw-1:0]	addr;	
input	[dw-1:0]	di;	
output	[dw-1:0]	do;	



`ifdef ARTISAN_SSP

art_hssp_8192x32 #(dw, 2<<aw, aw) artisan_ssp(
	.CLK(clk),
	.CEN(~ce),
	.WEN(~we),
	.A(addr),
	.D(di),
	.OEN(~oe),
	.Q(do)
);

`else

`ifdef AVANT_ATP

avant_atp avant_atp(
	.web(~we),
	.reb(),
	.oeb(~oe),
	.rcsb(),
	.wcsb(),
	.ra(addr),
	.wa(addr),
	.di(di),
	.do(do)
);

`else

`ifdef VIRAGE_SSP

virage_ssp virage_ssp(
	.clk(clk),
	.adr(addr),
	.d(di),
	.we(we),
	.oe(oe),
	.me(ce),
	.q(do)
);

`else

`ifdef VIRTUALSILICON_SSP

virtualsilicon_ssp #(2<<aw, aw-1, dw-1) virtualsilicon_ssp(
	.CK(clk),
	.ADR(addr),
	.DI(di),
	.WEN(~we),
	.CEN(~ce),
	.OEN(~oe),
	.DOUT(do)
);

`else

`ifdef XILINX_RAMB4_S16

ramb4_s16 ramb4_s16(
	.clk(clk),
	.rst(rst),
	.addr(addr),
	.di(di),
	.en(ce),
	.we(we),
	.do(do)
);

`else


reg	[dw-1:0]	mem [(2<<aw)-1:0];	
reg	[dw-1:0]	do_reg;			

assign do = (oe) ? do_reg : {dw{1'bz}};

always @(posedge clk)
	if (ce && !we)
		do_reg <= #1 mem[addr];
	else if (ce && we) begin
		mem[addr] <= #1 di;
		do_reg <= #1 di;
	end

`endif	
`endif	
`endif	
`endif  
`endif	

endmodule



`define BURST_BITS 1:0
`define FIXED_LOW_BIT 2

`define STRICT_32BIT_ACCESS

module top #(
	parameter		dw = 32,
	parameter		aw = 13
)(
	
	clk_i, rst_i, cyc_i, adr_i, dat_i, sel_i, we_i, stb_i,
	dat_o, ack_o, err_o
);

parameter aw = 12;
parameter dw = 32;

input			clk_i;	
input			rst_i;	
input			cyc_i;	
input 	[aw-1:0]	adr_i;	
input	[dw-1:0]	dat_i;	
input	[3:0]		sel_i;	
input			we_i;	
input			stb_i;	
output	[dw-1:0]	dat_o;	
output			ack_o;	
output			err_o;	

wire	[aw-1:0]	predicted_addr;	
wire	[aw-1:0]	ram_addr;	
wire			correct_data;	
reg	[aw-1:0]	last_addr;	
wire			valid_cycle;	


`ifdef STRICT_32BIT_ACCESS
assign err_o = valid_cycle & (sel_i != 4'b1111);
`else
assign err_o = 1'b0;
`endif

assign valid_cycle = cyc_i & stb_i;

assign predicted_addr = { last_addr[aw-1:`FIXED_LOW_BIT], last_addr[`BURST_BITS] + 1'b1 };

assign ram_addr = (~correct_data | we_i) ? adr_i : predicted_addr;

assign correct_data = (adr_i == last_addr);

assign ack_o = (correct_data | we_i) & valid_cycle;

always @(posedge clk_i or posedge rst_i)
	if (rst_i)
		last_addr <= #1 {aw{1'b0}};
	else if (valid_cycle)
		last_addr <= #1 ram_addr;

generic_spram #(aw, dw) spram (
	.clk(clk_i),
	.rst(rst_i),
	.addr(ram_addr),
	.di(dat_i),
	.ce(valid_cycle),
	.we(we_i),
	.oe(valid_cycle),
	.do(dat_o)
);

endmodule



