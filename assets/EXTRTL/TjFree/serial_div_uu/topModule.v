

module top (
                    clk_i,
                    clk_en_i,
                    rst_i,
                    pwm_signal_i,
                    ack_i,
                    dat_o,
                    stb_o
                    );

parameter COUNTER_WIDTH_PP     = 10; 
parameter DAT_WIDTH_PP         = 8;  
parameter DIV_COUNT_WIDTH_PP   = 3;  
                                     

input clk_i;
input clk_en_i;
input rst_i;
input pwm_signal_i;
input ack_i;

output [DAT_WIDTH_PP-1:0] dat_o;
output stb_o;

reg  [COUNTER_WIDTH_PP-1:0] s_cnt;
reg  [COUNTER_WIDTH_PP-1:0] t_cnt;
reg  pwm_ff_1;
reg  pwm_ff_2;
reg  ack_r;

wire rising_edge;
wire divide_done;

always @(posedge clk_i)
begin
  if (rst_i) pwm_ff_1 <= 0;
  else pwm_ff_1 <= pwm_signal_i;
end

always @(posedge clk_i)
begin
  if (rst_i) pwm_ff_2 <= 0;
  else pwm_ff_2 <= pwm_ff_1;
end
assign rising_edge = pwm_ff_1 && ~pwm_ff_2;

always @(posedge clk_i)
begin
  if (rst_i || rising_edge) t_cnt <= 0;
  else if (clk_en_i) t_cnt <= t_cnt + 1;
end

always @(posedge clk_i)
begin
  if (rst_i || rising_edge) s_cnt <= 0;
  else if (clk_en_i && pwm_signal_i) s_cnt <= s_cnt + 1;
end

serial_divide_uu #(
                   COUNTER_WIDTH_PP,    
                   COUNTER_WIDTH_PP,    
                   DAT_WIDTH_PP,        
                   COUNTER_WIDTH_PP,    
                   DIV_COUNT_WIDTH_PP,  
                   1                    
                   )
  divider_unit
  (
   .clk_i(clk_i),
   .clk_en_i(1'b1),
   .rst_i(rst_i),
   
   .divide_i(rising_edge && ~stb_o),
   .dividend_i(s_cnt),
   .divisor_i(t_cnt),
   .quotient_o(dat_o),
   .done_o(divide_done)
  );

always @(posedge clk_i)
begin
  if (rst_i || (rising_edge && ~stb_o)) ack_r <= 0;
  else if (stb_o) ack_r <= ack_i;
end

assign stb_o = divide_done && ~ack_r;

endmodule





module serial_divide_uu (
  clk_i,
  clk_en_i,
  rst_i,
  divide_i,
  dividend_i,
  divisor_i,
  quotient_o,
  done_o
  );

parameter M_PP = 16;           
parameter N_PP = 8;            
parameter R_PP = 0;            
parameter S_PP = 0;            
parameter COUNT_WIDTH_PP = 5;  
parameter HELD_OUTPUT_PP = 0;  
                               
                               
                               
                               

input  clk_i;                           
input  clk_en_i;
input  rst_i;                           
input  divide_i;                        
input  [M_PP-1:0] dividend_i;           
input  [N_PP-1:0] divisor_i;            
output [M_PP+R_PP-S_PP-1:0] quotient_o; 
output done_o;                          

reg  done_o;


reg  [M_PP+R_PP-1:0] grand_dividend;
reg  [M_PP+N_PP+R_PP-2:0] grand_divisor;
reg  [M_PP+R_PP-S_PP-1:0] quotient;
reg  [M_PP+R_PP-1:0] quotient_reg;       
reg  [COUNT_WIDTH_PP-1:0] divide_count;

wire [M_PP+N_PP+R_PP-1:0] subtract_node; 
wire [M_PP+R_PP-1:0]      quotient_node; 
wire [M_PP+N_PP+R_PP-2:0]  divisor_node; 


always @(posedge clk_i)
begin
  if (rst_i)
  begin
    grand_dividend <= 0;
    grand_divisor <= 0;
    divide_count <= 0;
    quotient <= 0;
    done_o <= 0;
  end
  else if (clk_en_i)
  begin
    done_o <= 0;
    if (divide_i)       
    begin
      quotient <= 0;
      divide_count <= 0;
      
      grand_dividend <= dividend_i << R_PP;
      
      
      
      grand_divisor  <= divisor_i << (N_PP+R_PP-S_PP-1);
    end
    else if (divide_count == M_PP+R_PP-S_PP-1)
    begin
      if (~done_o) quotient <= quotient_node;      
      if (~done_o) quotient_reg <= quotient_node;  
      done_o <= 1;                                 
    end
    else                
    begin
      
      if (~subtract_node[M_PP+N_PP+R_PP-1]) grand_dividend <= subtract_node;
      
      
      quotient <= quotient_node;
      
      grand_divisor <= divisor_node;
      
      divide_count <= divide_count + 1;
    end
  end  
end 

assign subtract_node = {1'b0,grand_dividend} - {1'b0,grand_divisor};
assign quotient_node = 
  {quotient[M_PP+R_PP-S_PP-2:0],~subtract_node[M_PP+N_PP+R_PP-1]};
assign divisor_node  = {1'b0,grand_divisor[M_PP+N_PP+R_PP-2:1]};

assign quotient_o = (HELD_OUTPUT_PP == 0)?quotient:quotient_reg;

endmodule




