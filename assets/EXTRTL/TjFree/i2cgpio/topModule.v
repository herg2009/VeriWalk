
`define		P0_P9_OP	4'b1010 
`define		P0_P3_OP	4'b0111 
`define		P4_P7_OP	4'b1110 

module top(clk, cs, sr_in, sda_out, sr_out, gpio); 

   input clk,cs;
   input sr_in;
   output sda_out;
   output sr_out;
   output [7:0] gpio;

   reg [7:0] 	sr;   
   reg [7:0] 	addrreg;
   reg 		sda_out;
   reg 		sr_out ;
   reg [7:0] 	gpio;
   reg [7:0] 	ram;
   wire [3:0] 	addr;
   wire [3:0] 	data;	

   assign addr = sr[3:0];
   assign data = sr[7:4];
   always@(posedge clk)
     begin
	if (cs == 1'b0)
	  begin 
             sr_out <= sr[7]; 
	     sr[7:1] <= sr[6:0];
	     sr[0] <= sr_in;
	  end 		
	begin
	   if (addr[0] == 1'b0)               
	     begin
		if(addr[3:0] == 4'h0E)         
		  begin
	             sda_out = 1'b1;          
		     if(addr[3]== 1'b1)       
		       begin
			  case (addr[3:0])    
			    `P0_P3_OP : gpio[3:0] <= {data[0], data[1], data[2], data[3]};
			    `P4_P7_OP : gpio[3:0] <= {data[3], data[2], data[1], data[0]};
			  endcase
			  sda_out = 1'b1;     
		       end
		     else
		       begin
			  sda_out = 1'bz;
		       end
		  end
	     end
	end
     end
endmodule





