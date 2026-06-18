

module des(clk,reset,load_i,decrypt_i,data_i,key_i,data_o,ready_o);
input clk;
input reset;
input load_i;
input decrypt_i;
input [63:0] data_i;
input [63:0] key_i;
output [63:0] data_o;
output ready_o;

reg [63:0] data_o;
reg ready_o;


reg [3:0] stage1_iter;

reg [3:0] next_stage1_iter;

reg next_ready_o;

reg[63:0] next_data_o;

reg data_ready;

reg next_data_ready;

reg [31:0] stage1_L_i;

reg [31:0] stage1_R_i;

reg [55:0] stage1_round_key_i;

reg [3:0] stage1_iteration_i;
wire [31:0] stage1_R_o;
wire [31:0] stage1_L_o;
wire [55:0] stage1_round_key_o;
wire [5:0] s1_stag1_i;
wire [5:0] s2_stag1_i;
wire [5:0] s3_stag1_i;
wire [5:0] s4_stag1_i;
wire [5:0] s5_stag1_i;
wire [5:0] s6_stag1_i;
wire [5:0] s7_stag1_i;
wire [5:0] s8_stag1_i;
wire [3:0] s1_stag1_o;
wire [3:0] s2_stag1_o;
wire [3:0] s3_stag1_o;
wire [3:0] s4_stag1_o;
wire [3:0] s5_stag1_o;
wire [3:0] s6_stag1_o;
wire [3:0] s7_stag1_o;
wire [3:0] s8_stag1_o;

reg[31:0]  L_i_var,R_i_var;	
reg[63:0]  data_i_var,data_o_var,data_o_var_t,key_i_var;
reg[55:0]  key_var_perm;


desround rd1 (.clk(clk), .reset(reset), .iteration_i(stage1_iteration_i), .decrypt_i(decrypt_i), .R_i(stage1_R_i), .L_i(stage1_L_i), .Key_i(stage1_round_key_i), .R_o(stage1_R_o), .L_o(stage1_L_o), .Key_o(stage1_round_key_o), .s1_o(s1_stag1_i), .s2_o(s2_stag1_i), .s3_o(s3_stag1_i), .s4_o(s4_stag1_i), .s5_o(s5_stag1_i), .s6_o(s6_stag1_i), .s7_o(s7_stag1_i), .s8_o(s8_stag1_i), .s1_i(s1_stag1_o), .s2_i(s2_stag1_o), .s3_i(s3_stag1_o), .s4_i(s4_stag1_o), .s5_i(s5_stag1_o), .s6_i(s6_stag1_o), .s7_i(s7_stag1_o), .s8_i(s8_stag1_o));
s1 sbox1 (.stage1_input(s1_stag1_i), .stage1_output(s1_stag1_o));
s2 sbox2 (.stage1_input(s2_stag1_i), .stage1_output(s2_stag1_o));
s3 sbox3 (.stage1_input(s3_stag1_i), .stage1_output(s3_stag1_o));
s4 sbox4 (.stage1_input(s4_stag1_i), .stage1_output(s4_stag1_o));
s5 sbox5 (.stage1_input(s5_stag1_i), .stage1_output(s5_stag1_o));
s6 sbox6 (.stage1_input(s6_stag1_i), .stage1_output(s6_stag1_o));
s7 sbox7 (.stage1_input(s7_stag1_i), .stage1_output(s7_stag1_o));
s8 sbox8 (.stage1_input(s8_stag1_i), .stage1_output(s8_stag1_o));

always @(posedge clk or negedge reset)

begin

   if(!reset)
   begin

     ready_o = (0);
     data_o = (0);  
     stage1_iter = (0);
     data_ready = (1);
   
   end
   else
   begin

     ready_o = (next_ready_o);
     data_o = (next_data_o);
     stage1_iter = (next_stage1_iter);
     data_ready = (next_data_ready);
   
   end
end


always @(  data_i or   key_i or   load_i or   stage1_iter or   data_ready or stage1_R_o or stage1_L_o or stage1_round_key_o)

