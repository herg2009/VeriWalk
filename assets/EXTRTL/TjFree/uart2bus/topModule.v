
module baud_gen 
(
	clock, reset, 
	ce_16, baud_freq, baud_limit 
);
input 			clock;		
input 			reset;		
output			ce_16;		
input	[11:0]	baud_freq;	
input	[15:0]	baud_limit;

reg ce_16;
reg [15:0]	counter;
always @ (posedge clock or posedge reset)
begin
	if (reset) 
		counter <= 16'b0;
	else if (counter >= baud_limit) 
		counter <= counter - baud_limit;
	else 
		counter <= counter + baud_freq;
end

always @ (posedge clock or posedge reset)
begin
	if (reset)
		ce_16 <= 1'b0;
	else if (counter >= baud_limit) 
		ce_16 <= 1'b1;
	else 
		ce_16 <= 1'b0;
end 

endmodule


module top 
(
	
	clock, reset,
	
	ser_in, ser_out,
	
	int_address, int_wr_data, int_write,
	int_rd_data, int_read, 
	int_req, int_gnt 
);
input 			clock;			
input 			reset;			
input			ser_in;			
output			ser_out;		
output	[15:0]	int_address;	
output	[7:0]	int_wr_data;	
output			int_write;		
output			int_read;		
input	[7:0]	int_rd_data;	
output			int_req;		
input			int_gnt;		

`define D_BAUD_FREQ			12'h90
`define D_BAUD_LIMIT		16'h0ba5

wire	[7:0]	tx_data;		
wire			new_tx_data;	
wire 			tx_busy;		
wire	[7:0]	rx_data;		
wire 			new_rx_data;	
wire	[11:0]	baud_freq;
wire	[15:0]	baud_limit;
wire			baud_clk;

uart_top uart1
(
	.clock(clock), .reset(reset),
	.ser_in(ser_in), .ser_out(ser_out),
	.rx_data(rx_data), .new_rx_data(new_rx_data), 
	.tx_data(tx_data), .new_tx_data(new_tx_data), .tx_busy(tx_busy), 
	.baud_freq(baud_freq), .baud_limit(baud_limit),
	.baud_clk(baud_clk) 
);

assign baud_freq = `D_BAUD_FREQ;
assign baud_limit = `D_BAUD_LIMIT;

uart_parser #(16) uart_parser1
(
	.clock(clock), .reset(reset),
	.rx_data(rx_data), .new_rx_data(new_rx_data), 
	.tx_data(tx_data), .new_tx_data(new_tx_data), .tx_busy(tx_busy), 
	.int_address(int_address), .int_wr_data(int_wr_data), .int_write(int_write),
	.int_rd_data(int_rd_data), .int_read(int_read), 
	.int_req(int_req), .int_gnt(int_gnt) 
);

endmodule


module uart_parser 
(
	
	clock, reset,
	
	rx_data, new_rx_data, 
	tx_data, new_tx_data, tx_busy, 
	
	int_address, int_wr_data, int_write,
	int_rd_data, int_read, 
	int_req, int_gnt 
);
parameter		AW = 8;			

input 			clock;			
input 			reset;			
output	[7:0]	tx_data;		
output			new_tx_data;	
								
input 			tx_busy;		
input	[7:0]	rx_data;		
input 			new_rx_data;	
output	[AW-1:0] int_address;	
output	[7:0]	int_wr_data;	
output			int_write;		
output			int_read;		
input	[7:0]	int_rd_data;	
output			int_req;		
input			int_gnt;		

reg	[7:0] tx_data;
reg new_tx_data;
reg	[AW-1:0] int_address;
reg	[7:0] int_wr_data;
reg write_req, read_req, int_write, int_read;

