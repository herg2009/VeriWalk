


/*
	Baud rate Generator
	==================

	div0 -	is the first stage divider
		Set this to the desired number of cycles less two
	div1 -	is the second stage divider
		Set this to the actual number of cycles

	Remember you have to generate a baud rate that is 4 higher than what
	you really want. This is because of the DPLL in the RX section ...

	Example:
	If your system clock is 50MHz and you want to generate a 9.6 Kbps baud rate:
	9600*4 = 38400KHz
	50MHz/38400KHz=1302 or 6*217
	set div0=4 (6-2) and set div1=217

*/

module sasc_brg(clk, rst, div0, div1, sio_ce, sio_ce_x4);
input		clk;
input		rst;
input	[7:0]	div0, div1;
output		sio_ce, sio_ce_x4;


reg	[7:0]	ps;
reg		ps_clr;
reg	[7:0]	br_cnt;
reg		br_clr;
reg		sio_ce_x4_r;
reg	[1:0]	cnt;
reg		sio_ce, sio_ce_x4;
reg		sio_ce_r ;
reg		sio_ce_x4_t;


always @(posedge clk)
	if(!rst)	ps <= #1 8'h0;
	else
	if(ps_clr)	ps <= #1 8'h0;
	else		ps <= #1 ps + 8'h1;

always @(posedge clk)
	ps_clr <= #1 (ps == div0);	

always @(posedge clk)
	if(!rst)	br_cnt <= #1 8'h0;
	else
	if(br_clr)	br_cnt <= #1 8'h0;
	else
	if(ps_clr)	br_cnt <= #1 br_cnt + 8'h1;

always @(posedge clk)
	br_clr <= #1 (br_cnt == div1); 

always @(posedge clk)
	sio_ce_x4_r <= #1 br_clr;

always @(posedge clk)
	sio_ce_x4_t <= #1 !sio_ce_x4_r & br_clr;

always @(posedge clk)
	sio_ce_x4 <= #1 sio_ce_x4_t;

always @(posedge clk)
	if(!rst)			cnt <= #1 2'h0;
	else
	if(!sio_ce_x4_r & br_clr)	cnt <= #1 cnt + 2'h1;

always @(posedge clk)
	sio_ce_r <= #1 (cnt == 2'h0);

always @(posedge clk)
	sio_ce <= #1 !sio_ce_r & (cnt == 2'h0);

endmodule





module sasc_fifo4(clk, rst, clr,  din, we, dout, re, full, empty);

input		clk, rst;
input		clr;
input   [7:0]	din;
input		we;
output  [7:0]	dout;
input		re;
output		full, empty;



reg     [7:0]	mem[0:3];
reg     [1:0]   wp;
reg     [1:0]   rp;
wire    [1:0]   wp_p1;
wire    [1:0]   wp_p2;
wire    [1:0]   rp_p1;
wire		full, empty;
reg		gb;


always @(posedge clk or negedge rst)
        if(!rst)	wp <= #1 2'h0;
        else
        if(clr)		wp <= #1 2'h0;
        else
        if(we)		wp <= #1 wp_p1;

assign wp_p1 = wp + 2'h1;
assign wp_p2 = wp + 2'h2;

always @(posedge clk or negedge rst)
        if(!rst)	rp <= #1 2'h0;
        else
        if(clr)		rp <= #1 2'h0;
        else
        if(re)		rp <= #1 rp_p1;

assign rp_p1 = rp + 2'h1;

assign  dout = mem[ rp ];

always @(posedge clk)
        if(we)     mem[ wp ] <= #1 din;

assign empty = (wp == rp) & !gb;
assign full  = (wp == rp) &  gb;

always @(posedge clk)
	if(!rst)			gb <= #1 1'b0;
	else
	if(clr)				gb <= #1 1'b0;
	else
	if((wp_p1 == rp) & we)		gb <= #1 1'b1;
	else
	if(re)				gb <= #1 1'b0;

endmodule






/*
Serial IO Interface
===============================
RTS I Request To Send
CTS O Clear to send
TD  I Transmit Data
RD  O Receive Data
*/

module top(	clk, rst,
	
			
			rxd_i, txd_o, cts_i, rts_o, 

			
			sio_ce, sio_ce_x4,

			
			din_i, dout_o, re_i, we_i, full_o, empty_o);

input		clk;
input		rst;
input		rxd_i;
output		txd_o;
input		cts_i;
output		rts_o; 
input		sio_ce;
input		sio_ce_x4;
input	[7:0]	din_i;
output	[7:0]	dout_o;
input		re_i, we_i;
output		full_o, empty_o;


parameter	START_BIT	= 1'b0,
		STOP_BIT	= 1'b1,
		IDLE_BIT	= 1'b1;

wire	[7:0]	txd_p;
reg		load;
reg		load_r;
wire		load_e;
reg	[9:0]	hold_reg;
wire		txf_empty;
reg		txd_o;
reg		shift_en;
reg	[3:0]	tx_bit_cnt;
reg		rxd_s, rxd_r;
wire		start;
reg	[3:0]	rx_bit_cnt;
reg		rx_go;
reg	[9:0]	rxr;
reg		rx_valid, rx_valid_r;
wire		rx_we;
wire		rxf_full;
reg		rts_o;
reg		txf_empty_r;
reg		shift_en_r;
reg		rxd_r1, rxd_r2;
wire		lock_en;
reg		change;
reg		rx_sio_ce_d, rx_sio_ce_r1, rx_sio_ce_r2, rx_sio_ce;
reg	[1:0]	dpll_state, dpll_next_state;
reg 	[5:0] 	rxd_dly; 
			

