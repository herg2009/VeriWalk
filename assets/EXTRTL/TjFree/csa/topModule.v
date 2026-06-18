
module single_block_decyper(ri,kk,ro);
input [8*8-1:0*8] ri;
input [8-1:0]  kk;
output [8*8-1:0*8] ro;

wire [8-1:0]sbox_in;
wire [8-1:0]sbox_out;
wire [8-1:0]perm_out;
wire [8-1:0]next_r8;

assign sbox_in=kk ^ ri[7*8-1:6*8];
block_sbox s(.in(sbox_in),.out(sbox_out));
block_perm p(.in(sbox_out),.out(perm_out));
assign next_r8=ri[7*8-1:6*8];
assign ro[7*8-1:6*8]=ri[6*8-1:5*8]^perm_out;
assign ro[6*8-1:5*8]=ri[5*8-1:4*8];
assign ro[5*8-1:4*8]=ri[4*8-1:3*8]^ri[8*8-1:7*8]^sbox_out;
assign ro[4*8-1:3*8]=ri[3*8-1:2*8]^ri[8*8-1:7*8]^sbox_out;
assign ro[3*8-1:2*8]=ri[2*8-1:1*8]^ri[8*8-1:7*8]^sbox_out;
assign ro[2*8-1:1*8]=ri[1*8-1:0*8];
assign ro[1*8-1:0*8]=ri[8*8-1:7*8]^sbox_out;
assign ro[8*8-1:7*8]=next_r8;
endmodule

module block_decypher(kk,ib,bd);
input   [56 *8-1:0*8]kk;
input   [8  *8-1:0]ib;
output  [8  *8-1:0]bd;

wire    [56*8*8-1:0]r;
single_block_decyper b56(.ri(ib[8*8-1:0]),.kk(kk[56*8-1:55*8]),.ro(r[56*8*8-1:55*8*8]));
single_block_decyper b55(.ri(r[56*8*8-1:55*8*8]),.kk(kk[55*8-1:54*8]),.ro(r[55*8*8-1:54*8*8]));
single_block_decyper b54(.ri(r[55*8*8-1:54*8*8]),.kk(kk[54*8-1:53*8]),.ro(r[54*8*8-1:53*8*8]));
single_block_decyper b53(.ri(r[54*8*8-1:53*8*8]),.kk(kk[53*8-1:52*8]),.ro(r[53*8*8-1:52*8*8]));
single_block_decyper b52(.ri(r[53*8*8-1:52*8*8]),.kk(kk[52*8-1:51*8]),.ro(r[52*8*8-1:51*8*8]));
single_block_decyper b51(.ri(r[52*8*8-1:51*8*8]),.kk(kk[51*8-1:50*8]),.ro(r[51*8*8-1:50*8*8]));
single_block_decyper b50(.ri(r[51*8*8-1:50*8*8]),.kk(kk[50*8-1:49*8]),.ro(r[50*8*8-1:49*8*8]));
single_block_decyper b49(.ri(r[50*8*8-1:49*8*8]),.kk(kk[49*8-1:48*8]),.ro(r[49*8*8-1:48*8*8]));
single_block_decyper b48(.ri(r[49*8*8-1:48*8*8]),.kk(kk[48*8-1:47*8]),.ro(r[48*8*8-1:47*8*8]));
single_block_decyper b47(.ri(r[48*8*8-1:47*8*8]),.kk(kk[47*8-1:46*8]),.ro(r[47*8*8-1:46*8*8]));
single_block_decyper b46(.ri(r[47*8*8-1:46*8*8]),.kk(kk[46*8-1:45*8]),.ro(r[46*8*8-1:45*8*8]));
single_block_decyper b45(.ri(r[46*8*8-1:45*8*8]),.kk(kk[45*8-1:44*8]),.ro(r[45*8*8-1:44*8*8]));
single_block_decyper b44(.ri(r[45*8*8-1:44*8*8]),.kk(kk[44*8-1:43*8]),.ro(r[44*8*8-1:43*8*8]));
single_block_decyper b43(.ri(r[44*8*8-1:43*8*8]),.kk(kk[43*8-1:42*8]),.ro(r[43*8*8-1:42*8*8]));
single_block_decyper b42(.ri(r[43*8*8-1:42*8*8]),.kk(kk[42*8-1:41*8]),.ro(r[42*8*8-1:41*8*8]));
single_block_decyper b41(.ri(r[42*8*8-1:41*8*8]),.kk(kk[41*8-1:40*8]),.ro(r[41*8*8-1:40*8*8]));
single_block_decyper b40(.ri(r[41*8*8-1:40*8*8]),.kk(kk[40*8-1:39*8]),.ro(r[40*8*8-1:39*8*8]));
single_block_decyper b39(.ri(r[40*8*8-1:39*8*8]),.kk(kk[39*8-1:38*8]),.ro(r[39*8*8-1:38*8*8]));
single_block_decyper b38(.ri(r[39*8*8-1:38*8*8]),.kk(kk[38*8-1:37*8]),.ro(r[38*8*8-1:37*8*8]));
single_block_decyper b37(.ri(r[38*8*8-1:37*8*8]),.kk(kk[37*8-1:36*8]),.ro(r[37*8*8-1:36*8*8]));
single_block_decyper b36(.ri(r[37*8*8-1:36*8*8]),.kk(kk[36*8-1:35*8]),.ro(r[36*8*8-1:35*8*8]));
single_block_decyper b35(.ri(r[36*8*8-1:35*8*8]),.kk(kk[35*8-1:34*8]),.ro(r[35*8*8-1:34*8*8]));
single_block_decyper b34(.ri(r[35*8*8-1:34*8*8]),.kk(kk[34*8-1:33*8]),.ro(r[34*8*8-1:33*8*8]));
single_block_decyper b33(.ri(r[34*8*8-1:33*8*8]),.kk(kk[33*8-1:32*8]),.ro(r[33*8*8-1:32*8*8]));
single_block_decyper b32(.ri(r[33*8*8-1:32*8*8]),.kk(kk[32*8-1:31*8]),.ro(r[32*8*8-1:31*8*8]));
single_block_decyper b31(.ri(r[32*8*8-1:31*8*8]),.kk(kk[31*8-1:30*8]),.ro(r[31*8*8-1:30*8*8]));
single_block_decyper b30(.ri(r[31*8*8-1:30*8*8]),.kk(kk[30*8-1:29*8]),.ro(r[30*8*8-1:29*8*8]));
single_block_decyper b29(.ri(r[30*8*8-1:29*8*8]),.kk(kk[29*8-1:28*8]),.ro(r[29*8*8-1:28*8*8]));
single_block_decyper b28(.ri(r[29*8*8-1:28*8*8]),.kk(kk[28*8-1:27*8]),.ro(r[28*8*8-1:27*8*8]));
single_block_decyper b27(.ri(r[28*8*8-1:27*8*8]),.kk(kk[27*8-1:26*8]),.ro(r[27*8*8-1:26*8*8]));
single_block_decyper b26(.ri(r[27*8*8-1:26*8*8]),.kk(kk[26*8-1:25*8]),.ro(r[26*8*8-1:25*8*8]));
single_block_decyper b25(.ri(r[26*8*8-1:25*8*8]),.kk(kk[25*8-1:24*8]),.ro(r[25*8*8-1:24*8*8]));
single_block_decyper b24(.ri(r[25*8*8-1:24*8*8]),.kk(kk[24*8-1:23*8]),.ro(r[24*8*8-1:23*8*8]));
single_block_decyper b23(.ri(r[24*8*8-1:23*8*8]),.kk(kk[23*8-1:22*8]),.ro(r[23*8*8-1:22*8*8]));
single_block_decyper b22(.ri(r[23*8*8-1:22*8*8]),.kk(kk[22*8-1:21*8]),.ro(r[22*8*8-1:21*8*8]));
single_block_decyper b21(.ri(r[22*8*8-1:21*8*8]),.kk(kk[21*8-1:20*8]),.ro(r[21*8*8-1:20*8*8]));
single_block_decyper b20(.ri(r[21*8*8-1:20*8*8]),.kk(kk[20*8-1:19*8]),.ro(r[20*8*8-1:19*8*8]));
single_block_decyper b19(.ri(r[20*8*8-1:19*8*8]),.kk(kk[19*8-1:18*8]),.ro(r[19*8*8-1:18*8*8]));
single_block_decyper b18(.ri(r[19*8*8-1:18*8*8]),.kk(kk[18*8-1:17*8]),.ro(r[18*8*8-1:17*8*8]));
single_block_decyper b17(.ri(r[18*8*8-1:17*8*8]),.kk(kk[17*8-1:16*8]),.ro(r[17*8*8-1:16*8*8]));
single_block_decyper b16(.ri(r[17*8*8-1:16*8*8]),.kk(kk[16*8-1:15*8]),.ro(r[16*8*8-1:15*8*8]));
single_block_decyper b15(.ri(r[16*8*8-1:15*8*8]),.kk(kk[15*8-1:14*8]),.ro(r[15*8*8-1:14*8*8]));
single_block_decyper b14(.ri(r[15*8*8-1:14*8*8]),.kk(kk[14*8-1:13*8]),.ro(r[14*8*8-1:13*8*8]));
single_block_decyper b13(.ri(r[14*8*8-1:13*8*8]),.kk(kk[13*8-1:12*8]),.ro(r[13*8*8-1:12*8*8]));
single_block_decyper b12(.ri(r[13*8*8-1:12*8*8]),.kk(kk[12*8-1:11*8]),.ro(r[12*8*8-1:11*8*8]));
single_block_decyper b11(.ri(r[12*8*8-1:11*8*8]),.kk(kk[11*8-1:10*8]),.ro(r[11*8*8-1:10*8*8]));
single_block_decyper b10(.ri(r[11*8*8-1:10*8*8]),.kk(kk[10*8-1: 9*8]),.ro(r[10*8*8-1: 9*8*8]));
single_block_decyper b9 (.ri(r[10*8*8-1: 9*8*8]),.kk(kk[ 9*8-1: 8*8]),.ro(r[ 9*8*8-1: 8*8*8]));
single_block_decyper b8 (.ri(r[ 9*8*8-1: 8*8*8]),.kk(kk[ 8*8-1: 7*8]),.ro(r[ 8*8*8-1: 7*8*8]));
single_block_decyper b7 (.ri(r[ 8*8*8-1: 7*8*8]),.kk(kk[ 7*8-1: 6*8]),.ro(r[ 7*8*8-1: 6*8*8]));
single_block_decyper b6 (.ri(r[ 7*8*8-1: 6*8*8]),.kk(kk[ 6*8-1: 5*8]),.ro(r[ 6*8*8-1: 5*8*8]));
single_block_decyper b5 (.ri(r[ 6*8*8-1: 5*8*8]),.kk(kk[ 5*8-1: 4*8]),.ro(r[ 5*8*8-1: 4*8*8]));
single_block_decyper b4 (.ri(r[ 5*8*8-1: 4*8*8]),.kk(kk[ 4*8-1: 3*8]),.ro(r[ 4*8*8-1: 3*8*8]));
single_block_decyper b3 (.ri(r[ 4*8*8-1: 3*8*8]),.kk(kk[ 3*8-1: 2*8]),.ro(r[ 3*8*8-1: 2*8*8]));
single_block_decyper b2 (.ri(r[ 3*8*8-1: 2*8*8]),.kk(kk[ 2*8-1: 1*8]),.ro(r[ 2*8*8-1: 1*8*8]));
single_block_decyper b1 (.ri(r[ 2*8*8-1: 1*8*8]),.kk(kk[ 1*8-1: 0*8]),.ro(r[ 1*8*8-1: 0*8*8]));

