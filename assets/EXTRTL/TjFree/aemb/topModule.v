/* $Id: aeMB2_brcc.v,v 1.3 2008-04-26 01:09:05 sybreon Exp $
**
** AEMB2 EDK 6.2 COMPATIBLE CORE
** Copyright (C) 2004-2008 Shawn Tan <shawn.tan@aeste.net>
**  
** This file is part of AEMB.
**
** AEMB is free software: you can redistribute it and/or modify it
** under the terms of the GNU Lesser General Public License as
** published by the Free Software Foundation, either version 3 of the
** License, or (at your option) any later version.
**
** AEMB is distributed in the hope that it will be useful, but WITHOUT
** ANY WARRANTY; without even the implied warranty of MERCHANTABILITY
** or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU Lesser General
** Public License for more details.
**
** You should have received a copy of the GNU Lesser General Public
** License along with AEMB. If not, see <http:**www.gnu.org/licenses/>.
*/
/**
 * Branch Condition Checker
 * @file aeMB2_brcc.v
 
 * This controls the decision to branch/delay. The actualy branch
   target is calculated in the ALU.
 
 */

module aeMB2_brcc (/*AUTOARG*/
   
   bra_ex,
   
   opd_of, ra_of, rd_of, opc_of, gclk, grst, dena, iena, gpha
   );
   parameter AEMB_HTX = 1;   
   
   input [31:0] opd_of;   
   input [4:0] 	ra_of;
   input [4:0] 	rd_of;
   input [5:0] 	opc_of;   

   output [1:0] bra_ex;
   
   
   input 	gclk,
		grst,
		dena,
		iena,
		gpha;      

   /*AUTOREG*/
   
   reg [1:0]		bra_ex;
   
   
   
   
   /* Branch Control */
   wire 	wRTD = (opc_of == 6'o55);
   wire 	wBCC = (opc_of == 6'o47) | (opc_of == 6'o57);
   wire 	wBRU = (opc_of == 6'o46) | (opc_of == 6'o56);
   
   wire 	wBEQ = (opd_of == 32'd0);
   wire 	wBLT = opd_of[31];
   wire 	wBLE = wBLT | wBEQ;   
   wire 	wBNE = ~wBEQ;
   wire 	wBGE = ~wBLT;
   wire 	wBGT = ~wBLE;   
   
   reg 		 xcc;
   
   always @(/*AUTOSENSE*/rd_of or wBEQ or wBGE or wBGT or wBLE or wBLT
	    or wBNE) begin
      case (rd_of[2:0])
	3'o0: xcc <= wBEQ;
	3'o1: xcc <= wBNE;
	3'o2: xcc <= wBLT;
	3'o3: xcc <= wBLE;
	3'o4: xcc <= wBGT;
	3'o5: xcc <= wBGE;
	default: xcc <= 1'bX;
      endcase 
   end 
   
   always @(posedge gclk)
     if (grst) begin
	/*AUTORESET*/
	
	bra_ex <= 2'h0;
	
     end else if (dena) begin
	bra_ex[1] <= #1 (wRTD | wBRU | (wBCC & xcc)); 
	bra_ex[0] <= #1 (wBRU) ? ra_of[4] : rd_of[4]; 
     end
      
endmodule 

/*
 $Log: not supported by cvs2svn $
 Revision 1.2  2008/04/20 16:34:32  sybreon
 Basic version with some features left out.

 Revision 1.1  2008/04/18 00:21:52  sybreon
 Initial import.
*/
/* $Id: aeMB2_bsft.v,v 1.3 2008-04-28 08:15:25 sybreon Exp $
**
** AEMB2 EDK 6.2 COMPATIBLE CORE
** Copyright (C) 2004-2008 Shawn Tan <shawn.tan@aeste.net>
**  
** This file is part of AEMB.
**
** AEMB is free software: you can redistribute it and/or modify it
** under the terms of the GNU Lesser General Public License as
** published by the Free Software Foundation, either version 3 of the
** License, or (at your option) any later version.
**
** AEMB is distributed in the hope that it will be useful, but WITHOUT
** ANY WARRANTY; without even the implied warranty of MERCHANTABILITY
** or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU Lesser General
** Public License for more details.
**
** You should have received a copy of the GNU Lesser General Public
** License along with AEMB. If not, see <http:**www.gnu.org/licenses/>.
*/
/**
 * Two Cycle Barrel Shift Unit
 * @file aeMB2_bsft.v

 * This implements a 2 cycle barrel shifter. The design can be further
   optimised depending on architecture.
 
 */


module aeMB2_bsft (/*AUTOARG*/
   
   bsf_mx,
   
   opa_of, opb_of, opc_of, imm_of, gclk, grst, dena, gpha
   );
   parameter AEMB_BSF = 1; 

   output [31:0] bsf_mx;   
   
   input [31:0]  opa_of;
   input [31:0]  opb_of;
   input [5:0] 	 opc_of;   
   input [10:9]  imm_of;
   
   
   input 	 gclk,
		 grst,
		 dena,
		 gpha;   

   /*AUTOREG*/
   
   reg [31:0] 	 rBSLL, rBSRL, rBSRA;   
   reg [31:0] 	 rBSR;
   reg [10:9] 	 imm_ex;
   
   wire [31:0] 	 wOPB = opb_of;
   wire [31:0] 	 wOPA = opa_of;

   
   
   
   always @(posedge gclk)
     if (grst) begin
	/*AUTORESET*/
	
	rBSLL <= 32'h0;
	rBSRL <= 32'h0;
	
     end else if (dena) begin
	rBSLL <= #1 wOPA << wOPB[4:0];
	rBSRL <= #1 wOPA >> wOPB[4:0];	
     end
   
   
   always @(posedge gclk)
     if (grst) begin
	/*AUTORESET*/
	
	rBSRA <= 32'h0;
	
     end else if (dena)
       case (wOPB[4:0])
	 5'd00: rBSRA <= wOPA;
	 5'd01: rBSRA <= {{(1){wOPA[31]}}, wOPA[31:1]};
	 5'd02: rBSRA <= {{(2){wOPA[31]}}, wOPA[31:2]};
	 5'd03: rBSRA <= {{(3){wOPA[31]}}, wOPA[31:3]};
	 5'd04: rBSRA <= {{(4){wOPA[31]}}, wOPA[31:4]};
	 5'd05: rBSRA <= {{(5){wOPA[31]}}, wOPA[31:5]};
	 5'd06: rBSRA <= {{(6){wOPA[31]}}, wOPA[31:6]};
	 5'd07: rBSRA <= {{(7){wOPA[31]}}, wOPA[31:7]};
	 5'd08: rBSRA <= {{(8){wOPA[31]}}, wOPA[31:8]};
	 5'd09: rBSRA <= {{(9){wOPA[31]}}, wOPA[31:9]};
	 5'd10: rBSRA <= {{(10){wOPA[31]}}, wOPA[31:10]};
	 5'd11: rBSRA <= {{(11){wOPA[31]}}, wOPA[31:11]};
	 5'd12: rBSRA <= {{(12){wOPA[31]}}, wOPA[31:12]};
	 5'd13: rBSRA <= {{(13){wOPA[31]}}, wOPA[31:13]};
	 5'd14: rBSRA <= {{(14){wOPA[31]}}, wOPA[31:14]};
	 5'd15: rBSRA <= {{(15){wOPA[31]}}, wOPA[31:15]};
	 5'd16: rBSRA <= {{(16){wOPA[31]}}, wOPA[31:16]};
	 5'd17: rBSRA <= {{(17){wOPA[31]}}, wOPA[31:17]};
	 5'd18: rBSRA <= {{(18){wOPA[31]}}, wOPA[31:18]};
	 5'd19: rBSRA <= {{(19){wOPA[31]}}, wOPA[31:19]};
	 5'd20: rBSRA <= {{(20){wOPA[31]}}, wOPA[31:20]};
	 5'd21: rBSRA <= {{(21){wOPA[31]}}, wOPA[31:21]};
	 5'd22: rBSRA <= {{(22){wOPA[31]}}, wOPA[31:22]};
	 5'd23: rBSRA <= {{(23){wOPA[31]}}, wOPA[31:23]};
	 5'd24: rBSRA <= {{(24){wOPA[31]}}, wOPA[31:24]};
	 5'd25: rBSRA <= {{(25){wOPA[31]}}, wOPA[31:25]};
	 5'd26: rBSRA <= {{(26){wOPA[31]}}, wOPA[31:26]};
	 5'd27: rBSRA <= {{(27){wOPA[31]}}, wOPA[31:27]};
	 5'd28: rBSRA <= {{(28){wOPA[31]}}, wOPA[31:28]};
	 5'd29: rBSRA <= {{(29){wOPA[31]}}, wOPA[31:29]};
	 5'd30: rBSRA <= {{(30){wOPA[31]}}, wOPA[31:30]};
	 5'd31: rBSRA <= {{(31){wOPA[31]}}, wOPA[31]};
       endcase 

   
   always @(posedge gclk)
     if (grst) begin
	/*AUTORESET*/
	
	imm_ex <= 2'h0;
	rBSR <= 32'h0;
	
     end else if (dena) begin
	case (imm_ex)
	  2'o0: rBSR <= #1 rBSRL;
	  2'o1: rBSR <= #1 rBSRA;       
	  2'o2: rBSR <= #1 rBSLL;
	  default: rBSR <= #1 32'hX;       
	endcase 
	imm_ex <= #1 imm_of[10:9]; 
     end

   assign 	 bsf_mx = (AEMB_BSF[0]) ? rBSR : 32'hX;   
         
endmodule 

/*
 $Log: not supported by cvs2svn $
 Revision 1.2  2008/04/26 01:09:05  sybreon
 Passes basic tests. Minor documentation changes to make it compatible with iverilog pre-processor.

 Revision 1.1  2008/04/18 00:21:52  sybreon
 Initial import.
*/
/* $Id: aeMB2_ctrl.v,v 1.7 2008-05-11 13:50:50 sybreon Exp $
**
** AEMB2 EDK 6.2 COMPATIBLE CORE
** Copyright (C) 2004-2008 Shawn Tan <shawn.tan@aeste.net>
**  
** This file is part of AEMB.
**
** AEMB is free software: you can redistribute it and/or modify it
** under the terms of the GNU Lesser General Public License as
** published by the Free Software Foundation, either version 3 of the
** License, or (at your option) any later version.
**
** AEMB is distributed in the hope that it will be useful, but WITHOUT
** ANY WARRANTY; without even the implied warranty of MERCHANTABILITY
** or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU Lesser General
** Public License for more details.
**
** You should have received a copy of the GNU Lesser General Public
** License along with AEMB. If not, see <http:**www.gnu.org/licenses/>.
*/
/**
 * Instruction Decode & Control
 * @file aeMB2_ctrl.v
 
 * This is the data decoder that will control the command signals and
   operand fetch. 
 
 */

module aeMB2_ctrl (/*AUTOARG*/
   
   opa_of, opb_of, opd_of, opc_of, ra_of, rd_of, imm_of, rd_ex,
   mux_of, mux_ex, hzd_bpc, hzd_fwd,
   
   opa_if, opb_if, opd_if, brk_if, bra_ex, rpc_if, alu_ex, ich_dat,
   gclk, grst, dena, iena, gpha
   );
   parameter AEMB_HTX = 1;   
   
   
   output [31:0] opa_of;
   output [31:0] opb_of;
   output [31:0] opd_of;
   output [5:0]  opc_of;   
   output [4:0]  ra_of,
		 
		 rd_of;
   output [15:0] imm_of;   
   output [4:0]	 rd_ex;   
   
   
   input [31:0]  opa_if,
		 opb_if,
		 opd_if;   
   
   
   output [2:0]  mux_of,
		 mux_ex;   
   
   
   input [1:0] 	 brk_if;   
   input [1:0] 	 bra_ex;   
   input [31:2]  rpc_if;   
   input [31:0]  alu_ex;   
   input [31:0]  ich_dat;
   
   output 	 hzd_bpc;   
   output 	 hzd_fwd;
   
   
   input 	 gclk,
		 grst,
		 dena,
		 iena,
		 gpha;   
   
   /*AUTOREG*/
   
   reg [15:0]		imm_of;
   reg [2:0]		mux_ex;
   reg [2:0]		mux_of;
   reg [31:0]		opa_of;
   reg [31:0]		opb_of;
   reg [5:0]		opc_of;
   reg [31:0]		opd_of;
   reg [4:0]		ra_of;
   reg [4:0]		rd_ex;
   reg [4:0]		rd_of;
   

   wire 		fINT;   
   
   wire [31:0] 		wINTOP = 32'hB9CD0010; 
   
   
   wire [1:0] 		mux_opa, mux_opb, mux_opd;   
   
   
   wire [4:0] 		wRD, wRA, wRB;
   wire [5:0] 		wOPC;
   wire [15:0] 		wIMM;
   wire [31:0] 		imm_if;
   
   assign 		{wOPC, wRD, wRA, wIMM} = (fINT) ? wINTOP : ich_dat;
   assign 		wRB = wIMM[15:11];

   

   
   
   wire 		fMUL = (wOPC == 6'o20) | (wOPC == 6'o30);
   wire 		fBSF = (wOPC == 6'o21) | (wOPC == 6'o31);
   
   wire 		fRTD = (wOPC == 6'o55);
   wire 		fBCC = (wOPC == 6'o47) | (wOPC == 6'o57);
   wire 		fBRU = (wOPC == 6'o46) | (wOPC == 6'o56);
   
   wire 		fIMM = (wOPC == 6'o54);
   wire 		fMOV = (wOPC == 6'o45);      
   wire 		fLOD = ({wOPC[5:4],wOPC[2]} == 3'o6);
   wire 		fSTR = ({wOPC[5:4],wOPC[2]} == 3'o7);
   
   
   wire 		fGET = (wOPC == 6'o33) & !wRB[4];   


   
   localparam [2:0] 	MUX_SFR = 3'o7,
			MUX_BSF = 3'o6,
			MUX_MUL = 3'o5,
			MUX_MEM = 3'o4,
			
			MUX_RPC = 3'o2,
			MUX_ALU = 3'o1,
			MUX_NOP = 3'o0;   							  
   
   always @(posedge gclk)
     if (grst) begin
	/*AUTORESET*/
	
	imm_of <= 16'h0;
	mux_of <= 3'h0;
	opc_of <= 6'h0;
	ra_of <= 5'h0;
	rd_of <= 5'h0;
	
     end else if (dena) begin

	mux_of <= #1
		  (hzd_bpc | hzd_fwd | fSTR | fRTD | fBCC) ? MUX_NOP :
		  (fLOD | fGET) ? MUX_MEM :
		  (fMOV) ? MUX_SFR :
		  (fMUL) ? MUX_MUL :
		  (fBSF) ? MUX_BSF :
		  (fBRU) ? MUX_RPC :		  
		  MUX_ALU;
	
	opc_of <= #1		  
		  (hzd_bpc | hzd_fwd) ? 6'o42 : 
		  wOPC;
	
	rd_of <= #1 wRD;	
	ra_of <= #1 wRA;
	imm_of <= #1 wIMM;
	
     end 
      
   
   reg [15:0] 		rIMM0, rIMM1;
   reg 			rFIM0, rFIM1;
   
   

   assign 		imm_if[15:0] = wIMM;
   assign 		imm_if[31:16] = (rFIM1) ? rIMM1 :
					{(16){wIMM[15]}};

   
   always @(posedge gclk)
     if (grst) begin
	/*AUTORESET*/
	
	rFIM0 <= 1'h0;
	rFIM1 <= 1'h0;
	rIMM0 <= 16'h0;
	rIMM1 <= 16'h0;
	
     end else if (dena) begin
	rFIM1 <= #1 rFIM0;
	rFIM0 <= #1 fIMM & !hzd_bpc;	

	rIMM1 <= #1 rIMM0;
	rIMM0 <= #1 wIMM;	
     end

   assign fINT = brk_if[0] & gpha & !rFIM1;   
   
   
   reg 			wrb_ex;
   reg 			fwd_ex;   
   reg [2:0] 		mux_mx;
   
   wire 		opb_fwd, opa_fwd, opd_fwd;
   
   assign 		mux_opb = {wOPC[3], opb_fwd};
   assign 		opb_fwd = ((wRB ^ rd_ex) == 5'd0) & 
				  fwd_ex & wrb_ex;   

   assign 		mux_opa = {(fBRU|fBCC), opa_fwd};
   assign 		opa_fwd = ((wRA ^ rd_ex) == 5'd0) & 
				  fwd_ex & wrb_ex;

   assign 		mux_opd = {fBCC, opd_fwd};		
   assign 		opd_fwd = (( ((wRA ^ rd_ex) == 5'd0) & fBCC) | 
				   ( ((wRD ^ rd_ex) == 5'd0) & fSTR)) & 
				  fwd_ex & wrb_ex;   

   always @(posedge gclk)
     if (grst) begin
	/*AUTORESET*/
	
	fwd_ex <= 1'h0;
	mux_ex <= 3'h0;
	mux_mx <= 3'h0;
	rd_ex <= 5'h0;
	wrb_ex <= 1'h0;
	
     end else if (dena) begin
	wrb_ex <= #1 |rd_of & |mux_of; 
	fwd_ex <= #1 |mux_of; 

	mux_mx <= #1 mux_ex;	
	mux_ex <= #1 mux_of;	
	rd_ex <= #1 rd_of;	
     end
      
   always @(posedge gclk)
     if (grst) begin
	/*AUTORESET*/
	
	opa_of <= 32'h0;
	opb_of <= 32'h0;
	opd_of <= 32'h0;
	
	
     end else if (dena) begin
		  
	case (mux_opd)
	  2'o2: opd_of <= #1 opa_if; 
	  2'o1: opd_of <= #1 alu_ex; 
	  2'o0: opd_of <= #1 opd_if; 
	  2'o3: opd_of <= #1 alu_ex; 
	endcase 
	
	case (mux_opb)
	  2'o0: opb_of <= #1 opb_if;
	  2'o1: opb_of <= #1 alu_ex;
	  2'o2: opb_of <= #1 imm_if;
	  2'o3: opb_of <= #1 imm_if;	  
	endcase 
	
	case (mux_opa)
	  2'o0: opa_of <= #1 opa_if;
	  2'o1: opa_of <= #1 alu_ex;
	  2'o2: opa_of <= #1 {rpc_if, 2'o0};
	  2'o3: opa_of <= #1 {rpc_if, 2'o0};	  
	endcase 
	 	
     end 
   
   
   
   
   
   
   
   assign 		hzd_fwd = (opd_fwd | opa_fwd | opb_fwd) & mux_ex[2];   
				  
   assign 		hzd_bpc = (bra_ex[1] & !bra_ex[0]);
   
endmodule 

/*
 $Log: not supported by cvs2svn $
 Revision 1.6  2008/05/01 08:32:58  sybreon
 Added interrupt capability.

 Revision 1.5  2008/04/28 08:15:25  sybreon
 Optimisations.

 Revision 1.4  2008/04/26 17:57:43  sybreon
 Minor performance improvements.

 Revision 1.3  2008/04/26 01:09:05  sybreon
 Passes basic tests. Minor documentation changes to make it compatible with iverilog pre-processor.

 Revision 1.2  2008/04/20 16:34:32  sybreon
 Basic version with some features left out.

 Revision 1.1  2008/04/18 00:21:52  sybreon
 Initial import.
*/
/* $Id: aeMB2_dparam.v,v 1.1 2008-04-26 17:57:43 sybreon Exp $
** 
** AEMB2 EDK 6.2 COMPATIBLE CORE
** Copyright (C) 2004-2008 Shawn Tan <shawn.tan@aeste.net>
** 
** This file is part of AEMB.
**
** AEMB is free software: you can redistribute it and/or modify it
** under the terms of the GNU Lesser General Public License as
** published by the Free Software Foundation, either version 3 of the
** License, or (at your option) any later version.
**
** AEMB is distributed in the hope that it will be useful, but WITHOUT
** ANY WARRANTY; without even the implied warranty of MERCHANTABILITY
** or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU Lesser General
** Public License for more details.
**
** You should have received a copy of the GNU Lesser General Public
** License along with AEMB. If not, see <http:**www.gnu.org/licenses/>.
*/
/**
 * @file aeMB2_dparam.v
 * @brief On-chip dual-port asynchronous SRAM.

 * This will be implemented as distributed RAM with one read/write
   port and one read-only port.
  
 */


module aeMB2_dparam (/*AUTOARG*/
   
   dat_o, xdat_o,
   
   adr_i, dat_i, wre_i, xadr_i, xdat_i, xwre_i, clk_i, ena_i
   ) ;
   parameter AW = 5; 
   parameter DW = 2; 

   
   output [DW-1:0] dat_o;  
   input [AW-1:0]  adr_i;
   input [DW-1:0]  dat_i;
   input 	   wre_i;
   
   
   output [DW-1:0] xdat_o;  
   input [AW-1:0]  xadr_i;
   input [DW-1:0]  xdat_i;
   input 	   xwre_i;
   
   
   input 	   clk_i, 
		   ena_i;

   /*AUTOREG*/   
   reg [DW-1:0]    rRAM [(1<<AW)-1:0];
   
   always @(posedge clk_i)
     if (wre_i) rRAM[adr_i] <= #1 dat_i;	
   
   assign 	   dat_o = rRAM[adr_i];
   assign 	   xdat_o = rRAM[xadr_i];   
   
   
   
   integer 	   i;
   initial begin
      for (i=0; i<(1<<AW); i=i+1) 
	begin
	   rRAM[i] <= {(DW){1'b0}};
end
   end
   
   
endmodule 

/*
 $Log: not supported by cvs2svn $
 Revision 1.1  2008/04/20 16:33:39  sybreon
 Initial import.
*/
/* $Id: aeMB2_dwbif.v,v 1.7 2008-04-27 16:41:55 sybreon Exp $
**
** AEMB2 EDK 6.2 COMPATIBLE CORE
** Copyright (C) 2004-2008 Shawn Tan <shawn.tan@aeste.net>
**  
** This file is part of AEMB.
**
** AEMB is free software: you can redistribute it and/or modify it
** under the terms of the GNU Lesser General Public License as
** published by the Free Software Foundation, either version 3 of the
** License, or (at your option) any later version.
**
** AEMB is distributed in the hope that it will be useful, but WITHOUT
** ANY WARRANTY; without even the implied warranty of MERCHANTABILITY
** or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU Lesser General
** Public License for more details.
**
** You should have received a copy of the GNU Lesser General Public
** License along with AEMB. If not, see <http:**www.gnu.org/licenses/>.
*/
/**
 * Data Wishbone Interface
 * @file aeMB2_dwbif.v
  
 * This sets up the Wishbone control signals for the DATA bus
   interfaces. Bus transactions are independent of the pipeline.
 
 */

module aeMB2_dwbif (/*AUTOARG*/
   
   dwb_adr_o, dwb_sel_o, dwb_stb_o, dwb_cyc_o, dwb_tag_o, dwb_wre_o,
   dwb_dat_o, dwb_fb, sel_mx, dwb_mx,
   
   dwb_dat_i, dwb_ack_i, imm_of, opd_of, opc_of, opa_of, opb_of,
   msr_ex, mem_ex, sfr_mx, gclk, grst, dena, gpha
   );
   parameter AEMB_DWB = 32; 

   
   output [AEMB_DWB-1:2] dwb_adr_o;   
   output [3:0] 	 dwb_sel_o;   
   output 		 dwb_stb_o,
			 dwb_cyc_o,
			 dwb_tag_o, 
			 dwb_wre_o;   
   output [31:0] 	 dwb_dat_o;   
   input [31:0] 	 dwb_dat_i; 		 
   input 		 dwb_ack_i;
   
   
   output 		 dwb_fb;
   output [3:0] 	 sel_mx;   
   output [31:0] 	 dwb_mx;   
   input [15:0] 	 imm_of;
   input [31:0] 	 opd_of;   
   input [5:0] 		 opc_of;    
   input [1:0] 		 opa_of;
   input [1:0] 		 opb_of;
   input [7:0] 		 msr_ex;   
   input [AEMB_DWB-1:2]  mem_ex;
   input [7:5] 		 sfr_mx;   
         
   
   input 		 gclk,
			 grst,
			 dena,
			 gpha;   
   
   /*AUTOREG*/
   
   reg			dwb_cyc_o;
   reg [31:0]		dwb_dat_o;
   reg [31:0]		dwb_mx;
   reg [3:0]		dwb_sel_o;
   reg			dwb_stb_o;
   reg			dwb_wre_o;
   reg [3:0]		sel_mx;
   
   
   wire [1:0] 		wOFF = (opa_of[1:0] + opb_of[1:0]); 
   wire [3:0] 		wSEL = {opc_of[1:0], wOFF};
   
   
   assign 		dwb_fb = (dwb_stb_o ~^ dwb_ack_i);   

   
   assign 		dwb_adr_o = mem_ex; 

   
   
   
   
   reg [31:0] 		dwb_lat;   
   reg [31:0] 		opd_ex;
   
   always @(posedge gclk)
     if (grst) begin
	/*AUTORESET*/
	
	dwb_dat_o <= 32'h0;
	
     end else if (dena) begin
	
	case (opc_of[1:0])
	  2'o0: dwb_dat_o <= #1 {(4){opd_of[7:0]}};
	  2'o1: dwb_dat_o <= #1 {(2){opd_of[15:0]}};
	  2'o2: dwb_dat_o <= #1 opd_of;
	  default: dwb_dat_o <= #1 32'hX;
	endcase 
     end

   
   always @(posedge gclk)
     if (grst) begin
	/*AUTORESET*/
	
	dwb_mx <= 32'h0;
	dwb_sel_o <= 4'h0;
	dwb_wre_o <= 1'h0;
	sel_mx <= 4'h0;
	
     end else if (dena) begin
	sel_mx <= #1 dwb_sel_o; 
				
				
				
				
	
	dwb_wre_o <= #1 opc_of[2]; 
	
	dwb_mx <= #1 
		  (dwb_ack_i) ? 
		  dwb_dat_i : 
		  dwb_lat; 

	case (wSEL) 
	  
	  4'h8: dwb_sel_o <= #1 4'hF;
	  
	  4'h4: dwb_sel_o <= #1 4'hC;
	  4'h6: dwb_sel_o <= #1 4'h3;
	  
	  4'h0: dwb_sel_o <= #1 4'h8;
	  4'h1: dwb_sel_o <= #1 4'h4;
	  4'h2: dwb_sel_o <= #1 4'h2;
	  4'h3: dwb_sel_o <= #1 4'h1;	
	  
	  4'hC, 4'hD, 4'hE, 4'hF: 
	    dwb_sel_o <= #1 4'h0;
	  
	  default: dwb_sel_o <= #1 4'hX;
	endcase 
     end 

   
   
   always @(posedge gclk)
     if (grst) begin
	/*AUTORESET*/
	
	dwb_lat <= 32'h0;
	
     end else if (dwb_ack_i) begin
	
	dwb_lat <= #1 dwb_dat_i;	
     end
      
   always @(posedge gclk)
     if (grst) begin
	/*AUTORESET*/
	
	dwb_cyc_o <= 1'h0;
	dwb_stb_o <= 1'h0;
	
     
     end else if (dwb_fb) begin
	dwb_stb_o <= #1
		     (dena) ? &opc_of[5:4] : 
		     (dwb_stb_o & !dwb_ack_i); 
	dwb_cyc_o <= #1 
		     (dena) ? &opc_of[5:4] | msr_ex[0] :
		     (dwb_stb_o & !dwb_ack_i) | msr_ex[0];	
     end

   assign dwb_tag_o = msr_ex[7]; 
   
endmodule 

/*
 $Log: not supported by cvs2svn $
 Revision 1.6  2008/04/26 17:57:43  sybreon
 Minor performance improvements.

 Revision 1.5  2008/04/26 01:09:05  sybreon
 Passes basic tests. Minor documentation changes to make it compatible with iverilog pre-processor.

 Revision 1.4  2008/04/23 14:18:52  sybreon
 Fixed pipelined latching of data bug.

 Revision 1.3  2008/04/21 12:11:38  sybreon
 Passes arithmetic tests with single thread.

 Revision 1.2  2008/04/20 16:34:32  sybreon
 Basic version with some features left out.

 Revision 1.1  2008/04/18 00:21:52  sybreon
 Initial import.
*/
/* $Id: aeMB2_edk62.v,v 1.8 2008-05-01 08:32:58 sybreon Exp $
**
** AEMB2 EDK 6.2 COMPATIBLE CORE
** Copyright (C) 2004-2008 Shawn Tan <shawn.tan@aeste.net>
**  
** This file is part of AEMB.
**
** AEMB is free software: you can redistribute it and/or modify it
** under the terms of the GNU Lesser General Public License as
** published by the Free Software Foundation, either version 3 of the
** License, or (at your option) any later version.
**
** AEMB is distributed in the hope that it will be useful, but WITHOUT
** ANY WARRANTY; without even the implied warranty of MERCHANTABILITY
** or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU Lesser General
** Public License for more details.
**
** You should have received a copy of the GNU Lesser General Public
** License along with AEMB. If not, see <http:**www.gnu.org/licenses/>.
*/
/**
 * Top Level Core
 * @file aeMB2_edk62.v

 * This implements an EDK 6.2 software compatible core. It implements
   all the software instructions except for division and cache writes.
 
 */

module aeMB2_edk62 (/*AUTOARG*/
   
   xwb_wre_o, xwb_tag_o, xwb_stb_o, xwb_sel_o, xwb_dat_o, xwb_cyc_o,
   xwb_adr_o, iwb_wre_o, iwb_tag_o, iwb_stb_o, iwb_sel_o, iwb_cyc_o,
   iwb_adr_o, dwb_wre_o, dwb_tag_o, dwb_stb_o, dwb_sel_o, dwb_dat_o,
   dwb_cyc_o, dwb_adr_o,
   
   xwb_dat_i, xwb_ack_i, sys_rst_i, sys_int_i, sys_ena_i, sys_clk_i,
   iwb_dat_i, iwb_ack_i, dwb_dat_i, dwb_ack_i
   );
   
   parameter AEMB_IWB = 32; 
   parameter AEMB_DWB = 32; 
   parameter AEMB_XWB = 7; 

   
   parameter AEMB_ICH = 11; 
   parameter AEMB_IDX = 6; 

   
   parameter AEMB_BSF = 1; 
   parameter AEMB_MUL = 1; 
   parameter AEMB_DIV = 0; 
   parameter AEMB_FPU = 0; 

   
   localparam AEMB_XSL = 1; 
   localparam AEMB_HTX = 1; 
      
   /*AUTOOUTPUT*/
   
   output [AEMB_DWB-1:2] dwb_adr_o;		
   output		dwb_cyc_o;		
   output [31:0]	dwb_dat_o;		
   output [3:0]		dwb_sel_o;		
   output		dwb_stb_o;		
   output		dwb_tag_o;		
   output		dwb_wre_o;		
   output [AEMB_IWB-1:2] iwb_adr_o;		
   output		iwb_cyc_o;		
   output [3:0]		iwb_sel_o;		
   output		iwb_stb_o;		
   output		iwb_tag_o;		
   output		iwb_wre_o;		
   output [AEMB_XWB-1:2] xwb_adr_o;		
   output		xwb_cyc_o;		
   output [31:0]	xwb_dat_o;		
   output [3:0]		xwb_sel_o;		
   output		xwb_stb_o;		
   output		xwb_tag_o;		
   output		xwb_wre_o;		
   
   /*AUTOINPUT*/
   
   input		dwb_ack_i;		
   input [31:0]		dwb_dat_i;		
   input		iwb_ack_i;		
   input [31:0]		iwb_dat_i;		
   input		sys_clk_i;		
   input		sys_ena_i;		
   input		sys_int_i;		
   input		sys_rst_i;		
   input		xwb_ack_i;		
   input [31:0]		xwb_dat_i;		
   
   /*AUTOWIRE*/
   
   wire [31:0]		alu_ex;			
   wire [31:0]		alu_mx;			
   wire [31:2]		bpc_ex;			
   wire [1:0]		bra_ex;			
   wire [1:0]		brk_if;			
   wire [31:0]		bsf_mx;			
   wire			dena;			
   wire			dwb_fb;			
   wire [31:0]		dwb_mx;			
   wire			fet_fb;			
   wire			gclk;			
   wire			gpha;			
   wire			grst;			
   wire			hzd_bpc;		
   wire			hzd_fwd;		
   wire [AEMB_IWB-1:2]	ich_adr;		
   wire [31:0]		ich_dat;		
   wire			ich_fb;			
   wire			ich_hit;		
   wire			iena;			
   wire [15:0]		imm_of;			
   wire [31:2]		mem_ex;			
   wire [7:0]		msr_ex;			
   wire [31:0]		mul_mx;			
   wire [2:0]		mux_ex;			
   wire [2:0]		mux_of;			
   wire [31:0]		opa_if;			
   wire [31:0]		opa_of;			
   wire [31:0]		opb_if;			
   wire [31:0]		opb_of;			
   wire [5:0]		opc_of;			
   wire [31:0]		opd_if;			
   wire [31:0]		opd_of;			
   wire [4:0]		ra_of;			
   wire [4:0]		rd_ex;			
   wire [4:0]		rd_of;			
   wire [31:2]		rpc_if;			
   wire [31:2]		rpc_mx;			
   wire [3:0]		sel_mx;			
   wire [31:0]		sfr_mx;			
   wire			xwb_fb;			
   wire [31:0]		xwb_mx;			
   
   /*AUTOREG*/
   
   aeMB2_pipe
     pip0
       (/*AUTOINST*/
	
	.brk_if				(brk_if[1:0]),
	.gpha				(gpha),
	.gclk				(gclk),
	.grst				(grst),
	.dena				(dena),
	.iena				(iena),
	
	.bra_ex				(bra_ex[1:0]),
	.dwb_fb				(dwb_fb),
	.xwb_fb				(xwb_fb),
	.ich_fb				(ich_fb),
	.fet_fb				(fet_fb),
	.msr_ex				(msr_ex[3:0]),
	.sys_clk_i			(sys_clk_i),
	.sys_int_i			(sys_int_i),
	.sys_rst_i			(sys_rst_i),
	.sys_ena_i			(sys_ena_i));   
   
   aeMB2_iche
     #(/*AUTOINSTPARAM*/
       
       .AEMB_IWB			(AEMB_IWB),
       .AEMB_ICH			(AEMB_ICH),
       .AEMB_IDX			(AEMB_IDX),
       .AEMB_HTX			(AEMB_HTX))
   iche0
     (/*AUTOINST*/
      
      .ich_dat				(ich_dat[31:0]),
      .ich_hit				(ich_hit),
      .ich_fb				(ich_fb),
      
      .ich_adr				(ich_adr[AEMB_IWB-1:2]),
      .iwb_dat_i			(iwb_dat_i[31:0]),
      .iwb_ack_i			(iwb_ack_i),
      .gclk				(gclk),
      .grst				(grst),
      .iena				(iena),
      .gpha				(gpha));   
   
   aeMB2_iwbif
     #(/*AUTOINSTPARAM*/
       
       .AEMB_IWB			(AEMB_IWB),
       .AEMB_HTX			(AEMB_HTX))
   iwbif0
     (/*AUTOINST*/
      
      .iwb_adr_o			(iwb_adr_o[AEMB_IWB-1:2]),
      .iwb_stb_o			(iwb_stb_o),
      .iwb_sel_o			(iwb_sel_o[3:0]),
      .iwb_wre_o			(iwb_wre_o),
      .iwb_cyc_o			(iwb_cyc_o),
      .iwb_tag_o			(iwb_tag_o),
      .ich_adr				(ich_adr[AEMB_IWB-1:2]),
      .fet_fb				(fet_fb),
      .rpc_if				(rpc_if[31:2]),
      .rpc_mx				(rpc_mx[31:2]),
      
      .iwb_ack_i			(iwb_ack_i),
      .iwb_dat_i			(iwb_dat_i[31:0]),
      .ich_hit				(ich_hit),
      .msr_ex				(msr_ex[7:5]),
      .hzd_bpc				(hzd_bpc),
      .hzd_fwd				(hzd_fwd),
      .bra_ex				(bra_ex[1:0]),
      .bpc_ex				(bpc_ex[31:2]),
      .gclk				(gclk),
      .grst				(grst),
      .dena				(dena),
      .iena				(iena),
      .gpha				(gpha));

   aeMB2_ctrl
     #(/*AUTOINSTPARAM*/
       
       .AEMB_HTX			(AEMB_HTX))
   ctrl0
     (/*AUTOINST*/
      
      .opa_of				(opa_of[31:0]),
      .opb_of				(opb_of[31:0]),
      .opd_of				(opd_of[31:0]),
      .opc_of				(opc_of[5:0]),
      .ra_of				(ra_of[4:0]),
      .rd_of				(rd_of[4:0]),
      .imm_of				(imm_of[15:0]),
      .rd_ex				(rd_ex[4:0]),
      .mux_of				(mux_of[2:0]),
      .mux_ex				(mux_ex[2:0]),
      .hzd_bpc				(hzd_bpc),
      .hzd_fwd				(hzd_fwd),
      
      .opa_if				(opa_if[31:0]),
      .opb_if				(opb_if[31:0]),
      .opd_if				(opd_if[31:0]),
      .brk_if				(brk_if[1:0]),
      .bra_ex				(bra_ex[1:0]),
      .rpc_if				(rpc_if[31:2]),
      .alu_ex				(alu_ex[31:0]),
      .ich_dat				(ich_dat[31:0]),
      .gclk				(gclk),
      .grst				(grst),
      .dena				(dena),
      .iena				(iena),
      .gpha				(gpha));

   aeMB2_brcc
     #(/*AUTOINSTPARAM*/
       
       .AEMB_HTX			(AEMB_HTX))
   brcc0
     (/*AUTOINST*/
      
      .bra_ex				(bra_ex[1:0]),
      
      .opd_of				(opd_of[31:0]),
      .ra_of				(ra_of[4:0]),
      .rd_of				(rd_of[4:0]),
      .opc_of				(opc_of[5:0]),
      .gclk				(gclk),
      .grst				(grst),
      .dena				(dena),
      .iena				(iena),
      .gpha				(gpha));   

   aeMB2_exec
     #(/*AUTOINSTPARAM*/
       
       .AEMB_IWB			(AEMB_IWB),
       .AEMB_DWB			(AEMB_DWB),
       .AEMB_MUL			(AEMB_MUL),
       .AEMB_BSF			(AEMB_BSF),
       .AEMB_HTX			(AEMB_HTX))
   exec0
     (/*AUTOINST*/
      
      .alu_ex				(alu_ex[31:0]),
      .alu_mx				(alu_mx[31:0]),
      .bpc_ex				(bpc_ex[31:2]),
      .bsf_mx				(bsf_mx[31:0]),
      .mem_ex				(mem_ex[31:2]),
      .msr_ex				(msr_ex[7:0]),
      .mul_mx				(mul_mx[31:0]),
      .sfr_mx				(sfr_mx[31:0]),
      
      .dena				(dena),
      .gclk				(gclk),
      .gpha				(gpha),
      .grst				(grst),
      .imm_of				(imm_of[15:0]),
      .opa_of				(opa_of[31:0]),
      .opb_of				(opb_of[31:0]),
      .opc_of				(opc_of[5:0]),
      .opd_of				(opd_of[31:0]),
      .ra_of				(ra_of[4:0]),
      .rd_of				(rd_of[4:0]));   
   
   aeMB2_memif
     #(/*AUTOINSTPARAM*/
       
       .AEMB_DWB			(AEMB_DWB),
       .AEMB_XWB			(AEMB_XWB),
       .AEMB_XSL			(AEMB_XSL))
   memif0
     (/*AUTOINST*/
      
      .dwb_adr_o			(dwb_adr_o[AEMB_DWB-1:2]),
      .dwb_cyc_o			(dwb_cyc_o),
      .dwb_dat_o			(dwb_dat_o[31:0]),
      .dwb_fb				(dwb_fb),
      .dwb_mx				(dwb_mx[31:0]),
      .dwb_sel_o			(dwb_sel_o[3:0]),
      .dwb_stb_o			(dwb_stb_o),
      .dwb_tag_o			(dwb_tag_o),
      .dwb_wre_o			(dwb_wre_o),
      .sel_mx				(sel_mx[3:0]),
      .xwb_adr_o			(xwb_adr_o[AEMB_XWB-1:2]),
      .xwb_cyc_o			(xwb_cyc_o),
      .xwb_dat_o			(xwb_dat_o[31:0]),
      .xwb_fb				(xwb_fb),
      .xwb_mx				(xwb_mx[31:0]),
      .xwb_sel_o			(xwb_sel_o[3:0]),
      .xwb_stb_o			(xwb_stb_o),
      .xwb_tag_o			(xwb_tag_o),
      .xwb_wre_o			(xwb_wre_o),
      
      .dena				(dena),
      .dwb_ack_i			(dwb_ack_i),
      .dwb_dat_i			(dwb_dat_i[31:0]),
      .gclk				(gclk),
      .gpha				(gpha),
      .grst				(grst),
      .imm_of				(imm_of[15:0]),
      .mem_ex				(mem_ex[AEMB_DWB-1:2]),
      .msr_ex				(msr_ex[7:0]),
      .opa_of				(opa_of[31:0]),
      .opb_of				(opb_of[1:0]),
      .opc_of				(opc_of[5:0]),
      .opd_of				(opd_of[31:0]),
      .sfr_mx				(sfr_mx[7:5]),
      .xwb_ack_i			(xwb_ack_i),
      .xwb_dat_i			(xwb_dat_i[31:0]));        

   aeMB2_regs
     #(/*AUTOINSTPARAM*/
       
       .AEMB_HTX			(AEMB_HTX))
   regs0
     (/*AUTOINST*/
      
      .opa_if				(opa_if[31:0]),
      .opb_if				(opb_if[31:0]),
      .opd_if				(opd_if[31:0]),
      
      .alu_mx				(alu_mx[31:0]),
      .bsf_mx				(bsf_mx[31:0]),
      .dena				(dena),
      .dwb_mx				(dwb_mx[31:0]),
      .gclk				(gclk),
      .gpha				(gpha),
      .grst				(grst),
      .ich_dat				(ich_dat[31:0]),
      .mul_mx				(mul_mx[31:0]),
      .mux_ex				(mux_ex[2:0]),
      .mux_of				(mux_of[2:0]),
      .rd_ex				(rd_ex[4:0]),
      .rd_of				(rd_of[4:0]),
      .rpc_mx				(rpc_mx[31:2]),
      .sel_mx				(sel_mx[3:0]),
      .sfr_mx				(sfr_mx[31:0]),
      .xwb_mx				(xwb_mx[31:0]));   
   
endmodule 

/*
 $Log: not supported by cvs2svn $
 Revision 1.7  2008/04/27 19:52:46  sybreon
 added iwb_tag_o signal tied to MSR_ICE.

 Revision 1.6  2008/04/26 17:57:43  sybreon
 Minor performance improvements.

 Revision 1.5  2008/04/26 01:11:30  sybreon
 Fixed minor typos.

 Revision 1.4  2008/04/26 01:09:05  sybreon
 Passes basic tests. Minor documentation changes to make it compatible with iverilog pre-processor.

 Revision 1.3  2008/04/21 12:11:38  sybreon
 Passes arithmetic tests with single thread.

 Revision 1.2  2008/04/20 16:34:32  sybreon
 Basic version with some features left out.

 Revision 1.1  2008/04/18 00:21:52  sybreon
 Initial import.
*/
/* $Id: aeMB2_exec.v,v 1.4 2008-04-26 17:57:43 sybreon Exp $
**
** AEMB2 EDK 6.2 COMPATIBLE CORE
** Copyright (C) 2004-2008 Shawn Tan <shawn.tan@aeste.net>
**  
** This file is part of AEMB.
**
** AEMB is free software: you can redistribute it and/or modify it
** under the terms of the GNU Lesser General Public License as
** published by the Free Software Foundation, either version 3 of the
** License, or (at your option) any later version.
**
** AEMB is distributed in the hope that it will be useful, but WITHOUT
** ANY WARRANTY; without even the implied warranty of MERCHANTABILITY
** or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU Lesser General
** Public License for more details.
**
** You should have received a copy of the GNU Lesser General Public
** License along with AEMB. If not, see <http:**www.gnu.org/licenses/>.
*/

/**
 * Execution Units Wrapper
 * @file aeMB2_exec.v

 * Collection of all the execution units.
 
 */


module aeMB2_exec (/*AUTOARG*/
   
   sfr_mx, mul_mx, msr_ex, mem_ex, bsf_mx, bpc_ex, alu_mx, alu_ex,
   
   rd_of, ra_of, opd_of, opc_of, opb_of, opa_of, imm_of, grst, gpha,
   gclk, dena
   );
   parameter AEMB_IWB = 32;
   parameter AEMB_DWB = 32;
   parameter AEMB_MUL = 1;
   parameter AEMB_BSF = 1;   
   parameter AEMB_HTX = 1;   
   
   /*AUTOOUTPUT*/
   
   output [31:0]	alu_ex;			
   output [31:0]	alu_mx;			
   output [31:2]	bpc_ex;			
   output [31:0]	bsf_mx;			
   output [31:2]	mem_ex;			
   output [7:0]		msr_ex;			
   output [31:0]	mul_mx;			
   output [31:0]	sfr_mx;			
   
   /*AUTOINPUT*/
   
   input		dena;			
   input		gclk;			
   input		gpha;			
   input		grst;			
   input [15:0]		imm_of;			
   input [31:0]		opa_of;			
   input [31:0]		opb_of;			
   input [5:0]		opc_of;			
   input [31:0]		opd_of;			
   input [4:0]		ra_of;			
   input [4:0]		rd_of;			
   
   /*AUTOWIRE*/

   aeMB2_bsft
     #(/*AUTOINSTPARAM*/
       
       .AEMB_BSF			(AEMB_BSF))
   bsft0
     (/*AUTOINST*/
      
      .bsf_mx				(bsf_mx[31:0]),
      
      .opa_of				(opa_of[31:0]),
      .opb_of				(opb_of[31:0]),
      .opc_of				(opc_of[5:0]),
      .imm_of				(imm_of[10:9]),
      .gclk				(gclk),
      .grst				(grst),
      .dena				(dena),
      .gpha				(gpha));   
   
   aeMB2_mult
     #(/*AUTOINSTPARAM*/
       
       .AEMB_MUL			(AEMB_MUL))
   mult0
     (/*AUTOINST*/
      
      .mul_mx				(mul_mx[31:0]),
      
      .opa_of				(opa_of[31:0]),
      .opb_of				(opb_of[31:0]),
      .opc_of				(opc_of[5:0]),
      .gclk				(gclk),
      .grst				(grst),
      .dena				(dena),
      .gpha				(gpha));   

   aeMB2_intu
     #(/*AUTOINSTPARAM*/
       
       .AEMB_DWB			(AEMB_DWB),
       .AEMB_IWB			(AEMB_IWB),
       .AEMB_HTX			(AEMB_HTX))
   intu0
     (/*AUTOINST*/
      
      .mem_ex				(mem_ex[31:2]),
      .bpc_ex				(bpc_ex[31:2]),
      .alu_ex				(alu_ex[31:0]),
      .alu_mx				(alu_mx[31:0]),
      .msr_ex				(msr_ex[7:0]),
      .sfr_mx				(sfr_mx[31:0]),
      
      .opc_of				(opc_of[5:0]),
      .opa_of				(opa_of[31:0]),
      .opb_of				(opb_of[31:0]),
      .opd_of				(opd_of[31:0]),
      .imm_of				(imm_of[15:0]),
      .rd_of				(rd_of[4:0]),
      .ra_of				(ra_of[4:0]),
      .gclk				(gclk),
      .grst				(grst),
      .dena				(dena),
      .gpha				(gpha));   
   
endmodule 

/*
 $Log: not supported by cvs2svn $
 Revision 1.3  2008/04/26 01:11:30  sybreon
 Fixed minor typos.

 Revision 1.2  2008/04/26 01:09:06  sybreon
 Passes basic tests. Minor documentation changes to make it compatible with iverilog pre-processor.

 Revision 1.1  2008/04/18 00:21:52  sybreon
 Initial import.
*/
/* $Id: aeMB2_gprf.v,v 1.4 2008-04-26 17:57:43 sybreon Exp $
**
** AEMB2 EDK 6.2 COMPATIBLE CORE
** Copyright (C) 2004-2008 Shawn Tan <shawn.tan@aeste.net>
**  
** This file is part of AEMB.
**
** AEMB is free software: you can redistribute it and/or modify it
** under the terms of the GNU Lesser General Public License as
** published by the Free Software Foundation, either version 3 of the
** License, or (at your option) any later version.
**
** AEMB is distributed in the hope that it will be useful, but WITHOUT
** ANY WARRANTY; without even the implied warranty of MERCHANTABILITY
** or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU Lesser General
** Public License for more details.
**
** You should have received a copy of the GNU Lesser General Public
** License along with AEMB. If not, see <http:**www.gnu.org/licenses/>.
*/
/**
 * General Purpose Register File
 * @aeMB2_gprf.v
 
 * Dual set of 32 general purpose registers for the core. These are
   R0-R31. A zero is written to R0 for both sets during reset and
   maintained after that.
 
 */

module aeMB2_gprf (/*AUTOARG*/
   
   opa_if, opb_if, opd_if,
   
   mux_of, mux_ex, ich_dat, rd_of, rd_ex, sel_mx, rpc_mx, xwb_mx,
   dwb_mx, alu_mx, sfr_mx, mul_mx, bsf_mx, gclk, grst, dena, gpha
   );
   parameter AEMB_HTX = 1;   
   
   
   output [31:0] opa_if,
		 opb_if,
		 opd_if;   
   
   input [2:0] 	 mux_of,
		 mux_ex;
   input [31:0]  ich_dat;
   input [4:0] 	 rd_of,
		 rd_ex;
   
   
   input [3:0] 	 sel_mx;
   input [31:2]  rpc_mx;
   input [31:0]  xwb_mx,
		 dwb_mx,
		 alu_mx,
		 sfr_mx,
		 mul_mx,
		 bsf_mx;   
   
   
   input 	 gclk,
		 grst,
		 dena,
		 gpha;   

   /*AUTOWIRE*/
   /*AUTOREG*/

   wire [31:0] 	 opd_wr;      
   reg [31:0] 	 rMEMA[63:0],
		 rMEMB[63:0],
		 rMEMD[63:0];      
   reg [31:0] 	 mem_mx;
   reg [31:0] 	 regd;   
   reg 		 wrb_fb;   
   reg [4:0] 	 rd_mx;
   reg [2:0] 	 mux_mx;   
   
   
   always @(posedge gclk)
     if (grst) begin
	/*AUTORESET*/
	
	mux_mx <= 3'h0;
	rd_mx <= 5'h0;
	wrb_fb <= 1'h0;
	
     end else if (dena) begin
	wrb_fb <= #1 |rd_ex & |mux_ex; 
	
	rd_mx <= #1 rd_ex;	
	mux_mx <= #1 mux_ex;	
     end

   
   always @(/*AUTOSENSE*/dwb_mx or sel_mx or xwb_mx) begin
      case (sel_mx)
	
	4'h8: mem_mx <= #1 {24'd0, dwb_mx[31:24]};
	4'h4: mem_mx <= #1 {24'd0, dwb_mx[23:16]};
	4'h2: mem_mx <= #1 {24'd0, dwb_mx[15:8]};
	4'h1: mem_mx <= #1 {24'd0, dwb_mx[7:0]};
	
	4'hC: mem_mx <= #1 {16'd0, dwb_mx[31:16]};
	4'h3: mem_mx <= #1 {16'd0, dwb_mx[15:0]};
	
	4'hF: mem_mx <= #1 dwb_mx;
	
	4'h0: mem_mx <= #1 xwb_mx;
	default: mem_mx <= 32'hX;	
      endcase 
   end 
   
   
   localparam [2:0] MUX_SFR = 3'o7,
		    MUX_BSF = 3'o6,
		    MUX_MUL = 3'o5,
		    MUX_MEM = 3'o4,
		    
		    MUX_RPC = 3'o2,
		    MUX_ALU = 3'o1,
		    MUX_NOP = 3'o0;   
   
   always @(/*AUTOSENSE*/alu_mx or bsf_mx or mem_mx or mul_mx
	    or mux_mx or rpc_mx or sfr_mx)
     case (mux_mx)
       MUX_ALU: regd <= #1 alu_mx; 
       MUX_RPC: regd <= #1 {rpc_mx[31:2], 2'o0}; 
       MUX_MEM: regd <= #1 mem_mx; 
       MUX_MUL: regd <= #1 mul_mx; 
       MUX_BSF: regd <= #1 bsf_mx; 
       MUX_NOP: regd <= #1 32'h0;
       MUX_SFR: regd <= #1 sfr_mx;       
       default: regd <= #1 32'hX;                     
     endcase 
   
   
   wire [5:0] 	    wRD0 = {gpha, ich_dat[25:21]};   
   wire [5:0] 	    wRA0 = {gpha, ich_dat[20:16]};
   wire [5:0] 	    wRB0 = {gpha, ich_dat[15:11]};
   wire [5:0] 	    wRW0 = {!gpha, rd_mx};
   wire 	    wWRE = grst | wrb_fb;
   
   wire [31:0] 	    wDA0,
		    wDB0,
		    wDD0;
   
   assign 	    opa_if = wDA0;
   assign 	    opb_if = wDB0;
   assign 	    opd_if = wDD0;   
   
   /* aeMB2_dparam AUTO_TEMPLATE "_\([a-z,0-9]+\)" (
    .AW(6'd6), 
    .DW(6'd32),
    
    .clk_i(gclk),
    .ena_i(dena),
    
    .dat_i(regd),
    .adr_i(wRW0[5:0]),
    .wre_i(wWRE),
    .dat_o(),
    
    .xwre_i(),
    .xdat_i(),
    .xadr_i(wR@[5:0]),
    .xdat_o(wD@[31:0]),
    ) */

   aeMB2_dparam
     #(/*AUTOINSTPARAM*/
       
       .AW				(6'd6),			 
       .DW				(6'd32))		 
   bank_A0
     (/*AUTOINST*/
      
      .dat_o				(),			 
      .xdat_o				(wDA0[31:0]),		 
      
      .adr_i				(wRW0[5:0]),		 
      .dat_i				(regd),			 
      .wre_i				(wWRE),			 
      .xadr_i				(wRA0[5:0]),		 
      .xdat_i				(),			 
      .xwre_i				(),			 
      .clk_i				(gclk),			 
      .ena_i				(dena));			 
   
   aeMB2_dparam
     #(/*AUTOINSTPARAM*/
       
       .AW				(6'd6),			 
       .DW				(6'd32))		 
   bank_B0
     (/*AUTOINST*/
      
      .dat_o				(),			 
      .xdat_o				(wDB0[31:0]),		 
      
      .adr_i				(wRW0[5:0]),		 
      .dat_i				(regd),			 
      .wre_i				(wWRE),			 
      .xadr_i				(wRB0[5:0]),		 
      .xdat_i				(),			 
      .xwre_i				(),			 
      .clk_i				(gclk),			 
      .ena_i				(dena));			 
   
   aeMB2_dparam
     #(/*AUTOINSTPARAM*/
       
       .AW				(6'd6),			 
       .DW				(6'd32))		 
   bank_D0
     (/*AUTOINST*/
      
      .dat_o				(),			 
      .xdat_o				(wDD0[31:0]),		 
      
      .adr_i				(wRW0[5:0]),		 
      .dat_i				(regd),			 
      .wre_i				(wWRE),			 
      .xadr_i				(wRD0[5:0]),		 
      .xdat_i				(),			 
      .xwre_i				(),			 
      .clk_i				(gclk),			 
      .ena_i				(dena));			 
      
endmodule 

/*
 $Log: not supported by cvs2svn $
 Revision 1.3  2008/04/26 01:09:06  sybreon
 Passes basic tests. Minor documentation changes to make it compatible with iverilog pre-processor.

 Revision 1.2  2008/04/20 16:34:32  sybreon
 Basic version with some features left out.

 Revision 1.1  2008/04/18 00:21:52  sybreon
 Initial import.
*/

`ifdef XXX
   
   wire [4:0] 	    wRD0 = (gpha) ? ich_dat[25:21] : 5'd0;   
   wire [4:0] 	    wRA0 = (gpha) ? ich_dat[20:16] : 5'd0;   
   wire [4:0] 	    wRB0 = (gpha) ? ich_dat[15:11] : 5'd0;   

   wire [4:0] 	    wRD1 = (!gpha) ? ich_dat[25:21] : 5'd0;   
   wire [4:0] 	    wRA1 = (!gpha) ? ich_dat[20:16] : 5'd0;   
   wire [4:0] 	    wRB1 = (!gpha) ? ich_dat[15:11] : 5'd0;   

   wire [4:0] 	    wRW  = rd_mx;   
   
   wire 	    wWR0 = (!gpha & dena & wrb_fb) | grst;
   wire 	    wWR1 = (gpha & dena & wrb_fb) | grst; 

   wire 	    wWA0 = wWR0;
   wire 	    wWB0 = wWR0;
   wire 	    wWD0 = wWR0;
   wire 	    wWA1 = wWR1;
   wire 	    wWB1 = wWR1;
   wire 	    wWD1 = wWR1;   

   wire [31:0] 	    wDA0, 
		    wDA1,
		    wDB0,
		    wDB1,
		    wDD0,
		    wDD1;   

   assign 	    opa_if = wDA0 | wDA1;
   assign 	    opb_if = wDB0 | wDB1;
   assign 	    opd_if = wDD0 | wDD1;   
   
   /* aeMB2_dparam AUTO_TEMPLATE "_\([a-z,0-9]+\)" (
    .AW(6'd5), 
    .DW(6'd32),
    
    .clk_i(gclk),
    .ena_i(dena),
    
    .dat_i(regd),
    .adr_i(wRW[4:0]),
    .wre_i(wW@),
    .dat_o(),
    
    .xwre_i(),
    .xdat_i(),
    .xadr_i(wR@[4:0]),
    .xdat_o(wD@[31:0]),
    ) */
   
   aeMB2_dparam
     #(/*AUTOINSTPARAM*/
       
       .AW				(6'd5),			 
       .DW				(6'd32))		 
   bank_A0
     (/*AUTOINST*/
      
      .dat_o				(),			 
      .xdat_o				(wDA0[31:0]),		 
      
      .adr_i				(wRW[4:0]),		 
      .dat_i				(regd),			 
      .wre_i				(wWA0),			 
      .xadr_i				(wRA0[4:0]),		 
      .xdat_i				(),			 
      .xwre_i				(),			 
      .clk_i				(gclk),			 
      .ena_i				(dena));			 

   aeMB2_dparam
     #(/*AUTOINSTPARAM*/
       
       .AW				(6'd5),			 
       .DW				(6'd32))		 
   bank_B0
     (/*AUTOINST*/
      
      .dat_o				(),			 
      .xdat_o				(wDB0[31:0]),		 
      
      .adr_i				(wRW[4:0]),		 
      .dat_i				(regd),			 
      .wre_i				(wWB0),			 
      .xadr_i				(wRB0[4:0]),		 
      .xdat_i				(),			 
      .xwre_i				(),			 
      .clk_i				(gclk),			 
      .ena_i				(dena));			 
   
   aeMB2_dparam
     #(/*AUTOINSTPARAM*/
       
       .AW				(6'd5),			 
       .DW				(6'd32))		 
   bank_D0
     (/*AUTOINST*/
      
      .dat_o				(),			 
      .xdat_o				(wDD0[31:0]),		 
      
      .adr_i				(wRW[4:0]),		 
      .dat_i				(regd),			 
      .wre_i				(wWD0),			 
      .xadr_i				(wRD0[4:0]),		 
      .xdat_i				(),			 
      .xwre_i				(),			 
      .clk_i				(gclk),			 
      .ena_i				(dena));			 
   
   aeMB2_dparam
     #(/*AUTOINSTPARAM*/
       
       .AW				(6'd5),			 
       .DW				(6'd32))		 
   bank_A1
     (/*AUTOINST*/
      
      .dat_o				(),			 
      .xdat_o				(wDA1[31:0]),		 
      
      .adr_i				(wRW[4:0]),		 
      .dat_i				(regd),			 
      .wre_i				(wWA1),			 
      .xadr_i				(wRA1[4:0]),		 
      .xdat_i				(),			 
      .xwre_i				(),			 
      .clk_i				(gclk),			 
      .ena_i				(dena));			 
   
   aeMB2_dparam
     #(/*AUTOINSTPARAM*/
       
       .AW				(6'd5),			 
       .DW				(6'd32))		 
   bank_B1
     (/*AUTOINST*/
      
      .dat_o				(),			 
      .xdat_o				(wDB1[31:0]),		 
      
      .adr_i				(wRW[4:0]),		 
      .dat_i				(regd),			 
      .wre_i				(wWB1),			 
      .xadr_i				(wRB1[4:0]),		 
      .xdat_i				(),			 
      .xwre_i				(),			 
      .clk_i				(gclk),			 
      .ena_i				(dena));			 
   
   aeMB2_dparam
     #(/*AUTOINSTPARAM*/
       
       .AW				(6'd5),			 
       .DW				(6'd32))		 
   bank_D1
     (/*AUTOINST*/
      
      .dat_o				(),			 
      .xdat_o				(wDD1[31:0]),		 
      
      .adr_i				(wRW[4:0]),		 
      .dat_i				(regd),			 
      .wre_i				(wWD1),			 
      .xadr_i				(wRD1[4:0]),		 
      .xdat_i				(),			 
      .xwre_i				(),			 
      .clk_i				(gclk),			 
      .ena_i				(dena));			 
`endif   

/* $Id: aeMB2_iche.v,v 1.5 2008-04-28 00:54:31 sybreon Exp $
**
** AEMB2 EDK 6.2 COMPATIBLE CORE
** Copyright (C) 2004-2008 Shawn Tan <shawn.tan@aeste.net>
**  
** This file is part of AEMB.
**
** AEMB is free software: you can redistribute it and/or modify it
** under the terms of the GNU Lesser General Public License as
** published by the Free Software Foundation, either version 3 of the
** License, or (at your option) any later version.
**
** AEMB is distributed in the hope that it will be useful, but WITHOUT
** ANY WARRANTY; without even the implied warranty of MERCHANTABILITY
** or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU Lesser General
** Public License for more details.
**
** You should have received a copy of the GNU Lesser General Public
** License along with AEMB. If not, see <http:**www.gnu.org/licenses/>.
*/
/**
 * Instruction Cache Block
 * @file aeMB2_iche.v

 * This is a non-optional instruction cache for single cycle
   operations. The maximum line width is 16 words (512 bits)
 
 * Single port synchronous RAM is used as the main cache DATA
   block. A single port asynchronous RAM is used as the TAG block.

 * The sizes need to be selected carefully to minimise resource
   wastage. Details are provided in the documentation.
 
 */


module aeMB2_iche (/*AUTOARG*/
   
   ich_dat, ich_hit, ich_fb,
   
   ich_adr, iwb_dat_i, iwb_ack_i, gclk, grst, iena, gpha
   );
   parameter AEMB_IWB = 32;   
   parameter AEMB_ICH = 11;
   parameter AEMB_IDX = 6;   
   parameter AEMB_HTX = 1;   
   
   
   input [AEMB_IWB-1:2] ich_adr;
   output [31:0] 	ich_dat;
   output 		ich_hit; 
   output 		ich_fb; 
   
   
   input [31:0] 	iwb_dat_i;
   input 		iwb_ack_i;
   
   
   input 		gclk,
			grst,
			iena,
			gpha;      

   
   localparam 		SIZ = AEMB_ICH-2; 
   localparam 		BLK = AEMB_ICH-AEMB_IDX; 
   localparam 		LNE = AEMB_IDX-2; 
       
   localparam 		TAG = AEMB_IWB-AEMB_ICH; 
   localparam 		VAL = (1<<LNE); 
   
   /*AUTOWIRE*/
   /*AUTOREG*/
   
   assign 		ich_fb = ich_hit;
   
   
   
   
   reg [VAL:1] 		rDEC; 		
   always @(/*AUTOSENSE*/ich_adr)
     case (ich_adr[AEMB_IDX-1:2])
       4'h0: rDEC <= #1 16'h0001;
       4'h1: rDEC <= #1 16'h0002;
       4'h2: rDEC <= #1 16'h0004;
       4'h3: rDEC <= #1 16'h0008;
       4'h4: rDEC <= #1 16'h0010;
       4'h5: rDEC <= #1 16'h0020;
       4'h6: rDEC <= #1 16'h0040;
       4'h7: rDEC <= #1 16'h0080;
       4'h8: rDEC <= #1 16'h0100;
       4'h9: rDEC <= #1 16'h0200;
       4'hA: rDEC <= #1 16'h0400;
       4'hB: rDEC <= #1 16'h0800;
       4'hC: rDEC <= #1 16'h1000;
       4'hD: rDEC <= #1 16'h2000;
       4'hE: rDEC <= #1 16'h4000;
       4'hF: rDEC <= #1 16'h8000;      
     endcase 
   
   wire [VAL:1] 	wDEC = rDEC[VAL:1]; 

   
   wire [VAL:1] 	oVAL, iVAL;   
   wire [SIZ:1] 	aLNE = ich_adr[AEMB_ICH-1:2]; 
   wire [BLK:1] 	aTAG = ich_adr[AEMB_ICH-1:AEMB_IDX]; 
   wire [TAG:1] 	iTAG = ich_adr[AEMB_IWB-1:AEMB_ICH]; 
   wire [TAG:1] 	oTAG; 		

   
   wire 		hTAG = ((iTAG ^ oTAG) == {(TAG){1'b0}}); 
			
			
   wire 		hVAL = 
			((oVAL & wDEC) != {(VAL){1'b0}});
   
   assign 		ich_hit = hTAG & hVAL;
   assign 		iVAL = (hTAG) ? 
			       oVAL | wDEC : 
			       wDEC; 
   
   /* 
    aeMB2_tpsram AUTO_TEMPLATE (
    .AW(SIZ), 
    .DW(6'd32),
    
    .dat_o(),
    .dat_i(iwb_dat_i[31:0]),
    .adr_i(aLNE[SIZ:1]),
    .rst_i(),
    .ena_i(iwb_ack_i),
    .clk_i(gclk),
    .wre_i(iwb_ack_i),
    
    .xdat_o(ich_dat[31:0]),
    .xdat_i(),    
    .xadr_i(aLNE[SIZ:1]),
    .xrst_i(grst),
    .xena_i(iena),
    .xclk_i(gclk),
    .xwre_i(),            
    ) 
    
    aeMB2_sparam AUTO_TEMPLATE (
    .AW(BLK), 
    .DW(VAL+TAG),
    
    .dat_o({oVAL, oTAG}),
    .dat_i({iVAL, iTAG}),
    .adr_i(aTAG[BLK:1]),
    .ena_i(iwb_ack_i),
    .clk_i(gclk),
    .wre_i(iwb_ack_i),
    )    
    */

   
   aeMB2_sparam
     #(/*AUTOINSTPARAM*/
       
       .AW				(BLK),			 
       .DW				(VAL+TAG))		 
   tag0
     (/*AUTOINST*/
      
      .dat_o				({oVAL, oTAG}),		 
      
      .adr_i				(aTAG[BLK:1]),		 
      .dat_i				({iVAL, iTAG}),		 
      .wre_i				(iwb_ack_i),		 
      .clk_i				(gclk),			 
      .ena_i				(iwb_ack_i));		 

   
   
   
   aeMB2_tpsram
     #(/*AUTOINSTPARAM*/
       
       .AW				(SIZ),			 
       .DW				(6'd32))		 
   data0
     (/*AUTOINST*/
      
      .dat_o				(),			 
      .xdat_o				(ich_dat[31:0]),	 
      
      .adr_i				(aLNE[SIZ:1]),		 
      .dat_i				(iwb_dat_i[31:0]),	 
      .wre_i				(iwb_ack_i),		 
      .ena_i				(iwb_ack_i),		 
      .rst_i				(),			 
      .clk_i				(gclk),			 
      .xadr_i				(aLNE[SIZ:1]),		 
      .xdat_i				(),			 
      .xwre_i				(),			 
      .xena_i				(iena),			 
      .xrst_i				(grst),			 
      .xclk_i				(gclk));			 
   
endmodule 

/*
 $Log: not supported by cvs2svn $
 Revision 1.4  2008/04/26 17:57:43  sybreon
 Minor performance improvements.

 Revision 1.3  2008/04/26 01:09:06  sybreon
 Passes basic tests. Minor documentation changes to make it compatible with iverilog pre-processor.

 Revision 1.2  2008/04/20 16:34:32  sybreon
 Basic version with some features left out.

 Revision 1.1  2008/04/18 00:21:52  sybreon
 Initial import.
*/
/* $Id: aeMB2_intu.v,v 1.7 2008-05-01 12:00:18 sybreon Exp $
**
** AEMB2 EDK 6.2 COMPATIBLE CORE
** Copyright (C) 2004-2008 Shawn Tan <shawn.tan@aeste.net>
**  
** This file is part of AEMB.
**
** AEMB is free software: you can redistribute it and/or modify it
** under the terms of the GNU Lesser General Public License as
** published by the Free Software Foundation, either version 3 of the
** License, or (at your option) any later version.
**
** AEMB is distributed in the hope that it will be useful, but WITHOUT
** ANY WARRANTY; without even the implied warranty of MERCHANTABILITY
** or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU Lesser General
** Public License for more details.
**
** You should have received a copy of the GNU Lesser General Public
** License along with AEMB. If not, see <http:**www.gnu.org/licenses/>.
*/
/**
 * One Cycle Integer Unit
 * @file aeMB2_intu.v
 
 * This implements a single cycle integer unit. It performs all basic
   arithmetic, shift, and logic operations. 
 
 */

module aeMB2_intu (/*AUTOARG*/
   
   mem_ex, bpc_ex, alu_ex, alu_mx, msr_ex, sfr_mx,
   
   opc_of, opa_of, opb_of, opd_of, imm_of, rd_of, ra_of, gclk, grst,
   dena, gpha
   );
   parameter AEMB_DWB = 32;   
   parameter AEMB_IWB = 32;
   parameter AEMB_HTX = 1;
   
   output [31:2] mem_ex;
   output [31:2] bpc_ex;   

   output [31:0] alu_ex,
		 alu_mx;   
   
   
   input [5:0] 	 opc_of;
   input [31:0]  opa_of;
   input [31:0]  opb_of;
   input [31:0]  opd_of;   
   input [15:0]  imm_of;
   input [4:0] 	 rd_of,
		 ra_of;   
   output [7:0]  msr_ex;   
   output [31:0] sfr_mx;   
   
   
   input 	 gclk,
		 grst,
		 dena,
		 gpha;      

   /*AUTOREG*/
   
   reg [31:0]		alu_ex;
   reg [31:0]		alu_mx;
   reg [31:2]		bpc_ex;
   reg [31:2]		mem_ex;
   reg [31:0]		sfr_mx;
   

   localparam [2:0] 	MUX_SFR = 3'o7,
			MUX_BSF = 3'o6,
			MUX_MUL = 3'o5,
			MUX_MEM = 3'o4,
			
			MUX_RPC = 3'o2,
			MUX_ALU = 3'o1,
			MUX_NOP = 3'o0;   
      
   reg 			rMSR_C,
			rMSR_CC,
			rMSR_MTX,
			rMSR_DTE, 
			rMSR_ITE,
			rMSR_BIP, 
			rMSR_IE,
			rMSR_BE;   
      
   
   
   
   reg [31:0] 		add_ex;
   reg 			add_c;
   
   wire [31:0] 		wADD;
   wire 		wADC;

   wire 		fCCC = !opc_of[5] & opc_of[1]; 
   wire 		fSUB = !opc_of[5] & opc_of[0]; 
   wire 		fCMP = !opc_of[3] & imm_of[1]; 
   wire 		wCMP = (fCMP) ? !wADC : wADD[31]; 
   
   wire [31:0] 		wOPA = (fSUB) ? ~opa_of : opa_of;
   wire 		wOPC = (fCCC) ? rMSR_CC : fSUB;
   
   assign 		{wADC, wADD} = (opb_of + wOPA) + wOPC; 
   
   always @(/*AUTOSENSE*/wADC or wADD or wCMP) begin
      {add_c, add_ex} <= #1 {wADC, wCMP, wADD[30:0]}; 
   end
      
   
   reg [31:0] 		slm_ex;

   always @(/*AUTOSENSE*/imm_of or opa_of or opb_of or opc_of
	    or rMSR_CC)
     case (opc_of[2:0])
       
       3'o0: slm_ex <= #1 opa_of | opb_of;
       3'o1: slm_ex <= #1 opa_of & opb_of;
       3'o2: slm_ex <= #1 opa_of ^ opb_of;
       3'o3: slm_ex <= #1 opa_of & ~opb_of;
       
       3'o4: case ({imm_of[6:5],imm_of[0]})
	       3'o1: slm_ex <= #1 {opa_of[31],opa_of[31:1]}; 
	       3'o3: slm_ex <= #1 {rMSR_CC,opa_of[31:1]}; 
	       3'o5: slm_ex <= #1 {1'b0,opa_of[31:1]}; 
	       3'o6: slm_ex <= #1 {{(24){opa_of[7]}}, opa_of[7:0]}; 
	       3'o7: slm_ex <= #1  {{(16){opa_of[15]}}, opa_of[15:0]}; 
	       default: slm_ex <= #1 32'hX;
	     endcase 
       
       
       
       
       default: slm_ex <= #1 32'hX;       
     endcase 
   
   
   always @(posedge gclk)
     if (grst) begin
	/*AUTORESET*/
	
	alu_ex <= 32'h0;
	alu_mx <= 32'h0;
	bpc_ex <= 30'h0;
	mem_ex <= 30'h0;
	
     end else if (dena) begin
	alu_mx <= #1 alu_ex;
	alu_ex <= #1 (opc_of[5]) ? slm_ex : add_ex;	
	mem_ex <= #1 wADD[AEMB_DWB-1:2]; 
	bpc_ex <= #1 
		  (!opc_of[0] & ra_of[3]) ? 
		  opb_of[AEMB_IWB-1:2] : 
		  wADD[AEMB_IWB-1:2]; 
     end

   

   /*
    MSR REGISTER
    
    We should keep common configuration bits in the lower 16-bits of
    the MSR in order to avoid using the IMMI instruction.
    
    MSR bits
    31 - CC (carry copy)    
    30 - HTE (hardware thread enabled)
    29 - PHA (current phase)
    
    7  - DTE (data cache enable)       
    5  - ITE (instruction cache enable)    
    4  - MTX (hardware mutex bit)
    3  - BIP (break in progress)
    2  - C (carry flag)
    1  - IE (interrupt enable)
    0  - BE (bus-lock enable)        
    */

   assign msr_ex = {
		    rMSR_DTE,
		    1'b0,
		    rMSR_ITE,
		    rMSR_MTX,
		    rMSR_BIP,
		    rMSR_C,
		    rMSR_IE,
		    rMSR_BE 
		    };
      
   
   wire [7:0] wRES = (ra_of[0]) ? 
	      (msr_ex[7:0]) & ~imm_of[7:0] : 
	      (msr_ex[7:0]) | imm_of[7:0]; 
   
   
   
   
   
   wire       fRTID = (opc_of == 6'o55) & rd_of[0];
   wire       fRTBD = (opc_of == 6'o55) & rd_of[1];
   
   wire       fBRKI = (opc_of == 6'o56) & (ra_of[4:0] == 5'hD);
   wire       fBRKB = ((opc_of == 6'o46) | (opc_of == 6'o56)) & (ra_of[4:0] == 5'hC);
   
   wire       fMOV = (opc_of == 6'o45);
   wire       fMTS = fMOV & &imm_of[15:14];
   wire       fMOP = fMOV & ~|imm_of[15:14];   
   
   reg [31:0] sfr_ex;
   
   always @(posedge gclk)
     if (grst) begin
	/*AUTORESET*/
	
	rMSR_BE <= 1'h0;
	rMSR_BIP <= 1'h0;
	rMSR_DTE <= 1'h0;
	rMSR_IE <= 1'h0;
	rMSR_ITE <= 1'h0;
	rMSR_MTX <= 1'h0;
	sfr_ex <= 32'h0;
	sfr_mx <= 32'h0;
	
     end else if (dena) begin 
	sfr_mx <= #1 sfr_ex;	
	sfr_ex <= #1
		  {rMSR_CC,
		   AEMB_HTX[0],
		   gpha,
		   21'd0,
		   rMSR_DTE,
		   1'b0,
		   rMSR_ITE,
		   rMSR_MTX,
		   rMSR_BIP,
		   rMSR_CC,
		   rMSR_IE,
		   rMSR_BE 
		   };
	
	rMSR_DTE <= #1
		   (fMTS) ? opa_of[7] :
		   (fMOP) ? wRES[7] :
		   rMSR_DTE;	

	rMSR_ITE <= #1
		   (fMTS) ? opa_of[5] :
		   (fMOP) ? wRES[5] :
		   rMSR_ITE;
	
	rMSR_MTX <= #1
		   (fMTS) ? opa_of[4] :
		   (fMOP) ? wRES[4] :
		   rMSR_MTX;	
	
	rMSR_BE <= #1
		   (fMTS) ? opa_of[0] :
		   (fMOP) ? wRES[0] :
		   rMSR_BE;	
	
	rMSR_IE <= #1
		   (fBRKI) ? 1'b0 :
		   (fRTID) ? 1'b1 :
		   (fMTS) ? opa_of[1] :
		   (fMOP) ? wRES[1] :
		   rMSR_IE;			

	rMSR_BIP <= #1
		    (fBRKB) ? 1'b1 :
		    (fRTBD) ? 1'b0 :
		    (fMTS) ? opa_of[3] :
		    (fMOP) ? wRES[3] :
		    rMSR_BIP;
	/*
	
	case ({fMTS, fMOP})
	  2'o2: {rMSR_DTE,
		 rMSR_ITE,
		 rMSR_MTX,
		 rMSR_BE} <= #1 {opa_of[7],
				 opa_of[5],
				 opa_of[4],
				 opa_of[0]};	  
	  2'o1: {rMSR_DTE,
		 rMSR_ITE,
		 rMSR_MTX,
		 rMSR_BE} <= #1 {wRES[7],
				 wRES[5],
				 wRES[4],
				 wRES[0]};	  
	  default: {rMSR_DTE,
		    rMSR_ITE,
		    rMSR_MTX,
		    rMSR_BE} <= #1 {rMSR_DTE,
				    rMSR_ITE,
				    rMSR_MTX,
				    rMSR_BE};	  
	endcase 

	case ({fMTS, fMOP})
	  2'o2: {rMSR_BIP,
		 rMSR_IE} <= #1 {opa_of[3],
				 opa_of[1]};
	  2'o1: {rMSR_BIP,
		 rMSR_IE} <= #1 {wRES[3],
				 wRES[1]};
	  default: begin
	     rMSR_BIP <= #1 (fBRKB | fRTBD) ? !rMSR_BIP : rMSR_BIP;	     
	     rMSR_IE <= #1 (fBRKI | fRTID) ? !rMSR_IE : rMSR_IE;
	  end
	endcase 
	 */
     end 

   
   wire fADDSUB = !opc_of[5] & !opc_of[4] & !opc_of[2];
   
   wire fSHIFT  = (opc_of == 6'o44) & &imm_of[6:5];   

   always @(posedge gclk)
     if (grst) begin
	/*AUTORESET*/
     end else if (dena) begin
     end
   
   always @(posedge gclk)
     if (grst) begin
	/*AUTORESET*/
	
	rMSR_C <= 1'h0;
	rMSR_CC <= 1'h0;
	
     end else if (dena) begin
	rMSR_CC <= #1 rMSR_C;
	
	rMSR_C <= #1
		  (fMTS) ? opa_of[2] :
		  (fMOP) ? wRES[2] :
		  (fSHIFT) ? opa_of[0] : 
		  (fADDSUB) ? add_c : 
		  rMSR_CC;
	 
	/*
	case ({fMTS,fMOP,fSHIFT,fADDSUB})
	  4'h8: rMSR_C <= #1 opa_of[2];
	  4'h4: rMSR_C <= #1 wRES[2];
	  4'h2: rMSR_C <= #1 opa_of[0];
	  4'h1: rMSR_C <= #1 add_c;	  
	  default: rMSR_C <= #1 rMSR_CC;	  
	endcase 
	*/
     end
   
endmodule 

/*
 $Log: not supported by cvs2svn $
 Revision 1.6  2008/04/28 08:15:25  sybreon
 Optimisations.

 Revision 1.5  2008/04/26 17:57:43  sybreon
 Minor performance improvements.

 Revision 1.4  2008/04/26 01:09:06  sybreon
 Passes basic tests. Minor documentation changes to make it compatible with iverilog pre-processor.

 Revision 1.3  2008/04/23 14:18:30  sybreon
 Fixed CMP bug.

 Revision 1.2  2008/04/21 12:11:38  sybreon
 Passes arithmetic tests with single thread.

 Revision 1.1  2008/04/18 00:21:52  sybreon
 Initial import.
*/

/* $Id: aeMB2_iwbif.v,v 1.5 2008-04-27 19:52:31 sybreon Exp $
**
** AEMB2 EDK 6.2 COMPATIBLE CORE
** Copyright (C) 2004-2008 Shawn Tan <shawn.tan@aeste.net>
**  
** This file is part of AEMB.
**
** AEMB is free software: you can redistribute it and/or modify it
** under the terms of the GNU Lesser General Public License as
** published by the Free Software Foundation, either version 3 of the
** License, or (at your option) any later version.
**
** AEMB is distributed in the hope that it will be useful, but WITHOUT
** ANY WARRANTY; without even the implied warranty of MERCHANTABILITY
** or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU Lesser General
** Public License for more details.
**
** You should have received a copy of the GNU Lesser General Public
** License along with AEMB. If not, see <http:**www.gnu.org/licenses/>.
*/
/**
 * Instruction Wishbone Interface
 * @file aeMB2_iwbif.v
 
  * This handles the instruction fetch portion of the pipeline. It
    alternates the PC and performs bubble/branch insertion. Bus
    transactions are independent of the pipeline.
 
 */

module aeMB2_iwbif (/*AUTOARG*/
   
   iwb_adr_o, iwb_stb_o, iwb_sel_o, iwb_wre_o, iwb_cyc_o, iwb_tag_o,
   ich_adr, fet_fb, rpc_if, rpc_mx,
   
   iwb_ack_i, iwb_dat_i, ich_hit, msr_ex, hzd_bpc, hzd_fwd, bra_ex,
   bpc_ex, gclk, grst, dena, iena, gpha
   );
   parameter AEMB_IWB = 32;
   parameter AEMB_HTX = 1;
   
   
   output [AEMB_IWB-1:2] iwb_adr_o;
   output 		 iwb_stb_o;
   output [3:0] 	 iwb_sel_o;
   output 		 iwb_wre_o;
   output 		 iwb_cyc_o;
   output 		 iwb_tag_o;   
   input 		 iwb_ack_i;
   input [31:0] 	 iwb_dat_i;
   
   
   output [AEMB_IWB-1:2] ich_adr;
   input 		 ich_hit;
   
   
   output 		 fet_fb;   
   
   output [31:2] 	 rpc_if,
			 rpc_mx;

   input [7:5] 		 msr_ex;   
   input 		 hzd_bpc,
			 hzd_fwd;
   
   input [1:0] 		 bra_ex;   
   input [31:2] 	 bpc_ex;
   
   
   input 		 gclk,
			 grst,
			 dena,
			 iena,
			 gpha;      

   /*AUTOWIRE*/   
   /*AUTOREG*/
   
   reg			iwb_stb_o;
   reg [31:2]		rpc_if;
   reg [31:2]		rpc_mx;
   
   reg [31:2] 		rpc_of, 
			rpc_ex;

   
   reg [31:2] 		rADR, rADR_;
   wire [31:2] 		wPCINC = (rADR + 1); 
   wire [31:2] 		wPCNXT = rADR_;
   
   always @(posedge gclk)
     if (grst) begin
	/*AUTORESET*/
	
	rADR <= 30'h0;
	rADR_ <= 30'h0;
	
     end else if (iena) begin
	
	case ({hzd_fwd,bra_ex[1]})
	  2'o0: {rADR} <= #1 {rADR_[AEMB_IWB-1:2]}; 
	  2'o1: {rADR} <= #1 {bpc_ex[AEMB_IWB-1:2]}; 
	  2'o2: {rADR} <= #1 {rpc_if[AEMB_IWB-1:2]}; 
	  default: {rADR} <= #1 32'hX;	  
	  
	  
	endcase 

	rADR_ <= #1 wPCINC;	
	
     end 

   assign 		ich_adr = rADR;
   
   always @(posedge gclk)
     if (grst) begin
	/*AUTORESET*/
	
	rpc_ex <= 30'h0;
	rpc_if <= 30'h0;
	rpc_mx <= 30'h0;
	rpc_of <= 30'h0;
	
     end else begin
	if (dena) begin
	   {rpc_mx, 
	    rpc_ex, 
	    rpc_of} <= #1 {rpc_ex, 
			   rpc_of, 
			   rpc_if};		    
	end
	if (iena) begin
	   rpc_if <= #1 rADR;	   
	end
     end 
   
   
   always @(posedge gclk)
     if (grst) begin
	/*AUTORESET*/
	
	iwb_stb_o <= 1'h0;
	
     end else begin
	iwb_stb_o <= #1 (iwb_stb_o & !iwb_ack_i) | (!iwb_stb_o & !ich_hit);
     end

   assign 		iwb_adr_o = rADR;
   assign 		iwb_wre_o = 1'b0;
   assign 		iwb_sel_o = 4'hF;   
   assign 		iwb_cyc_o = iwb_stb_o;
   assign 		iwb_tag_o = msr_ex[5];   
   
   assign 		fet_fb = iwb_stb_o ~^ iwb_ack_i; 
   
endmodule 

/*
 $Log: not supported by cvs2svn $
 Revision 1.4  2008/04/26 01:09:06  sybreon
 Passes basic tests. Minor documentation changes to make it compatible with iverilog pre-processor.

 Revision 1.3  2008/04/21 12:11:38  sybreon
 Passes arithmetic tests with single thread.

 Revision 1.2  2008/04/20 16:34:32  sybreon
 Basic version with some features left out.

 Revision 1.1  2008/04/18 00:21:52  sybreon
 Initial import.
*/
/* $Id: aeMB2_memif.v,v 1.3 2008-04-26 17:57:43 sybreon Exp $
**
** AEMB2 EDK 6.2 COMPATIBLE CORE
** Copyright (C) 2004-2008 Shawn Tan <shawn.tan@aeste.net>
**  
** This file is part of AEMB.
**
** AEMB is free software: you can redistribute it and/or modify it
** under the terms of the GNU Lesser General Public License as
** published by the Free Software Foundation, either version 3 of the
** License, or (at your option) any later version.
**
** AEMB is distributed in the hope that it will be useful, but WITHOUT
** ANY WARRANTY; without even the implied warranty of MERCHANTABILITY
** or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU Lesser General
** Public License for more details.
**
** You should have received a copy of the GNU Lesser General Public
** License along with AEMB. If not, see <http:**www.gnu.org/licenses/>.
*/
/**
 * Memory Interface Wrapper
 * @file aeMB2_memif.v

 * A wrapper for the data/xsel bus interfaces.
 
 */


module aeMB2_memif (/*AUTOARG*/
   
   xwb_wre_o, xwb_tag_o, xwb_stb_o, xwb_sel_o, xwb_mx, xwb_fb,
   xwb_dat_o, xwb_cyc_o, xwb_adr_o, sel_mx, dwb_wre_o, dwb_tag_o,
   dwb_stb_o, dwb_sel_o, dwb_mx, dwb_fb, dwb_dat_o, dwb_cyc_o,
   dwb_adr_o,
   
   xwb_dat_i, xwb_ack_i, sfr_mx, opd_of, opc_of, opb_of, opa_of,
   msr_ex, mem_ex, imm_of, grst, gpha, gclk, dwb_dat_i, dwb_ack_i,
   dena
   );   
   parameter AEMB_DWB = 32;
   parameter AEMB_XWB = 3;
   parameter AEMB_XSL = 1;
   
   /*AUTOOUTPUT*/
   
   output [AEMB_DWB-1:2] dwb_adr_o;		
   output		dwb_cyc_o;		
   output [31:0]	dwb_dat_o;		
   output		dwb_fb;			
   output [31:0]	dwb_mx;			
   output [3:0]		dwb_sel_o;		
   output		dwb_stb_o;		
   output		dwb_tag_o;		
   output		dwb_wre_o;		
   output [3:0]		sel_mx;			
   output [AEMB_XWB-1:2] xwb_adr_o;		
   output		xwb_cyc_o;		
   output [31:0]	xwb_dat_o;		
   output		xwb_fb;			
   output [31:0]	xwb_mx;			
   output [3:0]		xwb_sel_o;		
   output		xwb_stb_o;		
   output		xwb_tag_o;		
   output		xwb_wre_o;		
   
   /*AUTOINPUT*/
   
   input		dena;			
   input		dwb_ack_i;		
   input [31:0]		dwb_dat_i;		
   input		gclk;			
   input		gpha;			
   input		grst;			
   input [15:0]		imm_of;			
   input [AEMB_DWB-1:2]	mem_ex;			
   input [7:0]		msr_ex;			
   input [31:0]		opa_of;			
   input [1:0]		opb_of;			
   input [5:0]		opc_of;			
   input [31:0]		opd_of;			
   input [7:5]		sfr_mx;			
   input		xwb_ack_i;		
   input [31:0]		xwb_dat_i;		
   
   /*AUTOWIRE*/
   
   aeMB2_xslif
     #(/*AUTOINSTPARAM*/
       
       .AEMB_XSL			(AEMB_XSL),
       .AEMB_XWB			(AEMB_XWB))
   xslif0
     (/*AUTOINST*/
      
      .xwb_adr_o			(xwb_adr_o[AEMB_XWB-1:2]),
      .xwb_dat_o			(xwb_dat_o[31:0]),
      .xwb_sel_o			(xwb_sel_o[3:0]),
      .xwb_tag_o			(xwb_tag_o),
      .xwb_stb_o			(xwb_stb_o),
      .xwb_cyc_o			(xwb_cyc_o),
      .xwb_wre_o			(xwb_wre_o),
      .xwb_fb				(xwb_fb),
      .xwb_mx				(xwb_mx[31:0]),
      
      .xwb_dat_i			(xwb_dat_i[31:0]),
      .xwb_ack_i			(xwb_ack_i),
      .imm_of				(imm_of[15:0]),
      .opc_of				(opc_of[5:0]),
      .opa_of				(opa_of[31:0]),
      .gclk				(gclk),
      .grst				(grst),
      .dena				(dena),
      .gpha				(gpha));   
   
   aeMB2_dwbif
     #(/*AUTOINSTPARAM*/
       
       .AEMB_DWB			(AEMB_DWB))
   dwbif0
     (/*AUTOINST*/
      
      .dwb_adr_o			(dwb_adr_o[AEMB_DWB-1:2]),
      .dwb_sel_o			(dwb_sel_o[3:0]),
      .dwb_stb_o			(dwb_stb_o),
      .dwb_cyc_o			(dwb_cyc_o),
      .dwb_tag_o			(dwb_tag_o),
      .dwb_wre_o			(dwb_wre_o),
      .dwb_dat_o			(dwb_dat_o[31:0]),
      .dwb_fb				(dwb_fb),
      .sel_mx				(sel_mx[3:0]),
      .dwb_mx				(dwb_mx[31:0]),
      
      .dwb_dat_i			(dwb_dat_i[31:0]),
      .dwb_ack_i			(dwb_ack_i),
      .imm_of				(imm_of[15:0]),
      .opd_of				(opd_of[31:0]),
      .opc_of				(opc_of[5:0]),
      .opa_of				(opa_of[1:0]),
      .opb_of				(opb_of[1:0]),
      .msr_ex				(msr_ex[7:0]),
      .mem_ex				(mem_ex[AEMB_DWB-1:2]),
      .sfr_mx				(sfr_mx[7:5]),
      .gclk				(gclk),
      .grst				(grst),
      .dena				(dena),
      .gpha				(gpha));
      
   
endmodule 

/*
 $Log: not supported by cvs2svn $
 Revision 1.2  2008/04/26 01:09:06  sybreon
 Passes basic tests. Minor documentation changes to make it compatible with iverilog pre-processor.

 Revision 1.1  2008/04/18 00:21:52  sybreon
 Initial import.
*/
/* $Id: aeMB2_mult.v,v 1.5 2008-04-28 08:15:25 sybreon Exp $
**
** AEMB2 EDK 6.2 COMPATIBLE CORE
** Copyright (C) 2004-2008 Shawn Tan <shawn.tan@aeste.net>
**  
** This file is part of AEMB.
**
** AEMB is free software: you can redistribute it and/or modify it
** under the terms of the GNU Lesser General Public License as
** published by the Free Software Foundation, either version 3 of the
** License, or (at your option) any later version.
**
** AEMB is distributed in the hope that it will be useful, but WITHOUT
** ANY WARRANTY; without even the implied warranty of MERCHANTABILITY
** or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU Lesser General
** Public License for more details.
**
** You should have received a copy of the GNU Lesser General Public
** License along with AEMB. If not, see <http:**www.gnu.org/licenses/>.
*/
/**
 * Two Cycle Multiplier Unit
 * @file aeMB2_mult.v
 
 * This implements a 2 cycle multipler to increase clock speed. The
   multiplier architecture is left to the synthesis tool. Modify this
   to instantiate specific multipliers.
 
 */


module aeMB2_mult (/*AUTOARG*/
   
   mul_mx,
   
   opa_of, opb_of, opc_of, gclk, grst, dena, gpha
   );      
   parameter AEMB_MUL = 1; 
   
   output [31:0] mul_mx;   
   
   input [31:0]  opa_of;
   input [31:0]  opb_of;
   input [5:0] 	 opc_of;   

   
   input 	 gclk,
		 grst,
		 dena,
		 gpha;      

   /*AUTOREG*/

   reg [31:0] 	 rOPA, rOPB;   
   reg [31:0] 	 rMUL0, 
		 rMUL1;

   always @(posedge gclk)
     if (grst) begin
	/*AUTORESET*/
	
	rMUL0 <= 32'h0;
	rMUL1 <= 32'h0;
	rOPA <= 32'h0;
	rOPB <= 32'h0;
	
     end else if (dena) begin
	
	rMUL1 <= #1 rMUL0; 
	rMUL0 <= #1 (opa_of * opb_of);
	rOPA <= #1 opa_of;
	rOPB <= #1 opb_of;	
     end

   assign 	 mul_mx = (AEMB_MUL[0]) ? rMUL1 : 32'hX;
      
endmodule 

/*
 $Log: not supported by cvs2svn $
 Revision 1.4  2008/04/26 17:57:43  sybreon
 Minor performance improvements.

 Revision 1.3  2008/04/26 01:09:06  sybreon
 Passes basic tests. Minor documentation changes to make it compatible with iverilog pre-processor.

 Revision 1.2  2008/04/20 16:34:32  sybreon
 Basic version with some features left out.

 Revision 1.1  2008/04/18 00:21:52  sybreon
 Initial import.
*/
/* $Id: aeMB2_pipe.v,v 1.4 2008-05-01 08:32:58 sybreon Exp $
**
** AEMB2 EDK 6.2 COMPATIBLE CORE
** Copyright (C) 2004-2008 Shawn Tan <shawn.tan@aeste.net>
**  
** This file is part of AEMB.
**
** AEMB is free software: you can redistribute it and/or modify it
** under the terms of the GNU Lesser General Public License as
** published by the Free Software Foundation, either version 3 of the
** License, or (at your option) any later version.
**
** AEMB is distributed in the hope that it will be useful, but WITHOUT
** ANY WARRANTY; without even the implied warranty of MERCHANTABILITY
** or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU Lesser General
** Public License for more details.
**
** You should have received a copy of the GNU Lesser General Public
** License along with AEMB. If not, see <http:**www.gnu.org/licenses/>.
*/
/**
 * System signal controller
 * @file aeMB2_pipe.v

 * Generates clock, reset, and enable signals. Hardware clock/reset
   managers can be instantiated here.
 
 */

module aeMB2_pipe (/*AUTOARG*/
   
   brk_if, gpha, gclk, grst, dena, iena,
   
   bra_ex, dwb_fb, xwb_fb, ich_fb, fet_fb, msr_ex, sys_clk_i,
   sys_int_i, sys_rst_i, sys_ena_i
   );
   parameter AEMB_HTX = 1;   

   output [1:0] brk_if; 
   input [1:0] 	bra_ex;
   input 	dwb_fb;
   input 	xwb_fb;   
   input 	ich_fb;
   input 	fet_fb;
   input [3:0] 	msr_ex;   
   
   output 	gpha,
		gclk,
		grst,
		dena,
		iena;   
   
   input 	sys_clk_i,
		sys_int_i,
		sys_rst_i,
		sys_ena_i;
   
   /*AUTOREG*/
   
   reg [1:0]		brk_if;
   reg			gpha;
   
   reg [1:0] 		rst;   
   reg 			por;
   reg 			fet;
   reg 			hit;   
   
   
   assign 		gclk = sys_clk_i;
   assign 		grst = !rst[1];

   
   assign 		iena = ich_fb &
			       xwb_fb & 
			       dwb_fb & 
			       sys_ena_i;
   
   assign 		dena = iena;

   
   reg 			int_lat; 
   
   always @(posedge sys_clk_i)
     if (sys_rst_i) begin
	/*AUTORESET*/
	
	int_lat <= 1'h0;
	
     end else begin	
	int_lat <= #1 msr_ex[1] & (int_lat | sys_int_i);	
     end

   always @(posedge gclk)
     if (grst) begin
	/*AUTORESET*/
	
	brk_if <= 2'h0;
	
     end else if (dena) begin	
	brk_if[0] <= #1 !msr_ex[3] & int_lat; 
     end
   
   
   always @(posedge sys_clk_i)
     if (sys_rst_i) begin
	/*AUTORESET*/
	
	rst <= 2'h0;
	
     end else begin
	rst <= #1 {rst[0], !sys_rst_i};
     end

   
   always @(posedge sys_clk_i)
     if (sys_rst_i) begin
	/*AUTORESET*/
	
	gpha <= 1'h0;
	
     end else if (dena | grst) begin
	gpha <= #1 !gpha;
     end
   
endmodule 

/*
 $Log: not supported by cvs2svn $
 Revision 1.3  2008/04/26 01:09:06  sybreon
 Passes basic tests. Minor documentation changes to make it compatible with iverilog pre-processor.

 Revision 1.2  2008/04/20 16:34:32  sybreon
 Basic version with some features left out.

 Revision 1.1  2008/04/18 00:21:52  sybreon
 Initial import.
*/
/* $Id: aeMB2_regs.v,v 1.4 2008-04-26 17:57:43 sybreon Exp $
**
** AEMB2 EDK 6.2 COMPATIBLE CORE
** Copyright (C) 2004-2008 Shawn Tan <shawn.tan@aeste.net>
**  
** This file is part of AEMB.
**
** AEMB is free software: you can redistribute it and/or modify it
** under the terms of the GNU Lesser General Public License as
** published by the Free Software Foundation, either version 3 of the
** License, or (at your option) any later version.
**
** AEMB is distributed in the hope that it will be useful, but WITHOUT
** ANY WARRANTY; without even the implied warranty of MERCHANTABILITY
** or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU Lesser General
** Public License for more details.
**
** You should have received a copy of the GNU Lesser General Public
** License along with AEMB. If not, see <http:**www.gnu.org/licenses/>.
*/
/**
 * Register File Wrapper
 * @file aeMB2_regs.v

 * A collection of general purpose and special function registers.
 
 */


module aeMB2_regs (/*AUTOARG*/
   
   opd_if, opb_if, opa_if,
   
   xwb_mx, sfr_mx, sel_mx, rpc_mx, rd_of, rd_ex, mux_of, mux_ex,
   mul_mx, ich_dat, grst, gpha, gclk, dwb_mx, dena, bsf_mx, alu_mx
   );

   parameter AEMB_HTX = 1;

   /*AUTOOUTPUT*/
   
   output [31:0]	opa_if;			
   output [31:0]	opb_if;			
   output [31:0]	opd_if;			
   
   /*AUTOINPUT*/
   
   input [31:0]		alu_mx;			
   input [31:0]		bsf_mx;			
   input		dena;			
   input [31:0]		dwb_mx;			
   input		gclk;			
   input		gpha;			
   input		grst;			
   input [31:0]		ich_dat;		
   input [31:0]		mul_mx;			
   input [2:0]		mux_ex;			
   input [2:0]		mux_of;			
   input [4:0]		rd_ex;			
   input [4:0]		rd_of;			
   input [31:2]		rpc_mx;			
   input [3:0]		sel_mx;			
   input [31:0]		sfr_mx;			
   input [31:0]		xwb_mx;			
   
   /*AUTOWIRE*/

   
      
   aeMB2_gprf
     #(/*AUTOINSTPARAM*/
       
       .AEMB_HTX			(AEMB_HTX))
   gprf0
     (/*AUTOINST*/
      
      .opa_if				(opa_if[31:0]),
      .opb_if				(opb_if[31:0]),
      .opd_if				(opd_if[31:0]),
      
      .mux_of				(mux_of[2:0]),
      .mux_ex				(mux_ex[2:0]),
      .ich_dat				(ich_dat[31:0]),
      .rd_of				(rd_of[4:0]),
      .rd_ex				(rd_ex[4:0]),
      .sel_mx				(sel_mx[3:0]),
      .rpc_mx				(rpc_mx[31:2]),
      .xwb_mx				(xwb_mx[31:0]),
      .dwb_mx				(dwb_mx[31:0]),
      .alu_mx				(alu_mx[31:0]),
      .sfr_mx				(sfr_mx[31:0]),
      .mul_mx				(mul_mx[31:0]),
      .bsf_mx				(bsf_mx[31:0]),
      .gclk				(gclk),
      .grst				(grst),
      .dena				(dena),
      .gpha				(gpha));

endmodule 

/*
 $Log: not supported by cvs2svn $
 Revision 1.3  2008/04/26 01:09:06  sybreon
 Passes basic tests. Minor documentation changes to make it compatible with iverilog pre-processor.

 Revision 1.2  2008/04/21 12:11:38  sybreon
 Passes arithmetic tests with single thread.

 Revision 1.1  2008/04/18 00:21:52  sybreon
 Initial import.
*/
/* $Id: aeMB2_sim.v,v 1.2 2007-12-29 00:31:48 sybreon Exp $
**
** AEMB2 SIMULATION WRAPPER
** Copyright (C) 2004-2007 Shawn Tan Ser Ngiap <shawn.tan@aeste.net>
**  
** This file is part of AEMB.
**
** AEMB is free software: you can redistribute it and/or modify it
** under the terms of the GNU Lesser General Public License as
** published by the Free Software Foundation, either version 3 of the
** License, or (at your option) any later version.
**
** AEMB is distributed in the hope that it will be useful, but WITHOUT
** ANY WARRANTY; without even the implied warranty of MERCHANTABILITY
** or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU Lesser General
** Public License for more details.
**
** You should have received a copy of the GNU Lesser General Public
** License along with AEMB. If not, see <http:**www.gnu.org/licenses/>.
*/

module aeMB2_sim (/*AUTOARG*/
   
   iwb_wre_o, iwb_tga_o, iwb_stb_o, iwb_adr_o, dwb_wre_o, dwb_tga_o,
   dwb_stb_o, dwb_sel_o, dwb_dat_o, dwb_cyc_o, dwb_adr_o, cwb_wre_o,
   cwb_tga_o, cwb_stb_o, cwb_sel_o, cwb_dat_o, cwb_adr_o,
   
   sys_rst_i, sys_int_i, sys_clk_i, iwb_dat_i, iwb_ack_i, dwb_dat_i,
   dwb_ack_i, cwb_dat_i, cwb_ack_i
   );

   parameter IWB=16;
   parameter DWB=16;

   parameter TXE = 1; 
   
   parameter MUL = 1; 
   parameter BSF = 1; 
   parameter FSL = 1; 
   parameter DIV = 0; 
   
   /*AUTOOUTPUT*/
   
   output [6:2]		cwb_adr_o;		
   output [31:0]	cwb_dat_o;		
   output [3:0]		cwb_sel_o;		
   output		cwb_stb_o;		
   output [1:0]		cwb_tga_o;		
   output		cwb_wre_o;		
   output [DWB-1:2]	dwb_adr_o;		
   output		dwb_cyc_o;		
   output [31:0]	dwb_dat_o;		
   output [3:0]		dwb_sel_o;		
   output		dwb_stb_o;		
   output		dwb_tga_o;		
   output		dwb_wre_o;		
   output [IWB-1:2]	iwb_adr_o;		
   output		iwb_stb_o;		
   output		iwb_tga_o;		
   output		iwb_wre_o;		
   
   /*AUTOINPUT*/
   
   input		cwb_ack_i;		
   input [31:0]		cwb_dat_i;		
   input		dwb_ack_i;		
   input [31:0]		dwb_dat_i;		
   input		iwb_ack_i;		
   input [31:0]		iwb_dat_i;		
   input		sys_clk_i;		
   input		sys_int_i;		
   input		sys_rst_i;		
   
   /*AUTOWIRE*/
   
   aeMB2_edk32
     #(/*AUTOINSTPARAM*/
       
       .IWB				(IWB),
       .DWB				(DWB),
       .TXE				(TXE),
       .MUL				(MUL),
       .BSF				(BSF),
       .FSL				(FSL))
   sim
     (/*AUTOINST*/
      
      .cwb_adr_o			(cwb_adr_o[6:2]),
      .cwb_dat_o			(cwb_dat_o[31:0]),
      .cwb_sel_o			(cwb_sel_o[3:0]),
      .cwb_stb_o			(cwb_stb_o),
      .cwb_tga_o			(cwb_tga_o[1:0]),
      .cwb_wre_o			(cwb_wre_o),
      .dwb_adr_o			(dwb_adr_o[DWB-1:2]),
      .dwb_cyc_o			(dwb_cyc_o),
      .dwb_dat_o			(dwb_dat_o[31:0]),
      .dwb_sel_o			(dwb_sel_o[3:0]),
      .dwb_stb_o			(dwb_stb_o),
      .dwb_tga_o			(dwb_tga_o),
      .dwb_wre_o			(dwb_wre_o),
      .iwb_adr_o			(iwb_adr_o[IWB-1:2]),
      .iwb_stb_o			(iwb_stb_o),
      .iwb_tga_o			(iwb_tga_o),
      .iwb_wre_o			(iwb_wre_o),
      
      .cwb_ack_i			(cwb_ack_i),
      .cwb_dat_i			(cwb_dat_i[31:0]),
      .dwb_ack_i			(dwb_ack_i),
      .dwb_dat_i			(dwb_dat_i[31:0]),
      .iwb_ack_i			(iwb_ack_i),
      .iwb_dat_i			(iwb_dat_i[31:0]),
      .sys_clk_i			(sys_clk_i),
      .sys_int_i			(sys_int_i),
      .sys_rst_i			(sys_rst_i));

   
   
   wire [31:0] 		iwb_adr = {iwb_adr_o, 2'd0};
   wire [31:0] 		dwb_adr = {dwb_adr_o, 2'd0};
   wire [31:0] 		wMSR = sim.aslu.wMSR[31:0];   
   
   always @(posedge sim.clk_i) if (sim.ena_i) begin   

      $write ("\n", ($stime/10));
      $writeh (" T", sim.pha_i);
      $writeh(" PC=", iwb_adr);
      
      $writeh ("\t| ");
      
      case (sim.rOPC_IF)
	6'o00: if (sim.rRD_IF == 0) $write("   "); else $write("ADD");
	6'o01: $write("SUB");	
	6'o02: $write("ADDC");	
	6'o03: $write("SUBC");	
	6'o04: $write("ADDK");	
	6'o05: case (sim.rIMM_IF[1:0])
		 2'o0: $write("SUBK");	
		 2'o1: $write("CMP");	
		 2'o3: $write("CMPU");	
		 default: $write("XXX");
	       endcase 
	6'o06: $write("ADDKC");	
	6'o07: $write("SUBKC");	
	
	6'o10: $write("ADDI");	
	6'o11: $write("SUBI");	
	6'o12: $write("ADDIC");	
	6'o13: $write("SUBIC");	
	6'o14: $write("ADDIK");	
	6'o15: $write("SUBIK");	
	6'o16: $write("ADDIKC");	
	6'o17: $write("SUBIKC");	

	6'o20: $write("MUL");	
	6'o21: case (sim.rALT_IF[10:9])
		 2'o0: $write("BSRL");		 
		 2'o1: $write("BSRA");		 
		 2'o2: $write("BSLL");		 
		 default: $write("XXX");		 
	       endcase 
	6'o22: $write("IDIV");	

	6'o30: $write("MULI");	
	6'o31: case (sim.rALT_IF[10:9])
		 2'o0: $write("BSRLI");		 
		 2'o1: $write("BSRAI");		 
		 2'o2: $write("BSLLI");		 
		 default: $write("XXX");		 
	       endcase 
	6'o33: case (sim.rRB_IF[4:2])
		 3'o0: $write("GET");
		 3'o4: $write("PUT");		 
		 3'o2: $write("NGET");
		 3'o6: $write("NPUT");		 
		 3'o1: $write("CGET");
		 3'o5: $write("CPUT");		 
		 3'o3: $write("NCGET");
		 3'o7: $write("NCPUT");		 
	       endcase 

	6'o40: $write("OR");
	6'o41: $write("AND");	
	6'o42: if (sim.rRD_IF == 0) $write("   "); else $write("XOR");
	6'o43: $write("ANDN");	
	6'o44: case (sim.rIMM_IF[6:5])
		 2'o0: $write("SRA");
		 2'o1: $write("SRC");
		 2'o2: $write("SRL");
		 2'o3: if (sim.rIMM_IF[0]) $write("SEXT16"); else $write("SEXT8");		 
	       endcase 
	
	6'o45: $write("MOV");	
	6'o46: case (sim.rRA_IF[3:2])
		 3'o0: $write("BR");		 
		 3'o1: $write("BRL");		 
		 3'o2: $write("BRA");		 
		 3'o3: $write("BRAL");		 
	       endcase 
	
	6'o47: case (sim.rRD_IF[2:0])
		 3'o0: $write("BEQ");	
		 3'o1: $write("BNE");	
		 3'o2: $write("BLT");	
		 3'o3: $write("BLE");	
		 3'o4: $write("BGT");	
		 3'o5: $write("BGE");
		 default: $write("XXX");		 
	       endcase 
	
	6'o50: $write("ORI");	
	6'o51: $write("ANDI");	
	6'o52: $write("XORI");	
	6'o53: $write("ANDNI");	
	6'o54: $write("IMMI");	
	6'o55: case (sim.rRD_IF[1:0])
		 2'o0: $write("RTSD");
		 2'o1: $write("RTID");
		 2'o2: $write("RTBD");
		 default: $write("XXX");		 
	       endcase 
	6'o56: case (sim.rRA_IF[3:2])
		 3'o0: $write("BRI");		 
		 3'o1: $write("BRLI");		 
		 3'o2: $write("BRAI");		 
		 3'o3: $write("BRALI");		 
	       endcase 
	6'o57: case (sim.rRD_IF[2:0])
		 3'o0: $write("BEQI");	
		 3'o1: $write("BNEI");	
		 3'o2: $write("BLTI");	
		 3'o3: $write("BLEI");	
		 3'o4: $write("BGTI");	
		 3'o5: $write("BGEI");	
		 default: $write("XXX");		 
	       endcase 
	
	6'o60: $write("LBU");	
	6'o61: $write("LHU");	
	6'o62: $write("LW");	
	6'o64: $write("SB");	
	6'o65: $write("SH");	
	6'o66: $write("SW");	
	
	6'o70: $write("LBUI");	
	6'o71: $write("LHUI");	
	6'o72: $write("LWI");	
	6'o74: $write("SBI");	
	6'o75: $write("SHI");	
	6'o76: $write("SWI");

	default: $write("XXX");	
      endcase 

      case (sim.rOPC_IF[3])
	1'b1: $writeh("\t r",sim.rRD_IF,", r",sim.rRA_IF,", h",sim.rIMM_IF);
	1'b0: $writeh("\t r",sim.rRD_IF,", r",sim.rRA_IF,", r",sim.rRB_IF,"  ");	
      endcase 

      if (sim.bpcu.fHZD)
	$write ("*");      
      
      
      $write("\t|");
      $writeh(" A=",sim.rOPA_OF);
      $writeh(" B=",sim.rOPB_OF);
      $writeh(" C=",sim.rOPX_OF);
      $writeh(" M=",sim.rOPM_OF);
      
      $writeh(" MSR=", wMSR," ");

      case (sim.rALU_OF)
	3'o0: $write(" ADD");
	3'o1: $write(" BSF");
	3'o2: $write(" SLM");
	3'o3: $write(" MOV");
	default: $write(" XXX");
      endcase 

      
      $write ("\t| ");      
      if (sim.dwb_stb_o)
	$writeh("@",sim.rRES_EX);
      else
	$writeh("=",sim.rRES_EX);

      
      case (sim.rBRA)
	2'b00: $write(" ");
	2'b01: $write(".");	
	2'b10: $write("-");
	2'b11: $write("+");	
      endcase 
      
      
      $write("\t|");
      
      if (|sim.rRD_MA) begin
	 case (sim.rOPD_MA)
	   2'o2: begin
	      if (sim.rSEL_MA != 4'h0) $writeh("R",sim.rRD_MA,"=RAM(",sim.regf.rREGD,")");
	      if (sim.rSEL_MA == 4'h0) $writeh("R",sim.rRD_MA,"=FSL(",sim.regf.rREGD,")");
	   end
	   2'o1: $writeh("R",sim.rRD_MA,"=LNK(",sim.regf.rREGD,")");
	   2'o0: $writeh("R",sim.rRD_MA,"=ALU(",sim.regf.rREGD,")");
	 endcase 
      end

      /*
      
      if (dwb_stb_o & dwb_wre_o) begin
	 $writeh("RAM(", dwb_adr ,")=", dwb_dat_o);
	 case (dwb_sel_o)
	   4'hF: $write(":L");
	   4'h3,4'hC: $write(":W");
	   4'h1,4'h2,4'h4,4'h8: $write(":B");
	 endcase 
	 
      end
       */
   end 
   
   
      
endmodule 

/* $Log: not supported by cvs2svn $
/* Revision 1.1  2007/12/18 18:54:36  sybreon
/* Partitioned simulation model.
/* */
/* $Id: aeMB2_sparam.v,v 1.2 2008-04-26 01:09:06 sybreon Exp $
** 
** AEMB2 EDK 6.2 COMPATIBLE CORE
** Copyright (C) 2004-2008 Shawn Tan <shawn.tan@aeste.net>
** 
** This file is part of AEMB.
**
** AEMB is free software: you can redistribute it and/or modify it
** under the terms of the GNU Lesser General Public License as
** published by the Free Software Foundation, either version 3 of the
** License, or (at your option) any later version.
**
** AEMB is distributed in the hope that it will be useful, but WITHOUT
** ANY WARRANTY; without even the implied warranty of MERCHANTABILITY
** or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU Lesser General
** Public License for more details.
**
** You should have received a copy of the GNU Lesser General Public
** License along with AEMB. If not, see <http:**www.gnu.org/licenses/>.
*/
/**
 * @file aeMB2_sparam.v
 * @brief On-chip single-port asynchronous SRAM.

 * This will be implemented as distributed RAM.
  
 */

module aeMB2_sparam (/*AUTOARG*/
   
   dat_o,
   
   adr_i, dat_i, wre_i, clk_i, ena_i
   ) ;
   parameter AW = 5; 
   parameter DW = 2; 

   
   output [DW-1:0] dat_o;  
   input [AW-1:0]  adr_i;
   input [DW-1:0]  dat_i;
   input 	   wre_i;
   
   
   input 	   clk_i, ena_i;

   /*AUTOREG*/
   
   reg [DW-1:0]    rRAM [(1<<AW)-1:0];
   reg [AW-1:0]    rADDR;
   
   always @(posedge clk_i)
     begin
	if (wre_i) 
	  rRAM[adr_i] <= #1 dat_i;	
     end
   
   assign 	   dat_o = rRAM[adr_i];
   
   
   
   integer i;
   initial begin
      for (i=0; i<(1<<AW); i=i+1) begin
	 rRAM[i] <= {(DW){1'b0}};	 
end
   end
   
   
endmodule 

/*
 $Log: not supported by cvs2svn $
 Revision 1.1  2008/04/20 16:33:39  sybreon
 Initial import.
*/
/* $Id: aeMB2_spsram.v,v 1.1 2008-04-20 16:33:39 sybreon Exp $
** 
** AEMB2 EDK 6.2 COMPATIBLE CORE
** Copyright (C) 2004-2008 Shawn Tan <shawn.tan@aeste.net>
** 
** This file is part of AEMB.
**
** AEMB is free software: you can redistribute it and/or modify it
** under the terms of the GNU Lesser General Public License as
** published by the Free Software Foundation, either version 3 of the
** License, or (at your option) any later version.
**
** AEMB is distributed in the hope that it will be useful, but WITHOUT
** ANY WARRANTY; without even the implied warranty of MERCHANTABILITY
** or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU Lesser General
** Public License for more details.
**
** You should have received a copy of the GNU Lesser General Public
** License along with AEMB. If not, see <http:**www.gnu.org/licenses/>.
*/

/** 
 * @file aeMB2_spsram.v
 * @brief On-chip singla-port synchronous SRAM. 

 * Infer a write-before-read block RAM.

 * NOTES: Quartus (<=7.2) does not infer a block RAM with read enable.
 
 */

module aeMB2_spsram (/*AUTOARG*/
   
   dat_o,
   
   adr_i, dat_i, wre_i, ena_i, rst_i, clk_i
   ) ;
   parameter AW = 8;
   parameter DW = 32;

   
   output [DW-1:0] dat_o;  
   input [AW-1:0]  adr_i;
   input [DW-1:0]  dat_i;
   input 	   wre_i,
		   ena_i,		   
		   rst_i,
		   clk_i;
   
   /*AUTOREG*/
   
   reg [DW-1:0]		dat_o;
   
   reg [DW:1] 	   rRAM [(1<<AW)-1:0];
   reg [AW:1] 	   rADR;
   
   always @(posedge clk_i)
     if (wre_i) rRAM[adr_i] <= #1 dat_i;

   always @(posedge clk_i)
     if (rst_i)
       /*AUTORESET*/
       
       dat_o <= {(1+(DW-1)){1'b0}};
       
     else if (ena_i) 
       dat_o <= #1 rRAM[adr_i];	

   
   
   integer i;
   initial begin
      for (i=0; i<(1<<AW); i=i+1) begin
	 rRAM[i] <= $random;	 
      end
   end
   
   
endmodule 

/* $Id: aeMB2_tpsram.v,v 1.3 2008-04-26 17:57:43 sybreon Exp $
** 
** AEMB2 EDK 6.2 COMPATIBLE CORE
** Copyright (C) 2004-2008 Shawn Tan <shawn.tan@aeste.net>
** 
** This file is part of AEMB.
**
** AEMB is free software: you can redistribute it and/or modify it
** under the terms of the GNU Lesser General Public License as
** published by the Free Software Foundation, either version 3 of the
** License, or (at your option) any later version.
**
** AEMB is distributed in the hope that it will be useful, but WITHOUT
** ANY WARRANTY; without even the implied warranty of MERCHANTABILITY
** or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU Lesser General
** Public License for more details.
**
** You should have received a copy of the GNU Lesser General Public
** License along with AEMB. If not, see <http:**www.gnu.org/licenses/>.
*/
/** 
 * @file aeMB2_tpsram.v
 * @brief On-chip two-port synchronous SRAM. 

 * Port A is used for writing and port B is used for reading
 * ONLY. Output buffers are cleared during reset. NOTE: Quartus
 * (<=7.2) does not infer a correct SYNCRAM block with read enable.

 */

module aeMB2_tpsram (/*AUTOARG*/
   
   dat_o, xdat_o,
   
   adr_i, dat_i, wre_i, ena_i, rst_i, clk_i, xadr_i, xdat_i, xwre_i,
   xena_i, xrst_i, xclk_i
   ) ;
   parameter AW = 8; 
   parameter DW = 32; 

   
   output [DW-1:0] dat_o;  
   input [AW-1:0]  adr_i;
   input [DW-1:0]  dat_i;
   input 	   wre_i,		   
		   ena_i,
		   rst_i,
		   clk_i;
   
   
   output [DW-1:0] xdat_o;  
   input [AW-1:0]  xadr_i;
   input [DW-1:0]  xdat_i;
   input 	   xwre_i,
		   xena_i,
		   xrst_i,
		   xclk_i;     
   
   /*AUTOREG*/
   
   reg [DW-1:0]		xdat_o;
   
   reg [DW:1] 		rRAM [(1<<AW)-1:0];
   reg [AW:1] 		rADR;
   
   always @(posedge clk_i)    
     if (wre_i) rRAM[adr_i] <= #1 dat_i;	    
   
   always @(posedge xclk_i)
     if (xrst_i)
       /*AUTORESET*/
       
       xdat_o <= {(1+(DW-1)){1'b0}};
       
     else if (xena_i) 
       xdat_o <= #1 rRAM[xadr_i];   
   
   assign 		dat_o = {(DW){1'bX}}; 
   
   
   
   integer i;
   initial begin
      for (i=0; i<(1<<AW); i=i+1) begin
	 rRAM[i] <= $random;	 
      end
   end
   
   
endmodule 

/*
 $Log: not supported by cvs2svn $
 Revision 1.2  2008/04/26 01:09:06  sybreon
 Passes basic tests. Minor documentation changes to make it compatible with iverilog pre-processor.

 Revision 1.1  2008/04/20 16:33:39  sybreon
 Initial import.
*/
/* $Id: aeMB2_xslif.v,v 1.7 2008-04-27 16:41:46 sybreon Exp $
**
** AEMB2 EDK 6.2 COMPATIBLE CORE
** Copyright (C) 2004-2008 Shawn Tan <shawn.tan@aeste.net>
**  
** This file is part of AEMB.
**
** AEMB is free software: you can redistribute it and/or modify it
** under the terms of the GNU Lesser General Public License as
** published by the Free Software Foundation, either version 3 of the
** License, or (at your option) any later version.
**
** AEMB is distributed in the hope that it will be useful, but WITHOUT
** ANY WARRANTY; without even the implied warranty of MERCHANTABILITY
** or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU Lesser General
** Public License for more details.
**
** You should have received a copy of the GNU Lesser General Public
** License along with AEMB. If not, see <http:**www.gnu.org/licenses/>.
*/
/**
 * Accelerator Interface
 * @file aeMB2_xslif.v
  
 * This sets up the Wishbone control signals for the XSL bus
   interface. This is a non optional bus interface. Bus transactions
   are independent of the pipeline.
 
 */

module aeMB2_xslif (/*AUTOARG*/
   
   xwb_adr_o, xwb_dat_o, xwb_sel_o, xwb_tag_o, xwb_stb_o, xwb_cyc_o,
   xwb_wre_o, xwb_fb, xwb_mx,
   
   xwb_dat_i, xwb_ack_i, imm_of, opc_of, opa_of, gclk, grst, dena,
   gpha
   );
   parameter AEMB_XSL = 1; 
   parameter AEMB_XWB = 3; 

   
   output [AEMB_XWB-1:2] xwb_adr_o;
   output [31:0] 	 xwb_dat_o;   
   output [3:0] 	 xwb_sel_o;
   output 		 xwb_tag_o;   
   output 		 xwb_stb_o,
			 xwb_cyc_o,
			 xwb_wre_o;
   input [31:0] 	 xwb_dat_i; 		 
   input 		 xwb_ack_i;   
      
   
   output 		 xwb_fb;
   output [31:0] 	 xwb_mx;   
   input [15:0] 	 imm_of;
   input [5:0] 		 opc_of;    
   input [31:0] 	 opa_of;
   
   
   input 		 gclk,
			 grst,
			 dena,
			 gpha;   
   
   /*AUTOREG*/
   
   reg [AEMB_XWB-1:2]	xwb_adr_o;
   reg [31:0]		xwb_dat_o;
   reg [31:0]		xwb_mx;
   reg			xwb_stb_o;
   reg			xwb_tag_o;
   reg			xwb_wre_o;
   
   
   
   assign 		xwb_fb = (xwb_stb_o ~^ xwb_ack_i);
  
   
   reg [31:0] 		xwb_lat;
   
   always @(posedge gclk)
     if (grst) begin
	/*AUTORESET*/
	
	xwb_adr_o <= {(1+(AEMB_XWB-1)-(2)){1'b0}};
	xwb_dat_o <= 32'h0;
	xwb_mx <= 32'h0;
	xwb_tag_o <= 1'h0;
	xwb_wre_o <= 1'h0;
	
     end else if (dena) begin

	xwb_adr_o <= #1 imm_of[11:0]; 
	xwb_wre_o <= #1 imm_of[15]; 
	xwb_tag_o <= #1 imm_of[13]; 

	xwb_dat_o <= #1 opa_of; 

	xwb_mx <= #1 (xwb_ack_i) ? 
		  xwb_dat_i : 
		  xwb_lat; 
	
     end 

   assign xwb_sel_o = 4'hF;   
   
   
   reg 			xBLK;

   always @(posedge gclk)
     if (grst) begin
	/*AUTORESET*/
	
	xwb_lat <= 32'h0;
	
     end else if (xwb_ack_i) begin
	xwb_lat <= #1 xwb_dat_i;	
     end
   
   always @(posedge gclk)
     if (grst) begin
	/*AUTORESET*/
	
	xBLK <= 1'h0;
	xwb_stb_o <= 1'h0;
	
     end else if (xwb_fb) begin
	xBLK <= #1 imm_of[14]; 
	xwb_stb_o <= #1 (dena) ? !opc_of[5] & opc_of[4] & opc_of[3] & opc_of[1] : 
		     (xwb_stb_o & !xwb_ack_i);	
     end

   assign xwb_cyc_o = xwb_stb_o;
   
   
endmodule 

/*
 $Log: not supported by cvs2svn $
 Revision 1.6  2008/04/27 16:04:12  sybreon
 Fixed minor typos.

 Revision 1.5  2008/04/26 17:57:43  sybreon
 Minor performance improvements.

 Revision 1.4  2008/04/26 01:09:06  sybreon
 Passes basic tests. Minor documentation changes to make it compatible with iverilog pre-processor.

 Revision 1.3  2008/04/21 12:11:38  sybreon
 Passes arithmetic tests with single thread.

 Revision 1.2  2008/04/20 16:34:32  sybreon
 Basic version with some features left out.

 Revision 1.1  2008/04/18 00:21:52  sybreon
 Initial import.
*/


module aeMB_bpcu (/*AUTOARG*/
   
   iwb_adr_o, rPC, rPCLNK, rBRA, rDLY,
   
   rMXALT, rOPC, rRD, rRA, rRESULT, rDWBDI, rREGA, gclk, grst, gena
   );
   parameter IW = 24;

   
   output [IW-1:2] iwb_adr_o;

   
   output [31:2]   rPC, rPCLNK;
   output 	   rBRA;
   output 	   rDLY;
   
   
   
   input [1:0] 	   rMXALT;   
   input [5:0] 	   rOPC;
   input [4:0] 	   rRD, rRA;  
   input [31:0]    rRESULT; 
   input [31:0]    rDWBDI; 
   input [31:0]    rREGA;
   
   
   
   input 	   gclk, grst, gena;

   
   
   
   wire 	   fRTD = (rOPC == 6'o55);
   wire 	   fBCC = (rOPC == 6'o47) | (rOPC == 6'o57);
   wire 	   fBRU = (rOPC == 6'o46) | (rOPC == 6'o56);

   wire [31:0] 	   wREGA;
   assign 	   wREGA = (rMXALT == 2'o2) ? rDWBDI :
			   (rMXALT == 2'o1) ? rRESULT :
			   rREGA;   
   
   wire 	   wBEQ = (wREGA == 32'd0);
   wire 	   wBNE = ~wBEQ;
   wire 	   wBLT = wREGA[31];
   wire 	   wBLE = wBLT | wBEQ;   
   wire 	   wBGE = ~wBLT;
   wire 	   wBGT = ~wBLE;   

   reg 		   xXCC;
   always @(/*AUTOSENSE*/rRD or wBEQ or wBGE or wBGT or wBLE or wBLT
	    or wBNE)
     case (rRD[2:0])
       3'o0: xXCC <= wBEQ;
       3'o1: xXCC <= wBNE;
       3'o2: xXCC <= wBLT;
       3'o3: xXCC <= wBLE;
       3'o4: xXCC <= wBGT;
       3'o5: xXCC <= wBGE;
       default: xXCC <= 1'bX;
     endcase 

   reg 		   rBRA, xBRA;
   reg 		   rDLY, xDLY;
   wire 	   fSKIP = rBRA & !rDLY;   
   
   always @(/*AUTOSENSE*/fBCC or fBRU or fRTD or rBRA or rRA or rRD
	    or xXCC)
     
     if (rBRA) begin
	/*AUTORESET*/
	
	xBRA <= 1'h0;
	xDLY <= 1'h0;
	
     end else begin
	xDLY <= (fBRU & rRA[4]) | (fBCC & rRD[4]) | fRTD;      
	xBRA <= (fRTD | fBRU) ? 1'b1 :
		(fBCC) ? xXCC :
		1'b0;
     end

   
   
   
   reg [31:2] 	   rIPC, xIPC;
   reg [31:2] 	   rPC, xPC;
   reg [31:2] 	   rPCLNK, xPCLNK;
   
   assign 	   iwb_adr_o = rIPC[IW-1:2];
   
   always @(/*AUTOSENSE*/rBRA or rIPC or rPC or rRESULT) begin
      
      xPCLNK <= rPC;
      
      xPC <= rIPC;
      
      /*
     case (rXCE)
       2'o1: xIPC <= 30'h2;       
       2'o2: xIPC <= 30'h4;       
       2'o3: xIPC <= 30'h6;       
       default: xIPC <= (rBRA) ? rRESULT[31:2] : (rIPC + 1);
     endcase 
       */
      xIPC <= (rBRA) ? rRESULT[31:2] : (rIPC + 1);
   end   			   

   
   
   
   wire 	wIMM = (rOPC == 6'o54) & !fSKIP;
   wire 	wRTD = (rOPC == 6'o55) & !fSKIP;
   wire 	wBCC = xXCC & ((rOPC == 6'o47) | (rOPC == 6'o57)) & !fSKIP;
   wire 	wBRU = ((rOPC == 6'o46) | (rOPC == 6'o56)) & !fSKIP;   
   
   wire 	fATOM = ~(wIMM | wRTD | wBCC | wBRU | rBRA);   
   reg [1:0] 	rATOM, xATOM;

   always @(/*AUTOSENSE*/fATOM or rATOM)
     xATOM <= {rATOM[0], (rATOM[0] ^ fATOM)};   
     
   
   
    
   always @(posedge gclk)
     if (grst) begin
	/*AUTORESET*/
	
	rATOM <= 2'h0;
	rBRA <= 1'h0;
	rDLY <= 1'h0;
	rIPC <= 30'h0;
	rPC <= 30'h0;
	rPCLNK <= 30'h0;
	
     end else if (gena) begin
	rIPC <= #1 xIPC;
	rBRA <= #1 xBRA;
	rPC <= #1 xPC;
	rPCLNK <= #1 xPCLNK;
	rDLY <= #1 xDLY;
	rATOM <= #1 xATOM;	
     end
      
endmodule 



module aeMB_core (/*AUTOARG*/
   
   iwb_stb_o, iwb_adr_o, fsl_wre_o, fsl_tag_o, fsl_stb_o, fsl_dat_o,
   fsl_adr_o, dwb_wre_o, dwb_stb_o, dwb_sel_o, dwb_dat_o, dwb_adr_o,
   
   sys_rst_i, sys_int_i, sys_clk_i, iwb_dat_i, iwb_ack_i, fsl_dat_i,
   fsl_ack_i, dwb_dat_i, dwb_ack_i
   );
   
   parameter ISIZ = 32;
   
   parameter DSIZ = 32;
   
   parameter MUL = 1;
   
   parameter BSF = 1;   

   /*AUTOOUTPUT*/
   
   output [DSIZ-1:2]	dwb_adr_o;		
   output [31:0]	dwb_dat_o;		
   output [3:0]		dwb_sel_o;		
   output		dwb_stb_o;		
   output		dwb_wre_o;		
   output [6:2]		fsl_adr_o;		
   output [31:0]	fsl_dat_o;		
   output		fsl_stb_o;		
   output [1:0]		fsl_tag_o;		
   output		fsl_wre_o;		
   output [ISIZ-1:2]	iwb_adr_o;		
   output		iwb_stb_o;		
   
   /*AUTOINPUT*/
   
   input		dwb_ack_i;		
   input [31:0]		dwb_dat_i;		
   input		fsl_ack_i;		
   input [31:0]		fsl_dat_i;		
   input		iwb_ack_i;		
   input [31:0]		iwb_dat_i;		
   input		sys_clk_i;		
   input		sys_int_i;		
   input		sys_rst_i;		
   
   /*AUTOWIRE*/

   

   /* 
    aeMB_edk32 AUTO_TEMPLATE (
    .dwb_adr_o(dwb_adr_o[DSIZ-1:2]),
    .iwb_adr_o(iwb_adr_o[ISIZ-1:2]),
    );
    */
   
   aeMB_edk32 #(ISIZ, DSIZ, MUL, BSF)
   edk32 (/*AUTOINST*/
	  
	  .dwb_adr_o			(dwb_adr_o[DSIZ-1:2]),	 
	  .dwb_dat_o			(dwb_dat_o[31:0]),
	  .dwb_sel_o			(dwb_sel_o[3:0]),
	  .dwb_stb_o			(dwb_stb_o),
	  .dwb_wre_o			(dwb_wre_o),
	  .fsl_adr_o			(fsl_adr_o[6:2]),
	  .fsl_dat_o			(fsl_dat_o[31:0]),
	  .fsl_stb_o			(fsl_stb_o),
	  .fsl_tag_o			(fsl_tag_o[1:0]),
	  .fsl_wre_o			(fsl_wre_o),
	  .iwb_adr_o			(iwb_adr_o[ISIZ-1:2]),	 
	  .iwb_stb_o			(iwb_stb_o),
	  
	  .dwb_ack_i			(dwb_ack_i),
	  .dwb_dat_i			(dwb_dat_i[31:0]),
	  .fsl_ack_i			(fsl_ack_i),
	  .fsl_dat_i			(fsl_dat_i[31:0]),
	  .iwb_ack_i			(iwb_ack_i),
	  .iwb_dat_i			(iwb_dat_i[31:0]),
	  .sys_int_i			(sys_int_i),
	  .sys_clk_i			(sys_clk_i),
	  .sys_rst_i			(sys_rst_i));
   
   
endmodule 


module aeMB_ctrl (/*AUTOARG*/
   
   rMXDST, rMXSRC, rMXTGT, rMXALT, rMXALU, rRW, dwb_stb_o, dwb_wre_o,
   fsl_stb_o, fsl_wre_o,
   
   rDLY, rIMM, rALT, rOPC, rRD, rRA, rRB, rPC, rBRA, rMSR_IE, xIREG,
   dwb_ack_i, iwb_ack_i, fsl_ack_i, gclk, grst, gena
   );
   
   
   output [1:0]  rMXDST;
   output [1:0]  rMXSRC, rMXTGT, rMXALT;
   output [2:0]  rMXALU;   
   output [4:0]  rRW;
   
   input 	 rDLY;
   input [15:0]  rIMM;
   input [10:0]  rALT;
   input [5:0] 	 rOPC;
   input [4:0] 	 rRD, rRA, rRB;
   input [31:2]  rPC;
   input 	 rBRA;
   input 	 rMSR_IE;
   input [31:0]  xIREG;   
   
   
   output 	 dwb_stb_o;
   output 	 dwb_wre_o;
   input 	 dwb_ack_i;

   
   input 	 iwb_ack_i;
   
   
   output 	 fsl_stb_o;
   output 	 fsl_wre_o;
   input 	 fsl_ack_i;   
   
   
   input 	 gclk, grst, gena;

   
   

   wire [5:0] 	 wOPC;
   wire [4:0] 	 wRD, wRA, wRB;
   wire [10:0] 	 wALT;   
   
   assign 	 {wOPC, wRD, wRA, wRB, wALT} = xIREG; 

   wire 	 fSFT = (rOPC == 6'o44);
   wire 	 fLOG = ({rOPC[5:4],rOPC[2]} == 3'o4);   

   wire 	 fMUL = (rOPC == 6'o20) | (rOPC == 6'o30);
   wire 	 fBSF = (rOPC == 6'o21) | (rOPC == 6'o31);
   wire 	 fDIV = (rOPC == 6'o22);   
   
   wire 	 fRTD = (rOPC == 6'o55);
   wire 	 fBCC = (rOPC == 6'o47) | (rOPC == 6'o57);
   wire 	 fBRU = (rOPC == 6'o46) | (rOPC == 6'o56);
   wire 	 fBRA = fBRU & rRA[3];   

   wire 	 fIMM = (rOPC == 6'o54);
   wire 	 fMOV = (rOPC == 6'o45);   
   
   wire 	 fLOD = ({rOPC[5:4],rOPC[2]} == 3'o6);
   wire 	 fSTR = ({rOPC[5:4],rOPC[2]} == 3'o7);
   wire 	 fLDST = (&rOPC[5:4]);   

   wire          fPUT = (rOPC == 6'o33) & rRB[4];
   wire 	 fGET = (rOPC == 6'o33) & !rRB[4];   


   wire 	 wSFT = (wOPC == 6'o44);
   wire 	 wLOG = ({wOPC[5:4],wOPC[2]} == 3'o4);   

   wire 	 wMUL = (wOPC == 6'o20) | (wOPC == 6'o30);
   wire 	 wBSF = (wOPC == 6'o21) | (wOPC == 6'o31);
   wire 	 wDIV = (wOPC == 6'o22);   
   
   wire 	 wRTD = (wOPC == 6'o55);
   wire 	 wBCC = (wOPC == 6'o47) | (wOPC == 6'o57);
   wire 	 wBRU = (wOPC == 6'o46) | (wOPC == 6'o56);
   wire 	 wBRA = wBRU & wRA[3];   

   wire 	 wIMM = (wOPC == 6'o54);
   wire 	 wMOV = (wOPC == 6'o45);   
   
   wire 	 wLOD = ({wOPC[5:4],wOPC[2]} == 3'o6);
   wire 	 wSTR = ({wOPC[5:4],wOPC[2]} == 3'o7);
   wire 	 wLDST = (&wOPC[5:4]);   

   wire          wPUT = (wOPC == 6'o33) & wRB[4];
   wire 	 wGET = (wOPC == 6'o33) & !wRB[4];   

   
   

   reg [31:2] 	 rPCLNK, xPCLNK;
   reg [1:0] 	 rMXDST, xMXDST;
   reg [4:0] 	 rRW, xRW;   

   reg [1:0] 	 rMXSRC, xMXSRC;
   reg [1:0] 	 rMXTGT, xMXTGT;
   reg [1:0] 	 rMXALT, xMXALT;
   
   
   

   wire 	 wRDWE = |xRW;
   wire 	 wAFWD_M = (xRW == wRA) & (xMXDST == 2'o2) & wRDWE;
   wire 	 wBFWD_M = (xRW == wRB) & (xMXDST == 2'o2) & wRDWE;
   wire 	 wAFWD_R = (xRW == wRA) & (xMXDST == 2'o0) & wRDWE;   
   wire 	 wBFWD_R = (xRW == wRB) & (xMXDST == 2'o0) & wRDWE;

   always @(/*AUTOSENSE*/rBRA or wAFWD_M or wAFWD_R or wBCC or wBFWD_M
	    or wBFWD_R or wBRU or wOPC) 
     
     if (rBRA) begin
	/*AUTORESET*/
	
	xMXALT <= 2'h0;
	xMXSRC <= 2'h0;
	xMXTGT <= 2'h0;
	
     end else begin
	xMXSRC <= (wBRU | wBCC) ? 2'o3 : 
		  (wAFWD_M) ? 2'o2 : 
		  (wAFWD_R) ? 2'o1 : 
		  2'o0; 
	xMXTGT <= (wOPC[3]) ? 2'o3 : 
		  (wBFWD_M) ? 2'o2 : 
		  (wBFWD_R) ? 2'o1 : 
		  2'o0; 
	xMXALT <= (wAFWD_M) ? 2'o2 : 
		  (wAFWD_R) ? 2'o1 : 
		  2'o0; 
     end 
   
   

   reg [2:0]     rMXALU, xMXALU;

   always @(/*AUTOSENSE*/rBRA or wBRA or wBSF or wDIV or wLOG or wMOV
	    or wMUL or wSFT)
     
     if (rBRA) begin
	/*AUTORESET*/
	
	xMXALU <= 3'h0;
	
     end else begin
	xMXALU <= (wBRA | wMOV) ? 3'o3 :
		  (wSFT) ? 3'o2 :
		  (wLOG) ? 3'o1 :
		  (wMUL) ? 3'o4 :
		  (wBSF) ? 3'o5 :
		  (wDIV) ? 3'o6 :
		  3'o0;      	
     end 
   
   
   
   wire 	 fSKIP = (rBRA & !rDLY);
   
   always @(/*AUTOSENSE*/fBCC or fBRU or fGET or fLOD or fRTD or fSKIP
	    or fSTR or rRD)
     if (fSKIP) begin
	/*AUTORESET*/
	
	xMXDST <= 2'h0;
	xRW <= 5'h0;
	
     end else begin
	xMXDST <= (fSTR | fRTD | fBCC) ? 2'o3 :
		  (fLOD | fGET) ? 2'o2 :
		  (fBRU) ? 2'o1 :
		  2'o0;
	xRW <= rRD;
     end 


   

   wire 	 fDACK = !(dwb_stb_o ^ dwb_ack_i);
   
   reg 		 rDWBSTB, xDWBSTB;
   reg 		 rDWBWRE, xDWBWRE;

   assign 	 dwb_stb_o = rDWBSTB;
   assign 	 dwb_wre_o = rDWBWRE;
   
   
   always @(/*AUTOSENSE*/fLOD or fSKIP or fSTR or iwb_ack_i)
     
     if (fSKIP) begin
	/*AUTORESET*/
	
	xDWBSTB <= 1'h0;
	xDWBWRE <= 1'h0;
	
     end else begin
	xDWBSTB <= (fLOD | fSTR) & iwb_ack_i;
	xDWBWRE <= fSTR & iwb_ack_i;	
     end
   
   always @(posedge gclk)
     if (grst) begin
	/*AUTORESET*/
	
	rDWBSTB <= 1'h0;
	rDWBWRE <= 1'h0;
	
     end else if (fDACK) begin
	rDWBSTB <= #1 xDWBSTB;
	rDWBWRE <= #1 xDWBWRE;	
     end
   

   

   wire 	 fFACK = !(fsl_stb_o ^ fsl_ack_i);   
	 
   reg 		 rFSLSTB, xFSLSTB;
   reg 		 rFSLWRE, xFSLWRE;

   assign 	 fsl_stb_o = rFSLSTB;
   assign 	 fsl_wre_o = rFSLWRE;   

   always @(/*AUTOSENSE*/fGET or fPUT or fSKIP or iwb_ack_i) 
     
     if (fSKIP) begin
	/*AUTORESET*/
	
	xFSLSTB <= 1'h0;
	xFSLWRE <= 1'h0;
	
     end else begin
	xFSLSTB <= (fPUT | fGET) & iwb_ack_i;
	xFSLWRE <= fPUT & iwb_ack_i;	
     end

   always @(posedge gclk)
     if (grst) begin
	/*AUTORESET*/
	
	rFSLSTB <= 1'h0;
	rFSLWRE <= 1'h0;
	
     end else if (fFACK) begin
	rFSLSTB <= #1 xFSLSTB;
	rFSLWRE <= #1 xFSLWRE;	
     end
   
   

   always @(posedge gclk)
     if (grst) begin
	/*AUTORESET*/
	
	rMXALT <= 2'h0;
	rMXALU <= 3'h0;
	rMXDST <= 2'h0;
	rMXSRC <= 2'h0;
	rMXTGT <= 2'h0;
	rRW <= 5'h0;
	
     end else if (gena) begin 
	
	rMXDST <= #1 xMXDST;
	rRW <= #1 xRW;
	rMXSRC <= #1 xMXSRC;
	rMXTGT <= #1 xMXTGT;
	rMXALT <= #1 xMXALT;	
	rMXALU <= #1 xMXALU;	
     end

   
endmodule 

/* $Id: aeMB_edk32.v,v 1.14 2008-01-19 16:01:22 sybreon Exp $
**
** AEMB EDK 3.2 Compatible Core
** Copyright (C) 2004-2007 Shawn Tan Ser Ngiap <shawn.tan@aeste.net>
**  
** This file is part of AEMB.
**
** AEMB is free software: you can redistribute it and/or modify it
** under the terms of the GNU Lesser General Public License as
** published by the Free Software Foundation, either version 3 of the
** License, or (at your option) any later version.
**
** AEMB is distributed in the hope that it will be useful, but WITHOUT
** ANY WARRANTY; without even the implied warranty of MERCHANTABILITY
** or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU Lesser General
** Public License for more details.
**
** You should have received a copy of the GNU Lesser General Public
** License along with AEMB. If not, see <http:
*/

module aeMB_edk32 (/*AUTOARG*/
   
   iwb_stb_o, iwb_adr_o, fsl_wre_o, fsl_tag_o, fsl_stb_o, fsl_dat_o,
   fsl_adr_o, dwb_wre_o, dwb_stb_o, dwb_sel_o, dwb_dat_o, dwb_adr_o,
   
   sys_int_i, iwb_dat_i, iwb_ack_i, fsl_dat_i, fsl_ack_i, dwb_dat_i,
   dwb_ack_i, sys_clk_i, sys_rst_i
   );
   
   parameter IW = 32; 
   parameter DW = 32; 

   
   parameter MUL = 0; 
   parameter BSF = 1; 
   
   /*AUTOOUTPUT*/
   
   output [DW-1:2]	dwb_adr_o;		
   output [31:0]	dwb_dat_o;		
   output [3:0]		dwb_sel_o;		
   output		dwb_stb_o;		
   output		dwb_wre_o;		
   output [6:2]		fsl_adr_o;		
   output [31:0]	fsl_dat_o;		
   output		fsl_stb_o;		
   output [1:0]		fsl_tag_o;		
   output		fsl_wre_o;		
   output [IW-1:2]	iwb_adr_o;		
   output		iwb_stb_o;		
   
   /*AUTOINPUT*/
   
   input		dwb_ack_i;		
   input [31:0]		dwb_dat_i;		
   input		fsl_ack_i;		
   input [31:0]		fsl_dat_i;		
   input		iwb_ack_i;		
   input [31:0]		iwb_dat_i;		
   input		sys_int_i;		
   
   /*AUTOWIRE*/
   
   wire [10:0]		rALT;			
   wire			rBRA;			
   wire			rDLY;			
   wire [31:0]		rDWBDI;			
   wire [3:0]		rDWBSEL;		
   wire [15:0]		rIMM;			
   wire			rMSR_BIP;		
   wire			rMSR_IE;		
   wire [1:0]		rMXALT;			
   wire [2:0]		rMXALU;			
   wire [1:0]		rMXDST;			
   wire [1:0]		rMXSRC;			
   wire [1:0]		rMXTGT;			
   wire [5:0]		rOPC;			
   wire [31:2]		rPC;			
   wire [31:2]		rPCLNK;			
   wire [4:0]		rRA;			
   wire [4:0]		rRB;			
   wire [4:0]		rRD;			
   wire [31:0]		rREGA;			
   wire [31:0]		rREGB;			
   wire [31:0]		rRESULT;		
   wire [4:0]		rRW;			
   wire [31:0]		rSIMM;			
   wire			rSTALL;			
   wire [31:0]		xIREG;			
   

   input 		sys_clk_i;
   input 		sys_rst_i;

   wire 		grst = sys_rst_i;
   wire 		gclk = sys_clk_i;
   wire 		gena = !((dwb_stb_o ^ dwb_ack_i) | (fsl_stb_o ^ fsl_ack_i) | !iwb_ack_i) & !rSTALL;   
   wire 		oena = ((dwb_stb_o ^ dwb_ack_i) | (fsl_stb_o ^ fsl_ack_i) | !iwb_ack_i);   
   
   
          
   aeMB_ibuf
     ibuf (/*AUTOINST*/
	   
	   .rIMM			(rIMM[15:0]),
	   .rRA				(rRA[4:0]),
	   .rRD				(rRD[4:0]),
	   .rRB				(rRB[4:0]),
	   .rALT			(rALT[10:0]),
	   .rOPC			(rOPC[5:0]),
	   .rSIMM			(rSIMM[31:0]),
	   .xIREG			(xIREG[31:0]),
	   .rSTALL			(rSTALL),
	   .iwb_stb_o			(iwb_stb_o),
	   
	   .rBRA			(rBRA),
	   .rMSR_IE			(rMSR_IE),
	   .rMSR_BIP			(rMSR_BIP),
	   .iwb_dat_i			(iwb_dat_i[31:0]),
	   .iwb_ack_i			(iwb_ack_i),
	   .sys_int_i			(sys_int_i),
	   .gclk			(gclk),
	   .grst			(grst),
	   .gena			(gena),
	   .oena			(oena));   
   
   aeMB_ctrl
     ctrl (/*AUTOINST*/
	   
	   .rMXDST			(rMXDST[1:0]),
	   .rMXSRC			(rMXSRC[1:0]),
	   .rMXTGT			(rMXTGT[1:0]),
	   .rMXALT			(rMXALT[1:0]),
	   .rMXALU			(rMXALU[2:0]),
	   .rRW				(rRW[4:0]),
	   .dwb_stb_o			(dwb_stb_o),
	   .dwb_wre_o			(dwb_wre_o),
	   .fsl_stb_o			(fsl_stb_o),
	   .fsl_wre_o			(fsl_wre_o),
	   
	   .rDLY			(rDLY),
	   .rIMM			(rIMM[15:0]),
	   .rALT			(rALT[10:0]),
	   .rOPC			(rOPC[5:0]),
	   .rRD				(rRD[4:0]),
	   .rRA				(rRA[4:0]),
	   .rRB				(rRB[4:0]),
	   .rPC				(rPC[31:2]),
	   .rBRA			(rBRA),
	   .rMSR_IE			(rMSR_IE),
	   .xIREG			(xIREG[31:0]),
	   .dwb_ack_i			(dwb_ack_i),
	   .iwb_ack_i			(iwb_ack_i),
	   .fsl_ack_i			(fsl_ack_i),
	   .gclk			(gclk),
	   .grst			(grst),
	   .gena			(gena));

   aeMB_bpcu #(IW)
     bpcu (/*AUTOINST*/
	   
	   .iwb_adr_o			(iwb_adr_o[IW-1:2]),
	   .rPC				(rPC[31:2]),
	   .rPCLNK			(rPCLNK[31:2]),
	   .rBRA			(rBRA),
	   .rDLY			(rDLY),
	   
	   .rMXALT			(rMXALT[1:0]),
	   .rOPC			(rOPC[5:0]),
	   .rRD				(rRD[4:0]),
	   .rRA				(rRA[4:0]),
	   .rRESULT			(rRESULT[31:0]),
	   .rDWBDI			(rDWBDI[31:0]),
	   .rREGA			(rREGA[31:0]),
	   .gclk			(gclk),
	   .grst			(grst),
	   .gena			(gena));

   aeMB_regf
     regf (/*AUTOINST*/
	   
	   .rREGA			(rREGA[31:0]),
	   .rREGB			(rREGB[31:0]),
	   .rDWBDI			(rDWBDI[31:0]),
	   .dwb_dat_o			(dwb_dat_o[31:0]),
	   .fsl_dat_o			(fsl_dat_o[31:0]),
	   
	   .rOPC			(rOPC[5:0]),
	   .rRA				(rRA[4:0]),
	   .rRB				(rRB[4:0]),
	   .rRW				(rRW[4:0]),
	   .rRD				(rRD[4:0]),
	   .rMXDST			(rMXDST[1:0]),
	   .rPCLNK			(rPCLNK[31:2]),
	   .rRESULT			(rRESULT[31:0]),
	   .rDWBSEL			(rDWBSEL[3:0]),
	   .rBRA			(rBRA),
	   .rDLY			(rDLY),
	   .dwb_dat_i			(dwb_dat_i[31:0]),
	   .fsl_dat_i			(fsl_dat_i[31:0]),
	   .gclk			(gclk),
	   .grst			(grst),
	   .gena			(gena));   

   aeMB_xecu #(DW, MUL, BSF)
     xecu (/*AUTOINST*/
	   
	   .dwb_adr_o			(dwb_adr_o[DW-1:2]),
	   .dwb_sel_o			(dwb_sel_o[3:0]),
	   .fsl_adr_o			(fsl_adr_o[6:2]),
	   .fsl_tag_o			(fsl_tag_o[1:0]),
	   .rRESULT			(rRESULT[31:0]),
	   .rDWBSEL			(rDWBSEL[3:0]),
	   .rMSR_IE			(rMSR_IE),
	   .rMSR_BIP			(rMSR_BIP),
	   
	   .rREGA			(rREGA[31:0]),
	   .rREGB			(rREGB[31:0]),
	   .rMXSRC			(rMXSRC[1:0]),
	   .rMXTGT			(rMXTGT[1:0]),
	   .rRA				(rRA[4:0]),
	   .rRB				(rRB[4:0]),
	   .rMXALU			(rMXALU[2:0]),
	   .rBRA			(rBRA),
	   .rDLY			(rDLY),
	   .rALT			(rALT[10:0]),
	   .rSTALL			(rSTALL),
	   .rSIMM			(rSIMM[31:0]),
	   .rIMM			(rIMM[15:0]),
	   .rOPC			(rOPC[5:0]),
	   .rRD				(rRD[4:0]),
	   .rDWBDI			(rDWBDI[31:0]),
	   .rPC				(rPC[31:2]),
	   .gclk			(gclk),
	   .grst			(grst),
	   .gena			(gena));
   
      
endmodule 

/*
 $Log: not supported by cvs2svn $
 Revision 1.13  2007/12/25 22:15:09  sybreon
 Stalls pipeline on MUL/BSF instructions results in minor speed improvements.

 Revision 1.12  2007/12/23 20:40:44  sybreon
 Abstracted simulation kernel (top) to split simulation models from synthesis models.

 Revision 1.11  2007/11/30 17:08:29  sybreon
 Moved simulation kernel into code.
 
 Revision 1.10  2007/11/16 21:52:03  sybreon
 Added fsl_tag_o to FSL bus (tag either address or data).

 Revision 1.9  2007/11/14 23:19:24  sybreon
 Fixed minor typo.

 Revision 1.8  2007/11/14 22:14:34  sybreon
 Changed interrupt handling system (reported by M. Ettus).

 Revision 1.7  2007/11/10 16:39:38  sybreon
 Upgraded license to LGPLv3.
 Significant performance optimisations.

 Revision 1.6  2007/11/09 20:51:52  sybreon
 Added GET/PUT support through a FSL bus.

 Revision 1.5  2007/11/08 17:48:14  sybreon
 Fixed data WISHBONE arbitration problem (reported by J Lee).

 Revision 1.4  2007/11/08 14:17:47  sybreon
 Parameterised optional components.

 Revision 1.3  2007/11/03 08:34:55  sybreon
 Minor code cleanup.

 Revision 1.2  2007/11/02 19:20:58  sybreon
 Added better (beta) interrupt support.
 Changed MSR_IE to disabled at reset as per MB docs.

 Revision 1.1  2007/11/02 03:25:40  sybreon
 New EDK 3.2 compatible design with optional barrel-shifter and multiplier.
 Fixed various minor data hazard bugs.
 Code compatible with -O0/1/2/3/s generated code.
*/ 
/* $Id: aeMB_ibuf.v,v 1.10 2008-01-21 01:02:26 sybreon Exp $
**
** AEMB INSTRUCTION BUFFER
** Copyright (C) 2004-2007 Shawn Tan Ser Ngiap <shawn.tan@aeste.net>
**  
** This file is part of AEMB.
**
** AEMB is free software: you can redistribute it and/or modify it
** under the terms of the GNU Lesser General Public License as
** published by the Free Software Foundation, either version 3 of the
** License, or (at your option) any later version.
**
** AEMB is distributed in the hope that it will be useful, but WITHOUT
** ANY WARRANTY; without even the implied warranty of MERCHANTABILITY
** or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU Lesser General
** Public License for more details.
**
** You should have received a copy of the GNU Lesser General Public
** License along with AEMB. If not, see <http:
*/

module aeMB_ibuf (/*AUTOARG*/
   
   rIMM, rRA, rRD, rRB, rALT, rOPC, rSIMM, xIREG, rSTALL, iwb_stb_o,
   
   rBRA, rMSR_IE, rMSR_BIP, iwb_dat_i, iwb_ack_i, sys_int_i, gclk,
   grst, gena, oena
   );
   
   output [15:0] rIMM;
   output [4:0]  rRA, rRD, rRB;
   output [10:0] rALT;
   output [5:0]  rOPC;
   output [31:0] rSIMM;
   output [31:0] xIREG;
   output 	 rSTALL;   
   
   input 	 rBRA;
   
   input 	 rMSR_IE;
   input 	 rMSR_BIP;   
   
   
   output 	 iwb_stb_o;
   input [31:0]  iwb_dat_i;
   input 	 iwb_ack_i;

   
   input 	 sys_int_i;   

   
   input 	 gclk, grst, gena, oena;

   reg [15:0] 	 rIMM;
   reg [4:0] 	 rRA, rRD;
   reg [5:0] 	 rOPC;

   
   wire [31:0] 	 wIDAT = iwb_dat_i;
   assign 	 {rRB, rALT} = rIMM;   
   
   
   assign 	iwb_stb_o = 1'b1;

   reg [31:0] 	rSIMM, xSIMM;
   reg 		rSTALL;   

   wire [31:0] 	wXCEOP = 32'hBA2D0008; 
   wire [31:0] 	wINTOP = 32'hB9CE0010; 
   wire [31:0] 	wBRKOP = 32'hBA0C0018; 
   wire [31:0] 	wBRAOP = 32'h88000000; 
   
   wire [31:0] 	wIREG = {rOPC, rRD, rRA, rRB, rALT};   
   reg [31:0] 	xIREG;


   
   
   
   
   reg 		rFINT;
   reg [1:0] 	rDINT;
   wire 	wSHOT = rDINT[0];	

   always @(posedge gclk)
     if (grst) begin
	/*AUTORESET*/
	
	rDINT <= 2'h0;
	rFINT <= 1'h0;
	
     end else begin
	if (rMSR_IE)
	  rDINT <= #1 
		   {rDINT[0], sys_int_i};
	
	rFINT <= #1 
		 
		 (rFINT | wSHOT) & rMSR_IE;
     end

   wire 	fIMM = (rOPC == 6'o54);
   wire 	fRTD = (rOPC == 6'o55);
   wire 	fBRU = ((rOPC == 6'o46) | (rOPC == 6'o56));
   wire 	fBCC = ((rOPC == 6'o47) | (rOPC == 6'o57));   
   
   
   
   always @(/*AUTOSENSE*/fBCC or fBRU or fIMM or fRTD or rBRA or rFINT
	    or wBRAOP or wIDAT or wINTOP) begin
      xIREG <= (rBRA) ? wBRAOP : 
	       (!fIMM & rFINT & !fRTD & !fBRU & !fBCC) ? wINTOP :
	       wIDAT;
   end
   
   always @(/*AUTOSENSE*/fIMM or rBRA or rIMM or wIDAT or xIREG) begin
      xSIMM <= (!fIMM | rBRA) ? { {(16){xIREG[15]}}, xIREG[15:0]} :
	       {rIMM, wIDAT[15:0]};
   end   

   
   
   always @(posedge gclk)
     if (grst) begin
	/*AUTORESET*/
	
	rIMM <= 16'h0;
	rOPC <= 6'h0;
	rRA <= 5'h0;
	rRD <= 5'h0;
	rSIMM <= 32'h0;
	
     end else if (gena) begin
	{rOPC, rRD, rRA, rIMM} <= #1 xIREG;
	rSIMM <= #1 xSIMM;	
     end

   

   wire [5:0] wOPC = xIREG[31:26];   
   
   wire       fMUL = (wOPC == 6'o20) | (wOPC == 6'o30);
   wire       fBSF = (wOPC == 6'o21) | (wOPC == 6'o31);   
   
   always @(posedge gclk)
     if (grst) begin
	/*AUTORESET*/
	
	rSTALL <= 1'h0;
	
     end else begin
	rSTALL <= #1 (!rSTALL & (fMUL | fBSF)) | (oena & rSTALL);	
     end
   
endmodule 

/*
 $Log: not supported by cvs2svn $
 Revision 1.9  2008/01/19 16:01:22  sybreon
 Patched problem where memory access followed by dual cycle instructions were not stalling correctly (submitted by M. Ettus)

 Revision 1.8  2007/12/25 22:15:09  sybreon
 Stalls pipeline on MUL/BSF instructions results in minor speed improvements.

 Revision 1.7  2007/11/22 15:11:15  sybreon
 Change interrupt to positive level triggered interrupts.

 Revision 1.6  2007/11/14 23:39:51  sybreon
 Fixed interrupt signal synchronisation.

 Revision 1.5  2007/11/14 22:14:34  sybreon
 Changed interrupt handling system (reported by M. Ettus).

 Revision 1.4  2007/11/10 16:39:38  sybreon
 Upgraded license to LGPLv3.
 Significant performance optimisations.

 Revision 1.3  2007/11/03 08:34:55  sybreon
 Minor code cleanup.

 Revision 1.2  2007/11/02 19:20:58  sybreon
 Added better (beta) interrupt support.
 Changed MSR_IE to disabled at reset as per MB docs.

 Revision 1.1  2007/11/02 03:25:40  sybreon
 New EDK 3.2 compatible design with optional barrel-shifter and multiplier.
 Fixed various minor data hazard bugs.
 Code compatible with -O0/1/2/3/s generated code.
*/

module aeMB_regf (/*AUTOARG*/
   
   rREGA, rREGB, rDWBDI, dwb_dat_o, fsl_dat_o,
   
   rOPC, rRA, rRB, rRW, rRD, rMXDST, rPCLNK, rRESULT, rDWBSEL, rBRA,
   rDLY, dwb_dat_i, fsl_dat_i, gclk, grst, gena
   );
   
   output [31:0] rREGA, rREGB;
   output [31:0] rDWBDI;
   input [5:0] 	 rOPC;   
   input [4:0] 	 rRA, rRB, rRW, rRD;
   input [1:0] 	 rMXDST;
   input [31:2]  rPCLNK;
   input [31:0]  rRESULT;
   input [3:0] 	 rDWBSEL;   
   input 	 rBRA, rDLY;   
   
   
   output [31:0] dwb_dat_o;   
   input [31:0]  dwb_dat_i;   

   
   output [31:0] fsl_dat_o;
   input [31:0]	 fsl_dat_i;   
   
   
   input 	 gclk, grst, gena;   

   
   
   

   wire [31:0] 	 wDWBDI = dwb_dat_i; 
   wire [31:0] 	 wFSLDI = fsl_dat_i; 
    
   reg [31:0] 	 rDWBDI;
   reg [1:0] 	 rSIZ;
   
   always @(/*AUTOSENSE*/rDWBSEL or wDWBDI or wFSLDI) begin
      /* 51.2
       case (rSIZ)
        
        2'o3: rDWBDI <= wFSLDI;	
        
        2'o2: rDWBDI <= wDWBDI;
	
	2'o1: case (rRESULT[1])
		1'b0: rDWBDI <= {16'd0, wDWBDI[31:16]};
		1'b1: rDWBDI <= {16'd0, wDWBDI[15:0]};		
	      endcase 
	
	2'o0: case (rRESULT[1:0])
		2'o0: rDWBDI <= {24'd0, wDWBDI[31:24]};
		2'o1: rDWBDI <= {24'd0, wDWBDI[23:16]};
		2'o2: rDWBDI <= {24'd0, wDWBDI[15:8]};
		2'o3: rDWBDI <= {24'd0, wDWBDI[7:0]};
	      endcase 
      endcase 
      */
      
      /* 50.6
      case ({rSIZ, rRESULT[1:0]})
	
	4'hC, 4'hD, 4'hE, 4'hF: rDWBDI <= wFSLDI;	
	
	4'h8: rDWBDI <= wDWBDI;
	
	4'h4: rDWBDI <= {16'd0, wDWBDI[31:16]};
	4'h6: rDWBDI <= {16'd0, wDWBDI[15:0]};		
	
	4'h0: rDWBDI <= {24'd0, wDWBDI[31:24]};
	4'h1: rDWBDI <= {24'd0, wDWBDI[23:16]};
	4'h2: rDWBDI <= {24'd0, wDWBDI[15:8]};
	4'h3: rDWBDI <= {24'd0, wDWBDI[7:0]};
	default: rDWBDI <= 32'hX;	
      endcase 
      */

      
      case (rDWBSEL)
	
	4'h8: rDWBDI <= {24'd0, wDWBDI[31:24]};
	4'h4: rDWBDI <= {24'd0, wDWBDI[23:16]};
	4'h2: rDWBDI <= {24'd0, wDWBDI[15:8]};
	4'h1: rDWBDI <= {24'd0, wDWBDI[7:0]};
	
	4'hC: rDWBDI <= {16'd0, wDWBDI[31:16]};
	4'h3: rDWBDI <= {16'd0, wDWBDI[15:0]};
	
	4'hF: rDWBDI <= wDWBDI;
	
	4'h0: rDWBDI <= wFSLDI;       
	
	default: rDWBDI <= 32'hX;       
      endcase
       
   end

   always @(posedge gclk)
     if (grst) begin
	/*AUTORESET*/
	
	rSIZ <= 2'h0;
	
     end else if (gena) begin
	rSIZ <= rOPC[1:0];	
     end
   
   
   
   
   
   reg [31:0] 	 mARAM[0:31],
		 mBRAM[0:31],
		 mDRAM[0:31];

   wire [31:0] 	 rREGW = mDRAM[rRW];   
   wire [31:0] 	 rREGD = mDRAM[rRD];   
   assign 	 rREGA = mARAM[rRA];
   assign 	 rREGB = mBRAM[rRB];

   wire 	 fRDWE = |rRW;   
   
   reg [31:0] 	 xWDAT;

   always @(/*AUTOSENSE*/rDWBDI or rMXDST or rPCLNK or rREGW
	    or rRESULT)
     case (rMXDST)
       2'o2: xWDAT <= rDWBDI;
       2'o1: xWDAT <= {rPCLNK, 2'o0};
       2'o0: xWDAT <= rRESULT;       
       2'o3: xWDAT <= rREGW; 
     endcase 
   
   always @(posedge gclk)
     if (grst | fRDWE) begin
	mARAM[rRW] <= xWDAT;
	mBRAM[rRW] <= xWDAT;
	mDRAM[rRW] <= xWDAT;	
     end

   
   
   

   reg [31:0] 	 rDWBDO, xDWBDO;
   
   wire [31:0] 	 xFSL;   
   wire 	 fFFWD_M = (rRA == rRW) & (rMXDST == 2'o2) & fRDWE;
   wire 	 fFFWD_R = (rRA == rRW) & (rMXDST == 2'o0) & fRDWE;   
   
   assign 	 fsl_dat_o = rDWBDO;
   assign 	 xFSL = (fFFWD_M) ? rDWBDI :
			(fFFWD_R) ? rRESULT :
			rREGA;   

   wire [31:0] 	 xDST;   
   wire 	 fDFWD_M = (rRW == rRD) & (rMXDST == 2'o2) & fRDWE;
   wire 	 fDFWD_R = (rRW == rRD) & (rMXDST == 2'o0) & fRDWE;   
   
   assign 	 dwb_dat_o = rDWBDO;
   assign 	 xDST = (fDFWD_M) ? rDWBDI :
			(fDFWD_R) ? rRESULT :
			rREGD;   
   
   always @(/*AUTOSENSE*/rOPC or xDST or xFSL)
     case (rOPC[1:0])
       
       2'h0: xDWBDO <= {(4){xDST[7:0]}};
       
       2'h1: xDWBDO <= {(2){xDST[15:0]}};
       
       2'h2: xDWBDO <= xDST;
       
       2'h3: xDWBDO <= xFSL;       
       
     endcase 

   always @(posedge gclk)
     if (grst) begin
	/*AUTORESET*/
	
	rDWBDO <= 32'h0;
	
     end else if (gena) begin
	rDWBDO <= #1 xDWBDO;	
     end
   
   
   
   
   
   integer i;
   initial begin
      for (i=0; i<32; i=i+1) begin
	 mARAM[i] <= $random;
	 mBRAM[i] <= $random;
	 mDRAM[i] <= $random;
      end
   end
   
   
   
   
endmodule 

/* $Id: top.v,v 1.2 2008-06-06 09:36:02 sybreon Exp $
**
** AEMB EDK 3.2 Compatible Core
** Copyright (C) 2004-2007 Shawn Tan Ser Ngiap <shawn.tan@aeste.net>
**  
** This file is part of AEMB.
**
** AEMB is free software: you can redistribute it and/or modify it
** under the terms of the GNU Lesser General Public License as
** published by the Free Software Foundation, either version 3 of the
** License, or (at your option) any later version.
**
** AEMB is distributed in the hope that it will be useful, but WITHOUT
** ANY WARRANTY; without even the implied warranty of MERCHANTABILITY
** or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU Lesser General
** Public License for more details.
**
** You should have received a copy of the GNU Lesser General Public
** License along with AEMB. If not, see <http:
*/

module top (/*AUTOARG*/
   
   iwb_stb_o, iwb_adr_o, fsl_wre_o, fsl_tag_o, fsl_stb_o, fsl_dat_o,
   fsl_adr_o, dwb_wre_o, dwb_stb_o, dwb_sel_o, dwb_dat_o, dwb_adr_o,
   
   sys_rst_i, sys_int_i, sys_clk_i, iwb_dat_i, iwb_ack_i, fsl_dat_i,
   fsl_ack_i, dwb_dat_i, dwb_ack_i
   );
   
   parameter IW = 32; 
   parameter DW = 32; 

   
   parameter MUL = 1; 
   parameter BSF = 1; 
      
   /*AUTOOUTPUT*/
   
   output [DW-1:2]	dwb_adr_o;		
   output [31:0]	dwb_dat_o;		
   output [3:0]		dwb_sel_o;		
   output		dwb_stb_o;		
   output		dwb_wre_o;		
   output [6:2]		fsl_adr_o;		
   output [31:0]	fsl_dat_o;		
   output		fsl_stb_o;		
   output [1:0]		fsl_tag_o;		
   output		fsl_wre_o;		
   output [IW-1:2]	iwb_adr_o;		
   output		iwb_stb_o;		
   
   /*AUTOINPUT*/
   
   input		dwb_ack_i;		
   input [31:0]		dwb_dat_i;		
   input		fsl_ack_i;		
   input [31:0]		fsl_dat_i;		
   input		iwb_ack_i;		
   input [31:0]		iwb_dat_i;		
   input		sys_clk_i;		
   input		sys_int_i;		
   input		sys_rst_i;		
   
   /*AUTOWIRE*/

   aeMB_edk32
     #(/*AUTOINSTPARAM*/
       
       .IW				(IW),
       .DW				(DW),
       .MUL				(MUL),
       .BSF				(BSF))
   cpu
     (/*AUTOINST*/
      
      .dwb_adr_o			(dwb_adr_o[DW-1:2]),
      .dwb_dat_o			(dwb_dat_o[31:0]),
      .dwb_sel_o			(dwb_sel_o[3:0]),
      .dwb_stb_o			(dwb_stb_o),
      .dwb_wre_o			(dwb_wre_o),
      .fsl_adr_o			(fsl_adr_o[6:2]),
      .fsl_dat_o			(fsl_dat_o[31:0]),
      .fsl_stb_o			(fsl_stb_o),
      .fsl_tag_o			(fsl_tag_o[1:0]),
      .fsl_wre_o			(fsl_wre_o),
      .iwb_adr_o			(iwb_adr_o[IW-1:2]),
      .iwb_stb_o			(iwb_stb_o),
      
      .dwb_ack_i			(dwb_ack_i),
      .dwb_dat_i			(dwb_dat_i[31:0]),
      .fsl_ack_i			(fsl_ack_i),
      .fsl_dat_i			(fsl_dat_i[31:0]),
      .iwb_ack_i			(iwb_ack_i),
      .iwb_dat_i			(iwb_dat_i[31:0]),
      .sys_int_i			(sys_int_i),
      .sys_clk_i			(sys_clk_i),
      .sys_rst_i			(sys_rst_i));
   
   
   
   
   wire [IW-1:0] 	iwb_adr = {iwb_adr_o, 2'd0};
   wire [DW-1:0] 	dwb_adr = {dwb_adr_o,2'd0};   
   wire [1:0] 		wBRA = {cpu.rBRA, cpu.rDLY};   
   wire [3:0] 		wMSR = {cpu.xecu.rMSR_BIP, cpu.xecu.rMSR_C, cpu.xecu.rMSR_IE, cpu.xecu.rMSR_BE};


   `ifdef AEMB_SIM_KERNEL
   always @(posedge cpu.gclk) begin
      if (cpu.gena) begin
	 
	 $write ("\n", ($stime/10));
	 $writeh (" PC=", iwb_adr );
	 $writeh ("\t");
	 
	 case (wBRA)
	   2'b00: $write(" ");
	   2'b01: $write(".");	
	   2'b10: $write("-");
	   2'b11: $write("+");	
	 endcase 
      
	 case (cpu.rOPC)
	   6'o00: if (cpu.rRD == 0) $write("   "); else $write("ADD");
	   6'o01: $write("RSUB");	
	   6'o02: $write("ADDC");	
	   6'o03: $write("RSUBC");	
	   6'o04: $write("ADDK");	
	   6'o05: case (cpu.rIMM[1:0])
		    2'o0: $write("RSUBK");	
		    2'o1: $write("CMP");	
		    2'o3: $write("CMPU");	
		    default: $write("XXX");
		  endcase 
	   6'o06: $write("ADDKC");	
	   6'o07: $write("RSUBKC");	
	   
	   6'o10: $write("ADDI");	
	   6'o11: $write("RSUBI");	
	   6'o12: $write("ADDIC");	
	   6'o13: $write("RSUBIC");	
	   6'o14: $write("ADDIK");	
	   6'o15: $write("RSUBIK");	
	   6'o16: $write("ADDIKC");	
	   6'o17: $write("RSUBIKC");	
	   
	   6'o20: $write("MUL");	
	   6'o21: case (cpu.rALT[10:9])
		    2'o0: $write("BSRL");		 
		    2'o1: $write("BSRA");		 
		    2'o2: $write("BSLL");		 
		    default: $write("XXX");		 
		  endcase 
	   6'o22: $write("IDIV");	
	   
	   6'o30: $write("MULI");	
	   6'o31: case (cpu.rALT[10:9])
		    2'o0: $write("BSRLI");		 
		    2'o1: $write("BSRAI");		 
		    2'o2: $write("BSLLI");		 
		    default: $write("XXX");		 
		  endcase 
	   6'o33: case (cpu.rRB[4:2])
		    3'o0: $write("GET");
		    3'o4: $write("PUT");		 
		    3'o2: $write("NGET");
		    3'o6: $write("NPUT");		 
		    3'o1: $write("CGET");
		    3'o5: $write("CPUT");		 
		    3'o3: $write("NCGET");
		    3'o7: $write("NCPUT");		 
		  endcase 
	   
	   6'o40: $write("OR");
	   6'o41: $write("AND");	
	   6'o42: if (cpu.rRD == 0) $write("   "); else $write("XOR");
	   6'o43: $write("ANDN");	
	   6'o44: case (cpu.rIMM[6:5])
		    2'o0: $write("SRA");
		    2'o1: $write("SRC");
		    2'o2: $write("SRL");
		    2'o3: if (cpu.rIMM[0]) $write("SEXT16"); else $write("SEXT8");		 
		  endcase 
	   
	   6'o45: $write("MOV");	
	   6'o46: case (cpu.rRA[3:2])
		    3'o0: $write("BR");		 
		    3'o1: $write("BRL");		 
		    3'o2: $write("BRA");		 
		    3'o3: $write("BRAL");		 
		  endcase 
	   
	   6'o47: case (cpu.rRD[2:0])
		    3'o0: $write("BEQ");	
		    3'o1: $write("BNE");	
		    3'o2: $write("BLT");	
		    3'o3: $write("BLE");	
		    3'o4: $write("BGT");	
		    3'o5: $write("BGE");
		    default: $write("XXX");		 
		  endcase 
	   
	   6'o50: $write("ORI");	
	   6'o51: $write("ANDI");	
	   6'o52: $write("XORI");	
	   6'o53: $write("ANDNI");	
	   6'o54: $write("IMMI");	
	   6'o55: case (cpu.rRD[1:0])
		    2'o0: $write("RTSD");
		    2'o1: $write("RTID");
		    2'o2: $write("RTBD");
		    default: $write("XXX");		 
		  endcase 
	   6'o56: case (cpu.rRA[3:2])
		    3'o0: $write("BRI");		 
		    3'o1: $write("BRLI");		 
		    3'o2: $write("BRAI");		 
		    3'o3: $write("BRALI");		 
		  endcase 
	   6'o57: case (cpu.rRD[2:0])
		    3'o0: $write("BEQI");	
		    3'o1: $write("BNEI");	
		    3'o2: $write("BLTI");	
		    3'o3: $write("BLEI");	
		    3'o4: $write("BGTI");	
		    3'o5: $write("BGEI");	
		    default: $write("XXX");		 
		  endcase 
	   
	   6'o60: $write("LBU");	
	   6'o61: $write("LHU");	
	   6'o62: $write("LW");	
	   6'o64: $write("SB");	
	   6'o65: $write("SH");	
	   6'o66: $write("SW");	
	   
	   6'o70: $write("LBUI");	
	   6'o71: $write("LHUI");	
	   6'o72: $write("LWI");	
	   6'o74: $write("SBI");	
	   6'o75: $write("SHI");	
	   6'o76: $write("SWI");
	   
	   default: $write("XXX");	
	 endcase 
	 
	 case (cpu.rOPC[3])
	   1'b1: $writeh("\tr",cpu.rRD,", r",cpu.rRA,", h",cpu.rIMM);
	   1'b0: $writeh("\tr",cpu.rRD,", r",cpu.rRA,", r",cpu.rRB,"  ");	
	 endcase 
	 
	 
	 
	 $write("\t");
	 $writeh(" A=",cpu.xecu.rOPA);
	 $writeh(" B=",cpu.xecu.rOPB);
	 
	 case (cpu.rMXALU)
	   3'o0: $write(" ADD");
	   3'o1: $write(" LOG");
	   3'o2: $write(" SFT");
	   3'o3: $write(" MOV");
	   3'o4: $write(" MUL");
	   3'o5: $write(" BSF");
	   default: $write(" XXX");
	 endcase 
	 $writeh("=h",cpu.xecu.xRESULT);
	 
	 
	 $writeh("\tSR=", wMSR," ");
	 
	 if (cpu.regf.fRDWE) begin
	    case (cpu.rMXDST)
	      2'o2: begin
		 if (dwb_stb_o) $writeh("R",cpu.rRW,"=RAM(h",cpu.regf.xWDAT,")");
		 if (fsl_stb_o) $writeh("R",cpu.rRW,"=FSL(h",cpu.regf.xWDAT,")");
	      end
	      2'o1: $writeh("R",cpu.rRW,"=LNK(h",cpu.regf.xWDAT,")");
	      2'o0: $writeh("R",cpu.rRW,"=ALU(h",cpu.regf.xWDAT,")");
	    endcase 
	 end
	 
	 
	 if (dwb_stb_o & dwb_wre_o) begin
	    $writeh("RAM(", dwb_adr ,")=", dwb_dat_o);
	    case (dwb_sel_o)
	      4'hF: $write(":L");
	      4'h3,4'hC: $write(":W");
	      4'h1,4'h2,4'h4,4'h8: $write(":B");
	    endcase 
	    
	 end
	 
      end 
      
   end 
   `endif 
   
   
   
endmodule 

/* 
 $Log: not supported by cvs2svn $
 Revision 1.1  2007/12/23 20:40:45  sybreon
 Abstracted simulation kernel (top) to split simulation models from synthesis models.
 
 */
/* $Id: aeMB_xecu.v,v 1.12 2008-05-11 13:48:46 sybreon Exp $
**
** AEMB MAIN EXECUTION ALU
** Copyright (C) 2004-2007 Shawn Tan Ser Ngiap <shawn.tan@aeste.net>
**  
** This file is part of AEMB.
**
** AEMB is free software: you can redistribute it and/or modify it
** under the terms of the GNU Lesser General Public License as
** published by the Free Software Foundation, either version 3 of the
** License, or (at your option) any later version.
**
** AEMB is distributed in the hope that it will be useful, but WITHOUT
** ANY WARRANTY; without even the implied warranty of MERCHANTABILITY
** or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU Lesser General
** Public License for more details.
**
** You should have received a copy of the GNU Lesser General Public
** License along with AEMB. If not, see <http:
*/

module aeMB_xecu (/*AUTOARG*/
   
   dwb_adr_o, dwb_sel_o, fsl_adr_o, fsl_tag_o, rRESULT, rDWBSEL,
   rMSR_IE, rMSR_BIP,
   
   rREGA, rREGB, rMXSRC, rMXTGT, rRA, rRB, rMXALU, rBRA, rDLY, rALT,
   rSTALL, rSIMM, rIMM, rOPC, rRD, rDWBDI, rPC, gclk, grst, gena
   );
   parameter DW=32;

   parameter MUL=0;
   parameter BSF=0;   
   
   
   output [DW-1:2] dwb_adr_o;
   output [3:0]    dwb_sel_o;

   
   output [6:2]   fsl_adr_o;
   output [1:0]   fsl_tag_o;   
   
   
   output [31:0]   rRESULT;
   output [3:0]    rDWBSEL;   
   output 	   rMSR_IE;
   output 	   rMSR_BIP;
   input [31:0]    rREGA, rREGB;
   input [1:0] 	   rMXSRC, rMXTGT;
   input [4:0] 	   rRA, rRB;
   input [2:0] 	   rMXALU;
   input 	   rBRA, rDLY;
   input [10:0]    rALT;   

   input 	   rSTALL;   
   input [31:0]    rSIMM;
   input [15:0]    rIMM;
   input [5:0] 	   rOPC;
   input [4:0] 	   rRD;   
   input [31:0]    rDWBDI;
   input [31:2]    rPC;   
   
   
   input 	   gclk, grst, gena;

   reg 		   rMSR_C, xMSR_C;
   reg 		   rMSR_IE, xMSR_IE;
   reg 		   rMSR_BE, xMSR_BE;
   reg 		   rMSR_BIP, xMSR_BIP;
   
   wire 	   fSKIP = rBRA & !rDLY;

   

   reg [31:0] 	   rOPA, rOPB;
   always @(/*AUTOSENSE*/rDWBDI or rMXSRC or rPC or rREGA or rRESULT)
     case (rMXSRC)
       2'o0: rOPA <= rREGA;
       2'o1: rOPA <= rRESULT;
       2'o2: rOPA <= rDWBDI;
       2'o3: rOPA <= {rPC, 2'o0};       
     endcase 
   
   always @(/*AUTOSENSE*/rDWBDI or rMXTGT or rREGB or rRESULT or rSIMM)
     case (rMXTGT)
       2'o0: rOPB <= rREGB;
       2'o1: rOPB <= rRESULT;
       2'o2: rOPB <= rDWBDI;
       2'o3: rOPB <= rSIMM;       
     endcase 

   

   reg 		    rRES_ADDC;
   reg [31:0] 	    rRES_ADD;
   
   wire [31:0] 		wADD;
   wire 		wADC;

   wire 		fCCC = !rOPC[5] & rOPC[1]; 
   wire 		fSUB = !rOPC[5] & rOPC[0]; 
   wire 		fCMP = !rOPC[3] & rIMM[1]; 
   wire 		wCMP = (fCMP) ? !wADC : wADD[31]; 
   
   wire [31:0] 		wOPA = (fSUB) ? ~rOPA : rOPA;
   wire 		wOPC = (fCCC) ? rMSR_C : fSUB;
   
   assign 		{wADC, wADD} = (rOPB + wOPA) + wOPC; 
   
   always @(/*AUTOSENSE*/wADC or wADD or wCMP) begin
      {rRES_ADDC, rRES_ADD} <= #1 {wADC, wCMP, wADD[30:0]}; 
   end
   
   

   reg [31:0] 	    rRES_LOG;
   always @(/*AUTOSENSE*/rOPA or rOPB or rOPC)
     case (rOPC[1:0])
       2'o0: rRES_LOG <= #1 rOPA | rOPB;
       2'o1: rRES_LOG <= #1 rOPA & rOPB;
       2'o2: rRES_LOG <= #1 rOPA ^ rOPB;
       2'o3: rRES_LOG <= #1 rOPA & ~rOPB;       
     endcase 

   
   
   reg [31:0] 	    rRES_SFT;
   reg 		    rRES_SFTC;
   
   always @(/*AUTOSENSE*/rIMM or rMSR_C or rOPA)
     case (rIMM[6:5])
       2'o0: {rRES_SFT, rRES_SFTC} <= #1 {rOPA[31],rOPA[31:0]};
       2'o1: {rRES_SFT, rRES_SFTC} <= #1 {rMSR_C,rOPA[31:0]};
       2'o2: {rRES_SFT, rRES_SFTC} <= #1 {1'b0,rOPA[31:0]};
       2'o3: {rRES_SFT, rRES_SFTC} <= #1 (rIMM[0]) ? { {(16){rOPA[15]}}, rOPA[15:0], rMSR_C} :
				      { {(24){rOPA[7]}}, rOPA[7:0], rMSR_C};
     endcase 

   
   
   wire [31:0] 	    wMSR = {rMSR_C, 3'o0, 
			    20'h0ED32, 
			    4'h0, rMSR_BIP, rMSR_C, rMSR_IE, rMSR_BE};      
   wire 	    fMFSR = (rOPC == 6'o45) & !rIMM[14] & rIMM[0];
   wire 	    fMFPC = (rOPC == 6'o45) & !rIMM[14] & !rIMM[0];
   reg [31:0] 	    rRES_MOV;
   always @(/*AUTOSENSE*/fMFPC or fMFSR or rOPA or rOPB or rPC or rRA
	    or wMSR)
     rRES_MOV <= (fMFSR) ? wMSR :
		 (fMFPC) ? rPC :
		 (rRA[3]) ? rOPB : 
		 rOPA;   
   
   
   
   
   reg [31:0] 	    rRES_MUL, rRES_MUL0, xRES_MUL;
   always @(/*AUTOSENSE*/rOPA or rOPB) begin
      xRES_MUL <= (rOPA * rOPB);
   end

   always @(posedge gclk)
     if (grst) begin
	/*AUTORESET*/
	
	rRES_MUL <= 32'h0;
	
     end else if (rSTALL) begin
	rRES_MUL <= #1 xRES_MUL;	
     end

   
   

   reg [31:0] 	 rRES_BSF;
   reg [31:0] 	 xBSRL, xBSRA, xBSLL;
   
   
   always @(/*AUTOSENSE*/rOPA or rOPB)
     xBSLL <= rOPA << rOPB[4:0];
   
   
   always @(/*AUTOSENSE*/rOPA or rOPB)
     xBSRL <= rOPA >> rOPB[4:0];

   
   always @(/*AUTOSENSE*/rOPA or rOPB)
     case (rOPB[4:0])
       5'd00: xBSRA <= rOPA;
       5'd01: xBSRA <= {{(1){rOPA[31]}}, rOPA[31:1]};
       5'd02: xBSRA <= {{(2){rOPA[31]}}, rOPA[31:2]};
       5'd03: xBSRA <= {{(3){rOPA[31]}}, rOPA[31:3]};
       5'd04: xBSRA <= {{(4){rOPA[31]}}, rOPA[31:4]};
       5'd05: xBSRA <= {{(5){rOPA[31]}}, rOPA[31:5]};
       5'd06: xBSRA <= {{(6){rOPA[31]}}, rOPA[31:6]};
       5'd07: xBSRA <= {{(7){rOPA[31]}}, rOPA[31:7]};
       5'd08: xBSRA <= {{(8){rOPA[31]}}, rOPA[31:8]};
       5'd09: xBSRA <= {{(9){rOPA[31]}}, rOPA[31:9]};
       5'd10: xBSRA <= {{(10){rOPA[31]}}, rOPA[31:10]};
       5'd11: xBSRA <= {{(11){rOPA[31]}}, rOPA[31:11]};
       5'd12: xBSRA <= {{(12){rOPA[31]}}, rOPA[31:12]};
       5'd13: xBSRA <= {{(13){rOPA[31]}}, rOPA[31:13]};
       5'd14: xBSRA <= {{(14){rOPA[31]}}, rOPA[31:14]};
       5'd15: xBSRA <= {{(15){rOPA[31]}}, rOPA[31:15]};
       5'd16: xBSRA <= {{(16){rOPA[31]}}, rOPA[31:16]};
       5'd17: xBSRA <= {{(17){rOPA[31]}}, rOPA[31:17]};
       5'd18: xBSRA <= {{(18){rOPA[31]}}, rOPA[31:18]};
       5'd19: xBSRA <= {{(19){rOPA[31]}}, rOPA[31:19]};
       5'd20: xBSRA <= {{(20){rOPA[31]}}, rOPA[31:20]};
       5'd21: xBSRA <= {{(21){rOPA[31]}}, rOPA[31:21]};
       5'd22: xBSRA <= {{(22){rOPA[31]}}, rOPA[31:22]};
       5'd23: xBSRA <= {{(23){rOPA[31]}}, rOPA[31:23]};
       5'd24: xBSRA <= {{(24){rOPA[31]}}, rOPA[31:24]};
       5'd25: xBSRA <= {{(25){rOPA[31]}}, rOPA[31:25]};
       5'd26: xBSRA <= {{(26){rOPA[31]}}, rOPA[31:26]};
       5'd27: xBSRA <= {{(27){rOPA[31]}}, rOPA[31:27]};
       5'd28: xBSRA <= {{(28){rOPA[31]}}, rOPA[31:28]};
       5'd29: xBSRA <= {{(29){rOPA[31]}}, rOPA[31:29]};
       5'd30: xBSRA <= {{(30){rOPA[31]}}, rOPA[31:30]};
       5'd31: xBSRA <= {{(31){rOPA[31]}}, rOPA[31]};
     endcase 

   reg [31:0] 	 rBSRL, rBSRA, rBSLL;

   always @(posedge gclk)
     if (grst) begin
	/*AUTORESET*/
	
	rBSLL <= 32'h0;
	rBSRA <= 32'h0;
	rBSRL <= 32'h0;
	
     end else if (rSTALL) begin
	rBSRL <= #1 xBSRL;
	rBSRA <= #1 xBSRA;
	rBSLL <= #1 xBSLL;	
     end
   
   always @(/*AUTOSENSE*/rALT or rBSLL or rBSRA or rBSRL)
     case (rALT[10:9])
       2'd0: rRES_BSF <= rBSRL;
       2'd1: rRES_BSF <= rBSRA;       
       2'd2: rRES_BSF <= rBSLL;
       default: rRES_BSF <= 32'hX;       
     endcase 
   
   
   
   
   
   wire 	   fMTS = (rOPC == 6'o45) & rIMM[14] & !fSKIP;
   wire 	   fADDC = ({rOPC[5:4], rOPC[2]} == 3'o0);
   
   always @(/*AUTOSENSE*/fADDC or fMTS or fSKIP or rMSR_C or rMXALU
	    or rOPA or rRES_ADDC or rRES_SFTC)
     
     if (fSKIP) begin
	xMSR_C <= rMSR_C;
     end else
       case (rMXALU)
	 3'o0: xMSR_C <= (fADDC) ? rRES_ADDC : rMSR_C;	 
	 3'o1: xMSR_C <= rMSR_C; 
	 3'o2: xMSR_C <= rRES_SFTC; 
	 3'o3: xMSR_C <= (fMTS) ? rOPA[2] : rMSR_C;
	 3'o4: xMSR_C <= rMSR_C;	 
	 3'o5: xMSR_C <= rMSR_C;	 
	 default: xMSR_C <= 1'hX;       
       endcase 

   
   wire 	    fRTID = (rOPC == 6'o55) & rRD[0] & !fSKIP;   
   wire 	    fRTBD = (rOPC == 6'o55) & rRD[1] & !fSKIP;
   wire 	    fBRK = ((rOPC == 6'o56) | (rOPC == 6'o66)) & (rRA == 5'hC);
   wire 	    fINT = ((rOPC == 6'o56) | (rOPC == 6'o66)) & (rRA == 5'hE);
   
   always @(/*AUTOSENSE*/fINT or fMTS or fRTID or rMSR_IE or rOPA)
     xMSR_IE <= (fINT) ? 1'b0 :
		(fRTID) ? 1'b1 : 
		(fMTS) ? rOPA[1] :
		rMSR_IE;      
   
   always @(/*AUTOSENSE*/fBRK or fMTS or fRTBD or rMSR_BIP or rOPA)
     xMSR_BIP <= (fBRK) ? 1'b1 :
		 (fRTBD) ? 1'b0 : 
		 (fMTS) ? rOPA[3] :
		 rMSR_BIP;      
   
   always @(/*AUTOSENSE*/fMTS or rMSR_BE or rOPA)
     xMSR_BE <= (fMTS) ? rOPA[0] : rMSR_BE;      

   
   
   reg [31:0] 	   rRESULT, xRESULT;

   
   always @(/*AUTOSENSE*/fSKIP or rMXALU or rRES_ADD or rRES_BSF
	    or rRES_LOG or rRES_MOV or rRES_MUL or rRES_SFT)
     if (fSKIP) 
       /*AUTORESET*/
       
       xRESULT <= 32'h0;
       
     else
       case (rMXALU)
	 3'o0: xRESULT <= rRES_ADD;
	 3'o1: xRESULT <= rRES_LOG;
	 3'o2: xRESULT <= rRES_SFT;
	 3'o3: xRESULT <= rRES_MOV;
	 3'o4: xRESULT <= (MUL) ? rRES_MUL : 32'hX;	 
	 3'o5: xRESULT <= (BSF) ? rRES_BSF : 32'hX;	 
	 default: xRESULT <= 32'hX;       
       endcase 

   
   
   reg [3:0] 	    rDWBSEL, xDWBSEL;
   assign 	    dwb_adr_o = rRESULT[DW-1:2];
   assign 	    dwb_sel_o = rDWBSEL;

   always @(/*AUTOSENSE*/rOPC or wADD)
     case (rOPC[1:0])
       2'o0: case (wADD[1:0]) 
	       2'o0: xDWBSEL <= 4'h8;	       
	       2'o1: xDWBSEL <= 4'h4;	       
	       2'o2: xDWBSEL <= 4'h2;	       
	       2'o3: xDWBSEL <= 4'h1;	       
	     endcase 
       2'o1: xDWBSEL <= (wADD[1]) ? 4'h3 : 4'hC; 
       2'o2: xDWBSEL <= 4'hF; 
       2'o3: xDWBSEL <= 4'h0; 
     endcase 

   

   reg [14:2] 	    rFSLADR, xFSLADR;   
   
   assign 	    {fsl_adr_o, fsl_tag_o} = rFSLADR[8:2];

   always @(/*AUTOSENSE*/rALT or rRB) begin
      xFSLADR <= {rALT, rRB[3:2]};      
   end
   
   

   always @(posedge gclk)
     if (grst) begin
	/*AUTORESET*/
	
	rDWBSEL <= 4'h0;
	rFSLADR <= 13'h0;
	rMSR_BE <= 1'h0;
	rMSR_BIP <= 1'h0;
	rMSR_C <= 1'h0;
	rMSR_IE <= 1'h0;
	rRESULT <= 32'h0;
	
     end else if (gena) begin 
	rRESULT <= #1 xRESULT;
	rDWBSEL <= #1 xDWBSEL;
	rMSR_C <= #1 xMSR_C;
	rMSR_IE <= #1 xMSR_IE;	
	rMSR_BE <= #1 xMSR_BE;	
	rMSR_BIP <= #1 xMSR_BIP;
	rFSLADR <= #1 xFSLADR;
     end
   
endmodule 

/*
 $Log: not supported by cvs2svn $
 Revision 1.11  2008/01/19 15:57:36  sybreon
 Fix MTS during interrupt vectoring bug (reported by M. Ettus).

 Revision 1.10  2007/12/25 22:15:09  sybreon
 Stalls pipeline on MUL/BSF instructions results in minor speed improvements.

 Revision 1.9  2007/11/30 16:42:51  sybreon
 Minor code cleanup.

 Revision 1.8  2007/11/16 21:52:03  sybreon
 Added fsl_tag_o to FSL bus (tag either address or data).

 Revision 1.7  2007/11/14 22:14:34  sybreon
 Changed interrupt handling system (reported by M. Ettus).

 Revision 1.6  2007/11/10 16:39:38  sybreon
 Upgraded license to LGPLv3.
 Significant performance optimisations.

 Revision 1.5  2007/11/09 20:51:52  sybreon
 Added GET/PUT support through a FSL bus.

 Revision 1.4  2007/11/08 14:17:47  sybreon
 Parameterised optional components.

 Revision 1.3  2007/11/03 08:34:55  sybreon
 Minor code cleanup.

 Revision 1.2  2007/11/02 19:20:58  sybreon
 Added better (beta) interrupt support.
 Changed MSR_IE to disabled at reset as per MB docs.

 Revision 1.1  2007/11/02 03:25:41  sybreon
 New EDK 3.2 compatible design with optional barrel-shifter and multiplier.
 Fixed various minor data hazard bugs.
 Code compatible with -O0/1/2/3/s generated code.

*/


