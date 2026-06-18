/* ===============================================================
	(C) 2006 Robert Finch
	All rights reserved.
	rob@birdcomputer.ca

	change_det.v
	- detects a change in a value

	This source code is free for use and modification for
	non-commercial or evaluation purposes, provided this
	copyright statement and disclaimer remains present in
	the file.

	If you do modify the code, please state the origin and
	note that you have modified the code.

	NO WARRANTY.
	THIS Work, IS PROVIDEDED "AS IS" WITH NO WARRANTIES OF
	ANY KIND, WHETHER EXPRESS OR IMPLIED. The user must assume
	the entire risk of using the Work.

	IN NO EVENT SHALL THE AUTHOR OR CONTRIBUTORS BE LIABLE FOR
	ANY INCIDENTAL, CONSEQUENTIAL, OR PUNITIVE DAMAGES
	WHATSOEVER RELATING TO THE USE OF THIS WORK, OR YOUR
	RELATIONSHIP WITH THE AUTHOR.

	IN ADDITION, IN NO EVENT DOES THE AUTHOR AUTHORIZE YOU
	TO USE THE WORK IN APPLICATIONS OR SYSTEMS WHERE THE
	WORK'S FAILURE TO PERFORM CAN REASONABLY BE EXPECTED
	TO RESULT IN A SIGNIFICANT PHYSICAL INJURY, OR IN LOSS
	OF LIFE. ANY SUCH USE BY YOU IS ENTIRELY AT YOUR OWN RISK,
	AND YOU AGREE TO HOLD THE AUTHOR AND CONTRIBUTORS HARMLESS
	FROM ANY CLAIMS OR LOSSES RELATING TO SUCH UNAUTHORIZED
	USE.

=============================================================== */

module change_det(rst, clk, ce, i, cd);
	parameter WID=32;
	input rst;			
	input clk;			
	input ce;			
	input [WID:1] i;	
	output cd;			

	reg [WID:1] hold;

	always @(posedge clk)
		if (rst)
			hold <= i;
		else if (ce)
			hold <= i;

	assign cd = i != hold;

endmodule

module counter(rst, clk, ce, ld, d, q);
parameter WID=8;
input rst;
input clk;
input ce;
input ld;
input [WID:1] d;
output [WID:1] q;
reg [WID:1] q;

always @(posedge clk)
if (rst)
	q <= 0;
else if (ce) begin
	if (ld)
		q <= d;
	else
		q <= q + 1;
end

endmodule


module HVCounter(
	rst, vclk, pixcce, sync, cnt_offs, pixsz, maxpix, nxt_pix, pos, nxt_pos, ctr
);
input rst;
input vclk;				
input pixcce;			
input sync;				
input [11:0] cnt_offs;	
input [3:0] pixsz;		
input [4:0] maxpix;		
output nxt_pix;			
output [11:0] pos;		
output nxt_pos;			
output [11:0] ctr;		

reg [11:0] pos;
reg [11:0] ctr;
reg nxt_pix;

wire [11:0] ctr1;
wire nxp;
reg [23:0] x4096;

reg [11:0] inv;
always @(posedge vclk)
	case(maxpix)
	5'd00:	inv <= 12'd4095;
	5'd01:	inv <= 12'd2048;
	5'd02:	inv <= 12'd1365;
	5'd03:  inv <= 12'd1024;
	5'd04:	inv <= 12'd0819;
	5'd05:	inv <= 12'd0683;
	5'd06:	inv <= 12'd0585;
	5'd07:	inv <= 12'd0512;
	5'd08:	inv <= 12'd0455;
	5'd09:	inv <= 12'd0409;
	5'd10:	inv <= 12'd0372;
	5'd11:	inv <= 12'd0341;
	5'd12:	inv <= 12'd0315;
	5'd13:	inv <= 12'd0292;
	5'd14:	inv <= 12'd0273;
	5'd15:	inv <= 12'd0256;
	5'd16:	inv <= 12'd0240;
	5'd17:	inv <= 12'd0227;
	5'd18:	inv <= 12'd0215;
	5'd19:	inv <= 12'd0204;
	5'd20:	inv <= 12'd0195;
	5'd21:	inv <= 12'd0186;
	5'd22:	inv <= 12'd0178;
	5'd23:	inv <= 12'd0170;
	5'd24:	inv <= 12'd0163;
	5'd25:	inv <= 12'd0157;
	5'd26:	inv <= 12'd0151;
	5'd27:	inv <= 12'd0146;
	5'd28:	inv <= 12'd0141;
	5'd29:	inv <= 12'd0136;
	5'd30:	inv <= 12'd0132;
	5'd31:	inv <= 12'd0128;
	endcase


always @(posedge vclk)
	x4096 <= ctr * inv;
always @(x4096)
	pos <= x4096[23:12];
always @(posedge vclk)		
	ctr <= ctr1;
always @(posedge vclk)
	nxt_pix <= nxp;

