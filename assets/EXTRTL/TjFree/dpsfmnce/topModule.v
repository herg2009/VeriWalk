
`timescale 1ns / 1ps


module top #( 
    parameter addr  = 4,                
    parameter width = 16,               
    parameter init  = "DPSFnmRAM.coe"   
)(
    input   Rst,
    input   Clk,
    input   WE,
    input   RE,
    input   [(width - 1):0] DI,
    output  [(width - 1):0] DO,
    output  FF,
    output  EF,
    output  HF,
    output  [addr:0] Cnt
);


localparam  depth = (2**addr);


    reg     [(width - 1):0] RAM [(depth - 1):0];
    
    reg     [ (addr - 1):0] A, DPRA;
    reg     [ (addr - 1):0] WCnt;
    reg     nEF, rFF;
    
    wire    Wr, Rd, CE;



assign Wr = WE & ~FF;
assign Rd = RE & ~EF;
assign CE = Wr ^ Rd;


always @(posedge Clk)
begin
    if(Rst)
        A <= #1 0;
    else if(Wr)
        A <= #1 A + 1;
end


always @(posedge Clk)
begin
    if(Rst)
       DPRA <= #1 0;
    else if(Rd)
        DPRA <= #1 DPRA + 1;
end


always @(posedge Clk)
begin
    if(Rst)
        WCnt <= #1 0;
    else if(Wr & ~Rd)
        WCnt <= #1 WCnt + 1;
    else if(Rd & ~Wr)
        WCnt <= #1 WCnt - 1;
end


assign Cnt = {FF, WCnt};


always @(posedge Clk)
begin
    if(Rst)
        nEF <= #1 0;
    else if(CE)
        nEF <= #1 ~(RE & (Cnt == 1));
end

assign EF = ~nEF;


always @(posedge Clk)
begin
    if(Rst)
        rFF <= #1 0;
    else if(CE)
        rFF <= #1 (WE & (&WCnt));
end

assign FF = rFF;


assign HF = Cnt[addr] | Cnt[(addr - 1)];


initial
  $readmemh(init, RAM, 0, (depth - 1));

always @(posedge Clk)
begin
    if(Wr) 
        RAM[A] <= #1 DI;    
end

assign DO = RAM[DPRA];      
        
endmodule
					


