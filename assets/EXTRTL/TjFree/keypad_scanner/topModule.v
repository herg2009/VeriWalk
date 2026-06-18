

module top (
  clk_i,
  clk_en_i,
  rst_i,
  scan_i,
  col_i,
  row_o,
  dat_o,
  done_o
  );

parameter ROWS_PP = 4;         
parameter COLS_PP = 4;         
parameter ROW_BITS_PP = 2;     
parameter TMR_CLKS_PP = 60000; 
parameter TMR_BITS_PP = 16;    

input  clk_i;                           
input  clk_en_i;                        
input  rst_i;                           
input  scan_i;                          
input  [COLS_PP-1:0] col_i;             
output [ROWS_PP-1:0] row_o;             
output [COLS_PP*ROWS_PP-1:0] dat_o;     
output done_o;                          

reg  [COLS_PP*ROWS_PP-1:0] dat_o;

reg  [TMR_BITS_PP-1:0] tmr;
reg  [ROW_BITS_PP-1:0] row;
reg  [COLS_PP*(ROWS_PP-1)-1:0] shift_register;
reg  idle_state;

wire keyscan_row_clk;
wire end_of_scan;
wire [ROWS_PP-1:0] row_output_binary;


function [ROWS_PP-1:0] one_low_among_z;
  input [ROW_BITS_PP-1:0] row;
  integer k;
  begin
    for (k=0; k<ROWS_PP; k=k+1)
      one_low_among_z[k] = (k == row)?1'b0:1'bZ;
  end
endfunction



always @(posedge clk_i)
begin
  if (rst_i || idle_state) tmr <= 0;
  else if (clk_en_i) tmr <= tmr + 1;
end
assign keyscan_row_clk = (clk_en_i && (tmr == TMR_CLKS_PP-1));

always @(posedge clk_i)
begin
  if (rst_i || end_of_scan) row <= 0;
  else if (keyscan_row_clk) row <= row + 1;
end 
assign end_of_scan = ((row == ROWS_PP-1) && keyscan_row_clk);

always @(posedge clk_i)
begin
  if (rst_i) idle_state <= 1;     
  else if (scan_i && idle_state) idle_state <= 0;
  else if (end_of_scan && ~scan_i) idle_state <= 1;
end
assign done_o = (end_of_scan || idle_state);

always @(posedge clk_i)
begin
  if (keyscan_row_clk && ~end_of_scan)
  begin
    shift_register <= {shift_register,col_i};

    
    
    
    
  end
end

always @(posedge clk_i)
begin
  if (rst_i) dat_o <= 0;
  else if (keyscan_row_clk && end_of_scan) dat_o <= {shift_register,col_i};
end

assign row_o = one_low_among_z(row);

endmodule