VT163 #(4) u1
(
	.clk(vclk),
	.clr_n(!rst),
	.ent(pixcce),
	.enp(1'b1),
	.ld_n(!sync & !nxp),		
	.d(4'hF-pixsz),
	.q(),
	.rco(nxp)
);


VT163 #(12) u2
(
	.clk(vclk),
	.clr_n(!rst),
	.ent(nxp),
	.enp(1'b1),
	.ld_n(!sync),					
	.d(12'h000-cnt_offs),
	.q(ctr1),
	.rco()
);


change_det #(12) u3
(
	.rst(rst),
	.clk(vclk),
	.ce(nxt_pix),
	.i(pos),
	.cd(nxt_pos)
);

endmodule

/* ============================================================================
	2006,2007,2011  Robert T Finch
	robfinch@<remove>sympatico.ca

	ParallelToSerial.v
		Parallel to serial data converter (shift register).

    This source code is available for evaluation and validation purposes
    only. This copyright statement and disclaimer must remain present in
    the file.


	NO WARRANTY.
    THIS Work, IS PROVIDEDED "AS IS" WITH NO WARRANTIES OF ANY KIND, WHETHER
    EXPRESS OR IMPLIED. The user must assume the entire risk of using the
    Work.

    IN NO EVENT SHALL THE AUTHOR OR CONTRIBUTORS BE LIABLE FOR ANY
    INCIDENTAL, CONSEQUENTIAL, OR PUNITIVE DAMAGES WHATSOEVER RELATING TO
    THE USE OF THIS WORK, OR YOUR RELATIONSHIP WITH THE AUTHOR.

    IN ADDITION, IN NO EVENT DOES THE AUTHOR AUTHORIZE YOU TO USE THE WORK
    IN APPLICATIONS OR SYSTEMS WHERE THE WORK'S FAILURE TO PERFORM CAN
    REASONABLY BE EXPECTED TO RESULT IN A SIGNIFICANT PHYSICAL INJURY, OR IN
    LOSS OF LIFE. ANY SUCH USE BY YOU IS ENTIRELY AT YOUR OWN RISK, AND YOU
    AGREE TO HOLD THE AUTHOR AND CONTRIBUTORS HARMLESS FROM ANY CLAIMS OR
    LOSSES RELATING TO SUCH UNAUTHORIZED USE.


	Webpack 9.1i xc3s1000-4ft256	
	LUTs / slices / MHz
	block rams

============================================================================ */

module ParallelToSerial(rst, clk, ce, ld, qin, d, qh);
	parameter WID=8;
	input rst;			
	input clk;			
	input ce;			
	input ld;			
	input qin;			
	input [WID:1] d;	
	output qh;			

	reg [WID:1] q;

	always @(posedge clk)
		if (rst)
			q <= 0;
		else if (ce) begin
			if (ld)
				q <= d;
			else
				q <= {q[WID-1:1],qin};
		end

	assign qh = q[WID];

endmodule



`define TC64_BLACK			5'd0
`define TC64_WHITE			5'd1
`define TC64_RED			5'd2
`define TC64_CYAN			5'd3
`define TC64_PURPLE			5'd4
`define TC64_GREEN			5'd5
`define TC64_BLUE			5'd6
`define TC64_YELLOW			5'd7
`define TC64_ORANGE			5'd8
`define TC64_BROWN			5'd9
`define TC64_PINK			5'd10
`define TC64_DARK_GREY		5'd11
`define TC64_MEDIUM_GREY	5'd12
`define TC64_LIGHT_GREEN	5'd13
`define TC64_LIGHT_BLUE		5'd14
`define TC64_LIGHT_GREY		5'd15

`define TC64_BLACKa			5'd16
`define TC64_WHITEa			5'd17
`define TC64_REDa			5'd18
`define TC64_CYANa			5'd19
`define TC64_PURPLEa		5'd20
`define TC64_GREENa			5'd21
`define TC64_BLUEa			5'd22
`define TC64_YELLOWa		5'd23
`define TC64_ORANGEa		5'd24
`define TC64_BROWNa			5'd25
`define TC64_PINKa			5'd26
`define TC64_DARK_GREYa		5'd27
`define TC64_GREY3			5'd28
`define TC64_LIGHT_GREENa	5'd29
`define TC64_LIGHT_BLUEa	5'd30
`define TC64_GREY5			5'd31

module rtfColorROM(clk, ce, code, color);
input clk;
input ce;
input [4:0] code;
output [23:0] color;
reg [23:0] color;

always @(posedge clk)
	if (ce) begin
		case (code)
		`TC64_BLACK:	 	color = 24'h10_10_10;
		`TC64_WHITE:	 	color = 24'hFF_FF_FF;
		`TC64_RED:    		color = 24'hE0_40_40;
		`TC64_CYAN:   		color = 24'h60_FF_FF;
		`TC64_PURPLE: 		color = 24'hE0_60_E0;
		`TC64_GREEN:	 	color = 24'h40_E0_40;
		`TC64_BLUE:   		color = 24'h40_40_E0;
		`TC64_YELLOW: 		color = 24'hFF_FF_40;
		`TC64_ORANGE: 		color = 24'hE0_A0_40;
		`TC64_BROWN:  		color = 24'h9C_74_48;
		`TC64_PINK:   		color = 24'hFF_A0_A0;
		`TC64_DARK_GREY:   	color = 24'h54_54_54;
		`TC64_MEDIUM_GREY: 	color = 24'h88_88_88;
		`TC64_LIGHT_GREEN: 	color = 24'hA0_FF_A0;
		`TC64_LIGHT_BLUE:  	color = 24'hA0_A0_FF;
		`TC64_LIGHT_GREY:  	color = 24'hC0_C0_C0;

		`TC64_BLACKa:	 	color = 24'h10_10_10;
		`TC64_WHITEa:	 	color = 24'hFF_FF_FF;
		`TC64_REDa:    		color = 24'hE0_40_40;
		`TC64_CYANa:   		color = 24'h60_FF_FF;
		`TC64_PURPLEa: 		color = 24'hE0_60_E0;
		`TC64_GREENa:	 	color = 24'h40_E0_40;
		`TC64_BLUEa:   		color = 24'h40_40_E0;
		`TC64_YELLOWa: 		color = 24'hFF_FF_40;
		`TC64_ORANGEa: 		color = 24'hE0_A0_40;
		`TC64_BROWNa:  		color = 24'h9C_74_48;
		`TC64_PINKa:   		color = 24'hFF_A0_A0;
		`TC64_DARK_GREYa:   color = 24'h54_54_54;
		`TC64_GREY3: 		color = 24'h30_30_30;
		`TC64_LIGHT_GREENa: color = 24'hA0_FF_A0;
		`TC64_LIGHT_BLUEa:  color = 24'hA0_A0_FF;
		`TC64_GREY5:  		color = 24'h50_50_50;

		endcase
	end

endmodule




module rtfTextController(
	rst_i, clk_i,
	cyc_i, stb_i, ack_o, we_i, sel_i, adr_i, dat_i, dat_o,
	lp, curpos,
	vclk, eol, eof, blank, border, rgbIn, rgbOut
);
parameter COLS = 12'd56;
parameter ROWS = 12'd31;

input  rst_i;			
input  clk_i;			

input  cyc_i;			
input  stb_i;			
output ack_o;			
input  we_i;			
input  [ 1:0] sel_i;	
input  [63:0] adr_i;	
input  [15:0] dat_i;	
output [15:0] dat_o;	
reg    [15:0] dat_o;

input lp;				
input [15:0] curpos;	

input vclk;				
input eol;				
input eof;				
input blank;			
input border;			
input [24:0] rgbIn;		
output reg [24:0] rgbOut;	


wire [23:0] bkColor24;	
wire [23:0] fgColor24;	
wire [23:0] tcColor24;	

wire pix;				

reg [15:0] rego;
reg [11:0] windowTop;
reg [11:0] windowLeft;
reg [11:0] numCols;
reg [11:0] numRows;
reg [ 1:0] mode;
reg [ 4:0] maxScanline;
reg [ 4:0] maxScanpix;
reg [ 4:0] cursorStart, cursorEnd;
reg [15:0] cursorPos;
reg [15:0] startAddress;
reg [ 2:0] rBlink;
reg [ 3:0] bdrColorReg;
reg [ 3:0] pixelWidth;	
reg [ 3:0] pixelHeight;	

wire [11:0] hctr;		
wire [11:0] scanline;	
wire [11:0] row;		
wire [11:0] col;		
reg  [ 4:0] rowscan;	
wire nxt_row;			
wire nxt_col;			
wire [ 5:0] bcnt;		
wire blink;
reg  iblank;

wire nhp;				
wire ld_shft = nxt_col & nhp;


reg [15:0] txtAddr;		
reg [15:0] penAddr;
wire [8:0] txtOut;		
wire [8:0] charOut;		
wire [3:0] txtBkCode;	
wire [4:0] txtFgCode;	
reg  [4:0] txtTcCode;	
reg  bgt;

wire [8:0] tdat_o;
wire [8:0] cdat_o;
wire [8:0] chdat_o;

wire [2:0] scanindex = scanline[2:0];


wire cs_text = cyc_i && stb_i && (adr_i[63:16]==48'hFFFF_FFFF_FFD0);
wire cs_color= cyc_i && stb_i && (adr_i[63:16]==48'hFFFF_FFFF_FFD1);
wire cs_rom  = cyc_i && stb_i && (adr_i[63:16]==48'hFFFF_FFFF_FFD2);
wire cs_reg  = cyc_i && stb_i && (adr_i[63: 8]==56'hFFFF_FFFF_FFDA_00);
wire cs_any = cs_text|cs_color|cs_rom|cs_reg;

always @(posedge clk_i)
	if (cs_text) dat_o <= tdat_o;
	else if (cs_color) dat_o <= cdat_o;
	else if (cs_rom) dat_o <= chdat_o;
	else if (cs_reg) dat_o <= rego;
	else dat_o <= 16'h0000;



wire [17:0] rowcol = row * numCols;
always @(posedge vclk)
	txtAddr <= startAddress + rowcol + col;

syncRam4kx9_1rw1r textRam0
(
	.wclk(clk_i),
	.wadr(adr_i[13:1]),
	.i(dat_i),
	.wo(tdat_o),
	.wce(cs_text),
	.we(we_i),
	.wrst(1'b0),

	.rclk(vclk),
	.radr(txtAddr[12:0]),
	.o(txtOut),
	.rce(ld_shft),
	.rrst(1'b0)
);

syncRam4kx9_1rw1r colorRam0
(
	.wclk(clk_i),
	.wadr(adr_i[13:1]),
	.i(dat_i),
	.wo(cdat_o),
	.wce(cs_color),
	.we(we_i),
	.wrst(1'b0),

	.rclk(vclk),
	.radr(txtAddr[12:0]),
	.o({txtBkCode,txtFgCode}),
	.rce(ld_shft),
	.rrst(1'b0)
);


syncRam4kx9_1rw1r charRam0
(
	.wclk(clk_i),
	.wadr(adr_i[11:0]),
	.i(dat_i),
	.wo(chdat_o),
	.wce(cs_rom),
	.we(1'b0),
	.wrst(1'b0),

	.rclk(vclk),
	.radr({txtOut,rowscan[2:0]}),
	.o(charOut),
	.rce(ld_shft),
	.rrst(1'b0)
);


reg [3:0] txtBkCode1;
reg [4:0] txtFgCode1;
always @(posedge vclk)
	if (nhp & ld_shft) txtBkCode1 <= txtBkCode;
always @(posedge vclk)
	if (nhp & ld_shft) txtFgCode1 <= txtFgCode;

reg ramRdy,ramRdy1;
always @(posedge clk_i)
begin
	ramRdy1 <= cs_any & !(ramRdy1|ramRdy);
	ramRdy <= ramRdy1 & cs_any;
end

assign ack_o = (cyc_i & stb_i) ? (we_i ? cs_any : ramRdy) : 1'b0;



wire lpe;
edge_det u1 (.rst(rst_i), .clk(clk_i), .ce(1'b1), .i(lp), .pe(lpe), .ne(), .ee() );

always @(posedge clk_i)
	if (rst_i)
		penAddr <= 32'h0000_0000;
	else begin
		if (lpe)
			penAddr <= txtAddr;
	end


always @(cs_reg or cursorPos or penAddr or adr_i)
	if (cs_reg) begin
		case(adr_i[4:1])
		4'd0:		rego <= numCols;
		4'd1:		rego <= numRows;
		4'd11:		rego <= cursorPos;
		4'd12:		rego <= penAddr;
		default:	rego <= 16'h0000;
		endcase
	end
	else
		rego <= 16'h0000;



reg interlace;
always @(posedge clk_i)
	if (rst_i) begin
/*
		windowTop    <= 12'd26;
		windowLeft   <= 12'd260;
		pixelWidth   <= 4'd0;
		pixelHeight  <= 4'd1;		
*/
		windowTop    <= 12'd12;
		windowLeft   <= 12'd128;
		pixelWidth   <= 4'd2;
		pixelHeight  <= 4'd2;		

		numCols      <= COLS;
		numRows      <= ROWS;
		maxScanline  <= 5'd7;
		maxScanpix   <= 5'd7;
		rBlink       <= 3'b111;		
		startAddress <= 16'h0000;
		cursorStart  <= 5'd00;
		cursorEnd    <= 5'd31;
		cursorPos    <= 16'h0003;
		txtTcCode    <= 5'd31;
	end
	else begin
		
		if (cs_reg & we_i) begin	

			case(adr_i[4:1])
			4'd00:	numCols    <= dat_i;		
			4'd01:	numRows    <= dat_i;
			4'd02:	windowLeft <= dat_i[11:0];
			4'd03:	windowTop  <= dat_i[11:0];		
			4'd04:	maxScanline <= dat_i[4:0];
			4'd05:	begin
					pixelHeight <= dat_i[7:4];
					pixelWidth  <= dat_i[3:0];	
					end
			4'd07:	txtTcCode   <= dat_i[4:0];
			4'd08:	begin
					cursorStart <= dat_i[4:0];	
					rBlink      <= dat_i[7:5];
					end
			4'd09:	cursorEnd   <= dat_i[4:0];	
			4'd10:	startAddress <= dat_i;
			4'd11:	cursorPos <= dat_i;
			endcase
		end
	end



reg [7:0] curout;
always @(scanindex)
	case(scanindex)
	3'd0:	curout = 8'b11111111;
	3'd1:	curout = 8'b10000001;
	3'd2:	curout = 8'b10000001;
	3'd3:	curout = 8'b10000001;
	3'd4:	curout = 8'b10000001;
	3'd5:	curout = 8'b10000001;
	3'd6:	curout = 8'b10011001;
	3'd7:	curout = 8'b11111111;
	endcase




HVCounter uhv1
(
	.rst(rst_i),
	.vclk(vclk),
	.pixcce(1'b1),
	.sync(eol),
	.cnt_offs(windowLeft),
	.pixsz(pixelWidth),
	.maxpix(maxScanpix),
	.nxt_pix(nhp),
	.pos(col),
	.nxt_pos(nxt_col),
	.ctr(hctr)
);


HVCounter uhv2
(
	.rst(rst_i),
	.vclk(vclk),
	.pixcce(eol),
	.sync(eof),
	.cnt_offs(windowTop),
	.pixsz(pixelHeight),
	.maxpix(maxScanline),
	.nxt_pix(nvp),
	.pos(row),
	.nxt_pos(nxt_row),
	.ctr(scanline)
);

always @(posedge vclk)
	rowscan <= scanline - row * (maxScanline+1);


VT163 #(6) ub1
(
	.clk(vclk),
	.clr_n(!rst_i),
	.ent(eol & eof),
	.enp(1'b1),
	.ld_n(1'b1),
	.d(6'd0),
	.q(bcnt)
);

wire blink_en = (cursorPos+2==txtAddr) && (scanline[4:0] >= cursorStart) && (scanline[4:0] <= cursorEnd);

VT151 ub2
(
	.e_n(!blink_en),
	.s(rBlink),
	.i0(1'b1), .i1(1'b0), .i2(bcnt[4]), .i3(bcnt[5]),
	.i4(1'b1), .i5(1'b0), .i6(bcnt[4]), .i7(bcnt[5]),
	.z(blink),
	.z_n()
);

rtfColorROM ucm1 (.clk(vclk), .ce(nhp & ld_shft), .code(txtBkCode1),  .color(bkColor24) );
rtfColorROM ucm2 (.clk(vclk), .ce(nhp & ld_shft), .code(txtFgCode1),  .color(fgColor24) );
always @(posedge vclk)
	if (nhp & ld_shft)
		bgt <= {1'b0,txtBkCode1}==txtTcCode;


wire [7:0] charRev = {
	charOut[0],
	charOut[1],
	charOut[2],
	charOut[3],
	charOut[4],
	charOut[5],
	charOut[6],
	charOut[7]
};

wire [7:0] charout1 = blink ? (charRev ^ curout) : charRev;

ParallelToSerial ups1
(
	.rst(rst_i),
	.clk(vclk),
	.ce(nhp),
	.ld(ld_shft),
	.qin(1'b0),
	.d(charout1),
	.qh(pix)
);


wire bpix = hctr[1] ^ scanline[4];
always @(posedge vclk)
	if (nhp)	
		iblank <= (row >= numRows) || (col >= numCols + 2) || (col < 2);
	

always @(posedge vclk)
	if (nhp) begin
		casex({blank,iblank,border,bpix,pix})
		5'b1xxxx:	rgbOut <= 25'h0000000;
		5'b01xxx:	rgbOut <= rgbIn;
		5'b0010x:	rgbOut <= 24'hBF2020;
		5'b0011x:	rgbOut <= 24'hDFDFDF;
		5'b000x0:	rgbOut <= bgt ? rgbIn : bkColor24;
		5'b000x1:	rgbOut <= fgColor24;
		default:	rgbOut <= rgbIn;
		endcase
	end

endmodule


`timescale 1ns / 1ps

module rtfTextController3(
	rst_i, clk_i,
	cyc_i, stb_i, ack_o, we_i, adr_i, dat_i, dat_o,
	lp, curpos,
	vclk, hsync, vsync, blank, border, rgbIn, rgbOut
);
parameter COLS = 12'd56;
parameter ROWS = 12'd31;
parameter pTextAddress = 32'hFFD00000;
parameter pBitmapAddress = 32'hFFD20000;
parameter pRegAddress = 32'hFFDA0000;

input  rst_i;			
input  clk_i;			

input  cyc_i;			
input  stb_i;			
output ack_o;			
input  we_i;			
input  [31:0] adr_i;	
input  [31:0] dat_i;	
output [31:0] dat_o;	
reg    [31:0] dat_o;

input lp;				
input [15:0] curpos;	

input vclk;				
input hsync;			
input vsync;			
input blank;			
input border;			
input [24:0] rgbIn;		
output reg [24:0] rgbOut;	


reg [23:0] bkColor24;	
reg [23:0] fgColor24;	
wire [23:0] tcColor24;	

wire pix;				

reg [15:0] rego;
reg [11:0] windowTop;
reg [11:0] windowLeft;
reg [11:0] numCols;
reg [11:0] numRows;
reg [11:0] charOutDelay;
reg [ 1:0] mode;
reg [ 4:0] maxScanline;
reg [ 4:0] maxScanpix;
reg [ 4:0] cursorStart, cursorEnd;
reg [15:0] cursorPos;
reg [1:0] cursorType;
reg [15:0] startAddress;
reg [ 2:0] rBlink;
reg [ 3:0] bdrColorReg;
reg [ 3:0] pixelWidth;	
reg [ 3:0] pixelHeight;	

wire [11:0] hctr;		
wire [11:0] scanline;	
wire [11:0] row;		
wire [11:0] col;		
reg  [ 4:0] rowscan;	
wire nxt_row;			
wire nxt_col;			
wire [ 5:0] bcnt;		
wire blink;
reg  iblank;

wire nhp;				
wire ld_shft = nxt_col & nhp;


reg [15:0] txtAddr;		
reg [15:0] penAddr;
wire [8:0] txtOut;		
wire [8:0] charOut;		
wire [8:0] txtBkColor;	
wire [8:0] txtFgColor;	
reg  [8:0] txtTcCode;	
reg  bgt;

wire [27:0] tdat_o;
wire [8:0] chdat_o;

wire [2:0] scanindex = scanline[2:0];


wire cs_text = cyc_i && stb_i && (adr_i[31:16]==pTextAddress[31:16]);
wire cs_rom  = cyc_i && stb_i && (adr_i[31:16]==pBitmapAddress[31:16]);
wire cs_reg  = cyc_i && stb_i && (adr_i[31: 8]==pRegAddress[31:8]);
wire cs_any = cs_text|cs_rom|cs_reg;

always @(posedge clk_i)
	if (cs_text) dat_o <= {4'd0,tdat_o};
	else if (cs_rom) dat_o <= {23'd0,chdat_o};
	else if (cs_reg) dat_o <= {16'd0,rego};
	else dat_o <= 32'h0000;



wire [17:0] rowcol = row * numCols;
always @(posedge vclk)
	txtAddr <= startAddress + rowcol[15:0] + col;

syncRam4kx9_1rw1r textRam0
(
	.wclk(clk_i),
	.wadr(adr_i[13:2]),
	.i(dat_i[8:0]),
	.wo(tdat_o[8:0]),
	.wce(cs_text),
	.we(we_i),
	.wrst(1'b0),

	.rclk(vclk),
	.radr(txtAddr[11:0]),
	.o(txtOut),
	.rce(ld_shft),
	.rrst(1'b0)
);

syncRam4kx9_1rw1r fgColorRam
(
	.wclk(clk_i),
	.wadr(adr_i[13:2]),
	.i(dat_i[18:10]),
	.wo(tdat_o[18:10]),
	.wce(cs_text),
	.we(we_i),
	.wrst(1'b0),

	.rclk(vclk),
	.radr(txtAddr[11:0]),
	.o(txtFgColor),
	.rce(ld_shft),
	.rrst(1'b0)
);

syncRam4kx9_1rw1r bkColorRam
(
	.wclk(clk_i),
	.wadr(adr_i[13:2]),
	.i(dat_i[27:19]),
	.wo(tdat_o[27:19]),
	.wce(cs_text),
	.we(we_i),
	.wrst(1'b0),

	.rclk(vclk),
	.radr(txtAddr[11:0]),
	.o(txtBkColor),
	.rce(ld_shft),
	.rrst(1'b0)
);


syncRam4kx9_1rw1r charRam0
(
	.wclk(clk_i),
	.wadr(adr_i[13:2]),
	.i(dat_i),
	.wo(chdat_o),
	.wce(cs_rom),
	.we(1'b0),
	.wrst(1'b0),

	.rclk(vclk),
	.radr({txtOut,rowscan[2:0]}),
	.o(charOut),
	.rce(ld_shft),
	.rrst(1'b0)
);


reg [8:0] txtBkCode1;
reg [8:0] txtFgCode1;
always @(posedge vclk)
	if (nhp & ld_shft) txtBkCode1 <= txtBkColor;
always @(posedge vclk)
	if (nhp & ld_shft) txtFgCode1 <= txtFgColor;

reg ramRdy,ramRdy1;
always @(posedge clk_i)
begin
	ramRdy1 <= cs_any;
	ramRdy <= ramRdy1 & cs_any;
end

assign ack_o = cs_any ? (we_i ? 1'b1 : ramRdy) : 1'b0;



wire lpe;
edge_det u1 (.rst(rst_i), .clk(clk_i), .ce(1'b1), .i(lp), .pe(lpe), .ne(), .ee() );

always @(posedge clk_i)
	if (rst_i)
		penAddr <= 32'h0000_0000;
	else begin
		if (lpe)
			penAddr <= txtAddr;
	end


always @(cs_reg or cursorPos or penAddr or adr_i or numCols or numRows)
	if (cs_reg) begin
		case(adr_i[5:2])
		4'd0:		rego <= numCols;
		4'd1:		rego <= numRows;
		4'd11:		rego <= cursorPos;
		4'd12:		rego <= penAddr;
		default:	rego <= 16'h0000;
		endcase
	end
	else
		rego <= 16'h0000;



reg interlace;
always @(posedge clk_i)
	if (rst_i) begin
/*
		windowTop    <= 12'd26;
		windowLeft   <= 12'd260;
		pixelWidth   <= 4'd0;
		pixelHeight  <= 4'd1;		
*/
/*
		
		windowTop    <= 12'd16;
		windowLeft   <= 12'd90;
		pixelWidth   <= 4'd1;		
		pixelHeight  <= 4'd1;		
*/
		
		windowTop    <= 12'd16;
		windowLeft   <= 12'd56;
		pixelWidth   <= 4'd2;		
		pixelHeight  <= 4'd2;		
		numCols      <= COLS;
		numRows      <= ROWS;
		maxScanline  <= 5'd7;
		maxScanpix   <= 5'd7;
		rBlink       <= 3'b111;		
		startAddress <= 16'h0000;
		cursorStart  <= 5'd00;
		cursorEnd    <= 5'd31;
		cursorPos    <= 16'h0003;
		cursorType 	 <= 2'b00;
		txtTcCode    <= 9'h1ff;
		charOutDelay <= 12'd2;
	end
	else begin
		
		if (cs_reg & we_i) begin	

			case(adr_i[5:2])
			4'd00:	begin
					numCols    <= dat_i[15:0];		
					charOutDelay <= dat_i[31:16];
					end
			4'd01:	numRows    <= dat_i;
			4'd02:	windowLeft <= dat_i[11:0];
			4'd03:	windowTop  <= dat_i[11:0];		
			4'd04:	maxScanline <= dat_i[4:0];
			4'd05:	begin
					pixelHeight <= dat_i[7:4];
					pixelWidth  <= dat_i[3:0];	
					end
			4'd07:	txtTcCode   <= dat_i[4:0];
			4'd08:	begin
					cursorStart <= dat_i[4:0];	
					rBlink      <= dat_i[7:5];
					cursorType  <= dat_i[9:8];
					end
			4'd09:	cursorEnd   <= dat_i[4:0];	
			4'd10:	startAddress <= dat_i;
			4'd11:	cursorPos <= dat_i;
			endcase
		end
	end



reg [7:0] curout;
always @(scanindex or cursorType)
	case({cursorType,scanindex})
	
	5'b00_000:	curout = 8'b11111111;
	5'b00_001:	curout = 8'b10000001;
	5'b00_010:	curout = 8'b10000001;
	5'b00_011:	curout = 8'b10000001;
	5'b00_100:	curout = 8'b10000001;
	5'b00_101:	curout = 8'b10000001;
	5'b00_110:	curout = 8'b10011001;
	5'b00_111:	curout = 8'b11111111;
	
	5'b01_000:	curout = 8'b11000000;
	5'b01_001:	curout = 8'b10000000;
	5'b01_010:	curout = 8'b10000000;
	5'b01_011:	curout = 8'b10000000;
	5'b01_100:	curout = 8'b10000000;
	5'b01_101:	curout = 8'b10000000;
	5'b01_110:	curout = 8'b10000000;
	5'b01_111:	curout = 8'b11000000;
	
	5'b10_000:	curout = 8'b00000000;
	5'b10_001:	curout = 8'b00000000;
	5'b10_010:	curout = 8'b00000000;
	5'b10_011:	curout = 8'b00000000;
	5'b10_100:	curout = 8'b00000000;
	5'b10_101:	curout = 8'b00000000;
	5'b10_110:	curout = 8'b00000000;
	5'b10_111:	curout = 8'b11111111;
	
	5'b11_000:	curout = 8'b00000000;
	5'b11_001:	curout = 8'b00000000;
	5'b11_010:	curout = 8'b00100100;
	5'b11_011:	curout = 8'b00011000;
	5'b11_100:	curout = 8'b01111110;
	5'b11_101:	curout = 8'b00011000;
	5'b11_110:	curout = 8'b00100100;
	5'b11_111:	curout = 8'b00000000;
	endcase



wire pe_hsync;
wire pe_vsync;
edge_det edh1
(
	.rst(rst_i),
	.clk(vclk),
	.ce(1'b1),
	.i(hsync),
	.pe(pe_hsync),
	.ne(),
	.ee()
);

edge_det edv1
(
	.rst(rst_i),
	.clk(vclk),
	.ce(1'b1),
	.i(vsync),
	.pe(pe_vsync),
	.ne(),
	.ee()
);

HVCounter uhv1
(
	.rst(rst_i),
	.vclk(vclk),
	.pixcce(1'b1),
	.sync(hsync),
	.cnt_offs(windowLeft),
	.pixsz(pixelWidth),
	.maxpix(maxScanpix),
	.nxt_pix(nhp),
	.pos(col),
	.nxt_pos(nxt_col),
	.ctr(hctr)
);


HVCounter uhv2
(
	.rst(rst_i),
	.vclk(vclk),
	.pixcce(pe_hsync),
	.sync(vsync),
	.cnt_offs(windowTop),
	.pixsz(pixelHeight),
	.maxpix(maxScanline),
	.nxt_pix(nvp),
	.pos(row),
	.nxt_pos(nxt_row),
	.ctr(scanline)
);

always @(posedge vclk)
	rowscan <= scanline - row * (maxScanline+1);


VT163 #(6) ub1
(
	.clk(vclk),
	.clr_n(!rst_i),
	.ent(pe_vsync),
	.enp(1'b1),
	.ld_n(1'b1),
	.d(6'd0),
	.q(bcnt),
	.rco()
);

wire blink_en = (cursorPos+2==txtAddr) && (scanline[4:0] >= cursorStart) && (scanline[4:0] <= cursorEnd);

VT151 ub2
(
	.e_n(!blink_en),
	.s(rBlink),
	.i0(1'b1), .i1(1'b0), .i2(bcnt[4]), .i3(bcnt[5]),
	.i4(1'b1), .i5(1'b0), .i6(bcnt[4]), .i7(bcnt[5]),
	.z(blink),
	.z_n()
);

always @(posedge vclk)
	if (nhp & ld_shft)
		bkColor24 <= {txtBkCode1[8:6],5'h10,txtBkCode1[5:3],5'h10,txtBkCode1[2:0],5'h10};
always @(posedge vclk)
	if (nhp & ld_shft)
		fgColor24 <= {txtFgCode1[8:6],5'h10,txtFgCode1[5:3],5'h10,txtFgCode1[2:0],5'h10};

always @(posedge vclk)
	if (nhp & ld_shft)
		bgt <= txtBkCode1==txtTcCode;


wire [7:0] charRev = {
	charOut[0],
	charOut[1],
	charOut[2],
	charOut[3],
	charOut[4],
	charOut[5],
	charOut[6],
	charOut[7]
};

wire [7:0] charout1 = blink ? (charRev ^ curout) : charRev;

ParallelToSerial ups1
(
	.rst(rst_i),
	.clk(vclk),
	.ce(nhp),
	.ld(ld_shft),
	.qin(1'b0),
	.d(charout1),
	.qh(pix)
);


wire bpix = hctr[1] ^ scanline[4];
always @(posedge vclk)
	if (nhp)	
		iblank <= (row >= numRows) || (col >= numCols + charOutDelay) || (col < charOutDelay);
	

always @(posedge vclk)
	if (nhp) begin
		casex({blank,iblank,border,bpix,pix})
		5'b1xxxx:	rgbOut <= 25'h0000000;
		5'b01xxx:	rgbOut <= rgbIn;
		5'b0010x:	rgbOut <= 24'hBF2020;
		5'b0011x:	rgbOut <= 24'hDFDFDF;
		5'b000x0:	rgbOut <= bgt ? rgbIn : bkColor24;
		5'b000x1:	rgbOut <= fgColor24;
		default:	rgbOut <= rgbIn;
		endcase
	end

endmodule


/* ===============================================================
	2008,2011  Robert Finch
	robfinch@sympatico.ca

	syncRam4kx9_1rw1r.v

	This source code is free for use and modification for
	non-commercial or evaluation purposes, provided this
	copyright statement and disclaimer remains present in
	the file.

	If you do modify the code, please state the origin and
	note that you have modified the code.

	NO WARRANTY.
	THIS Work, IS PROVIDEDED "AS IS" WITH NO WARRANTIES OF
	ANY KIND, WHETHER EXPRESS OR IMPLIED. The user must assume
	the entire risk of using the Work.

	IN NO EVENT SHALL THE AUTHOR OR CONTRIBUTORS BE LIABLE FOR
	ANY INCIDENTAL, CONSEQUENTIAL, OR PUNITIVE DAMAGES
	WHATSOEVER RELATING TO THE USE OF THIS WORK, OR YOUR
	RELATIONSHIP WITH THE AUTHOR.

	IN ADDITION, IN NO EVENT DOES THE AUTHOR AUTHORIZE YOU
	TO USE THE WORK IN APPLICATIONS OR SYSTEMS WHERE THE
	WORK'S FAILURE TO PERFORM CAN REASONABLY BE EXPECTED
	TO RESULT IN A SIGNIFICANT PHYSICAL INJURY, OR IN LOSS
	OF LIFE. ANY SUCH USE BY YOU IS ENTIRELY AT YOUR OWN RISK,
	AND YOU AGREE TO HOLD THE AUTHOR AND CONTRIBUTORS HARMLESS
	FROM ANY CLAIMS OR LOSSES RELATING TO SUCH UNAUTHORIZED
	USE.


=============================================================== */

`define SYNTHESIS
`define VENDOR_XILINX
`define SPARTAN3

module syncRam4kx9_1rw1r(
	input wrst,
	input wclk,
	input wce,
	input we,
	input [11:0] wadr,
	input [8:0] i,
	output [8:0] wo,
	input rrst,
	input rclk,
	input rce,
	input [11:0] radr,
	output [8:0] o
);

`ifdef SYNTHESIS
`ifdef VENDOR_XILINX

`ifdef SPARTAN3
	wire [8:0] o0;
	wire [8:0] o1;
	wire [8:0] wo0;
	wire [8:0] wo1;
	wire rrst0 =  radr[11];
	wire rrst1 = ~radr[11];
	wire wrst0 =  wadr[11];
	wire wrst1 = ~wadr[11];
	wire we0 = we & ~wadr[11];
	wire we1 = we &  wadr[11];

	RAMB16_S9_S9 ram0(
		.CLKA(wclk), .ADDRA(wadr), .DIA(i[7:0]), .DIPA(i[8]), .DOA(wo0[7:0]), .DOPA(wo0[8]), .ENA(wce), .WEA(we0), .SSRA(wrst0),
		.CLKB(rclk), .ADDRB(radr), .DIB(8'hFF), .DIPB(1'b1), .DOB(o0[7:0]), .DOPB(o0[8]), .ENB(rce), .WEB(1'b0), .SSRB(rrst0)  );
	RAMB16_S9_S9 ram1(
		.CLKA(wclk), .ADDRA(wadr), .DIA(i[7:0]), .DIPA(i[8]), .DOA(wo1[7:0]), .DOPA(wo1[8]), .ENA(wce), .WEA(we1), .SSRA(wrst1),
		.CLKB(rclk), .ADDRB(radr), .DIB(8'hFF), .DIPB(1'b1), .DOB(o1[7:0]), .DOPB(o1[8]), .ENB(rce), .WEB(1'b0), .SSRB(rrst1)  );

	assign o = o0|o1;
	assign wo = wo0|wo1;

`endif

`ifdef SPARTAN2
	RAMB4_S1_S1 ram0(
		.CLKA(wclk), .ADDRA(wadr), .DIA(i[0]), .DOA(wo[0]), .ENA(wce), .WEA(we), .RSTA(wrst),
		.CLKB(rclk), .ADDRB(radr), .DIB(1'b1), .DOB(o[0]), .ENB(rce), .WEB(1'b0), .RSTB(rrst)  );
	RAMB4_S1_S1 ram1(
		.CLKA(wclk), .ADDRA(wadr), .DIA(i[1]), .DOA(wo[1]), .ENA(wce), .WEA(we), .RSTA(wrst),
		.CLKB(rclk), .ADDRB(radr), .DIB(1'b1), .DOB(o[1]), .ENB(rce), .WEB(1'b0), .RSTB(rrst)  );
	RAMB4_S1_S1 ram2(
		.CLKA(wclk), .ADDRA(wadr), .DIA(i[2]), .DOA(wo[2]), .ENA(wce), .WEA(we), .RSTA(wrst),
		.CLKB(rclk), .ADDRB(radr), .DIB(1'b1), .DOB(o[2]), .ENB(rce), .WEB(1'b0), .RSTB(rrst)  );
	RAMB4_S1_S1 ram3(
		.CLKA(wclk), .ADDRA(wadr), .DIA(i[3]), .DOA(wo[3]), .ENA(wce), .WEA(we), .RSTA(wrst),
		.CLKB(rclk), .ADDRB(radr), .DIB(1'b1), .DOB(o[3]), .ENB(rce), .WEB(1'b0), .RSTB(rrst)  );
	RAMB4_S1_S1 ram4(
		.CLKA(wclk), .ADDRA(wadr), .DIA(i[4]), .DOA(wo[4]), .ENA(wce), .WEA(we), .RSTA(wrst),
		.CLKB(rclk), .ADDRB(radr), .DIB(1'b1), .DOB(o[4]), .ENB(rce), .WEB(1'b0), .RSTB(rrst)  );
	RAMB4_S1_S1 ram5(
		.CLKA(wclk), .ADDRA(wadr), .DIA(i[5]), .DOA(wo[5]), .ENA(wce), .WEA(we), .RSTA(wrst),
		.CLKB(rclk), .ADDRB(radr), .DIB(1'b1), .DOB(o[5]), .ENB(rce), .WEB(1'b0), .RSTB(rrst)  );
	RAMB4_S1_S1 ram6(
		.CLKA(wclk), .ADDRA(wadr), .DIA(i[6]), .DOA(wo[6]), .ENA(wce), .WEA(we), .RSTA(wrst),
		.CLKB(rclk), .ADDRB(radr), .DIB(1'b1), .DOB(o[6]), .ENB(rce), .WEB(1'b0), .RSTB(rrst)  );
	RAMB4_S1_S1 ram7(
		.CLKA(wclk), .ADDRA(wadr), .DIA(i[7]), .DOA(wo[7]), .ENA(wce), .WEA(we), .RSTA(wrst),
		.CLKB(rclk), .ADDRB(radr), .DIB(1'b1), .DOB(o[7]), .ENB(rce), .WEB(1'b0), .RSTB(rrst)  );
`endif

`endif

`ifdef VENDOR_ALTERA

	reg [8:0] mem [4095:0];
	reg [10:0] rradr;
	reg [10:0] rwadr;

	
	always @(posedge rclk)
		if (rce) rradr <= radr;

	assign o = mem[rradr];

	
	always @(posedge wclk)
		if (wce) rwadr <= wadr;

	always @(posedge wclk)
		if (wce) mem[wadr] <= i;

	assign wo = mem[rwadr];

`endif

`else

	reg [8:0] mem [4095:0];
	reg [10:0] rradr;
	reg [10:0] rwadr;

	
	always @(posedge rclk)
		if (rce) rradr <= radr;

	assign o = mem[rradr];

	
	always @(posedge wclk)
		if (wce) rwadr <= wadr;

	always @(posedge wclk)
		if (wce) mem[wadr] <= i;

	assign wo = mem[rwadr];

`endif

endmodule


module VT151(e_n, s, i0, i1, i2, i3, i4, i5, i6, i7, z, z_n);
	parameter WID=1;
	input e_n;
	input [2:0] s;
	input [WID:1] i0;
	input [WID:1] i1;
	input [WID:1] i2;
	input [WID:1] i3;
	input [WID:1] i4;
	input [WID:1] i5;
	input [WID:1] i6;
	input [WID:1] i7;
	output [WID:1] z;
	output [WID:1] z_n;

	reg [WID:1] z;

	always @(e_n or s or i0 or i1 or i2 or i3 or i4 or i5 or i6 or i7)
		case({e_n,s})
		4'b0000:	z <= i0;
		4'b0001:	z <= i1;
		4'b0010:	z <= i2;
		4'b0011:	z <= i3;
		4'b0100:	z <= i4;
		4'b0101:	z <= i5;
		4'b0110:	z <= i6;
		4'b0111:	z <= i7;
		default:	z <= {WID{1'b0}};
		endcase

	assign z_n = !z;

endmodule


module VT163(clk, clr_n, ent, enp, ld_n, d, q, rco);
	parameter WID=4;
	input clk;
	input clr_n;	
	input ent;		
	input enp;		
	input ld_n;		
	input [WID:1] d;
	output [WID:1] q;
	reg [WID:1] q;
	output rco;

	assign rco = &{q[WID:1],ent};

	always @(posedge clk)
		begin
			if (!clr_n)
				q <= {WID{1'b0}};
			else if (!ld_n)
				q <= d;
			else if (enp & ent)
				q <= q + {{WID-1{1'b0}},1'b1};
		end

endmodule


module WXGASyncGen1366x768_60Hz(rst, clk, hSync, vSync, blank, border);
parameter phSyncOn  = 72;		
parameter phSyncOff = 216;		
parameter phBlankOff = 434;		
parameter phBorderOff = 434;	
parameter phBorderOn = 1800;	
parameter phBlankOn = 1800;		
parameter phTotal = 1800;		
parameter pvSyncOn  = 2;		
parameter pvSyncOff = 5;		
parameter pvBlankOff = 27;		
parameter pvBorderOff = 27;		
parameter pvBorderOn = 795;		
parameter pvBlankOn = 795;  	
parameter pvTotal = 795;		
input rst;			
input clk;			
output reg hSync, vSync;	
output blank;			
output border;


wire [11:0] hCtr;	
wire [11:0] vCtr;	

wire vBlank, hBlank;
wire hSync1,vSync1;
reg blank;
reg border;

wire eol = hCtr==phTotal;
wire eof = vCtr==pvTotal && eol;

assign vSync1 = vCtr >= pvSyncOn && vCtr < pvSyncOff;
assign hSync1 = !(hCtr >= phSyncOn && hCtr < phSyncOff);
assign vBlank = vCtr >= pvBlankOn || vCtr < pvBlankOff;
assign hBlank = hCtr >= phBlankOn || hCtr < phBlankOff;
assign vBorder = vCtr >= pvBorderOn || vCtr < pvBorderOff;
assign hBorder = hCtr >= phBorderOn || hCtr < phBorderOff;

counter #(12) u1 (.rst(rst), .clk(clk), .ce(1'b1), .ld(eol), .d(12'd1), .q(hCtr) );
counter #(12) u2 (.rst(rst), .clk(clk), .ce(eol),  .ld(eof), .d(12'd1), .q(vCtr) );

always @(posedge clk)
    blank <= #1 hBlank|vBlank;
always @(posedge clk)
    border <= #1 hBorder|vBorder;
always @(posedge clk)
	hSync <= #1 hSync1;
always @(posedge clk)
	vSync <= #1 vSync1;

endmodule



module WXGASyncGen1680x1050_60Hz(rst, clk, hSync, vSync, blank, border, eol, eof);
parameter phSyncOn  = 48;		
parameter phSyncOff = 136;		
parameter phBlankOff = 280;		
parameter phBorderOff = 284;	
parameter phBorderOn = 1124;	
parameter phBlankOn = 1128;		
parameter phTotal = 1128;		
parameter pvSyncOn  = 1;		
parameter pvSyncOff = 4;		
parameter pvBlankOff = 34;		
parameter pvBorderOff = 36;		
parameter pvBorderOn = 1086;	
parameter pvBlankOn = 1087;  	
parameter pvTotal = 1087;		
input rst;			
input clk;			
output hSync, vSync;	
output blank;			
output border;
output eol;			
output eof;			


wire [11:0] hCtr;	
wire [11:0] vCtr;	

wire vBlank, hBlank;
reg blank;
reg border;

assign eol     = hCtr == phTotal;
assign eof     = vCtr == pvTotal && eol;

assign vSync = vCtr >= pvSyncOn && vCtr < pvSyncOff;
assign hSync = !(hCtr >= phSyncOn && hCtr < phSyncOff);
assign vBlank = vCtr >= pvBlankOn || vCtr < pvBlankOff;
assign hBlank = hCtr >= phBlankOn || hCtr < phBlankOff;
assign vBorder = vCtr >= pvBorderOn || vCtr < pvBorderOff;
assign hBorder = hCtr >= phBorderOn || hCtr < phBorderOff;

counter #(12) u1 (.rst(rst), .clk(clk), .ce(1'b1), .ld(eol), .d(12'd1), .q(hCtr) );
counter #(12) u2 (.rst(rst), .clk(clk), .ce(eol),  .ld(eof), .d(12'd1), .q(vCtr) );

always @(posedge clk)
    blank <= hBlank|vBlank;
always @(posedge clk)
    border <= hBorder|vBorder;

endmodule



module top();

reg clk;
reg rst;

initial begin
	clk = 1;
	rst = 0;
	#100 rst = 1;
	#100 rst = 0;
end

always #6.8000 clk = ~clk;	

WXGASyncGen1680x1050_60Hz u1
(
.rst(rst),
.clk(clk),
.hSync(),
.vSync(),
.blank(),
.border(),
.eol(),
.eof()
);

endmodule