assign bd=r[ 1*8*8-1: 0*8*8];
endmodule



module block_perm(in, out);
input  [7:0] in;
output [7:0] out;
reg    [7:0] out;

always @(in)
        case (in)
        8'h00: out=8'h00;
        8'h01: out=8'h02;
        8'h02: out=8'h80;
        8'h03: out=8'h82;
        8'h04: out=8'h20;
        8'h05: out=8'h22;
        8'h06: out=8'hA0;
        8'h07: out=8'hA2;
        8'h08: out=8'h10;
        8'h09: out=8'h12;
        8'h0A: out=8'h90;
        8'h0B: out=8'h92;
        8'h0C: out=8'h30;
        8'h0D: out=8'h32;
        8'h0E: out=8'hB0;
        8'h0F: out=8'hB2;
        8'h10: out=8'h04;
        8'h11: out=8'h06;
        8'h12: out=8'h84;
        8'h13: out=8'h86;
        8'h14: out=8'h24;
        8'h15: out=8'h26;
        8'h16: out=8'hA4;
        8'h17: out=8'hA6;
        8'h18: out=8'h14;
        8'h19: out=8'h16;
        8'h1A: out=8'h94;
        8'h1B: out=8'h96;
        8'h1C: out=8'h34;
        8'h1D: out=8'h36;
        8'h1E: out=8'hB4;
        8'h1F: out=8'hB6;
        8'h20: out=8'h40;
        8'h21: out=8'h42;
        8'h22: out=8'hC0;
        8'h23: out=8'hC2;
        8'h24: out=8'h60;
        8'h25: out=8'h62;
        8'h26: out=8'hE0;
        8'h27: out=8'hE2;
        8'h28: out=8'h50;
        8'h29: out=8'h52;
        8'h2A: out=8'hD0;
        8'h2B: out=8'hD2;
        8'h2C: out=8'h70;
        8'h2D: out=8'h72;
        8'h2E: out=8'hF0;
        8'h2F: out=8'hF2;
        8'h30: out=8'h44;
        8'h31: out=8'h46;
        8'h32: out=8'hC4;
        8'h33: out=8'hC6;
        8'h34: out=8'h64;
        8'h35: out=8'h66;
        8'h36: out=8'hE4;
        8'h37: out=8'hE6;
        8'h38: out=8'h54;
        8'h39: out=8'h56;
        8'h3A: out=8'hD4;
        8'h3B: out=8'hD6;
        8'h3C: out=8'h74;
        8'h3D: out=8'h76;
        8'h3E: out=8'hF4;
        8'h3F: out=8'hF6;
        8'h40: out=8'h01;
        8'h41: out=8'h03;
        8'h42: out=8'h81;
        8'h43: out=8'h83;
        8'h44: out=8'h21;
        8'h45: out=8'h23;
        8'h46: out=8'hA1;
        8'h47: out=8'hA3;
        8'h48: out=8'h11;
        8'h49: out=8'h13;
        8'h4A: out=8'h91;
        8'h4B: out=8'h93;
        8'h4C: out=8'h31;
        8'h4D: out=8'h33;
        8'h4E: out=8'hB1;
        8'h4F: out=8'hB3;
        8'h50: out=8'h05;
        8'h51: out=8'h07;
        8'h52: out=8'h85;
        8'h53: out=8'h87;
        8'h54: out=8'h25;
        8'h55: out=8'h27;
        8'h56: out=8'hA5;
        8'h57: out=8'hA7;
        8'h58: out=8'h15;
        8'h59: out=8'h17;
        8'h5A: out=8'h95;
        8'h5B: out=8'h97;
        8'h5C: out=8'h35;
        8'h5D: out=8'h37;
        8'h5E: out=8'hB5;
        8'h5F: out=8'hB7;
        8'h60: out=8'h41;
        8'h61: out=8'h43;
        8'h62: out=8'hC1;
        8'h63: out=8'hC3;
        8'h64: out=8'h61;
        8'h65: out=8'h63;
        8'h66: out=8'hE1;
        8'h67: out=8'hE3;
        8'h68: out=8'h51;
        8'h69: out=8'h53;
        8'h6A: out=8'hD1;
        8'h6B: out=8'hD3;
        8'h6C: out=8'h71;
        8'h6D: out=8'h73;
        8'h6E: out=8'hF1;
        8'h6F: out=8'hF3;
        8'h70: out=8'h45;
        8'h71: out=8'h47;
        8'h72: out=8'hC5;
        8'h73: out=8'hC7;
        8'h74: out=8'h65;
        8'h75: out=8'h67;
        8'h76: out=8'hE5;
        8'h77: out=8'hE7;
        8'h78: out=8'h55;
        8'h79: out=8'h57;
        8'h7A: out=8'hD5;
        8'h7B: out=8'hD7;
        8'h7C: out=8'h75;
        8'h7D: out=8'h77;
        8'h7E: out=8'hF5;
        8'h7F: out=8'hF7;
        8'h80: out=8'h08;
        8'h81: out=8'h0A;
        8'h82: out=8'h88;
        8'h83: out=8'h8A;
        8'h84: out=8'h28;
        8'h85: out=8'h2A;
        8'h86: out=8'hA8;
        8'h87: out=8'hAA;
        8'h88: out=8'h18;
        8'h89: out=8'h1A;
        8'h8A: out=8'h98;
        8'h8B: out=8'h9A;
        8'h8C: out=8'h38;
        8'h8D: out=8'h3A;
        8'h8E: out=8'hB8;
        8'h8F: out=8'hBA;
        8'h90: out=8'h0C;
        8'h91: out=8'h0E;
        8'h92: out=8'h8C;
        8'h93: out=8'h8E;
        8'h94: out=8'h2C;
        8'h95: out=8'h2E;
        8'h96: out=8'hAC;
        8'h97: out=8'hAE;
        8'h98: out=8'h1C;
        8'h99: out=8'h1E;
        8'h9A: out=8'h9C;
        8'h9B: out=8'h9E;
        8'h9C: out=8'h3C;
        8'h9D: out=8'h3E;
        8'h9E: out=8'hBC;
        8'h9F: out=8'hBE;
        8'hA0: out=8'h48;
        8'hA1: out=8'h4A;
        8'hA2: out=8'hC8;
        8'hA3: out=8'hCA;
        8'hA4: out=8'h68;
        8'hA5: out=8'h6A;
        8'hA6: out=8'hE8;
        8'hA7: out=8'hEA;
        8'hA8: out=8'h58;
        8'hA9: out=8'h5A;
        8'hAA: out=8'hD8;
        8'hAB: out=8'hDA;
        8'hAC: out=8'h78;
        8'hAD: out=8'h7A;
        8'hAE: out=8'hF8;
        8'hAF: out=8'hFA;
        8'hB0: out=8'h4C;
        8'hB1: out=8'h4E;
        8'hB2: out=8'hCC;
        8'hB3: out=8'hCE;
        8'hB4: out=8'h6C;
        8'hB5: out=8'h6E;
        8'hB6: out=8'hEC;
        8'hB7: out=8'hEE;
        8'hB8: out=8'h5C;
        8'hB9: out=8'h5E;
        8'hBA: out=8'hDC;
        8'hBB: out=8'hDE;
        8'hBC: out=8'h7C;
        8'hBD: out=8'h7E;
        8'hBE: out=8'hFC;
        8'hBF: out=8'hFE;
        8'hC0: out=8'h09;
        8'hC1: out=8'h0B;
        8'hC2: out=8'h89;
        8'hC3: out=8'h8B;
        8'hC4: out=8'h29;
        8'hC5: out=8'h2B;
        8'hC6: out=8'hA9;
        8'hC7: out=8'hAB;
        8'hC8: out=8'h19;
        8'hC9: out=8'h1B;
        8'hCA: out=8'h99;
        8'hCB: out=8'h9B;
        8'hCC: out=8'h39;
        8'hCD: out=8'h3B;
        8'hCE: out=8'hB9;
        8'hCF: out=8'hBB;
        8'hD0: out=8'h0D;
        8'hD1: out=8'h0F;
        8'hD2: out=8'h8D;
        8'hD3: out=8'h8F;
        8'hD4: out=8'h2D;
        8'hD5: out=8'h2F;
        8'hD6: out=8'hAD;
        8'hD7: out=8'hAF;
        8'hD8: out=8'h1D;
        8'hD9: out=8'h1F;
        8'hDA: out=8'h9D;
        8'hDB: out=8'h9F;
        8'hDC: out=8'h3D;
        8'hDD: out=8'h3F;
        8'hDE: out=8'hBD;
        8'hDF: out=8'hBF;
        8'hE0: out=8'h49;
        8'hE1: out=8'h4B;
        8'hE2: out=8'hC9;
        8'hE3: out=8'hCB;
        8'hE4: out=8'h69;
        8'hE5: out=8'h6B;
        8'hE6: out=8'hE9;
        8'hE7: out=8'hEB;
        8'hE8: out=8'h59;
        8'hE9: out=8'h5B;
        8'hEA: out=8'hD9;
        8'hEB: out=8'hDB;
        8'hEC: out=8'h79;
        8'hED: out=8'h7B;
        8'hEE: out=8'hF9;
        8'hEF: out=8'hFB;
        8'hF0: out=8'h4D;
        8'hF1: out=8'h4F;
        8'hF2: out=8'hCD;
        8'hF3: out=8'hCF;
        8'hF4: out=8'h6D;
        8'hF5: out=8'h6F;
        8'hF6: out=8'hED;
        8'hF7: out=8'hEF;
        8'hF8: out=8'h5D;
        8'hF9: out=8'h5F;
        8'hFA: out=8'hDD;
        8'hFB: out=8'hDF;
        8'hFC: out=8'h7D;
        8'hFD: out=8'h7F;
        8'hFE: out=8'hFD;
        8'hFF: out=8'hFF;

        endcase
