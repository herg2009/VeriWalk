
module mfm_read
  (
  input reset_l,

  

  input clk,

  

  input read_pulse_l,

  

  output reg [7:0] data_out,	
  output reg mark,		
  output reg valid,		
  output reg crc_zero		
  );


parameter PERIOD = (24 * 256);

parameter HALF = (PERIOD / 2);

reg [12:0] count;	

reg capture;		

reg [2:0] leading;	

reg sep_clock;
reg sep_data;

reg [12:0] adjust; 

always @(posedge clk or negedge reset_l)
  if (!reset_l)
    begin
      leading <= 3'b111;
      capture <= 0;
      count <= 0;
      sep_clock <= 0;
      sep_data <= 0;
    end
  else
    begin
      sep_clock <= 0;

      
      leading <= { read_pulse_l, leading[2:1] };

      
      adjust = 256;

      
      if (!leading[1] && leading[0])
        begin
          
          capture <= 1;

          
          if (count > HALF)
            
            adjust = 256 - ((count-HALF)>>1);
          else if (count < HALF)
            
            adjust = 256 + ((count-HALF)>>1);
        end

      
      if (count + adjust >= PERIOD)
        begin
          count <= count + adjust - PERIOD;
          capture <= 0;
          sep_clock <= 1;
          sep_data <= capture;
        end
      else
        count <= count + adjust;

    end


reg [15:0] shift_reg;	
reg [3:0] shift_count;


wire [7:0] data = { shift_reg[14], shift_reg[12], shift_reg[10], shift_reg[8],
                    shift_reg[6], shift_reg[4], shift_reg[2], shift_reg[0] };


wire [7:0] clock = { shift_reg[15], shift_reg[13], shift_reg[11], shift_reg[9],
                     shift_reg[7], shift_reg[5], shift_reg[3], shift_reg[1] };

reg [7:0] aligned_byte;
reg aligned_valid;
reg aligned_mark;

always @(posedge clk or negedge reset_l)
  if(!reset_l)
    begin
      shift_reg <= 0;
      shift_count <= 0;
      aligned_mark <= 0;
      aligned_byte <= 0;
      aligned_valid <= 0;
    end
  else
    begin
      aligned_valid <= 0;
      if(sep_clock)
        begin
          shift_reg <= { shift_reg[14:0], sep_data };

          if(shift_count)
            shift_count <= shift_count - 1;

          if(clock==8'h0A && data==8'hA1 || !shift_count)
            begin
              shift_count <= 15;
              aligned_byte <= data;
              aligned_valid <= 1;
              if(clock==8'h0A && data==8'hA1)
                aligned_mark <= 1;
              else
                aligned_mark <= 0;
            end
        end
    end


function [15:0] crc;
input [15:0] accu;
input [7:0] byte;
  begin
    crc[0] = accu[4'h8]^accu[4'hC]^byte[4]^byte[0];
    crc[1] = accu[4'h9]^accu[4'hD]^byte[5]^byte[1];
    crc[2] = accu[4'hA]^accu[4'hE]^byte[6]^byte[2];
    crc[3] = accu[4'hB]^accu[4'hF]^byte[7]^byte[3];
    crc[4] = accu[4'hC]^byte[4];
    crc[5] = accu[4'hD]^byte[5]^accu[4'h8]^accu[4'hC]^byte[4]^byte[0];
    crc[6] = accu[4'hE]^byte[6]^accu[4'h9]^accu[4'hD]^byte[5]^byte[1];
    crc[7] = accu[4'hF]^byte[7]^accu[4'hA]^accu[4'hE]^byte[6]^byte[2];
    crc[8] = accu[4'h0]^accu[4'hB]^accu[4'hF]^byte[7]^byte[3];
    crc[9] = accu[4'h1]^accu[4'hC]^byte[4];
    crc[10] = accu[4'h2]^accu[4'hD]^byte[5];
    crc[11] = accu[4'h3]^accu[4'hE]^byte[6];
    crc[12] = accu[4'h4]^accu[4'hF]^byte[7]^accu[4'h8]^accu[4'hC]^byte[4]^byte[0];
    crc[13] = accu[4'h5]^accu[4'h9]^accu[4'hD]^byte[5]^byte[1];
    crc[14] = accu[4'h6]^accu[4'hA]^accu[4'hE]^byte[6]^byte[2];
    crc[15] = accu[4'h7]^accu[4'hB]^accu[4'hF]^byte[7]^byte[3];
  end
endfunction

reg [15:0] fcs;
reg [2:0] count;

always @(posedge clk or negedge reset_l)
  if(!reset_l)
    begin
      fcs <= 0;
      count <= 0;
      data_out <= 0;
      mark <= 0;
      valid <= 0;
      crc_zero <= 0;
    end
  else
    begin
      if(aligned_valid)
        begin
          data_out <= aligned_data;
          valid <= 1;
          mark <= aligned_mark;

          fcs <= compute_fcs(fcs, aligned_byte);
          crc_zero <= (compute_fcs(fcs, aligned_byte)==16'h0000);

          
          if(count)
            count <= count - 1;
          else if(aligned_mark)
            begin
              
              fcs <= compute_fcs(16'hFFFF, aligned_byte);
              count <= 4;
            end
        end
      else
        valid <= 0;
    end

endmodule


module top
  (
  input reset_l,
  input clk,

  

  input start_writing,			

  input [7:0] encode_fifo_rd_data,
  input encode_fifo_rd_mark,		
  input encode_fifo_done,		
  input encode_fifo_ne,			
  output reg encode_fifo_re,		

  

  output reg write_gate_l,		
  output reg serial_out_l		
  );

parameter BIT_RATE_DIVISOR = 24;	
parameter PULSE_WIDTH = 5;		

reg [6:0] counter;			
reg [7:0] shift_reg;			
reg [2:0] bit_counter;			
reg prev_bit;				
reg clk_data;				

reg [3:0] pulse_counter;

always @(posedge clk or negedge reset_l)
  if(!reset_l)
    begin
      counter <= 0;
      pulse_counter <= 0;
      write_gate_l <= 1;
      serial_out_l <= 1;
      encode_fifo_re <= 0;
    end
  else
    begin
      encode_fifo_re <= 0;

      if (pulse_counter)
        pulse_counter <= pulse_counter - 1;
      else
        serial_out_l <= 1;

      if (counter)
        counter <= counter - 1;
      else
        begin
          counter <= BIT_RATE_DIVISOR - 1;
          if (clk_data)
            begin
              
              clk_data <= 0;
              if (!shift_reg[0] && !prev_bit)
                begin
                  serial_out_l <= 0;
                  pulse_counter <= PULSE_WIDTH;
                end
            end
          else
            begin
              
              clk_data <= 1;
              if (shift_reg[0])
                begin
                  serial_out_l <= 0;
                  pulse_counter <= PULSE_WIDTH;
                end
              prev_bit <= shift_reg[0];
              if (bit_counter)
                bit_counter <= bit_counter - 1;
              else
                begin
                  
                  shift_reg <= encode_fifo_rd_data;
                  encode_fifo_re <= 1;
                  bit_counter <= 7;
                end
            end
        end
    end

endmodule