`define CHAR_CR			8'h0d
`define CHAR_LF			8'h0a
`define CHAR_SPACE		8'h20
`define CHAR_TAB		8'h09
`define CHAR_COMMA		8'h2C
`define CHAR_R_UP		8'h52
`define CHAR_r_LO		8'h72
`define CHAR_W_UP		8'h57
`define CHAR_w_LO		8'h77
`define CHAR_0			8'h30
`define CHAR_1			8'h31
`define CHAR_2			8'h32
`define CHAR_3			8'h33
`define CHAR_4			8'h34
`define CHAR_5			8'h35
`define CHAR_6			8'h36
`define CHAR_7			8'h37
`define CHAR_8			8'h38
`define CHAR_9			8'h39
`define CHAR_A_UP		8'h41
`define CHAR_B_UP		8'h42
`define CHAR_C_UP		8'h43
`define CHAR_D_UP		8'h44
`define CHAR_E_UP		8'h45
`define CHAR_F_UP		8'h46
`define CHAR_a_LO		8'h61
`define CHAR_b_LO		8'h62
`define CHAR_c_LO		8'h63
`define CHAR_d_LO		8'h64
`define CHAR_e_LO		8'h65
`define CHAR_f_LO		8'h66

`define MAIN_IDLE		4'b0000
`define MAIN_WHITE1		4'b0001
`define MAIN_DATA		4'b0010
`define MAIN_WHITE2		4'b0011
`define MAIN_ADDR		4'b0100
`define MAIN_EOL		4'b0101
`define MAIN_BIN_CMD	4'b1000
`define MAIN_BIN_ADRH	4'b1001
`define MAIN_BIN_ADRL	4'b1010
`define MAIN_BIN_LEN    4'b1011
`define MAIN_BIN_DATA   4'b1100 

`define TX_IDLE			3'b000
`define TX_HI_NIB		3'b001
`define TX_LO_NIB		3'b100
`define TX_CHAR_CR		3'b101
`define TX_CHAR_LF		3'b110

`define BIN_CMD_NOP		2'b00
`define BIN_CMD_READ	2'b01
`define BIN_CMD_WRITE	2'b10

reg [3:0] main_sm;			
reg read_op;				
reg write_op;				
reg data_in_hex_range;		
reg [7:0] data_param;		
reg [15:0] addr_param;		
reg [3:0] data_nibble;		
reg read_done;				
reg read_done_s;			
reg [7:0] read_data_s;		
reg [3:0] tx_nibble;		
reg [7:0] tx_char;			
reg [2:0] tx_sm;			
reg s_tx_busy;				
reg bin_read_op;			
reg bin_write_op;			
reg addr_auto_inc;			
reg send_stat_flag;			
reg [7:0] bin_byte_count;	
wire bin_last_byte;			
wire tx_end_p;				