begin

      
   L_i_var=0;
   R_i_var=0;
   data_i_var=0;
   
   next_ready_o = (0);
   next_data_ready = (data_ready);
   next_stage1_iter = (stage1_iter);

   stage1_L_i = (0);
   stage1_R_i = (0);
   stage1_round_key_i = (0);
	

   key_i_var=key_i;
	
   key_var_perm[55]=key_i_var[7];key_var_perm[54]=key_i_var[15];key_var_perm[53]=key_i_var[23];key_var_perm[52]=key_i_var[31];
   key_var_perm[51]=key_i_var[39];key_var_perm[50]=key_i_var[47];key_var_perm[49]=key_i_var[55];key_var_perm[48]=key_i_var[63];

   key_var_perm[47]=key_i_var[6];key_var_perm[46]=key_i_var[14];key_var_perm[45]=key_i_var[22];key_var_perm[44]=key_i_var[30];
   key_var_perm[43]=key_i_var[38];key_var_perm[42]=key_i_var[46];key_var_perm[41]=key_i_var[54];key_var_perm[40]=key_i_var[62];
	
   key_var_perm[39]=key_i_var[5];key_var_perm[38]=key_i_var[13];key_var_perm[37]=key_i_var[21];key_var_perm[36]=key_i_var[29];
   key_var_perm[35]=key_i_var[37];key_var_perm[34]=key_i_var[45];key_var_perm[33]=key_i_var[53];key_var_perm[32]=key_i_var[61];
   
   key_var_perm[31]=key_i_var[4];key_var_perm[30]=key_i_var[12];key_var_perm[29]=key_i_var[20];key_var_perm[28]=key_i_var[28];
   key_var_perm[27]=key_i_var[1];key_var_perm[26]=key_i_var[9];key_var_perm[25]=key_i_var[17];key_var_perm[24]=key_i_var[25];
   
   key_var_perm[23]=key_i_var[33];key_var_perm[22]=key_i_var[41];key_var_perm[21]=key_i_var[49];key_var_perm[20]=key_i_var[57];
   key_var_perm[19]=key_i_var[2];key_var_perm[18]=key_i_var[10];key_var_perm[17]=key_i_var[18];key_var_perm[16]=key_i_var[26];
   
   key_var_perm[15]=key_i_var[34];key_var_perm[14]=key_i_var[42];key_var_perm[13]=key_i_var[50];key_var_perm[12]=key_i_var[58];
   key_var_perm[11]=key_i_var[3];key_var_perm[10]=key_i_var[11];key_var_perm[9]=key_i_var[19];key_var_perm[8]=key_i_var[27];
   
   key_var_perm[7]=key_i_var[35];key_var_perm[6]=key_i_var[43];key_var_perm[5]=key_i_var[51];key_var_perm[4]=key_i_var[59];
   key_var_perm[3]=key_i_var[36];key_var_perm[2]=key_i_var[44];key_var_perm[1]=key_i_var[52];key_var_perm[0]=key_i_var[60];
   
	
   data_i_var=data_i;
   L_i_var[31]=data_i_var[6];L_i_var[30]=data_i_var[14];L_i_var[29]=data_i_var[22];L_i_var[28]=data_i_var[30];
   L_i_var[27]=data_i_var[38];L_i_var[26]=data_i_var[46];L_i_var[25]=data_i_var[54];L_i_var[24]=data_i_var[62];

   L_i_var[23]=data_i_var[4];L_i_var[22]=data_i_var[12];L_i_var[21]=data_i_var[20];L_i_var[20]=data_i_var[28];
   L_i_var[19]=data_i_var[36];L_i_var[18]=data_i_var[44];L_i_var[17]=data_i_var[52];L_i_var[16]=data_i_var[60];

   L_i_var[15]=data_i_var[2];L_i_var[14]=data_i_var[10];L_i_var[13]=data_i_var[18];L_i_var[12]=data_i_var[26];
   L_i_var[11]=data_i_var[34];L_i_var[10]=data_i_var[42];L_i_var[9]=data_i_var[50];L_i_var[8]=data_i_var[58];

   L_i_var[7]=data_i_var[0];L_i_var[6]=data_i_var[8];L_i_var[5]=data_i_var[16];L_i_var[4]=data_i_var[24];
   L_i_var[3]=data_i_var[32];L_i_var[2]=data_i_var[40];L_i_var[1]=data_i_var[48];L_i_var[0]=data_i_var[56];		   
		   		   
   R_i_var[31]=data_i_var[7];R_i_var[30]=data_i_var[15];R_i_var[29]=data_i_var[23];R_i_var[28]=data_i_var[31];
   R_i_var[27]=data_i_var[39];R_i_var[26]=data_i_var[47];R_i_var[25]=data_i_var[55];R_i_var[24]=data_i_var[63];

   R_i_var[23]=data_i_var[5];R_i_var[22]=data_i_var[13];R_i_var[21]=data_i_var[21];R_i_var[20]=data_i_var[29];
   R_i_var[19]=data_i_var[37];R_i_var[18]=data_i_var[45];R_i_var[17]=data_i_var[53];R_i_var[16]=data_i_var[61];

   R_i_var[15]=data_i_var[3];R_i_var[14]=data_i_var[11];R_i_var[13]=data_i_var[19];R_i_var[12]=data_i_var[27];
   R_i_var[11]=data_i_var[35];R_i_var[10]=data_i_var[43];R_i_var[9]=data_i_var[51];R_i_var[8]=data_i_var[59];

   R_i_var[7]=data_i_var[1];R_i_var[6]=data_i_var[9];R_i_var[5]=data_i_var[17];R_i_var[4]=data_i_var[25];
   R_i_var[3]=data_i_var[33];R_i_var[2]=data_i_var[41];R_i_var[1]=data_i_var[49];R_i_var[0]=data_i_var[57];	


   
   data_o_var_t[63:32]=stage1_R_o;
   data_o_var_t[31:0]=stage1_L_o;
   
   data_o_var[63]=data_o_var_t[24];data_o_var[62]=data_o_var_t[56];data_o_var[61]=data_o_var_t[16];data_o_var[60]=data_o_var_t[48];
   data_o_var[59]=data_o_var_t[8];data_o_var[58]=data_o_var_t[40];data_o_var[57]=data_o_var_t[0];data_o_var[56]=data_o_var_t[32];   
   
   data_o_var[55]=data_o_var_t[25];data_o_var[54]=data_o_var_t[57];data_o_var[53]=data_o_var_t[17];data_o_var[52]=data_o_var_t[49];
   data_o_var[51]=data_o_var_t[9];data_o_var[50]=data_o_var_t[41];data_o_var[49]=data_o_var_t[1];data_o_var[48]=data_o_var_t[33];
   
   data_o_var[47]=data_o_var_t[26];data_o_var[46]=data_o_var_t[58];data_o_var[45]=data_o_var_t[18];data_o_var[44]=data_o_var_t[50];
   data_o_var[43]=data_o_var_t[10];data_o_var[42]=data_o_var_t[42];data_o_var[41]=data_o_var_t[2];data_o_var[40]=data_o_var_t[34];
   
   data_o_var[39]=data_o_var_t[27];data_o_var[38]=data_o_var_t[59];data_o_var[37]=data_o_var_t[19];data_o_var[36]=data_o_var_t[51];
   data_o_var[35]=data_o_var_t[11];data_o_var[34]=data_o_var_t[43];data_o_var[33]=data_o_var_t[3];data_o_var[32]=data_o_var_t[35];
   
   data_o_var[31]=data_o_var_t[28];data_o_var[30]=data_o_var_t[60];data_o_var[29]=data_o_var_t[20];data_o_var[28]=data_o_var_t[52];
   data_o_var[27]=data_o_var_t[12];data_o_var[26]=data_o_var_t[44];data_o_var[25]=data_o_var_t[4];data_o_var[24]=data_o_var_t[36];   
   
   data_o_var[23]=data_o_var_t[29];data_o_var[22]=data_o_var_t[61];data_o_var[21]=data_o_var_t[21];data_o_var[20]=data_o_var_t[53];
   data_o_var[19]=data_o_var_t[13];data_o_var[18]=data_o_var_t[45];data_o_var[17]=data_o_var_t[5];data_o_var[16]=data_o_var_t[37];
   
   data_o_var[15]=data_o_var_t[30];data_o_var[14]=data_o_var_t[62];data_o_var[13]=data_o_var_t[22];data_o_var[12]=data_o_var_t[54];
   data_o_var[11]=data_o_var_t[14];data_o_var[10]=data_o_var_t[46];data_o_var[9]=data_o_var_t[6];data_o_var[8]=data_o_var_t[38];
   
   data_o_var[7]=data_o_var_t[31];data_o_var[6]=data_o_var_t[63];data_o_var[5]=data_o_var_t[23];data_o_var[4]=data_o_var_t[55];
   data_o_var[3]=data_o_var_t[15];data_o_var[2]=data_o_var_t[47];data_o_var[1]=data_o_var_t[7];data_o_var[0]=data_o_var_t[39];
   
   next_data_o = (data_o_var);
   
   stage1_iteration_i = (stage1_iter);

   next_ready_o = (0);	 	 
   stage1_L_i = (stage1_L_o);
   stage1_R_i = (stage1_R_o);
   stage1_round_key_i = (stage1_round_key_o);
    
   case(stage1_iter)
	
     0:
     begin
       if(load_i)
       begin
         next_stage1_iter = (1);
         stage1_L_i = (L_i_var);
         stage1_R_i = (R_i_var);
         stage1_round_key_i = (key_var_perm);
         next_data_ready = (0);
       end
       else if (!data_ready)
       begin

         next_stage1_iter = (0);	
         next_ready_o = (1);
         next_data_ready = (1);			 
       end
	 end
       
     15:
       next_stage1_iter = (0);
       
     default:	
       next_stage1_iter = (stage1_iter+1);		 
   
   endcase
 
