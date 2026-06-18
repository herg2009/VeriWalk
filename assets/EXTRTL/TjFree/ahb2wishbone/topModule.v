





`timescale 1 ns/1 ns

module top(
	adr_o, dat_o, dat_i, ack_i, cyc_o,
	we_o, stb_o, hclk, hresetn, haddr, htrans, hwrite, hsize, hburst,
	hsel, hwdata, hrdata, hresp, hready, clk_i, rst_i
	);


	parameter AWIDTH = 16;
	parameter DWIDTH = 32;



 
	input [DWIDTH-1:0]dat_i;						
	input ack_i;									
	input clk_i;
	input rst_i;
	
 
	input hclk; 									
	input hresetn;									
	input [DWIDTH-1:0]hwdata;						
	input hwrite;									
	input [2:0]hburst;								
	input [2:0]hsize;								
	input [1:0]htrans;								
	input hsel;										
	input [AWIDTH-1:0]haddr;						



 
	output [AWIDTH-1:0]adr_o;						
	output [DWIDTH-1:0]dat_o;						
	output cyc_o;									
	output we_o;									
	output stb_o;									
		

 
	output [DWIDTH-1:0]hrdata;						
	output [1:0]hresp;								
	output hready;									






	reg [DWIDTH-1:0]hrdata;
	reg hready;
	reg [1:0]hresp;
	reg stb_o;
	wire we_o;
	reg cyc_o;
	wire [AWIDTH-1:0]adr_o;
	reg [DWIDTH-1:0]dat_o;
	
	reg [AWIDTH-1 : 0]addr_temp;
	reg hwrite_temp;								

						
	assign #2 we_o = hwrite_temp;
	assign #2 adr_o = addr_temp;

	always @ (posedge hclk ) begin
		if (!hresetn) begin
			hresp  <= 2'b00;
			cyc_o <= 'b0;
			stb_o <= 'b0;
			addr_temp <= 'bx;
			hwrite_temp <= 'bx;
			dat_o <='bx;
		end
		else if(hready & hsel) begin
			case (hburst)
 				
				3'b000 	:	begin										
								case (htrans)
									
									2'b00 :	begin
												cyc_o <= 'b0;
												hresp <= 2'b00;			
												stb_o <= 'b0;
											
											end

									
									2'b01 :	begin						
												hresp <= 2'b00; 		
												stb_o <= 'b0;
												cyc_o <= 'b1;
											end
	
									
									2'b10 : begin
												cyc_o <= 'b1;
												stb_o <= 'b1;
												addr_temp <= haddr;
												hwrite_temp <= hwrite;			
											end
								endcase
							end

				default	:	cyc_o <= 'b0;
			endcase
		end
		else if (!hsel & hready) begin
			cyc_o <= 'b0;					
		end

	end


	always@(hwrite_temp or hwdata or dat_i or ack_i or hresetn or stb_o ) begin
		
		if (!hresetn) begin
			hready <= 'b1;
		end
		else begin		
			if (stb_o) 
				hready = ack_i;

			if ( hwrite_temp ) 
				dat_o = hwdata;
			else if (!hwrite_temp) 
				hrdata = dat_i;
		end
						
	end	
		
endmodule





