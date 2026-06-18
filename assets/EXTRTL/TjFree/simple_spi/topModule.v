




module fifo4(clk, rst, clr,  din, we, dout, re, full, empty);

parameter dw = 8;

input		clk, rst;
input		clr;
input   [dw:1]	din;
input		we;
output  [dw:1]	dout;
input		re;
output		full, empty;



reg     [dw:1]	mem[0:3];
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
        if(we)	mem[ wp ] <= #1 din;

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








module top #(
	parameter		dw = 8
)(
  
  input  wire       clk_i,         
  input  wire       rst_i,         
  input  wire       cyc_i,         
  input  wire       stb_i,         
  input  wire [1:0] adr_i,         
  input  wire       we_i,          
  input  wire [7:0] dat_i,         
  output reg  [7:0] dat_o,         
  output reg        ack_o,         
  output reg        inta_o,        

  
  output reg        sck_o,         
  output wire       mosi_o,        
  input  wire       miso_i         
);

  
  
  
  reg  [7:0] spcr;       
  wire [7:0] spsr;       
  reg  [7:0] sper;       
  reg  [7:0] treg, rreg; 

  
  wire [7:0] rfdout;
  reg        wfre, rfwe;
  wire       rfre, rffull, rfempty;
  wire [7:0] wfdout;
  wire       wfwe, wffull, wfempty;

  
  wire      tirq;     
  wire      wfov;     
  reg [1:0] state;    
  reg [2:0] bcnt;

  
  
  wire wb_acc = cyc_i & stb_i;       
  wire wb_wr  = wb_acc & we_i;       

  
  always @(posedge clk_i or negedge rst_i)
    if (~rst_i)
      begin
          spcr <= #1 8'h10;  
          sper <= #1 8'h00;
      end
    else if (wb_wr)
      begin
        if (adr_i == 2'b00)
          spcr <= #1 dat_i | 8'h10; 

        if (adr_i == 2'b11)
          sper <= #1 dat_i;
      end

  
  assign wfwe = wb_acc & (adr_i == 2'b10) & ack_o &  we_i;
  assign wfov = wfwe & wffull;

  
  always @(posedge clk_i)
    case(adr_i) 
      2'b00: dat_o <= #1 spcr;
      2'b01: dat_o <= #1 spsr;
      2'b10: dat_o <= #1 rfdout;
      2'b11: dat_o <= #1 sper;
    endcase

  
  assign rfre = wb_acc & (adr_i == 2'b10) & ack_o & ~we_i;

  
  always @(posedge clk_i or negedge rst_i)
    if (~rst_i)
      ack_o <= #1 1'b0;
    else
      ack_o <= #1 wb_acc & !ack_o;

  
  wire       spie = spcr[7];   
  wire       spe  = spcr[6];   
  wire       dwom = spcr[5];   
  wire       mstr = spcr[4];   
  wire       cpol = spcr[3];   
  wire       cpha = spcr[2];   
  wire [1:0] spr  = spcr[1:0]; 

  
  wire [1:0] icnt = sper[7:6]; 
  wire [1:0] spre = sper[1:0]; 

  wire [3:0] espr = {spre, spr};

  
  wire wr_spsr = wb_wr & (adr_i == 2'b01);

  reg spif;
  always @(posedge clk_i)
    if (~spe)
      spif <= #1 1'b0;
    else
      spif <= #1 (tirq | spif) & ~(wr_spsr & dat_i[7]);

  reg wcol;
  always @(posedge clk_i)
    if (~spe)
      wcol <= #1 1'b0;
    else
      wcol <= #1 (wfov | wcol) & ~(wr_spsr & dat_i[6]);

  assign spsr[7]   = spif;
  assign spsr[6]   = wcol;
  assign spsr[5:4] = 2'b00;
  assign spsr[3]   = wffull;
  assign spsr[2]   = wfempty;
  assign spsr[1]   = rffull;
  assign spsr[0]   = rfempty;
  

  
  always @(posedge clk_i)
    inta_o <= #1 spif & spie;

  
  
  fifo4 #(8)
  rfifo(
	.clk   ( clk_i   ),
	.rst   ( rst_i   ),
	.clr   ( ~spe    ),
	.din   ( treg    ),
	.we    ( rfwe    ),
	.dout  ( rfdout  ),
	.re    ( rfre    ),
	.full  ( rffull  ),
	.empty ( rfempty )
  ),
  wfifo(
	.clk   ( clk_i   ),
	.rst   ( rst_i   ),
	.clr   ( ~spe    ),
	.din   ( dat_i   ),
	.we    ( wfwe    ),
	.dout  ( wfdout  ),
	.re    ( wfre    ),
	.full  ( wffull  ),
	.empty ( wfempty )
  );

  
  
  reg [11:0] clkcnt;
  always @(posedge clk_i)
    if(spe & (|clkcnt & |state))
      clkcnt <= #1 clkcnt - 11'h1;
    else
      case (espr) 
        4'b0000: clkcnt <= #1 12'h0;   
        4'b0001: clkcnt <= #1 12'h1;   
        4'b0010: clkcnt <= #1 12'h3;   
        4'b0011: clkcnt <= #1 12'hf;   
        4'b0100: clkcnt <= #1 12'h1f;  
        4'b0101: clkcnt <= #1 12'h7;   
        4'b0110: clkcnt <= #1 12'h3f;  
        4'b0111: clkcnt <= #1 12'h7f;  
        4'b1000: clkcnt <= #1 12'hff;  
        4'b1001: clkcnt <= #1 12'h1ff; 
        4'b1010: clkcnt <= #1 12'h3ff; 
        4'b1011: clkcnt <= #1 12'h7ff; 
      endcase

  
  wire ena = ~|clkcnt;

  
  always @(posedge clk_i)
    if (~spe)
      begin
          state <= #1 2'b00; 
          bcnt  <= #1 3'h0;
          treg  <= #1 8'h00;
          wfre  <= #1 1'b0;
          rfwe  <= #1 1'b0;
          sck_o <= #1 1'b0;
      end
    else
      begin
         wfre <= #1 1'b0;
         rfwe <= #1 1'b0;

         case (state) 
           2'b00: 
              begin
                  bcnt  <= #1 3'h7;   
                  treg  <= #1 wfdout; 
                  sck_o <= #1 cpol;   

                  if (~wfempty) begin
                    wfre  <= #1 1'b1;
                    state <= #1 2'b01;
                    if (cpha) sck_o <= #1 ~sck_o;
                  end
              end

           2'b01: 
              if (ena) begin
                sck_o   <= #1 ~sck_o;
                state   <= #1 2'b11;
              end

           2'b11: 
              if (ena) begin
                treg <= #1 {treg[6:0], miso_i};
                bcnt <= #1 bcnt -3'h1;

                if (~|bcnt) begin
                  state <= #1 2'b00;
                  sck_o <= #1 cpol;
                  rfwe  <= #1 1'b1;
                end else begin
                  state <= #1 2'b01;
                  sck_o <= #1 ~sck_o;
                end
              end

           2'b10: state <= #1 2'b00;
         endcase
      end

  assign mosi_o = treg[7];


  
  reg [1:0] tcnt; 
  always @(posedge clk_i)
    if (~spe)
      tcnt <= #1 icnt;
    else if (rfwe) 
      if (|tcnt)
        tcnt <= #1 tcnt - 2'h1;
      else
        tcnt <= #1 icnt;

  assign tirq = ~|tcnt & rfwe;

endmodule