end

endmodule


`timescale 10ns/1ns

module desround(clk,reset,iteration_i,decrypt_i,R_i,L_i,Key_i,R_o,L_o,Key_o,s1_o,s2_o,s3_o,s4_o,s5_o,s6_o,s7_o,s8_o,s1_i,s2_i,s3_i,s4_i,s5_i,s6_i,s7_i,s8_i);

input clk;
input reset;
input [3:0] iteration_i;
input decrypt_i;
input [31:0] R_i;
input [31:0] L_i;
input [55:0] Key_i;
output [31:0] R_o;
output [31:0] L_o;
output [55:0] Key_o;
output [5:0] s1_o;
output [5:0] s2_o;
output [5:0] s3_o;
output [5:0] s4_o;
output [5:0] s5_o;
output [5:0] s6_o;
output [5:0] s7_o;
output [5:0] s8_o;
input [3:0] s1_i;
input [3:0] s2_i;
input [3:0] s3_i;
input [3:0] s4_i;
input [3:0] s5_i;
input [3:0] s6_i;
input [3:0] s7_i;
input [3:0] s8_i;

reg [31:0] R_o;
reg [31:0] L_o;
reg [55:0] Key_o;
reg [5:0] s1_o;
reg [5:0] s2_o;
reg [5:0] s3_o;
reg [5:0] s4_o;
reg [5:0] s5_o;
reg [5:0] s6_o;
reg [5:0] s7_o;
reg [5:0] s8_o;


reg  [55:0] previous_key;

reg [3:0] iteration;

reg decrypt;


wire [55:0] non_perm_key;


wire [47:0] new_key;

reg [31:0] next_R;

reg [31:0] expanRSig;

reg[47:0]  expandedR;
reg[47:0]  round_key;
reg[47:0]  KER;
reg[31:0]  R_i_var;
	
reg[31:0]  Soutput;
reg[31:0]  f;	


key_gen kg1 (.previous_key(previous_key), .iteration(iteration), .decrypt(decrypt), .new_key(new_key), .non_perm_key(non_perm_key));

always @(posedge clk or negedge reset)

begin

	
  if(!reset)
  begin

    L_o = (0);
    R_o = (0);
    Key_o = (0);
	
  end
  else
  begin

    L_o = (R_i);
    R_o = (next_R);
    Key_o = (non_perm_key);
	
  end

end


always @(  R_i or   L_i or   Key_i or   iteration_i or   decrypt_i or   new_key or   s1_i or   s2_i or   s3_i or   s4_i or   s5_i or   s6_i or   s7_i or   s8_i)

begin

R_i_var=R_i;	
	

expandedR[47]=R_i_var[0]; expandedR[46]=R_i_var[31]; expandedR[45]=R_i_var[30]; expandedR[44]=R_i_var[29];
expandedR[43]=R_i_var[28]; expandedR[42]=R_i_var[27]; expandedR[41]=R_i_var[28]; expandedR[40]=R_i_var[27];
	
expandedR[39]=R_i_var[26]; expandedR[38]=R_i_var[25]; expandedR[37]=R_i_var[24]; expandedR[36]=R_i_var[23];
expandedR[35]=R_i_var[24]; expandedR[34]=R_i_var[23]; expandedR[33]=R_i_var[22]; expandedR[32]=R_i_var[21];
  
expandedR[31]=R_i_var[20]; expandedR[30]=R_i_var[19]; expandedR[29]=R_i_var[20]; expandedR[28]=R_i_var[19];
expandedR[27]=R_i_var[18]; expandedR[26]=R_i_var[17]; expandedR[25]=R_i_var[16]; expandedR[24]=R_i_var[15];
	
expandedR[23]=R_i_var[16]; expandedR[22]=R_i_var[15]; expandedR[21]=R_i_var[14]; expandedR[20]=R_i_var[13];
expandedR[19]=R_i_var[12]; expandedR[18]=R_i_var[11]; expandedR[17]=R_i_var[12]; expandedR[16]=R_i_var[11]; 

expandedR[15]=R_i_var[10]; expandedR[14]=R_i_var[9]; expandedR[13]=R_i_var[8]; expandedR[12]=R_i_var[7]; 
expandedR[11]=R_i_var[8]; expandedR[10]=R_i_var[7]; expandedR[9]=R_i_var[6]; expandedR[8]=R_i_var[5]; 
	
expandedR[7]=R_i_var[4]; expandedR[6]=R_i_var[3]; expandedR[5]=R_i_var[4]; expandedR[4]=R_i_var[3]; 
expandedR[3]=R_i_var[2]; expandedR[2]=R_i_var[1]; expandedR[1]=R_i_var[0]; expandedR[0]=R_i_var[31]; 
	  
  
previous_key = (Key_i);
iteration = (iteration_i);
decrypt = (decrypt_i);
  
round_key=new_key;
  
KER=expandedR^round_key;
    
  
s1_o = (KER[47:42]);
s2_o = (KER[41:36]);
s3_o = (KER[35:30]);
s4_o = (KER[29:24]);
s5_o = (KER[23:18]);
s6_o = (KER[17:12]);
s7_o = (KER[11:6]);
s8_o = (KER[5:0]);

Soutput[31:28]=s1_i;
Soutput[27:24]=s2_i;
Soutput[23:20]=s3_i;
Soutput[19:16]=s4_i;
Soutput[15:12]=s5_i;
Soutput[11:8]=s6_i;
Soutput[7:4]=s7_i;
Soutput[3:0]=s8_i;
      
  
f[31]=Soutput[16]; f[30]=Soutput[25]; f[29]=Soutput[12]; f[28]=Soutput[11]; 
f[27]=Soutput[3]; f[26]=Soutput[20]; f[25]=Soutput[4]; f[24]=Soutput[15]; 
  
f[23]=Soutput[31]; f[22]=Soutput[17]; f[21]=Soutput[9]; f[20]=Soutput[6]; 
f[19]=Soutput[27]; f[18]=Soutput[14]; f[17]=Soutput[1]; f[16]=Soutput[22]; 
  
f[15]=Soutput[30]; f[14]=Soutput[24]; f[13]=Soutput[8]; f[12]=Soutput[18]; 
f[11]=Soutput[0]; f[10]=Soutput[5]; f[9]=Soutput[29]; f[8]=Soutput[23]; 
  
f[7]=Soutput[13]; f[6]=Soutput[19]; f[5]=Soutput[2]; f[4]=Soutput[26]; 
f[3]=Soutput[10]; f[2]=Soutput[21]; f[1]=Soutput[28]; f[0]=Soutput[7]; 
  
next_R = (L_i^f);
  
expanRSig = (L_i^f);
  
 
end

endmodule



module key_gen(previous_key,iteration,decrypt,non_perm_key,new_key);

input [55:0] previous_key;
input [3:0] iteration;
input decrypt;
output [55:0] non_perm_key;
output [47:0] new_key;

reg [55:0] non_perm_key;
reg [47:0] new_key;


reg  prev0,prev1;
reg[55:0]  prev_key_var,non_perm_key_var;
reg[47:0]  new_key_var;
reg[27:0]  semi_key;


always @(  previous_key or   iteration or   decrypt)

begin

  prev_key_var=previous_key;
  new_key_var=0;
  new_key = (0);
  non_perm_key_var=0;
  non_perm_key = (0);
	
  if(!decrypt)
    begin

      case(iteration)

        0, 1, 8, 15:
        begin
          semi_key=prev_key_var[55:28];
          prev0=semi_key[27];
          semi_key=semi_key<<1;
          semi_key[0]=prev0;
          non_perm_key_var[55:28]=semi_key;
          semi_key=prev_key_var[27:0];
          prev0=semi_key[27];
          semi_key=semi_key<<1;
          semi_key[0]=prev0;
          non_perm_key_var[27:0]=semi_key;
        end
		
        default:    
        begin
          semi_key=prev_key_var[55:28];
          prev0=semi_key[27];
          prev1=semi_key[26];
          semi_key=semi_key<<2;
          semi_key[1]=prev0;
          semi_key[0]=prev1;
          non_perm_key_var[55:28]=semi_key;
          semi_key=prev_key_var[27:0];
          prev0=semi_key[27];
          prev1=semi_key[26];
          semi_key=semi_key<<2;
          semi_key[1]=prev0;
          semi_key[0]=prev1;
          non_perm_key_var[27:0]=semi_key;
        end
      
      endcase
	end
  else
  begin
   
    case(iteration)

      0:
      begin
        semi_key=prev_key_var[55:28];
        non_perm_key_var[55:28]=semi_key;
        semi_key=prev_key_var[27:0];
        non_perm_key_var[27:0]=semi_key;
      end
	  
      1, 8, 15:
      begin
        semi_key=prev_key_var[55:28];
        prev0=semi_key[0];
        semi_key=semi_key>>1;
        semi_key[27]=prev0;
        non_perm_key_var[55:28]=semi_key;
        semi_key=prev_key_var[27:0];
        prev0=semi_key[0];
        semi_key=semi_key>>1;
        semi_key[27]=prev0;
        non_perm_key_var[27:0]=semi_key;
      end
		
      default:    
      begin
        semi_key=prev_key_var[55:28];
        prev0=semi_key[0];
        prev1=semi_key[1];
        semi_key=semi_key>>2;
        semi_key[26]=prev0;
        semi_key[27]=prev1;
        non_perm_key_var[55:28]=semi_key;
        semi_key=prev_key_var[27:0];
        prev0=semi_key[0];
        prev1=semi_key[1];
        semi_key=semi_key>>2;
        semi_key[26]=prev0;
        semi_key[27]=prev1;
        non_perm_key_var[27:0]=semi_key;
      end
	 
   endcase
   
end

   
non_perm_key = (non_perm_key_var);
      

new_key_var[47]=non_perm_key_var[42]; new_key_var[46]=non_perm_key_var[39]; new_key_var[45]=non_perm_key_var[45]; new_key_var[44]=non_perm_key_var[32];
new_key_var[43]=non_perm_key_var[55]; new_key_var[42]=non_perm_key_var[51]; new_key_var[41]=non_perm_key_var[53]; new_key_var[40]=non_perm_key_var[28];
	
new_key_var[39]=non_perm_key_var[41]; new_key_var[38]=non_perm_key_var[50]; new_key_var[37]=non_perm_key_var[35]; new_key_var[36]=non_perm_key_var[46];
new_key_var[35]=non_perm_key_var[33]; new_key_var[34]=non_perm_key_var[37]; new_key_var[33]=non_perm_key_var[44]; new_key_var[32]=non_perm_key_var[52];
  
new_key_var[31]=non_perm_key_var[30]; new_key_var[30]=non_perm_key_var[48]; new_key_var[29]=non_perm_key_var[40]; new_key_var[28]=non_perm_key_var[49];
new_key_var[27]=non_perm_key_var[29]; new_key_var[26]=non_perm_key_var[36]; new_key_var[25]=non_perm_key_var[43]; new_key_var[24]=non_perm_key_var[54];

new_key_var[23]=non_perm_key_var[15]; new_key_var[22]=non_perm_key_var[4]; new_key_var[21]=non_perm_key_var[25]; new_key_var[20]=non_perm_key_var[19];
new_key_var[19]=non_perm_key_var[9]; new_key_var[18]=non_perm_key_var[1]; new_key_var[17]=non_perm_key_var[26]; new_key_var[16]=non_perm_key_var[16]; 

new_key_var[15]=non_perm_key_var[5]; new_key_var[14]=non_perm_key_var[11]; new_key_var[13]=non_perm_key_var[23]; new_key_var[12]=non_perm_key_var[8]; 
new_key_var[11]=non_perm_key_var[12]; new_key_var[10]=non_perm_key_var[7]; new_key_var[9]=non_perm_key_var[17]; new_key_var[8]=non_perm_key_var[0]; 
	
new_key_var[7]=non_perm_key_var[22]; new_key_var[6]=non_perm_key_var[3]; new_key_var[5]=non_perm_key_var[10]; new_key_var[4]=non_perm_key_var[14]; 
new_key_var[3]=non_perm_key_var[6]; new_key_var[2]=non_perm_key_var[20]; new_key_var[1]=non_perm_key_var[27]; new_key_var[0]=non_perm_key_var[24]; 

new_key = (new_key_var);
   

end

endmodule



module s1(stage1_input,stage1_output);
input [5:0] stage1_input;
output [3:0] stage1_output;

reg [3:0] stage1_output;


always @(  stage1_input)

begin

	
   case(stage1_input)
	    0: stage1_output = (14); 
        1: stage1_output = (0); 
        2: stage1_output = (4); 
        3: stage1_output = (15); 
        4: stage1_output = (13); 
        5: stage1_output = (7); 
        6: stage1_output = (1); 
        7: stage1_output = (4); 
        8: stage1_output = (2); 
        9: stage1_output = (14); 
        10: stage1_output = (15); 
        11: stage1_output = (2); 
        12: stage1_output = (11); 
        13: stage1_output = (13); 
        14: stage1_output = (8); 
        15: stage1_output = (1); 
        16: stage1_output = (3); 
        17: stage1_output = (10); 
        18: stage1_output = (10); 
        19: stage1_output = (6); 
        20: stage1_output = (6); 
        21: stage1_output = (12); 
        22: stage1_output = (12); 
        23: stage1_output = (11); 
        24: stage1_output = (5); 
        25: stage1_output = (9); 
        26: stage1_output = (9); 
        27: stage1_output = (5); 
        28: stage1_output = (0); 
        29: stage1_output = (3); 
        30: stage1_output = (7); 
        31: stage1_output = (8); 
        32: stage1_output = (4); 
        33: stage1_output = (15); 
        34: stage1_output = (1); 
        35: stage1_output = (12); 
        36: stage1_output = (14); 
        37: stage1_output = (8); 
        38: stage1_output = (8); 
        39: stage1_output = (2); 
        40: stage1_output = (13); 
        41: stage1_output = (4); 
        42: stage1_output = (6); 
        43: stage1_output = (9); 
        44: stage1_output = (2); 
        45: stage1_output = (1); 
        46: stage1_output = (11); 
        47: stage1_output = (7); 
        48: stage1_output = (15); 
        49: stage1_output = (5); 
        50: stage1_output = (12); 
        51: stage1_output = (11); 
        52: stage1_output = (9); 
        53: stage1_output = (3); 
        54: stage1_output = (7); 
        55: stage1_output = (14); 
        56: stage1_output = (3); 
        57: stage1_output = (10); 
        58: stage1_output = (10); 
        59: stage1_output = (0); 
        60: stage1_output = (5); 
        61: stage1_output = (6); 
        62: stage1_output = (0); 
        63: stage1_output = (13); 
    
   endcase

end

endmodule



module s2(stage1_input,stage1_output);
input [5:0] stage1_input;
output [3:0] stage1_output;

reg [3:0] stage1_output;


always @(  stage1_input)

begin


   case(stage1_input)
        0: stage1_output = (15); 
        1: stage1_output = (3); 
        2: stage1_output = (1); 
        3: stage1_output = (13); 
        4: stage1_output = (8); 
        5: stage1_output = (4); 
        6: stage1_output = (14); 
        7: stage1_output = (7); 
        8: stage1_output = (6); 
        9: stage1_output = (15); 
        10: stage1_output = (11); 
        11: stage1_output = (2); 
        12: stage1_output = (3); 
        13: stage1_output = (8); 
        14: stage1_output = (4); 
        15: stage1_output = (14); 
        16: stage1_output = (9); 
        17: stage1_output = (12); 
        18: stage1_output = (7); 
        19: stage1_output = (0); 
        20: stage1_output = (2); 
        21: stage1_output = (1); 
        22: stage1_output = (13); 
        23: stage1_output = (10); 
        24: stage1_output = (12); 
        25: stage1_output = (6); 
        26: stage1_output = (0); 
        27: stage1_output = (9); 
        28: stage1_output = (5); 
        29: stage1_output = (11); 
        30: stage1_output = (10); 
        31: stage1_output = (5); 
        32: stage1_output = (0); 
        33: stage1_output = (13); 
        34: stage1_output = (14); 
        35: stage1_output = (8); 
        36: stage1_output = (7); 
        37: stage1_output = (10); 
        38: stage1_output = (11); 
        39: stage1_output = (1); 
        40: stage1_output = (10); 
        41: stage1_output = (3); 
        42: stage1_output = (4); 
        43: stage1_output = (15); 
        44: stage1_output = (13); 
        45: stage1_output = (4); 
        46: stage1_output = (1); 
        47: stage1_output = (2); 
        48: stage1_output = (5); 
        49: stage1_output = (11); 
        50: stage1_output = (8); 
        51: stage1_output = (6); 
        52: stage1_output = (12); 
        53: stage1_output = (7); 
        54: stage1_output = (6); 
        55: stage1_output = (12); 
        56: stage1_output = (9); 
        57: stage1_output = (0); 
        58: stage1_output = (3); 
        59: stage1_output = (5); 
        60: stage1_output = (2); 
        61: stage1_output = (14); 
        62: stage1_output = (15); 
        63: stage1_output = (9); 
   
  endcase

end

endmodule



module s3(stage1_input,stage1_output);
input [5:0] stage1_input;
output [3:0] stage1_output;

reg [3:0] stage1_output;


always @(  stage1_input)

begin

   case(stage1_input)

        0: stage1_output = (10); 
        1: stage1_output = (13); 
        2: stage1_output = (0); 
        3: stage1_output = (7); 
        4: stage1_output = (9); 
        5: stage1_output = (0); 
        6: stage1_output = (14); 
        7: stage1_output = (9); 
        8: stage1_output = (6); 
        9: stage1_output = (3); 
        10: stage1_output = (3); 
        11: stage1_output = (4); 
        12: stage1_output = (15); 
        13: stage1_output = (6); 
        14: stage1_output = (5); 
        15: stage1_output = (10); 
        16: stage1_output = (1); 
        17: stage1_output = (2); 
        18: stage1_output = (13); 
        19: stage1_output = (8); 
        20: stage1_output = (12); 
        21: stage1_output = (5); 
        22: stage1_output = (7); 
        23: stage1_output = (14); 
        24: stage1_output = (11); 
        25: stage1_output = (12); 
        26: stage1_output = (4); 
        27: stage1_output = (11); 
        28: stage1_output = (2); 
        29: stage1_output = (15); 
        30: stage1_output = (8); 
        31: stage1_output = (1); 
        32: stage1_output = (13); 
        33: stage1_output = (1); 
        34: stage1_output = (6); 
        35: stage1_output = (10); 
        36: stage1_output = (4); 
        37: stage1_output = (13); 
        38: stage1_output = (9); 
        39: stage1_output = (0); 
        40: stage1_output = (8); 
        41: stage1_output = (6); 
        42: stage1_output = (15); 
        43: stage1_output = (9); 
        44: stage1_output = (3); 
        45: stage1_output = (8); 
        46: stage1_output = (0); 
        47: stage1_output = (7); 
        48: stage1_output = (11); 
        49: stage1_output = (4); 
        50: stage1_output = (1); 
        51: stage1_output = (15); 
        52: stage1_output = (2); 
        53: stage1_output = (14); 
        54: stage1_output = (12); 
        55: stage1_output = (3); 
        56: stage1_output = (5); 
        57: stage1_output = (11); 
        58: stage1_output = (10); 
        59: stage1_output = (5); 
        60: stage1_output = (14); 
        61: stage1_output = (2); 
        62: stage1_output = (7); 
        63: stage1_output = (12); 
  
   endcase

end

endmodule



module s4(stage1_input,stage1_output);
input [5:0] stage1_input;
output [3:0] stage1_output;

reg [3:0] stage1_output;


always @(  stage1_input)

begin

   case(stage1_input)

        0: stage1_output = (7); 
        1: stage1_output = (13); 
        2: stage1_output = (13); 
        3: stage1_output = (8); 
        4: stage1_output = (14); 
        5: stage1_output = (11); 
        6: stage1_output = (3); 
        7: stage1_output = (5); 
        8: stage1_output = (0); 
        9: stage1_output = (6); 
        10: stage1_output = (6); 
        11: stage1_output = (15); 
        12: stage1_output = (9); 
        13: stage1_output = (0); 
        14: stage1_output = (10); 
        15: stage1_output = (3); 
        16: stage1_output = (1); 
        17: stage1_output = (4); 
        18: stage1_output = (2); 
        19: stage1_output = (7); 
        20: stage1_output = (8); 
        21: stage1_output = (2); 
        22: stage1_output = (5); 
        23: stage1_output = (12); 
        24: stage1_output = (11); 
        25: stage1_output = (1); 
        26: stage1_output = (12); 
        27: stage1_output = (10); 
        28: stage1_output = (4); 
        29: stage1_output = (14); 
        30: stage1_output = (15); 
        31: stage1_output = (9); 
        32: stage1_output = (10); 
        33: stage1_output = (3); 
        34: stage1_output = (6); 
        35: stage1_output = (15); 
        36: stage1_output = (9); 
        37: stage1_output = (0); 
        38: stage1_output = (0); 
        39: stage1_output = (6); 
        40: stage1_output = (12); 
        41: stage1_output = (10); 
        42: stage1_output = (11); 
        43: stage1_output = (1); 
        44: stage1_output = (7); 
        45: stage1_output = (13); 
        46: stage1_output = (13); 
        47: stage1_output = (8); 
        48: stage1_output = (15); 
        49: stage1_output = (9); 
        50: stage1_output = (1); 
        51: stage1_output = (4); 
        52: stage1_output = (3); 
        53: stage1_output = (5); 
        54: stage1_output = (14); 
        55: stage1_output = (11); 
        56: stage1_output = (5); 
        57: stage1_output = (12); 
        58: stage1_output = (2); 
        59: stage1_output = (7); 
        60: stage1_output = (8); 
        61: stage1_output = (2); 
        62: stage1_output = (4); 
        63: stage1_output = (14); 

   endcase

end

endmodule



module s5(stage1_input,stage1_output);
input [5:0] stage1_input;
output [3:0] stage1_output;

reg [3:0] stage1_output;


always @(  stage1_input)

begin

   case(stage1_input)

        0: stage1_output = (2); 
        1: stage1_output = (14); 
        2: stage1_output = (12); 
        3: stage1_output = (11); 
        4: stage1_output = (4); 
        5: stage1_output = (2); 
        6: stage1_output = (1); 
        7: stage1_output = (12); 
        8: stage1_output = (7); 
        9: stage1_output = (4); 
        10: stage1_output = (10); 
        11: stage1_output = (7); 
        12: stage1_output = (11); 
        13: stage1_output = (13); 
        14: stage1_output = (6); 
        15: stage1_output = (1); 
        16: stage1_output = (8); 
        17: stage1_output = (5); 
        18: stage1_output = (5); 
        19: stage1_output = (0); 
        20: stage1_output = (3); 
        21: stage1_output = (15); 
        22: stage1_output = (15); 
        23: stage1_output = (10); 
        24: stage1_output = (13); 
        25: stage1_output = (3); 
        26: stage1_output = (0); 
        27: stage1_output = (9); 
        28: stage1_output = (14); 
        29: stage1_output = (8); 
        30: stage1_output = (9); 
        31: stage1_output = (6); 
        32: stage1_output = (4); 
        33: stage1_output = (11); 
        34: stage1_output = (2); 
        35: stage1_output = (8); 
        36: stage1_output = (1); 
        37: stage1_output = (12); 
        38: stage1_output = (11); 
        39: stage1_output = (7); 
        40: stage1_output = (10); 
        41: stage1_output = (1); 
        42: stage1_output = (13); 
        43: stage1_output = (14); 
        44: stage1_output = (7); 
        45: stage1_output = (2); 
        46: stage1_output = (8); 
        47: stage1_output = (13); 
        48: stage1_output = (15); 
        49: stage1_output = (6); 
        50: stage1_output = (9); 
        51: stage1_output = (15); 
        52: stage1_output = (12); 
        53: stage1_output = (0); 
        54: stage1_output = (5); 
        55: stage1_output = (9); 
        56: stage1_output = (6); 
        57: stage1_output = (10); 
        58: stage1_output = (3); 
        59: stage1_output = (4); 
        60: stage1_output = (0); 
        61: stage1_output = (5); 
        62: stage1_output = (14); 
        63: stage1_output = (3); 

   endcase


end

endmodule



module s6(stage1_input,stage1_output);
input [5:0] stage1_input;
output [3:0] stage1_output;

reg [3:0] stage1_output;


always @(  stage1_input)

begin

   case(stage1_input)

        0: stage1_output = (12); 
        1: stage1_output = (10); 
        2: stage1_output = (1); 
        3: stage1_output = (15); 
        4: stage1_output = (10); 
        5: stage1_output = (4); 
        6: stage1_output = (15); 
        7: stage1_output = (2); 
        8: stage1_output = (9); 
        9: stage1_output = (7); 
        10: stage1_output = (2); 
        11: stage1_output = (12); 
        12: stage1_output = (6); 
        13: stage1_output = (9); 
        14: stage1_output = (8); 
        15: stage1_output = (5); 
        16: stage1_output = (0); 
        17: stage1_output = (6); 
        18: stage1_output = (13); 
        19: stage1_output = (1); 
        20: stage1_output = (3); 
        21: stage1_output = (13); 
        22: stage1_output = (4); 
        23: stage1_output = (14); 
        24: stage1_output = (14); 
        25: stage1_output = (0); 
        26: stage1_output = (7); 
        27: stage1_output = (11); 
        28: stage1_output = (5); 
        29: stage1_output = (3); 
        30: stage1_output = (11); 
        31: stage1_output = (8); 
        32: stage1_output = (9); 
        33: stage1_output = (4); 
        34: stage1_output = (14); 
        35: stage1_output = (3); 
        36: stage1_output = (15); 
        37: stage1_output = (2); 
        38: stage1_output = (5); 
        39: stage1_output = (12); 
        40: stage1_output = (2); 
        41: stage1_output = (9); 
        42: stage1_output = (8); 
        43: stage1_output = (5); 
        44: stage1_output = (12); 
        45: stage1_output = (15); 
        46: stage1_output = (3); 
        47: stage1_output = (10); 
        48: stage1_output = (7); 
        49: stage1_output = (11); 
        50: stage1_output = (0); 
        51: stage1_output = (14); 
        52: stage1_output = (4); 
        53: stage1_output = (1); 
        54: stage1_output = (10); 
        55: stage1_output = (7); 
        56: stage1_output = (1); 
        57: stage1_output = (6); 
        58: stage1_output = (13); 
        59: stage1_output = (0); 
        60: stage1_output = (11); 
        61: stage1_output = (8); 
        62: stage1_output = (6); 
        63: stage1_output = (13); 

   endcase
	

end

endmodule


module s7(stage1_input,stage1_output);
input [5:0] stage1_input;
output [3:0] stage1_output;

reg [3:0] stage1_output;


always @(  stage1_input)

begin

   case(stage1_input)

        0: stage1_output = (4); 
        1: stage1_output = (13); 
        2: stage1_output = (11); 
        3: stage1_output = (0); 
        4: stage1_output = (2); 
        5: stage1_output = (11); 
        6: stage1_output = (14); 
        7: stage1_output = (7); 
        8: stage1_output = (15); 
        9: stage1_output = (4); 
        10: stage1_output = (0); 
        11: stage1_output = (9); 
        12: stage1_output = (8); 
        13: stage1_output = (1); 
        14: stage1_output = (13); 
        15: stage1_output = (10); 
        16: stage1_output = (3); 
        17: stage1_output = (14); 
        18: stage1_output = (12); 
        19: stage1_output = (3); 
        20: stage1_output = (9); 
        21: stage1_output = (5); 
        22: stage1_output = (7); 
        23: stage1_output = (12); 
        24: stage1_output = (5); 
        25: stage1_output = (2); 
        26: stage1_output = (10); 
        27: stage1_output = (15); 
        28: stage1_output = (6); 
        29: stage1_output = (8); 
        30: stage1_output = (1); 
        31: stage1_output = (6); 
        32: stage1_output = (1); 
        33: stage1_output = (6); 
        34: stage1_output = (4); 
        35: stage1_output = (11); 
        36: stage1_output = (11); 
        37: stage1_output = (13); 
        38: stage1_output = (13); 
        39: stage1_output = (8); 
        40: stage1_output = (12); 
        41: stage1_output = (1); 
        42: stage1_output = (3); 
        43: stage1_output = (4); 
        44: stage1_output = (7); 
        45: stage1_output = (10); 
        46: stage1_output = (14); 
        47: stage1_output = (7); 
        48: stage1_output = (10); 
        49: stage1_output = (9); 
        50: stage1_output = (15); 
        51: stage1_output = (5); 
        52: stage1_output = (6); 
        53: stage1_output = (0); 
        54: stage1_output = (8); 
        55: stage1_output = (15); 
        56: stage1_output = (0); 
        57: stage1_output = (14); 
        58: stage1_output = (5); 
        59: stage1_output = (2); 
        60: stage1_output = (9); 
        61: stage1_output = (3); 
        62: stage1_output = (2); 
        63: stage1_output = (12); 

   endcase


end

endmodule


module s8(stage1_input,stage1_output);
input [5:0] stage1_input;
output [3:0] stage1_output;

reg [3:0] stage1_output;


always @(stage1_input)

begin

   case(stage1_input)

        0: stage1_output = (13); 
        1: stage1_output = (1); 
        2: stage1_output = (2); 
        3: stage1_output = (15); 
        4: stage1_output = (8); 
        5: stage1_output = (13); 
        6: stage1_output = (4); 
        7: stage1_output = (8); 
        8: stage1_output = (6); 
        9: stage1_output = (10); 
        10: stage1_output = (15); 
        11: stage1_output = (3); 
        12: stage1_output = (11); 
        13: stage1_output = (7); 
        14: stage1_output = (1); 
        15: stage1_output = (4); 
        16: stage1_output = (10); 
        17: stage1_output = (12); 
        18: stage1_output = (9); 
        19: stage1_output = (5); 
        20: stage1_output = (3); 
        21: stage1_output = (6); 
        22: stage1_output = (14); 
        23: stage1_output = (11); 
        24: stage1_output = (5); 
        25: stage1_output = (0); 
        26: stage1_output = (0); 
        27: stage1_output = (14); 
        28: stage1_output = (12); 
        29: stage1_output = (9); 
        30: stage1_output = (7); 
        31: stage1_output = (2); 
        32: stage1_output = (7); 
        33: stage1_output = (2); 
        34: stage1_output = (11); 
        35: stage1_output = (1); 
        36: stage1_output = (4); 
        37: stage1_output = (14); 
        38: stage1_output = (1); 
        39: stage1_output = (7); 
        40: stage1_output = (9); 
        41: stage1_output = (4); 
        42: stage1_output = (12); 
        43: stage1_output = (10); 
        44: stage1_output = (14); 
        45: stage1_output = (8); 
        46: stage1_output = (2); 
        47: stage1_output = (13); 
        48: stage1_output = (0); 
        49: stage1_output = (15); 
        50: stage1_output = (6); 
        51: stage1_output = (12); 
        52: stage1_output = (10); 
        53: stage1_output = (9); 
        54: stage1_output = (13); 
        55: stage1_output = (0); 
        56: stage1_output = (15); 
        57: stage1_output = (3); 
        58: stage1_output = (3); 
        59: stage1_output = (5); 
        60: stage1_output = (5); 
        61: stage1_output = (6); 
        62: stage1_output = (8); 
        63: stage1_output = (11); 

   endcase


end

endmodule


module top(clk,reset,wb_stb_i,wb_dat_o,wb_dat_i,wb_ack_o,
               wb_adr_i,wb_we_i,wb_cyc_i,wb_sel_i);

input         clk;
input         reset;
input         wb_stb_i;
output [31:0] wb_dat_o;
input  [31:0] wb_dat_i;
output        wb_ack_o;
input  [7:0]  wb_adr_i;
input         wb_we_i;
input         wb_cyc_i;
input  [3:0]  wb_sel_i;

reg  [31:0]  wb_dat_o;
reg          wb_ack_o;

wire [63:0]  data_i;
reg  [63:0]  data_o;
wire         ready_i;
reg  [63:0]  key_o;


reg  [31:0]  control_reg;
reg  [63:0]  cypher_data_reg;

des des(.clk(clk),
        .reset(~control_reg[0]),
		.load_i(control_reg[1]),
		.decrypt_i(control_reg[3]),
		.ready_o(ready_i),
		.data_o(data_i),
		.data_i(data_o),
		.key_i(key_o)
	   );

always @(posedge clk or posedge reset)
begin
     if(reset==1)
     begin
       wb_ack_o<=#1 0;
       wb_dat_o<=#1 0;
       control_reg <= #1 32'h60;
       cypher_data_reg <= #1 64'h0;
       key_o <= #1 32'h0;
       data_o <= #1 32'h0;
     end
     else
     begin

        control_reg[31:4]<= #1 28'h6;	   	   

       if(ready_i)
       begin
        control_reg[2] <= #1 1'b1;  
        cypher_data_reg <= #1 data_i;
       end
         
       if(wb_stb_i && wb_cyc_i && wb_we_i && ~wb_ack_o)
       begin
         wb_ack_o<=#1 1;
         case(wb_adr_i)
             8'h0:
             begin
                 
                 control_reg[3:0]<= #1 wb_dat_i[3:0];
             end
             8'h4:
              begin
                 data_o[63:32]<= #1 wb_dat_i;
             end                 
             8'h8:
             begin
                 data_o[31:0]<= #1 wb_dat_i;
             end                 
             8'hC:
             begin
                 key_o[63:32]<= #1 wb_dat_i;
             end                 
             8'h10:
             begin
                 key_o[31:0]<= #1 wb_dat_i;
             end                 
         endcase
       end
       else if(wb_stb_i && wb_cyc_i && ~wb_we_i && ~wb_ack_o)
       begin
           wb_ack_o<=#1 1;
           case(wb_adr_i)
             8'h0:
             begin
                 wb_dat_o<= #1 control_reg;
                 control_reg[2]<=1'b0;
             end
             8'h14:
             begin
                 wb_dat_o<= #1 cypher_data_reg[63:32];
             end
             8'h18:
             begin
                 wb_dat_o<= #1 cypher_data_reg[31:0];
             end
           endcase
       end
       else
       begin
           wb_ack_o<=#1 0;
           control_reg[1]<= #1 1'b0;
       end

     end
end


endmodule




