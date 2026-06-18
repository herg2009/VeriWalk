

module bcd_to_binary (
  clk_i,
  ce_i,
  rst_i,
  start_i,
  dat_bcd_i,
  dat_binary_o,
  done_o
  );
parameter BCD_DIGITS_IN_PP   = 5;  
parameter BITS_OUT_PP        = 16; 
parameter BIT_COUNT_WIDTH_PP = 4;  

input  clk_i;                      
input  ce_i;                       
input  rst_i;                      
input  start_i;                    
input  [4*BCD_DIGITS_IN_PP-1:0] dat_bcd_i;  
output [BITS_OUT_PP-1:0] dat_binary_o;      
output done_o;                     

reg [BITS_OUT_PP-1:0] dat_binary_o;


reg  [BITS_OUT_PP-1:0] bin_reg;
reg  [4*BCD_DIGITS_IN_PP-1:0] bcd_reg;
wire [BITS_OUT_PP-1:0] bin_next;
reg  [4*BCD_DIGITS_IN_PP-1:0] bcd_next;
reg  busy_bit;
reg  [BIT_COUNT_WIDTH_PP-1:0] bit_count;
wire bit_count_done;


function [4*BCD_DIGITS_IN_PP-1:0] bcd_asr;
  input [4*BCD_DIGITS_IN_PP-1:0] din;
  integer k;
  reg cin;
  reg [3:0] digit;
  reg [3:0] digit_more;

  begin
    cin = 1'b0;
    for (k=BCD_DIGITS_IN_PP-1; k>=0; k=k-1) 
    begin
      digit[3] = 1'b0;
      digit[2] = din[4*k+3];
      digit[1] = din[4*k+2];
      digit[0] = din[4*k+1];
      digit_more = digit + 5;
      if (cin)
      begin
        bcd_asr[4*k+3] = digit_more[3];
        bcd_asr[4*k+2] = digit_more[2];
        bcd_asr[4*k+1] = digit_more[1];
        bcd_asr[4*k+0] = digit_more[0];
      end
      else
      begin
        bcd_asr[4*k+3] = digit[3];
        bcd_asr[4*k+2] = digit[2];
        bcd_asr[4*k+1] = digit[1];
        bcd_asr[4*k+0] = digit[0];
      end
      cin = din[4*k+0];
    end  
  end

endfunction


assign bin_next = {bcd_reg[0],bin_reg[BITS_OUT_PP-1:1]};
always @(bcd_reg)
begin
  bcd_next <= bcd_asr(bcd_reg);
end

always @(posedge clk_i)
begin
  if (rst_i)
  begin
    busy_bit <= 0;  
    dat_binary_o <= 0;
  end
  else if (start_i && ~busy_bit)
  begin
    busy_bit <= 1;
    bcd_reg <= dat_bcd_i;
    bin_reg <= 0;
  end
  else if (busy_bit && ce_i && bit_count_done && ~start_i)
  begin
    busy_bit <= 0;
    dat_binary_o <= bin_next;
  end
  else if (busy_bit && ce_i & ~bit_count_done)
  begin
    bin_reg <= bin_next;
    bcd_reg <= bcd_next;
  end
end
assign done_o = ~busy_bit;

always @(posedge clk_i)
begin
  if (~busy_bit) bit_count <= 0;
  else if (ce_i && ~bit_count_done) bit_count <= bit_count + 1;
end
assign bit_count_done = (bit_count == (BITS_OUT_PP-1));

endmodule




module top (
  clk_i,
  ce_i,
  rst_i,
  start_i,
  dat_binary_i,
  dat_bcd_o,
  done_o
  );
parameter BITS_IN_PP         = 16; 
parameter BCD_DIGITS_OUT_PP  = 5;  
parameter BIT_COUNT_WIDTH_PP = 4;  

input  clk_i;                      
input  ce_i;                       
input  rst_i;                      
input  start_i;                    
input  [BITS_IN_PP-1:0] dat_binary_i;        
output [4*BCD_DIGITS_OUT_PP-1:0] dat_bcd_o;  
output done_o;                     

reg [4*BCD_DIGITS_OUT_PP-1:0] dat_bcd_o;


reg  [BITS_IN_PP-1:0] bin_reg;
reg  [4*BCD_DIGITS_OUT_PP-1:0] bcd_reg;
wire [BITS_IN_PP-1:0] bin_next;
reg  [4*BCD_DIGITS_OUT_PP-1:0] bcd_next;
reg  busy_bit;
reg  [BIT_COUNT_WIDTH_PP-1:0] bit_count;
wire bit_count_done;


function [4*BCD_DIGITS_OUT_PP-1:0] bcd_asl;
  input [4*BCD_DIGITS_OUT_PP-1:0] din;
  input newbit;
  integer k;
  reg cin;
  reg [3:0] digit;
  reg [3:0] digit_less;
  begin
    cin = newbit;
    for (k=0; k<BCD_DIGITS_OUT_PP; k=k+1)
    begin
      digit[3] = din[4*k+3];
      digit[2] = din[4*k+2];
      digit[1] = din[4*k+1];
      digit[0] = din[4*k];
      digit_less = digit - 5;
      if (digit > 4'b0100)
      begin
        bcd_asl[4*k+3] = digit_less[2];
        bcd_asl[4*k+2] = digit_less[1];
        bcd_asl[4*k+1] = digit_less[0];
        bcd_asl[4*k+0] = cin;
        cin = 1'b1;
      end
      else
      begin
        bcd_asl[4*k+3] = digit[2];
        bcd_asl[4*k+2] = digit[1];
        bcd_asl[4*k+1] = digit[0];
        bcd_asl[4*k+0] = cin;
        cin = 1'b0;
      end

    end 
  end
endfunction


assign bin_next = {bin_reg,1'b0};
always @(bcd_reg or bin_reg)
begin
  bcd_next <= bcd_asl(bcd_reg,bin_reg[BITS_IN_PP-1]);
end

always @(posedge clk_i)
begin
  if (rst_i)
  begin
    busy_bit <= 0;  
    dat_bcd_o <= 0;
  end
  else if (start_i && ~busy_bit)
  begin
    busy_bit <= 1;
    bin_reg <= dat_binary_i;
    bcd_reg <= 0;
  end
  else if (busy_bit && ce_i && bit_count_done && ~start_i)
  begin
    busy_bit <= 0;
    dat_bcd_o <= bcd_next;
  end
  else if (busy_bit && ce_i && ~bit_count_done)
  begin
    bcd_reg <= bcd_next;
    bin_reg <= bin_next;
  end
end
assign done_o = ~busy_bit;

always @(posedge clk_i)
begin
  if (~busy_bit) bit_count <= 0;
  else if (ce_i && ~bit_count_done) bit_count <= bit_count + 1;
end
assign bit_count_done = (bit_count == (BITS_IN_PP-1));

endmodule