endmodule


module block_sbox(in, out);
input  [7:0] in;
output [7:0] out;
reg    [7:0] out;

always @(in)
        case (in)
        8'h00: out=8'h3A;
        8'h01: out=8'hEA;
        8'h02: out=8'h68;
        8'h03: out=8'hFE;
        8'h04: out=8'h33;
        8'h05: out=8'hE9;
        8'h06: out=8'h88;
        8'h07: out=8'h1A;
        8'h08: out=8'h83;
        8'h09: out=8'hCF;
        8'h0A: out=8'hE1;
        8'h0B: out=8'h7F;
        8'h0C: out=8'hBA;
        8'h0D: out=8'hE2;
        8'h0E: out=8'h38;
        8'h0F: out=8'h12;
        8'h10: out=8'hE8;
        8'h11: out=8'h27;
        8'h12: out=8'h61;
        8'h13: out=8'h95;
        8'h14: out=8'h0C;
        8'h15: out=8'h36;
        8'h16: out=8'hE5;
        8'h17: out=8'h70;
        8'h18: out=8'hA2;
        8'h19: out=8'h06;
        8'h1A: out=8'h82;
        8'h1B: out=8'h7C;
        8'h1C: out=8'h17;
        8'h1D: out=8'hA3;
        8'h1E: out=8'h26;
        8'h1F: out=8'h49;
        8'h20: out=8'hBE;
        8'h21: out=8'h7A;
        8'h22: out=8'h6D;
        8'h23: out=8'h47;
        8'h24: out=8'hC1;
        8'h25: out=8'h51;
        8'h26: out=8'h8F;
        8'h27: out=8'hF3;
        8'h28: out=8'hCC;
        8'h29: out=8'h5B;
        8'h2A: out=8'h67;
        8'h2B: out=8'hBD;
        8'h2C: out=8'hCD;
        8'h2D: out=8'h18;
        8'h2E: out=8'h08;
        8'h2F: out=8'hC9;
        8'h30: out=8'hFF;
        8'h31: out=8'h69;
        8'h32: out=8'hEF;
        8'h33: out=8'h03;
        8'h34: out=8'h4E;
        8'h35: out=8'h48;
        8'h36: out=8'h4A;
        8'h37: out=8'h84;
        8'h38: out=8'h3F;
        8'h39: out=8'hB4;
        8'h3A: out=8'h10;
        8'h3B: out=8'h04;
        8'h3C: out=8'hDC;
        8'h3D: out=8'hF5;
        8'h3E: out=8'h5C;
        8'h3F: out=8'hC6;
        8'h40: out=8'h16;
        8'h41: out=8'hAB;
        8'h42: out=8'hAC;
        8'h43: out=8'h4C;
        8'h44: out=8'hF1;
        8'h45: out=8'h6A;
        8'h46: out=8'h2F;
        8'h47: out=8'h3C;
        8'h48: out=8'h3B;
        8'h49: out=8'hD4;
        8'h4A: out=8'hD5;
        8'h4B: out=8'h94;
        8'h4C: out=8'hD0;
        8'h4D: out=8'hC4;
        8'h4E: out=8'h63;
        8'h4F: out=8'h62;
        8'h50: out=8'h71;
        8'h51: out=8'hA1;
        8'h52: out=8'hF9;
        8'h53: out=8'h4F;
        8'h54: out=8'h2E;
        8'h55: out=8'hAA;
        8'h56: out=8'hC5;
        8'h57: out=8'h56;
        8'h58: out=8'hE3;
        8'h59: out=8'h39;
        8'h5A: out=8'h93;
        8'h5B: out=8'hCE;
        8'h5C: out=8'h65;
        8'h5D: out=8'h64;
        8'h5E: out=8'hE4;
        8'h5F: out=8'h58;
        8'h60: out=8'h6C;
        8'h61: out=8'h19;
        8'h62: out=8'h42;
        8'h63: out=8'h79;
        8'h64: out=8'hDD;
        8'h65: out=8'hEE;
        8'h66: out=8'h96;
        8'h67: out=8'hF6;
        8'h68: out=8'h8A;
        8'h69: out=8'hEC;
        8'h6A: out=8'h1E;
        8'h6B: out=8'h85;
        8'h6C: out=8'h53;
        8'h6D: out=8'h45;
        8'h6E: out=8'hDE;
        8'h6F: out=8'hBB;
        8'h70: out=8'h7E;
        8'h71: out=8'h0A;
        8'h72: out=8'h9A;
        8'h73: out=8'h13;
        8'h74: out=8'h2A;
        8'h75: out=8'h9D;
        8'h76: out=8'hC2;
        8'h77: out=8'h5E;
        8'h78: out=8'h5A;
        8'h79: out=8'h1F;
        8'h7A: out=8'h32;
        8'h7B: out=8'h35;
        8'h7C: out=8'h9C;
        8'h7D: out=8'hA8;
        8'h7E: out=8'h73;
        8'h7F: out=8'h30;
        8'h80: out=8'h29;
        8'h81: out=8'h3D;
        8'h82: out=8'hE7;
        8'h83: out=8'h92;
        8'h84: out=8'h87;
        8'h85: out=8'h1B;
        8'h86: out=8'h2B;
        8'h87: out=8'h4B;
        8'h88: out=8'hA5;
        8'h89: out=8'h57;
        8'h8A: out=8'h97;
        8'h8B: out=8'h40;
        8'h8C: out=8'h15;
        8'h8D: out=8'hE6;
        8'h8E: out=8'hBC;
        8'h8F: out=8'h0E;
        8'h90: out=8'hEB;
        8'h91: out=8'hC3;
        8'h92: out=8'h34;
        8'h93: out=8'h2D;
        8'h94: out=8'hB8;
        8'h95: out=8'h44;
        8'h96: out=8'h25;
        8'h97: out=8'hA4;
        8'h98: out=8'h1C;
        8'h99: out=8'hC7;
        8'h9A: out=8'h23;
        8'h9B: out=8'hED;
        8'h9C: out=8'h90;
        8'h9D: out=8'h6E;
        8'h9E: out=8'h50;
        8'h9F: out=8'h00;
        8'hA0: out=8'h99;
        8'hA1: out=8'h9E;
        8'hA2: out=8'h4D;
        8'hA3: out=8'hD9;
        8'hA4: out=8'hDA;
        8'hA5: out=8'h8D;
        8'hA6: out=8'h6F;
        8'hA7: out=8'h5F;
        8'hA8: out=8'h3E;
        8'hA9: out=8'hD7;
        8'hAA: out=8'h21;
        8'hAB: out=8'h74;
        8'hAC: out=8'h86;
        8'hAD: out=8'hDF;
        8'hAE: out=8'h6B;
        8'hAF: out=8'h05;
        8'hB0: out=8'h8E;
        8'hB1: out=8'h5D;
        8'hB2: out=8'h37;
        8'hB3: out=8'h11;
        8'hB4: out=8'hD2;
        8'hB5: out=8'h28;
        8'hB6: out=8'h75;
        8'hB7: out=8'hD6;
        8'hB8: out=8'hA7;
        8'hB9: out=8'h77;
        8'hBA: out=8'h24;
        8'hBB: out=8'hBF;
        8'hBC: out=8'hF0;
        8'hBD: out=8'hB0;
        8'hBE: out=8'h02;
        8'hBF: out=8'hB7;
        8'hC0: out=8'hF8;
        8'hC1: out=8'hFC;
        8'hC2: out=8'h81;
        8'hC3: out=8'h09;
        8'hC4: out=8'hB1;
        8'hC5: out=8'h01;
        8'hC6: out=8'h76;
        8'hC7: out=8'h91;
        8'hC8: out=8'h7D;
        8'hC9: out=8'h0F;
        8'hCA: out=8'hC8;
        8'hCB: out=8'hA0;
        8'hCC: out=8'hF2;
        8'hCD: out=8'hCB;
        8'hCE: out=8'h78;
        8'hCF: out=8'h60;
        8'hD0: out=8'hD1;
        8'hD1: out=8'hF7;
        8'hD2: out=8'hE0;
        8'hD3: out=8'hB5;
        8'hD4: out=8'h98;
        8'hD5: out=8'h22;
        8'hD6: out=8'hB3;
        8'hD7: out=8'h20;
        8'hD8: out=8'h1D;
        8'hD9: out=8'hA6;
        8'hDA: out=8'hDB;
        8'hDB: out=8'h7B;
        8'hDC: out=8'h59;
        8'hDD: out=8'h9F;
        8'hDE: out=8'hAE;
        8'hDF: out=8'h31;
        8'hE0: out=8'hFB;
        8'hE1: out=8'hD3;
        8'hE2: out=8'hB6;
        8'hE3: out=8'hCA;
        8'hE4: out=8'h43;
        8'hE5: out=8'h72;
        8'hE6: out=8'h07;
        8'hE7: out=8'hF4;
        8'hE8: out=8'hD8;
        8'hE9: out=8'h41;
        8'hEA: out=8'h14;
        8'hEB: out=8'h55;
        8'hEC: out=8'h0D;
        8'hED: out=8'h54;
        8'hEE: out=8'h8B;
        8'hEF: out=8'hB9;
        8'hF0: out=8'hAD;
        8'hF1: out=8'h46;
        8'hF2: out=8'h0B;
        8'hF3: out=8'hAF;
        8'hF4: out=8'h80;
        8'hF5: out=8'h52;
        8'hF6: out=8'h2C;
        8'hF7: out=8'hFA;
        8'hF8: out=8'h8C;
        8'hF9: out=8'h89;
        8'hFA: out=8'h66;
        8'hFB: out=8'hFD;
        8'hFC: out=8'hB2;
        8'hFD: out=8'hA9;
        8'hFE: out=8'h9B;
        8'hFF: out=8'hC0;

        endcase