sasc_fifo4 tx_fifo(	.clk(		clk		),
			.rst(		rst		),
			.clr(		1'b0		),
			.din(		din_i		),
			.we(		we_i		),
			.dout(		txd_p		),
			.re(		load_e		),
			.full(		full_o		),
			.empty(		txf_empty	)
			);

sasc_fifo4 rx_fifo(	.clk(		clk		),
			.rst(		rst		),
			.clr(		1'b0		),
			.din(		rxr[9:2]	),
			.we(		rx_we		),
			.dout(		dout_o		),
			.re(		re_i		),
			.full(		rxf_full	),
			.empty(		empty_o		)
			);

always @(posedge clk)
	if(!rst)	txf_empty_r <= #1 1'b1;
	else
	if(sio_ce)	txf_empty_r <= #1 txf_empty;

always @(posedge clk)
	load <= #1 !txf_empty_r & !shift_en & !cts_i;

always @(posedge clk)
	load_r <= #1 load;

assign load_e = load & sio_ce;

always @(posedge clk)
	if(load_e)		hold_reg <= #1 {STOP_BIT, txd_p, START_BIT};
	else
	if(shift_en & sio_ce)	hold_reg <= #1 {IDLE_BIT, hold_reg[9:1]};

always @(posedge clk)
	if(!rst)				txd_o <= #1 IDLE_BIT;
	else
	if(sio_ce)
		if(shift_en | shift_en_r)	txd_o <= #1 hold_reg[0];
		else				txd_o <= #1 IDLE_BIT;

always @(posedge clk)
        if(!rst)		tx_bit_cnt <= #1 4'h9;
	else
	if(load_e)		tx_bit_cnt <= #1 4'h0;
	else
	if(shift_en & sio_ce)	tx_bit_cnt <= #1 tx_bit_cnt + 4'h1;

always @(posedge clk)
	shift_en <= #1 (tx_bit_cnt != 4'h9);

always @(posedge clk)
	if(!rst)	shift_en_r <= #1 1'b0;
	else
	if(sio_ce)	shift_en_r <= #1 shift_en;


always @(posedge clk)
begin
    rxd_dly[5:1] <= #1 rxd_dly[4:0];
	 rxd_dly[0] <= #1rxd_i;
	 rxd_s <= #1rxd_dly[5];  
    rxd_r <= #1 rxd_s;  
end


assign start = (rxd_r == IDLE_BIT) & (rxd_s == START_BIT);

always @(posedge clk)
        if(!rst)		rx_bit_cnt <= #1 4'ha;
	else
	if(!rx_go & start)	rx_bit_cnt <= #1 4'h0;
	else
	if(rx_go & rx_sio_ce)	rx_bit_cnt <= #1 rx_bit_cnt + 4'h1;

always @(posedge clk)
	rx_go <= #1 (rx_bit_cnt != 4'ha);

always @(posedge clk)
	rx_valid <= #1 (rx_bit_cnt == 4'h9);

always @(posedge clk)
	rx_valid_r <= #1 rx_valid;

assign rx_we = !rx_valid_r & rx_valid & !rxf_full;

always @(posedge clk)
	if(rx_go & rx_sio_ce)	rxr <= {rxd_s, rxr[9:1]};

always @(posedge clk)
	rts_o <= #1 rxf_full;



always @(posedge clk)
	if(sio_ce_x4)	rxd_r1 <= #1 rxd_s;

always @(posedge clk)
	if(sio_ce_x4)	rxd_r2 <= #1 rxd_r1;

always @(posedge clk)
    if(!rst)        
        change <= #1 1'b0;
    else if ((rxd_dly[1] != rxd_r1) || (rxd_dly[1] != rxd_s))
        change <= #1 1'b1;
    else if(sio_ce_x4)
        change <= #1 1'b0;

always @(posedge clk or negedge rst)
	if(!rst)	dpll_state <= #1 2'h1;
	else
	if(sio_ce_x4)	dpll_state <= #1 dpll_next_state;

always @(dpll_state or change)
   begin
	rx_sio_ce_d = 1'b0;
	case(dpll_state)
	   2'h0:
		if(change)	dpll_next_state = 3'h0;
		else		dpll_next_state = 3'h1;
	   2'h1:begin
		rx_sio_ce_d = 1'b1;
		if(change)	dpll_next_state = 3'h3;
		else		dpll_next_state = 3'h2;
		end
	   2'h2:
		if(change)	dpll_next_state = 3'h0;
		else		dpll_next_state = 3'h3;
	   2'h3:
		if(change)	dpll_next_state = 3'h0;
		else		dpll_next_state = 3'h0;
	endcase
   end

always @(posedge clk)
	rx_sio_ce_r1 <= #1 rx_sio_ce_d;

always @(posedge clk)
	rx_sio_ce_r2 <= #1 rx_sio_ce_r1;

always @(posedge clk)
	rx_sio_ce <= #1 rx_sio_ce_r1 & !rx_sio_ce_r2;

endmodule



`timescale 1ns / 10ps