always @ (posedge clock or posedge reset)
begin 
	if (reset)
		main_sm <= `MAIN_IDLE;
	else if (new_rx_data) 
	begin 
		case (main_sm)
			
			
			`MAIN_IDLE:
				
				if (rx_data == 8'h0)
					
					main_sm <= `MAIN_BIN_CMD;
				else if ((rx_data == `CHAR_r_LO) | (rx_data == `CHAR_R_UP))
					
					main_sm <= `MAIN_WHITE2;
				else if ((rx_data == `CHAR_w_LO) | (rx_data == `CHAR_W_UP))
					
					main_sm <= `MAIN_WHITE1;
				else if ((rx_data == `CHAR_CR) | (rx_data == `CHAR_LF))
					
					main_sm <= `MAIN_IDLE;
				else 
					
					main_sm <= `MAIN_EOL;
				
			
			`MAIN_WHITE1:
				
				
				
				
				if ((rx_data == `CHAR_SPACE) | (rx_data == `CHAR_TAB))
					main_sm <= `MAIN_WHITE1;
				else if (data_in_hex_range)
					main_sm <= `MAIN_DATA;
				else if ((rx_data == `CHAR_CR) | (rx_data == `CHAR_LF))
					main_sm <= `MAIN_IDLE;
				else 
					main_sm <= `MAIN_EOL;
					
			
			`MAIN_DATA:
				
				
				
				if (data_in_hex_range)
					main_sm <= `MAIN_DATA;
				else if ((rx_data == `CHAR_SPACE) | (rx_data == `CHAR_TAB))
					main_sm <= `MAIN_WHITE2;
				else if ((rx_data == `CHAR_CR) | (rx_data == `CHAR_LF))
					main_sm <= `MAIN_IDLE;
				else 
					main_sm <= `MAIN_EOL;
				
			
			`MAIN_WHITE2:
				
				if ((rx_data == `CHAR_SPACE) | (rx_data == `CHAR_TAB))
					main_sm <= `MAIN_WHITE2;
				else if (data_in_hex_range)
					main_sm <= `MAIN_ADDR;
				else if ((rx_data == `CHAR_CR) | (rx_data == `CHAR_LF))
					main_sm <= `MAIN_IDLE;
				else 
					main_sm <= `MAIN_EOL;

			
			`MAIN_ADDR:
				
				if (data_in_hex_range)
					main_sm <= `MAIN_ADDR;
				else if ((rx_data == `CHAR_CR) | (rx_data == `CHAR_LF))
					main_sm <= `MAIN_IDLE;
				else 
					main_sm <= `MAIN_EOL;

			
			`MAIN_EOL:
				
				if ((rx_data == `CHAR_CR) | (rx_data == `CHAR_LF))
					main_sm <= `MAIN_IDLE;
					
			
			
			`MAIN_BIN_CMD:
				
				if (rx_data[5:4] == `BIN_CMD_NOP)
					
					main_sm <= `MAIN_IDLE;
				else 
					
					main_sm <= `MAIN_BIN_ADRH;
							
			
			
			`MAIN_BIN_ADRH:
				
				main_sm <= `MAIN_BIN_ADRL;
			
			
			`MAIN_BIN_ADRL:
				
				main_sm <= `MAIN_BIN_LEN;
			
			
			`MAIN_BIN_LEN:
				
				if (bin_write_op)
					
					main_sm <= `MAIN_BIN_DATA;
				else 
					
					main_sm <= `MAIN_IDLE;
			
			
			`MAIN_BIN_DATA:
				
				if (bin_last_byte)
					main_sm <= `MAIN_IDLE;
				
			
			default:
				main_sm <= `MAIN_IDLE;
		endcase 
	end 
end 

always @ (rx_data)
begin 
	if (((rx_data >= `CHAR_0   ) && (rx_data <= `CHAR_9   )) || 
	    ((rx_data >= `CHAR_A_UP) && (rx_data <= `CHAR_F_UP)) || 
	    ((rx_data >= `CHAR_a_LO) && (rx_data <= `CHAR_f_LO)))
		data_in_hex_range <= 1'b1;
	else 
		data_in_hex_range <= 1'b0;
end 

always @ (posedge clock or posedge reset)
begin 
	if (reset)
		read_op <= 1'b0;
	else if ((main_sm == `MAIN_IDLE) && new_rx_data) 
	begin 
		
		
		if ((rx_data == `CHAR_r_LO) | (rx_data == `CHAR_R_UP))
			read_op <= 1'b1;
		else 
			read_op <= 1'b0;
	end 
end 

always @ (posedge clock or posedge reset)
begin 
	if (reset)
		write_op <= 1'b0;
	else if ((main_sm == `MAIN_IDLE) & new_rx_data) 
	begin 
		
		
		if ((rx_data == `CHAR_w_LO) | (rx_data == `CHAR_W_UP))
			write_op <= 1'b1;
		else 
			write_op <= 1'b0;
	end 
end 

always @ (posedge clock or posedge reset)
begin 
	if (reset)
		bin_read_op <= 1'b0;
	else if ((main_sm == `MAIN_BIN_CMD) && new_rx_data && (rx_data[5:4] == `BIN_CMD_READ))
		
		bin_read_op <= 1'b1;
	else if (bin_read_op && tx_end_p && bin_last_byte)
		
		bin_read_op <= 1'b0;
end 