endmodule



module decrypt(clk,rst,ck,key_en,even_odd,en,encrypted,decrypted,invalid);
input             clk;
input             rst;
input             key_en;    
input             even_odd;  
input             en;        
input  [8*8-1:0]  ck;        
input  [  8-1:0]  encrypted; 
output [  8-1:0]  decrypted; 
output            invalid;   


reg  [56*8-1 : 0] even_kk;
reg  [56*8-1 : 0] odd_kk;
reg  [ 8*8-1 : 0] even_ck;
reg  [ 8*8-1 : 0] odd_ck;
reg               even_odd_d;

wire [56*8-1 : 0] kk;
wire              ks_busy;
wire              ks_done;

key_schedule ks( 
                        .clk  (clk)
                      , .rst  (rst)
                      , .start(key_en)
                      , .busy (ks_busy)
                      , .done (ks_done)
                      , .i_ck (ck)
                      , .o_kk (kk)
               );

always @(posedge clk)
begin
        if(rst)
        begin
                even_kk <=  448'h0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000;       
                odd_kk <=  448'h0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000;       
                even_ck <=  64'h0000000000000000;
                odd_ck <=  64'h0000000000000000;
        end
        else
        begin
                if(key_en & ~ks_busy)
                begin
                        even_odd_d <= even_odd;
                        if(even_odd)
                        begin
                                odd_ck <= ck;
                        end
                        else
                        begin
                                even_ck <= ck;
                        end
                end
                else if (ks_done)
                        if(even_odd_d)
                                odd_kk <= kk;
                        else
                                even_kk <= kk;
        end
end

reg  [8*8-1:0] group;    
reg            sync;     
reg  [8-1:0]   ts_cnt;   
reg            using_even_odd_key; 
reg            need_dec;
reg            group_valid;
reg            group_valid_d;
reg            head;
reg   [5:0]    group_id;
reg [4*8-1:0] group_d;


always @(posedge clk)
        if (rst)
        begin
                group  <= 64'h00000000;
                sync   <= 1'h0;
                ts_cnt <= 8'h00;
                using_even_odd_key <= 1'h0;
                need_dec <= 1'h0;
                group_valid_d <=1'h0; 
                head <= 1'h0;
        end
        else
        begin
                group_valid <=1'h0;
                group_valid_d <= group_valid;
                head <= 1'h0;
                group_d <= group;
                if(sync)
                begin
                        if(en)
                                ts_cnt <= ts_cnt + 8'h01;
                        if(ts_cnt == 8'hb7 ) 
                        begin
                                sync <= 1'h0;
                                ts_cnt<=8'h0;
                                group_valid<=1'h1;
                                group_id<=ts_cnt[7:3];
                        end
                        if(ts_cnt[2:0]==3'h7 && en )
                        begin
                                group_valid<=1'h1;
                                group_id<=ts_cnt[7:3];
                        end
                end
                if(en)
                begin
                        group  <= {  encrypted, group [8*8-1:1*8] };
                        if(group[5*8-1:4*8]==8'h47)
                        begin
                                sync   <= 1;
                                ts_cnt <= 8'h00;
                                using_even_odd_key <= group[62];
                                head  <= 1'h1;
                                group_d <= {1'h0,group[62:32]};
                        end
                end
        end

reg  [8*8-1:0] db;
reg            db_valid;

wire [56*8-1:0]kk_decrypt;
wire [ 8*8-1:0]ck_decrypt;

assign   kk_decrypt = (using_even_odd_key) ? odd_kk : even_kk ; 
assign   ck_decrypt = (using_even_odd_key) ? odd_ck : even_ck ; 

wire [8*8-1:0] sc_sb;
wire [8*8-1:0] sc_cb;
wire           init;
wire           sc_en;
wire           last;

assign sc_sb = group;
assign init  = group_id == 5'h00;
assign last  = group_id == 5'd22;
reg     [2:0] last_cnt;
reg     last_run;
assign sc_en = group_valid;

stream_cypher sc(  
                    .clk   (clk)
                  , .rst   (rst)
                  , .en    (sc_en)
                  , .init  (init)
                  , .ck    (ck_decrypt)
                  , .sb    (sc_sb)
                  , .cb    (sc_cb)
                  );

wire [ 8*8-1:0]   bco;
reg  [ 8*8-1:0]   bc;
reg  [ 8*8-1:0]   ib;
block_decypher bcm(
                          .kk (kk_decrypt)
                        , .ib (ib[8*8-1:0])
                        , .bd (bco)
                        );


always @(posedge clk)
if(rst)
begin
        db <= 64'h00;
        ib <= 128'h00000000000000000000000000000000;
        bc <= 64'hffffffffffffffff;
        last_cnt<=3'h0;
        last_run<=1'h0;
end
else
begin
        db_valid<=1'h0;                        
        if(group_valid_d)
        begin
                bc<=bco;
                if(init)
                begin
                        ib<={ ib[8*8-1:0],sc_cb };
                        db<=bco^sc_cb;
                end
                else
                begin
                        ib<={ ib[8*8-1:0],sc_cb^sc_sb };
                        db<=bco^sc_cb^sc_sb;
                end
                if(group_id>1'h0)
                begin
                        db_valid<=1'h1;                        
                end

                if(last)
                        last_run<=1'h1;

        end
        if(last_run)
        begin
                last_cnt<=last_cnt+3'h1;
                if(last_cnt==3'h7)
                begin
                        db_valid<=1'h1;                        
                        db<=bco;
                        last_run<=1'h0;
                end

        end
end

reg [2:0]     cnt;
reg           invalid;
reg [7:0]     decrypted;
reg [7*8-1:0] dec_group_ouput;

always @(posedge clk)
        if(rst)
        begin
                dec_group_ouput <= 32'h00000000;
                cnt <= 2'h0;
        end
        else
        begin
                invalid <= 1'h0;
                if(db_valid)
                begin
                        dec_group_ouput <= db[8*8-1:1*8];
                        decrypted <= db[7:0];
                        cnt <= 3'h7;
                        invalid <= 1'h1;
                end
                if(cnt)
                begin
                        invalid <= 1'h1;
                        dec_group_ouput <= {dec_group_ouput [7:0],dec_group_ouput[7*8-1:1*8]};
                        decrypted <= dec_group_ouput [ 7:0 ];
                        cnt <= cnt - 2'h1;
                end
                if(head)
                begin
                        dec_group_ouput <= group_d[4*8-1:1*8];
                        decrypted <= group_d[7:0];
                        cnt <= 2'h3;
                        invalid <= 1'h1;
                end
        end



endmodule






module top(cw,key);
		input 	[63:0]	cw;		
		output	[447:0]	key;            
		
		wire	[63:0]	key1;
		wire	[63:0]	key2;
		wire	[63:0]	key3;
		wire	[63:0]	key4;
		wire	[63:0]	key5;
		wire	[63:0]	key6;
		
		key_perm kp0 (   cw, key6 );
		key_perm kp1 ( key6, key5 );
		key_perm kp2 ( key5, key4 );
		key_perm kp3 ( key4, key3 );
		key_perm kp4 ( key3, key2 );
		key_perm kp5 ( key2, key1 );
		
		assign key[64*1-1:64*0]=key1 ^ 64'h0000000000000000;
		assign key[64*2-1:64*1]=key2 ^ 64'h0101010101010101;
		assign key[64*3-1:64*2]=key3 ^ 64'h0202020202020202;
		assign key[64*4-1:64*3]=key4 ^ 64'h0303030303030303;
		assign key[64*5-1:64*4]=key5 ^ 64'h0404040404040404;
		assign key[64*6-1:64*5]=key6 ^ 64'h0505050505050505;
		assign key[64*7-1:64*6]=cw   ^ 64'h0606060606060606;
		
endmodule





module key_perm(i_key,o_key);
    input   [63:0] i_key;                
    output  [63:0] o_key;

    assign o_key={ 
                        i_key[6'h1b],i_key[6'h20],i_key[6'h09],i_key[6'h37],
                        i_key[6'h29],i_key[6'h0d],i_key[6'h3e],i_key[6'h08],
                        i_key[6'h02],i_key[6'h0c],i_key[6'h27],i_key[6'h25],
                        i_key[6'h12],i_key[6'h0e],i_key[6'h38],i_key[6'h35],
                        i_key[6'h18],i_key[6'h03],i_key[6'h34],i_key[6'h30],
                        i_key[6'h2f],i_key[6'h3d],i_key[6'h2a],i_key[6'h22],
                        i_key[6'h0a],i_key[6'h1f],i_key[6'h26],i_key[6'h06],
                        i_key[6'h15],i_key[6'h3a],i_key[6'h14],i_key[6'h1a],
                        i_key[6'h2c],i_key[6'h19],i_key[6'h11],i_key[6'h0f],
                        i_key[6'h01],i_key[6'h21],i_key[6'h2e],i_key[6'h3f],
                        i_key[6'h28],i_key[6'h07],i_key[6'h0b],i_key[6'h16],
                        i_key[6'h00],i_key[6'h23],i_key[6'h2b],i_key[6'h17],
                        i_key[6'h05],i_key[6'h31],i_key[6'h33],i_key[6'h24],
                        i_key[6'h1d],i_key[6'h1c],i_key[6'h3c],i_key[6'h39],
                        i_key[6'h10],i_key[6'h13],i_key[6'h3b],i_key[6'h1e],
                        i_key[6'h36],i_key[6'h32],i_key[6'h04],i_key[6'h2d] 
                 };
endmodule

module key_schedule(clk,rst,start,i_ck,busy,done,o_kk);
        input             clk;
        input             rst;
        input             start;
        input  [ 8*8-1:0] i_ck;
        output            busy;
        output            done;
        output [56*8-1:0] o_kk;

        reg    [56*8-1:0] o_kk;
        reg    [     2:0] cnt;

        wire   [ 8*8-1:0] ik;
        wire   [ 8*8-1:0] okd;
        wire   [ 8*8-1:0] oki;
        reg    [ 8*8-1:0] ok_d;
        reg               done;
        reg               busy;

        key_perm kpo(.i_key(ok_d), .o_key(okd));
        key_perm kpi(.i_key(i_ck), .o_key(oki));

        always @(posedge clk)
        begin
                done <= 1'h0;
                if(rst)
                begin
                        o_kk <= 448'h0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000;
                        cnt  <= 3'h0;
                        ok_d <= 64'h0000000000000000;
                        busy <= 1'h0;
                end
                else 
                begin
                        if(cnt==3'h0 && busy)
                        begin
                                busy <= 1'h0;
                                done <= 1'h1;
                        end


                        if(start & ~busy)
                        begin
                                cnt  <= 3'h5;
                                o_kk <= {o_kk [(6*8)*8-1:8*0], i_ck};
                                busy <= 1'h1;
                                ok_d <= oki;
                                o_kk <= {o_kk [(6*8)*8-1:8*0],
                                                oki ^ 64'h0606060606060606};
                        end

                        if(busy)
                        begin
                                o_kk <= {o_kk [(6*8)*8-1:8*0],
                                                ok_d ^ { 
                                                        5'h00, cnt,
                                                        5'h00, cnt,
                                                        5'h00, cnt,
                                                        5'h00, cnt,
                                                        5'h00, cnt,
                                                        5'h00, cnt,
                                                        5'h00, cnt,
                                                        5'h00, cnt 
                                                      } 
                                         };
                                if(cnt!=3'h0)
                                        cnt  <= cnt - 3'h1;
                                ok_d <= okd;
                        end
                end
        end




endmodule

module sbox1(in,out);
input [4:0]in;
output [1:0]out;
reg [1:0]out;

always @(in)
        case (in)          
        5'h00:out=2'h2;
        5'h01:out=2'h0;
        5'h02:out=2'h1;
        5'h03:out=2'h1;
        5'h04:out=2'h2;
        5'h05:out=2'h3;
        5'h06:out=2'h3;
        5'h07:out=2'h0;
        5'h08:out=2'h3;
        5'h09:out=2'h2;
        5'h0a:out=2'h2;
        5'h0b:out=2'h0;
        5'h0c:out=2'h1;
        5'h0d:out=2'h1;
        5'h0e:out=2'h0;
        5'h0f:out=2'h3;
        5'h10:out=2'h0;
        5'h11:out=2'h3;
        5'h12:out=2'h3;
        5'h13:out=2'h0;
        5'h14:out=2'h2;
        5'h15:out=2'h2;
        5'h16:out=2'h1;
        5'h17:out=2'h1;
        5'h18:out=2'h2;
        5'h19:out=2'h2;
        5'h1a:out=2'h0;
        5'h1b:out=2'h3;
        5'h1c:out=2'h1;
        5'h1d:out=2'h1;
        5'h1e:out=2'h3;
        5'h1f:out=2'h0;
        endcase
endmodule

module sbox2(in,out);
input [4:0]in;
output [1:0]out;
reg [1:0]out;

always @(in)
        case (in)          
        5'h00:out=2'h3;
        5'h01:out=2'h1;
        5'h02:out=2'h0;
        5'h03:out=2'h2;
        5'h04:out=2'h2;
        5'h05:out=2'h3;
        5'h06:out=2'h3;
        5'h07:out=2'h0;
        5'h08:out=2'h1;
        5'h09:out=2'h3;
        5'h0a:out=2'h2;
        5'h0b:out=2'h1;
        5'h0c:out=2'h0;
        5'h0d:out=2'h0;
        5'h0e:out=2'h1;
        5'h0f:out=2'h2;
        5'h10:out=2'h3;
        5'h11:out=2'h1;
        5'h12:out=2'h0;
        5'h13:out=2'h3;
        5'h14:out=2'h3;
        5'h15:out=2'h2;
        5'h16:out=2'h0;
        5'h17:out=2'h2;
        5'h18:out=2'h0;
        5'h19:out=2'h0;
        5'h1a:out=2'h1;
        5'h1b:out=2'h2;
        5'h1c:out=2'h2;
        5'h1d:out=2'h1;
        5'h1e:out=2'h3;
        5'h1f:out=2'h1;
        endcase
endmodule

module sbox3(in,out);
input [4:0]in;
output [1:0]out;
reg [1:0]out;

always @(in)
        case (in)          
        5'h00:out=2'h2;
        5'h01:out=2'h0;
        5'h02:out=2'h1;
        5'h03:out=2'h2;
        5'h04:out=2'h2;
        5'h05:out=2'h3;
        5'h06:out=2'h3;
        5'h07:out=2'h1;
        5'h08:out=2'h1;
        5'h09:out=2'h1;
        5'h0a:out=2'h0;
        5'h0b:out=2'h3;
        5'h0c:out=2'h3;
        5'h0d:out=2'h0;
        5'h0e:out=2'h2;
        5'h0f:out=2'h0;
        5'h10:out=2'h1;
        5'h11:out=2'h3;
        5'h12:out=2'h0;
        5'h13:out=2'h1;
        5'h14:out=2'h3;
        5'h15:out=2'h0;
        5'h16:out=2'h2;
        5'h17:out=2'h2;
        5'h18:out=2'h2;
        5'h19:out=2'h0;
        5'h1a:out=2'h1;
        5'h1b:out=2'h2;
        5'h1c:out=2'h0;
        5'h1d:out=2'h3;
        5'h1e:out=2'h3;
        5'h1f:out=2'h1;
        endcase
endmodule

module sbox4(in,out);
input [4:0]in;
output [1:0]out;
reg [1:0]out;

always @(in)
        case (in)          
        5'h00:out=2'h3;
        5'h01:out=2'h1;
        5'h02:out=2'h2;
        5'h03:out=2'h3;
        5'h04:out=2'h0;
        5'h05:out=2'h2;
        5'h06:out=2'h1;
        5'h07:out=2'h2;
        5'h08:out=2'h1;
        5'h09:out=2'h2;
        5'h0a:out=2'h0;
        5'h0b:out=2'h1;
        5'h0c:out=2'h3;
        5'h0d:out=2'h0;
        5'h0e:out=2'h0;
        5'h0f:out=2'h3;
        5'h10:out=2'h1;
        5'h11:out=2'h0;
        5'h12:out=2'h3;
        5'h13:out=2'h1;
        5'h14:out=2'h2;
        5'h15:out=2'h3;
        5'h16:out=2'h0;
        5'h17:out=2'h3;
        5'h18:out=2'h0;
        5'h19:out=2'h3;
        5'h1a:out=2'h2;
        5'h1b:out=2'h0;
        5'h1c:out=2'h1;
        5'h1d:out=2'h2;
        5'h1e:out=2'h2;
        5'h1f:out=2'h1;
        endcase
endmodule

module sbox5(in,out);
input [4:0]in;
output [1:0]out;
reg [1:0]out;

always @(in)
        case (in)          
        5'h00:out=2'h2;
        5'h01:out=2'h0;
        5'h02:out=2'h0;
        5'h03:out=2'h1;
        5'h04:out=2'h3;
        5'h05:out=2'h2;
        5'h06:out=2'h3;
        5'h07:out=2'h2;
        5'h08:out=2'h0;
        5'h09:out=2'h1;
        5'h0a:out=2'h3;
        5'h0b:out=2'h3;
        5'h0c:out=2'h1;
        5'h0d:out=2'h0;
        5'h0e:out=2'h2;
        5'h0f:out=2'h1;
        5'h10:out=2'h2;
        5'h11:out=2'h3;
        5'h12:out=2'h2;
        5'h13:out=2'h0;
        5'h14:out=2'h0;
        5'h15:out=2'h3;
        5'h16:out=2'h1;
        5'h17:out=2'h1;
        5'h18:out=2'h1;
        5'h19:out=2'h0;
        5'h1a:out=2'h3;
        5'h1b:out=2'h2;
        5'h1c:out=2'h3;
        5'h1d:out=2'h1;
        5'h1e:out=2'h0;
        5'h1f:out=2'h2;
        endcase
endmodule

module sbox6(in,out);
input [4:0]in;
output [1:0]out;
reg [1:0]out;

always @(in)
        case (in)          
        5'h00:out=2'h0;
        5'h01:out=2'h1;
        5'h02:out=2'h2;
        5'h03:out=2'h3;
        5'h04:out=2'h1;
        5'h05:out=2'h2;
        5'h06:out=2'h2;
        5'h07:out=2'h0;
        5'h08:out=2'h0;
        5'h09:out=2'h1;
        5'h0a:out=2'h3;
        5'h0b:out=2'h0;
        5'h0c:out=2'h2;
        5'h0d:out=2'h3;
        5'h0e:out=2'h1;
        5'h0f:out=2'h3;
        5'h10:out=2'h2;
        5'h11:out=2'h3;
        5'h12:out=2'h0;
        5'h13:out=2'h2;
        5'h14:out=2'h3;
        5'h15:out=2'h0;
        5'h16:out=2'h1;
        5'h17:out=2'h1;
        5'h18:out=2'h2;
        5'h19:out=2'h1;
        5'h1a:out=2'h1;
        5'h1b:out=2'h2;
        5'h1c:out=2'h0;
        5'h1d:out=2'h3;
        5'h1e:out=2'h3;
        5'h1f:out=2'h0;
        endcase
endmodule

module sbox7(in,out);
input [4:0]in;
output [1:0]out;
reg [1:0]out;

always @(in)
        case (in)          
        5'h00:out=2'h0;
        5'h01:out=2'h3;
        5'h02:out=2'h2;
        5'h03:out=2'h2;
        5'h04:out=2'h3;
        5'h05:out=2'h0;
        5'h06:out=2'h0;
        5'h07:out=2'h1;
        5'h08:out=2'h3;
        5'h09:out=2'h0;
        5'h0a:out=2'h1;
        5'h0b:out=2'h3;
        5'h0c:out=2'h1;
        5'h0d:out=2'h2;
        5'h0e:out=2'h2;
        5'h0f:out=2'h1;
        5'h10:out=2'h1;
        5'h11:out=2'h0;
        5'h12:out=2'h3;
        5'h13:out=2'h3;
        5'h14:out=2'h0;
        5'h15:out=2'h1;
        5'h16:out=2'h1;
        5'h17:out=2'h2;
        5'h18:out=2'h2;
        5'h19:out=2'h3;
        5'h1a:out=2'h1;
        5'h1b:out=2'h0;
        5'h1c:out=2'h2;
        5'h1d:out=2'h3;
        5'h1e:out=2'h0;
        5'h1f:out=2'h2;
        endcase
endmodule



module sboxes(A, s1, s2, s3, s4, s5, s6, s7);
input [9*4-1:0] A;

output [2-1:0] s1;
output [2-1:0] s2;
output [2-1:0] s3;
output [2-1:0] s4;
output [2-1:0] s5;
output [2-1:0] s6;
output [2-1:0] s7;

sbox1 b1({A[(4-1)*4+0], A[(1-1)*4+2], A[(6-1)*4+1], A[(7-1)*4+3], A[(9-1)*4+0]}, s1);
sbox2 b2({A[(2-1)*4+1], A[(3-1)*4+2], A[(6-1)*4+3], A[(7-1)*4+0], A[(9-1)*4+1]}, s2);
sbox3 b3({A[(1-1)*4+3], A[(2-1)*4+0], A[(5-1)*4+1], A[(5-1)*4+3], A[(6-1)*4+2]}, s3);
sbox4 b4({A[(3-1)*4+3], A[(1-1)*4+1], A[(2-1)*4+3], A[(4-1)*4+2], A[(8-1)*4+0]}, s4);
sbox5 b5({A[(5-1)*4+2], A[(4-1)*4+3], A[(6-1)*4+0], A[(8-1)*4+1], A[(9-1)*4+2]}, s5);
sbox6 b6({A[(3-1)*4+1], A[(4-1)*4+1], A[(5-1)*4+0], A[(7-1)*4+2], A[(9-1)*4+3]}, s6);
sbox7 b7({A[(2-1)*4+2], A[(3-1)*4+0], A[(7-1)*4+1], A[(8-1)*4+2], A[(8-1)*4+3]}, s7);

endmodule




module stream_8bytes(
                                init,sb,
                                Ai,Bi,Di,Ei,Fi,Xi,Yi,Zi,pi,qi,ri,
                                Ao,Bo,Do,Eo,Fo,Xo,Yo,Zo,po,qo,ro,
                                cb
                        );
input            init;
input [8*8-1 :0] sb;

input [10*4-1:0] Ai;
input [10*4-1:0] Bi;
input [3     :0] Di;
input [3     :0] Ei;
input [3     :0] Fi;
input [3     :0] Xi;
input [3     :0] Yi;
input [3     :0] Zi;
input            pi;
input            qi;
input            ri;

output [10*4-1:0] Ao;
output [10*4-1:0] Bo;
output [3     :0] Do;
output [3     :0] Eo;
output [3     :0] Fo;
output [3     :0] Xo;
output [3     :0] Yo;
output [3     :0] Zo;
output            po;
output            qo;
output            ro;

output [8*8-1 :0] cb;

wire  [10*4-1:0] A1;
wire  [10*4-1:0] B1;
wire  [3     :0] D1;
wire  [3     :0] E1;
wire  [3     :0] F1;
wire  [3     :0] X1;
wire  [3     :0] Y1;
wire  [3     :0] Z1;
wire             p1;
wire             q1;
wire             r1;

wire  [10*4-1:0] A2;
wire  [10*4-1:0] B2;
wire  [3     :0] D2;
wire  [3     :0] E2;
wire  [3     :0] F2;
wire  [3     :0] X2;
wire  [3     :0] Y2;
wire  [3     :0] Z2;
wire             p2;
wire             q2;
wire             r2;

wire  [10*4-1:0] A3;
wire  [10*4-1:0] B3;
wire  [3     :0] D3;
wire  [3     :0] E3;
wire  [3     :0] F3;
wire  [3     :0] X3;
wire  [3     :0] Y3;
wire  [3     :0] Z3;
wire             p3;
wire             q3;
wire             r3;

wire  [10*4-1:0] A4;
wire  [10*4-1:0] B4;
wire  [3     :0] D4;
wire  [3     :0] E4; 
wire  [3     :0] F4; 
wire  [3     :0] X4;
wire  [3     :0] Y4;
wire  [3     :0] Z4;
wire             p4;
wire             q4;
wire             r4;

wire  [10*4-1:0] A5;
wire  [10*4-1:0] B5;
wire  [3     :0] D5;
wire  [3     :0] E5;
wire  [3     :0] F5;
wire  [3     :0] X5;
wire  [3     :0] Y5;
wire  [3     :0] Z5;
wire             p5;
wire             q5;
wire             r5;

wire  [10*4-1:0] A6;
wire  [10*4-1:0] B6;
wire  [3     :0] D6;
wire  [3     :0] E6;
wire  [3     :0] F6;
wire  [3     :0] X6;
wire  [3     :0] Y6;
wire  [3     :0] Z6;
wire             p6;
wire             q6;
wire             r6;

wire  [10*4-1:0] A7;
wire  [10*4-1:0] B7;
wire  [3     :0] D7;
wire  [3     :0] E7;
wire  [3     :0] F7;
wire  [3     :0] X7;
wire  [3     :0] Y7;
wire  [3     :0] Z7;
wire             p7;
wire             q7;
wire             r7;

stream_byte b1(
                         .init(init)
                        ,.sb  (sb[8*1-1:8*0])
                        ,.Ai  (Ai)
                        ,.Bi  (Bi)
                        ,.Di  (Di)
                        ,.Ei  (Ei)
                        ,.Fi  (Fi)
                        ,.Xi  (Xi)
                        ,.Yi  (Yi)
                        ,.Zi  (Zi)
                        ,.pi  (pi)
                        ,.qi  (qi)
                        ,.ri  (ri)
                        ,.Ao  (A1)
                        ,.Bo  (B1)
                        ,.Do  (D1)
                        ,.Eo  (E1)
                        ,.Fo  (F1)
                        ,.Xo  (X1)
                        ,.Yo  (Y1)
                        ,.Zo  (Z1)
                        ,.po  (p1)
                        ,.qo  (q1)
                        ,.ro  (r1)
                        ,.op  (cb[8*1-1:8*0])                        
                );

stream_byte b2(
                         .init(init)
                        ,.sb  (sb[8*2-1:8*1])
                        ,.Ai  (A1)
                        ,.Bi  (B1)
                        ,.Di  (D1)
                        ,.Ei  (E1)
                        ,.Fi  (F1)
                        ,.Xi  (X1)
                        ,.Yi  (Y1)
                        ,.Zi  (Z1)
                        ,.pi  (p1)
                        ,.qi  (q1)
                        ,.ri  (r1)
                        ,.Ao  (A2)
                        ,.Bo  (B2)
                        ,.Do  (D2)
                        ,.Eo  (E2)
                        ,.Fo  (F2)
                        ,.Xo  (X2)
                        ,.Yo  (Y2)
                        ,.Zo  (Z2)
                        ,.po  (p2)
                        ,.qo  (q2)
                        ,.ro  (r2)
                        ,.op  (cb[8*2-1:8*1])                        
                );

stream_byte b3(
                         .init(init)
                        ,.sb  (sb[8*3-1:8*2])
                        ,.Ai  (A2)
                        ,.Bi  (B2)
                        ,.Di  (D2)
                        ,.Ei  (E2)
                        ,.Fi  (F2)
                        ,.Xi  (X2)
                        ,.Yi  (Y2)
                        ,.Zi  (Z2)
                        ,.pi  (p2)
                        ,.qi  (q2)
                        ,.ri  (r2)
                        ,.Ao  (A3)
                        ,.Bo  (B3)
                        ,.Do  (D3)
                        ,.Eo  (E3)
                        ,.Fo  (F3)
                        ,.Xo  (X3)
                        ,.Yo  (Y3)
                        ,.Zo  (Z3)
                        ,.po  (p3)
                        ,.qo  (q3)
                        ,.ro  (r3)
                        ,.op  (cb[8*3-1:8*2])                        
                );

stream_byte b4(
                         .init(init)
                        ,.sb  (sb[8*4-1:8*3])
                        ,.Ai  (A3)
                        ,.Bi  (B3)
                        ,.Di  (D3)
                        ,.Ei  (E3)
                        ,.Fi  (F3)
                        ,.Xi  (X3)
                        ,.Yi  (Y3)
                        ,.Zi  (Z3)
                        ,.pi  (p3)
                        ,.qi  (q3)
                        ,.ri  (r3)
                        ,.Ao  (A4)
                        ,.Bo  (B4)
                        ,.Do  (D4)
                        ,.Eo  (E4)
                        ,.Fo  (F4)
                        ,.Xo  (X4)
                        ,.Yo  (Y4)
                        ,.Zo  (Z4)
                        ,.po  (p4)
                        ,.qo  (q4)
                        ,.ro  (r4)
                        ,.op  (cb[8*4-1:8*3])                        
                );

stream_byte b5(
                         .init(init)
                        ,.sb  (sb[8*5-1:8*4])
                        ,.Ai  (A4)
                        ,.Bi  (B4)
                        ,.Di  (D4)
                        ,.Ei  (E4)
                        ,.Fi  (F4)
                        ,.Xi  (X4)
                        ,.Yi  (Y4)
                        ,.Zi  (Z4)
                        ,.pi  (p4)
                        ,.qi  (q4)
                        ,.ri  (r4)
                        ,.Ao  (A5)
                        ,.Bo  (B5)
                        ,.Do  (D5)
                        ,.Eo  (E5)
                        ,.Fo  (F5)
                        ,.Xo  (X5)
                        ,.Yo  (Y5)
                        ,.Zo  (Z5)
                        ,.po  (p5)
                        ,.qo  (q5)
                        ,.ro  (r5)
                        ,.op  (cb[8*5-1:8*4])                        
                );

stream_byte b6(
                         .init(init)
                        ,.sb  (sb[8*6-1:8*5])
                        ,.Ai  (A5)
                        ,.Bi  (B5)
                        ,.Di  (D5)
                        ,.Ei  (E5)
                        ,.Fi  (F5)
                        ,.Xi  (X5)
                        ,.Yi  (Y5)
                        ,.Zi  (Z5)
                        ,.pi  (p5)
                        ,.qi  (q5)
                        ,.ri  (r5)
                        ,.Ao  (A6)
                        ,.Bo  (B6)
                        ,.Do  (D6)
                        ,.Eo  (E6)
                        ,.Fo  (F6)
                        ,.Xo  (X6)
                        ,.Yo  (Y6)
                        ,.Zo  (Z6)
                        ,.po  (p6)
                        ,.qo  (q6)
                        ,.ro  (r6)
                        ,.op  (cb[8*6-1:8*5])                        
                );

stream_byte b7(
                         .init(init)
                        ,.sb  (sb[8*7-1:8*6])
                        ,.Ai  (A6)
                        ,.Bi  (B6)
                        ,.Di  (D6)
                        ,.Ei  (E6)
                        ,.Fi  (F6)
                        ,.Xi  (X6)
                        ,.Yi  (Y6)
                        ,.Zi  (Z6)
                        ,.pi  (p6)
                        ,.qi  (q6)
                        ,.ri  (r6)
                        ,.Ao  (A7)
                        ,.Bo  (B7)
                        ,.Do  (D7)
                        ,.Eo  (E7)
                        ,.Fo  (F7)
                        ,.Xo  (X7)
                        ,.Yo  (Y7)
                        ,.Zo  (Z7)
                        ,.po  (p7)
                        ,.qo  (q7)
                        ,.ro  (r7)
                        ,.op  (cb[8*7-1:8*6])                        
                );

stream_byte b8(
                         .init(init)
                        ,.sb  (sb[8*8-1:8*7])
                        ,.Ai  (A7)
                        ,.Bi  (B7)
                        ,.Di  (D7)
                        ,.Ei  (E7)
                        ,.Fi  (F7)
                        ,.Xi  (X7)
                        ,.Yi  (Y7)
                        ,.Zi  (Z7)
                        ,.pi  (p7)
                        ,.qi  (q7)
                        ,.ri  (r7)
                        ,.Ao  (Ao)
                        ,.Bo  (Bo)
                        ,.Do  (Do)
                        ,.Eo  (Eo)
                        ,.Fo  (Fo)
                        ,.Xo  (Xo)
                        ,.Yo  (Yo)
                        ,.Zo  (Zo)
                        ,.po  (po)
                        ,.qo  (qo)
                        ,.ro  (ro)
                        ,.op  (cb[8*8-1:8*7])                        
                );

endmodule





module stream_byte(init,sb,
                                Ai,Bi,Di,Ei,Fi,Xi,Yi,Zi,pi,qi,ri,
                                Ao,Bo,Do,Eo,Fo,Xo,Yo,Zo,po,qo,ro,
                                op
                  );
input            init;
input [7     :0] sb;

input [10*4-1:0] Ai;
input [10*4-1:0] Bi;
input [3     :0] Di;
input [3     :0] Ei;
input [3     :0] Fi;
input [3     :0] Xi;
input [3     :0] Yi;
input [3     :0] Zi;
input            pi;
input            qi;
input            ri;

output [10*4-1:0] Ao;
output [10*4-1:0] Bo;
output [3     :0] Do;
output [3     :0] Eo;
output [3     :0] Fo;
output [3     :0] Xo;
output [3     :0] Yo;
output [3     :0] Zo;
output            po;
output            qo;
output            ro;

output[7     :0]  op;

wire [10*4-1:0] A1;
wire [10*4-1:0] B1;
wire [3     :0] D1;
wire [3     :0] E1;
wire [3     :0] F1;
wire [3     :0] X1;
wire [3     :0] Y1;
wire [3     :0] Z1;
wire            p1;
wire            q1;

wire [10*4-1:0] A2;
wire [10*4-1:0] B2;
wire [3     :0] D2;
wire [3     :0] E2;
wire [3     :0] F2;
wire [3     :0] X2;
wire [3     :0] Y2;
wire [3     :0] Z2;
wire            p2;
wire            q2;

wire [10*4-1:0] A3;
wire [10*4-1:0] B3;
wire [3     :0] D3;
wire [3     :0] E3;
wire [3     :0] F3;
wire [3     :0] X3;
wire [3     :0] Y3;
wire [3     :0] Z3;
wire            p3;
wire            q3;
wire [7     :0] _op;

wire [3     :0] in1;
wire [3     :0] in2;

assign in1 = sb[7:4];
assign in2 = sb[3:0];

stream_iteration  b1 (
                         .init(init)
                        ,.in1 (in2)
                        ,.in2 (in1)
                        ,.Ai  (Ai)
                        ,.Bi  (Bi)
                        ,.Di  (Di)
                        ,.Ei  (Ei)
                        ,.Fi  (Fi)
                        ,.Xi  (Xi)
                        ,.Yi  (Yi)
                        ,.Zi  (Zi)
                        ,.pi  (pi)
                        ,.qi  (qi)
                        ,.ri  (ri)
                        ,.Ao  (A1)
                        ,.Bo  (B1)
                        ,.Do  (D1)
                        ,.Eo  (E1)
                        ,.Fo  (F1)
                        ,.Xo  (X1)
                        ,.Yo  (Y1)
                        ,.Zo  (Z1)
                        ,.po  (p1)
                        ,.qo  (q1)
                        ,.ro  (r1)
                        ,.op  (_op[7:6])
                        );

stream_iteration  b2 (
                         .init(init)
                        ,.in1 (in1)
                        ,.in2 (in2)
                        ,.Ai  (A1)
                        ,.Bi  (B1)
                        ,.Di  (D1)
                        ,.Ei  (E1)
                        ,.Fi  (F1)
                        ,.Xi  (X1)
                        ,.Yi  (Y1)
                        ,.Zi  (Z1)
                        ,.pi  (p1)
                        ,.qi  (q1)
                        ,.ri  (r1)
                        ,.Ao  (A2)
                        ,.Bo  (B2)
                        ,.Do  (D2)
                        ,.Eo  (E2)
                        ,.Fo  (F2)
                        ,.Xo  (X2)
                        ,.Yo  (Y2)
                        ,.Zo  (Z2)
                        ,.po  (p2)
                        ,.qo  (q2)
                        ,.ro  (r2)
                        ,.op  (_op[5:4])
                        );

stream_iteration  b3 (
                         .init(init)
                        ,.in1 (in2)
                        ,.in2 (in1)
                        ,.Ai  (A2)
                        ,.Bi  (B2)
                        ,.Di  (D2)
                        ,.Ei  (E2)
                        ,.Fi  (F2)
                        ,.Xi  (X2)
                        ,.Yi  (Y2)
                        ,.Zi  (Z2)
                        ,.pi  (p2)
                        ,.qi  (q2)
                        ,.ri  (r2)
                        ,.Ao  (A3)
                        ,.Bo  (B3)
                        ,.Do  (D3)
                        ,.Eo  (E3)
                        ,.Fo  (F3)
                        ,.Xo  (X3)
                        ,.Yo  (Y3)
                        ,.Zo  (Z3)
                        ,.po  (p3)
                        ,.qo  (q3)
                        ,.ro  (r3)
                        ,.op  (_op[3:2])
                        );

stream_iteration  b4 (
                         .init(init)
                        ,.in1 (in1)
                        ,.in2 (in2)
                        ,.Ai  (A3)
                        ,.Bi  (B3)
                        ,.Di  (D3)
                        ,.Ei  (E3)
                        ,.Fi  (F3)
                        ,.Xi  (X3)
                        ,.Yi  (Y3)
                        ,.Zi  (Z3)
                        ,.pi  (p3)
                        ,.qi  (q3)
                        ,.ri  (r3)
                        ,.Ao  (Ao)
                        ,.Bo  (Bo)
                        ,.Do  (Do)
                        ,.Eo  (Eo)
                        ,.Fo  (Fo)
                        ,.Xo  (Xo)
                        ,.Yo  (Yo)
                        ,.Zo  (Zo)
                        ,.po  (po)
                        ,.qo  (qo)
                        ,.ro  (ro)
                        ,.op  (_op[1:0])
                        );

assign op=(init)?sb:_op;
endmodule




module stream_cypher(clk,rst,en,init,ck,sb,cb);
input                 clk;
input                 rst;   
input                 en;      
input                 init;    
input  [8 *8-1:0]     ck;
input  [8 *8-1:0]     sb;
output [8 *8-1:0]     cb;


reg    [10*4-1 : 0]A;
reg    [10*4-1 : 0]B;
reg    [4-1    : 0]X;
reg    [4-1    : 0]Y;
reg    [4-1    : 0]Z;
reg    [4-1    : 0]D;
reg    [4-1    : 0]E;
reg    [4-1    : 0]F;
reg                p;
reg                q;
reg                r;
reg    [8 *8-1 : 0]cb;

wire   [10*4-1 : 0]Ao;
wire   [10*4-1 : 0]Ainit;
wire   [10*4-1 : 0]Bo;
wire   [10*4-1 : 0]Binit;
wire   [4-1    : 0]Xo;
wire   [4-1    : 0]Yo;
wire   [4-1    : 0]Zo;
wire   [4-1    : 0]Do;
wire   [4-1    : 0]Eo;
wire   [4-1    : 0]Fo;
wire               po;
wire               qo;
wire               ro;
wire   [8 *8-1 : 0]cbo;

assign Ainit = { 
                4'b0,         4'b0,
        ck[7*4-1:6*4],ck[8*4-1:7*4], 
        ck[5*4-1:4*4],ck[6*4-1:5*4], 
        ck[3*4-1:2*4],ck[4*4-1:3*4], 
        ck[1*4-1:0*4],ck[2*4-1:1*4] 
};

assign Binit = { 
                   4'b0,           4'b0,
        ck[15*4-1:14*4],ck[16*4-1:15*4], 
        ck[13*4-1:12*4],ck[14*4-1:13*4], 
        ck[11*4-1:10*4],ck[12*4-1:11*4], 
        ck[ 9*4-1: 8*4],ck[10*4-1: 9*4]
};

always @(posedge clk)
begin
        if(rst)
        begin
                A<= 40'h0000000000;
                B<= 40'h0000000000;
                X<=  8'h00;
                Y<=  8'h00;
                Z<=  8'h00;
                D<=  8'h00;
                E<=  8'h00;
                F<=  8'h00;
                p<=  8'h00;
                q<=  8'h00;
                r<=  8'h00;
        end
        else 
        begin
                if(en)
                begin
                        cb <= cbo;
                        A<=  Ao;
                        B<=  Bo;
                        X<=  Xo;
                        Y<=  Yo;
                        Z<=  Zo;
                        D<=  Do;
                        E<=  Eo;
                        F<=  Fo;
                        p<=  po;
                        q<=  qo;
                        r<=  ro;
                end
        end
end


stream_8bytes b(
                        .init(init)
                       ,.sb(sb)
                       ,.Ai((init)?Ainit:A)
                       ,.Bi((init)?Binit:B)
                       ,.Di((init)?4'b0 :D)
                       ,.Ei((init)?4'b0 :E)
                       ,.Fi((init)?4'b0 :F)
                       ,.Xi((init)?4'b0 :X)
                       ,.Yi((init)?4'b0 :Y)
                       ,.Zi((init)?4'b0 :Z)
                       ,.pi((init)?1'b0 :p)
                       ,.qi((init)?1'b0 :q)
                       ,.ri((init)?1'b0 :r)

                       ,.Ao(Ao)
                       ,.Bo(Bo)
                       ,.Do(Do)
                       ,.Eo(Eo)
                       ,.Fo(Fo)
                       ,.Xo(Xo)
                       ,.Yo(Yo)
                       ,.Zo(Zo)
                       ,.po(po)
                       ,.qo(qo)
                       ,.ro(ro)
                       ,.cb(cbo)
                );

endmodule



module stream_iteration(init,in1,in2,
                                Ai,Bi,Di,Ei,Fi,Xi,Yi,Zi,pi,qi,ri,
                                Ao,Bo,Do,Eo,Fo,Xo,Yo,Zo,po,qo,ro,
                                op);
input    init;
input [3     :0] in1;
input [3     :0] in2;

input [10*4-1:0] Ai;
input [10*4-1:0] Bi;
input [3     :0] Di;
input [3     :0] Ei;
input [3     :0] Fi;
input [3     :0] Xi;
input [3     :0] Yi;
input [3     :0] Zi;
input            pi;
input            qi;
input            ri;

output [10*4-1:0] Ao;
output [10*4-1:0] Bo;
output [3     :0] Do;
output [3     :0] Eo;
output [3     :0] Fo;
output [3     :0] Xo;
output [3     :0] Yo;
output [3     :0] Zo;
output            po;
output            qo;
output            ro;

output[1     :0] op;

wire [1:0] s1;
wire [1:0] s2;
wire [1:0] s3;
wire [1:0] s4;
wire [1:0] s5;
wire [1:0] s6;
wire [1:0] s7;

wire [3:0] extra_B;
wire [3:0] next_A1;
wire [3:0] _next_B1;
wire [3:0] next_B1;
wire [3:0] next_E;

wire [4:0] total;

sboxes b(
                .A(Ai[9*4-1:0])
               ,.s1(s1)
               ,.s2(s2)
               ,.s3(s3)
               ,.s4(s4)
               ,.s5(s5)
               ,.s6(s6)
               ,.s7(s7)
        );

assign extra_B ={( Bi[(3-1)*4+0] ^ Bi[(6-1)*4+1] ^ Bi[(7-1)*4+2] ^ Bi[(9-1)*4+3]) ,
                 ( Bi[(6-1)*4+0] ^ Bi[(8-1)*4+1] ^ Bi[(3-1)*4+3] ^ Bi[(4-1)*4+2]) ,
                 ( Bi[(5-1)*4+3] ^ Bi[(8-1)*4+2] ^ Bi[(4-1)*4+0] ^ Bi[(5-1)*4+1]) ,
                 ( Bi[(9-1)*4+2] ^ Bi[(6-1)*4+3] ^ Bi[(3-1)*4+1] ^ Bi[(8-1)*4+0]) };

assign next_A1=(init)?   Ai[(10)*4-1:(10-1)*4] ^ Xi ^ Di ^ in2
                        :Ai[(10)*4-1:(10-1)*4] ^ Xi;

assign _next_B1=(init)?  Bi[7*4-1:(7-1)*4] ^ Bi[10*4-1:(10-1)*4] ^ Yi ^ in1
                        :Bi[7*4-1:(7-1)*4] ^ Bi[10*4-1:(10-1)*4] ^ Yi ;

assign next_B1=(pi)?{ _next_B1[2:0], _next_B1[3] }: _next_B1;

assign Do = Ei ^ Zi ^ extra_B;

assign next_E=Fi;

assign total=Zi+Ei+ri;

assign Fo=(qi)? total[3:0]:Ei;
assign ro=(qi)? total[4]:ri;

assign Eo=next_E;

assign Ao[10*4-1:4]=Ai[9*4-1:0];
assign Ao[1*4-1:0] =next_A1;
assign Bo[10*4-1:4]=Bi[9*4-1:0];
assign Bo[1*4-1:0] =next_B1;

assign Xo ={s4[0] , s3[0] , s2[1] , s1[1] };
assign Yo ={s6[0] , s5[0] , s4[1] , s3[1] };
assign Zo ={s2[0] , s1[0] , s6[1] , s5[1] };

assign po=s7[1];
assign qo=s7[0];

assign op = { Do[3] ^ Do[2], Do[1] ^ Do[0]  };
endmodule