always @ (posedge clock or posedge reset)
begin 
	if (reset)
		bin_write_op <= 1'b0;
	else if ((main_sm == `MAIN_BIN_CMD) && new_rx_data && (rx_data[5:4] == `BIN_CMD_WRITE))
		
		bin_write_op <= 1'b1;
	else if ((main_sm == `MAIN_BIN_DATA) && new_rx_data && bin_last_byte)
		bin_write_op <= 1'b0;
end 

always @ (posedge clock or posedge reset)
begin 
	if (reset)
		send_stat_flag <= 1'b0;
	else if ((main_sm == `MAIN_BIN_CMD) && new_rx_data)
	begin 
		
		if (rx_data[0] == 1'b1)
			send_stat_flag <= 1'b1;
		else 
			send_stat_flag <= 1'b0;
	end 
end 

always @ (posedge clock or posedge reset)
begin 
	if (reset)
		addr_auto_inc <= 1'b0;
	else if ((main_sm == `MAIN_BIN_CMD) && new_rx_data)
	begin 
		
		
		if (rx_data[1] == 1'b0)
			addr_auto_inc <= 1'b1;
		else 
			addr_auto_inc <= 1'b0;
	end 
end 

always @ (posedge clock or posedge reset)
begin 
	if (reset)
		data_param <= 8'h0;
	else if ((main_sm == `MAIN_WHITE1) & new_rx_data & data_in_hex_range) 
		data_param <= {4'h0, data_nibble};
	else if ((main_sm == `MAIN_DATA) & new_rx_data & data_in_hex_range) 
		data_param <= {data_param[3:0], data_nibble};
end 

always @ (posedge clock or posedge reset)
begin 
	if (reset)
		addr_param <= 0;
	else if ((main_sm == `MAIN_WHITE2) & new_rx_data & data_in_hex_range) 
		addr_param <= {12'b0, data_nibble};
	else if ((main_sm == `MAIN_ADDR) & new_rx_data & data_in_hex_range) 
		addr_param <= {addr_param[11:0], data_nibble};
	
	else if (main_sm == `MAIN_BIN_ADRH)
		addr_param[15:8] <= rx_data;
	else if (main_sm == `MAIN_BIN_ADRL)
		addr_param[7:0] <= rx_data;
end 

always @ (posedge clock or posedge reset)
begin 
	if (reset)
		bin_byte_count <= 8'b0;
	else if ((main_sm == `MAIN_BIN_LEN) && new_rx_data)
		bin_byte_count <= rx_data;
	else if ((bin_write_op && (main_sm == `MAIN_BIN_DATA) && new_rx_data) || 
			 (bin_read_op && tx_end_p))
		
		
		bin_byte_count <= bin_byte_count - 1;
end 
assign bin_last_byte = (bin_byte_count == 8'h01) ? 1'b1 : 1'b0;

always @ (posedge clock or posedge reset)
begin 
	if (reset)
	begin 
		write_req <= 1'b0;
		int_write <= 1'b0;
		int_wr_data <= 0;
	end 
	else if (write_op && (main_sm == `MAIN_ADDR) && new_rx_data && !data_in_hex_range)
	begin 
		write_req <= 1'b1;
		int_wr_data <= data_param;
	end 
	
	else if (bin_write_op && (main_sm == `MAIN_BIN_DATA) && new_rx_data) 
	begin 
		write_req <= 1'b1;
		int_wr_data <= rx_data;
	end 
	else if (int_gnt && write_req) 
	begin 
		
		int_write <= 1'b1;
		write_req <= 1'b0;
	end 
	else 
		int_write <= 1'b0;
end 

always @ (posedge clock or posedge reset)
begin 
	if (reset)
	begin 
		int_read <= 1'b0;
		read_req <= 1'b0;
	end 
	else if (read_op && (main_sm == `MAIN_ADDR) && new_rx_data && !data_in_hex_range)
		read_req <= 1'b1;
	
	else if (bin_read_op && (main_sm == `MAIN_BIN_LEN) && new_rx_data)
		
		read_req <= 1'b1;
	else if (bin_read_op && tx_end_p && !bin_last_byte)
		
		
		read_req <= 1'b1;
	else if (int_gnt && read_req) 
	begin 
		
		int_read <= 1'b1;
		read_req <= 1'b0;
	end 
	else 
		int_read <= 1'b0;
end 

assign int_req = write_req | read_req;

always @ (posedge clock or posedge reset)
begin
	if (reset) 
		int_address <= 0;
	else if ((main_sm == `MAIN_ADDR) && new_rx_data && !data_in_hex_range)
		int_address <= addr_param[AW-1:0];
	
	else if ((main_sm == `MAIN_BIN_LEN) && new_rx_data)
		
		int_address <= addr_param[AW-1:0];
	else if (addr_auto_inc && 
			 ((bin_read_op && tx_end_p && !bin_last_byte) || 
			  (bin_write_op && int_write)))
		
		int_address <= int_address + 1;
end 

always @ (posedge clock or posedge reset)
begin
	if (reset) begin 
		read_done <= 1'b0;
		read_done_s <= 1'b0;
		read_data_s <= 8'h0;
	end 
	else 
	begin 
		
		if (int_read) 
			read_done <= 1'b1;
		else 
			read_done <= 1'b0;
			
		
		read_done_s <= read_done;
		
		
		if (read_done)
			read_data_s <= int_rd_data;
	end 
end 

always @ (posedge clock or posedge reset)
begin 
	if (reset) begin 
		tx_sm <= `TX_IDLE;
		tx_data <= 8'h0;
		new_tx_data <= 1'b0;
	end 
	else 
		case (tx_sm)
			
			`TX_IDLE: 
				
				
				if (read_done_s) 
					
					if (bin_read_op)
					begin 
						
						tx_data <= read_data_s;
						new_tx_data <= 1'b1;
					end 
					else 
					begin 
						tx_sm <= `TX_HI_NIB;
						tx_data <= tx_char;
						new_tx_data <= 1'b1;
					end 
				
				else if ((send_stat_flag && bin_read_op && tx_end_p && bin_last_byte) ||	
					(send_stat_flag && bin_write_op && new_rx_data && bin_last_byte) ||	
					((main_sm == `MAIN_BIN_CMD) && new_rx_data && (rx_data[5:4] == `BIN_CMD_NOP)))	
				begin 
					
					tx_data <= 8'h5a;
					new_tx_data <= 1'b1;
				end 
				else 
					new_tx_data <= 1'b0;

			
			`TX_HI_NIB:	
				if (tx_end_p) 
				begin 
					tx_sm <= `TX_LO_NIB;
					tx_data <= tx_char;
					new_tx_data <= 1'b1;
				end 
				else 
					new_tx_data <= 1'b0;
					
			
			`TX_LO_NIB:	
				if (tx_end_p) 
				begin 
					tx_sm <= `TX_CHAR_CR;
					tx_data <= `CHAR_CR;
					new_tx_data <= 1'b1;
				end 
				else 
					new_tx_data <= 1'b0;
					
			
			`TX_CHAR_CR:	
				if (tx_end_p) 
				begin 
					tx_sm <= `TX_CHAR_LF;
					tx_data <= `CHAR_LF;
					new_tx_data <= 1'b1;
				end 
				else 
					new_tx_data <= 1'b0;
					
			
			`TX_CHAR_LF:	
				begin 
					if (tx_end_p) 
						tx_sm <= `TX_IDLE;
					
					new_tx_data <= 1'b0;
				end 
					
			
			default:
				tx_sm <= `TX_IDLE;
		endcase 
end 

always @ (tx_sm or read_data_s)
begin 
	case (tx_sm)
		`TX_IDLE:		tx_nibble = read_data_s[7:4];
		`TX_HI_NIB:		tx_nibble = read_data_s[3:0];
		default:		tx_nibble = read_data_s[7:4];
	endcase
end 

always @ (posedge clock or posedge reset)
begin 
	if (reset)
		s_tx_busy <= 1'b0;
	else 
		s_tx_busy <= tx_busy;
end 
assign tx_end_p = ~tx_busy & s_tx_busy;

always @ (rx_data)
begin 
	case (rx_data) 
		`CHAR_0:				data_nibble = 4'h0;
		`CHAR_1:				data_nibble = 4'h1;
		`CHAR_2:				data_nibble = 4'h2;
		`CHAR_3:				data_nibble = 4'h3;
		`CHAR_4:				data_nibble = 4'h4;
		`CHAR_5:				data_nibble = 4'h5;
		`CHAR_6:				data_nibble = 4'h6;
		`CHAR_7:				data_nibble = 4'h7;
		`CHAR_8:				data_nibble = 4'h8;
		`CHAR_9:				data_nibble = 4'h9;
		`CHAR_A_UP, `CHAR_a_LO:	data_nibble = 4'ha;
		`CHAR_B_UP, `CHAR_b_LO:	data_nibble = 4'hb;
		`CHAR_C_UP, `CHAR_c_LO:	data_nibble = 4'hc;
		`CHAR_D_UP, `CHAR_d_LO:	data_nibble = 4'hd;
		`CHAR_E_UP, `CHAR_e_LO:	data_nibble = 4'he;
		`CHAR_F_UP, `CHAR_f_LO:	data_nibble = 4'hf;
		default:				data_nibble = 4'hf;
	endcase 
end 

always @ (tx_nibble)
begin 
	case (tx_nibble)
		4'h0:	tx_char = `CHAR_0;
		4'h1:	tx_char = `CHAR_1;
		4'h2:	tx_char = `CHAR_2;
		4'h3:	tx_char = `CHAR_3;
		4'h4:	tx_char = `CHAR_4;
		4'h5:	tx_char = `CHAR_5;
		4'h6:	tx_char = `CHAR_6;
		4'h7:	tx_char = `CHAR_7;
		4'h8:	tx_char = `CHAR_8;
		4'h9:	tx_char = `CHAR_9;
		4'ha:	tx_char = `CHAR_A_UP;
		4'hb:	tx_char = `CHAR_B_UP;
		4'hc:	tx_char = `CHAR_C_UP;
		4'hd:	tx_char = `CHAR_D_UP;
		4'he:	tx_char = `CHAR_E_UP;
		default: tx_char = `CHAR_F_UP;
	endcase 
end 

endmodule


module uart_rx 
(
	clock, reset,
	ce_16, ser_in, 
	rx_data, new_rx_data 
);
input 			clock;			
input 			reset;			
input			ce_16;			
input			ser_in;			
output	[7:0]	rx_data;		
output 			new_rx_data;	

wire ce_1;		
wire ce_1_mid;	

reg	[7:0] rx_data;
reg	new_rx_data;
reg [1:0] in_sync;
reg rx_busy; 
reg [3:0]	count16;
reg [3:0]	bit_count;
reg [7:0]	data_buf;
always @ (posedge clock or posedge reset)
begin 
	if (reset) 
		in_sync <= 2'b11;
	else 
		in_sync <= {in_sync[0], ser_in};
end 

always @ (posedge clock or posedge reset)
begin
	if (reset) 
		count16 <= 4'b0;
	else if (ce_16) 
	begin 
		if (rx_busy | (in_sync[1] == 1'b0))
			count16 <= count16 + 4'b1;
		else 
			count16 <= 4'b0;
	end 
end 

assign ce_1 = (count16 == 4'b1111) & ce_16;
assign ce_1_mid = (count16 == 4'b0111) & ce_16;

always @ (posedge clock or posedge reset)
begin 
	if (reset)
		rx_busy <= 1'b0;
	else if (~rx_busy & ce_1_mid)
		rx_busy <= 1'b1;
	else if (rx_busy & (bit_count == 4'h8) & ce_1_mid) 
		rx_busy <= 1'b0;
end 

always @ (posedge clock or posedge reset)
begin 
	if (reset)
		bit_count <= 4'h0;
	else if (~rx_busy) 
		bit_count <= 4'h0;
	else if (rx_busy & ce_1_mid)
		bit_count <= bit_count + 4'h1;
end 

always @ (posedge clock or posedge reset)
begin 
	if (reset)
		data_buf <= 8'h0;
	else if (rx_busy & ce_1_mid)
		data_buf <= {in_sync[1], data_buf[7:1]};
end 

always @ (posedge clock or posedge reset)
begin 
	if (reset) 
	begin 
		rx_data <= 8'h0;
		new_rx_data <= 1'b0;
	end 
	else if (rx_busy & (bit_count == 4'h8) & ce_1)
	begin 
		rx_data <= data_buf;
		new_rx_data <= 1'b1;
	end 
	else 
		new_rx_data <= 1'b0;
end 

endmodule


module uart_top 
(
	
	clock, reset,
	
	ser_in, ser_out,
	
	rx_data, new_rx_data, 
	tx_data, new_tx_data, tx_busy, 
	
	baud_freq, baud_limit, 
	baud_clk 
);
input 			clock;			
input 			reset;			
input			ser_in;			
output			ser_out;		
input	[7:0]	tx_data;		
input			new_tx_data;	
output 			tx_busy;		
output	[7:0]	rx_data;		
output 			new_rx_data;	
input	[11:0]	baud_freq;	
input	[15:0]	baud_limit;
output			baud_clk;

wire ce_16;		

assign baud_clk = ce_16;
baud_gen baud_gen_1
(
	.clock(clock), .reset(reset), 
	.ce_16(ce_16), .baud_freq(baud_freq), .baud_limit(baud_limit)
);

uart_rx uart_rx_1 
(
	.clock(clock), .reset(reset), 
	.ce_16(ce_16), .ser_in(ser_in), 
	.rx_data(rx_data), .new_rx_data(new_rx_data) 
);

uart_tx  uart_tx_1
(
	.clock(clock), .reset(reset), 
	.ce_16(ce_16), .tx_data(tx_data), .new_tx_data(new_tx_data), 
	.ser_out(ser_out), .tx_busy(tx_busy) 
);

endmodule


module uart_tx  
(
	clock, reset,
	ce_16, tx_data, new_tx_data, 
	ser_out, tx_busy
);
input 			clock;			
input 			reset;			
input			ce_16;			
input	[7:0]	tx_data;		
input			new_tx_data;	
output			ser_out;		
output 			tx_busy;		

wire ce_1;		

reg ser_out;
reg tx_busy;
reg [3:0]	count16;
reg [3:0]	bit_count;
reg [8:0]	data_buf;
always @ (posedge clock or posedge reset)
begin
	if (reset) 
		count16 <= 4'b0;
	else if (tx_busy & ce_16)
		count16 <= count16 + 4'b1;
	else if (~tx_busy)
		count16 <= 4'b0;
end 

assign ce_1 = (count16 == 4'b1111) & ce_16;

always @ (posedge clock or posedge reset)
begin
	if (reset) 
		tx_busy <= 1'b0;
	else if (~tx_busy & new_tx_data)
		tx_busy <= 1'b1;
	else if (tx_busy & (bit_count == 4'h9) & ce_1)
		tx_busy <= 1'b0;
end 

always @ (posedge clock or posedge reset)
begin
	if (reset) 
		bit_count <= 4'h0;
	else if (tx_busy & ce_1)
		bit_count <= bit_count + 4'h1;
	else if (~tx_busy) 
		bit_count <= 4'h0;
end 

always @ (posedge clock or posedge reset)
begin
	if (reset) 
		data_buf <= 9'b0;
	else if (~tx_busy)
		data_buf <= {tx_data, 1'b0};
	else if (tx_busy & ce_1)
		data_buf <= {1'b1, data_buf[8:1]};
end 

always @ (posedge clock or posedge reset)
begin
	if (reset) 
		ser_out <= 1'b1;
	else if (tx_busy)
		ser_out <= data_buf[0];
	else 
		ser_out <= 1'b1;
end 

endmodule



