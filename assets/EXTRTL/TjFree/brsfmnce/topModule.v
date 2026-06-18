`timescale 1ns / 1ps

module top #(
    parameter pAddr        = 10,            
    parameter pWidth       = 8,             
    parameter pRAMInitSize = 128,           
    parameter pFRAM_Init   = "RAMINIT.mif"  
)(
    input   Rst,                        
    input   Clk,                        
    
    input   Clr,                        
    
    input   WE,                         
    input   [(pWidth - 1):0] DI,        
    
    input   RE,                         
    output  reg [(pWidth - 1):0] DO,    
    output  reg ACK,                    
    
    output  reg FF,                     
    output  reg AF,                     
    output  HF,                         
    output  reg AE,                     
    output  reg EF,                     
    
    output  [pAddr:0] Cnt               
);


    reg     [(pWidth - 1):0] FRAM [((2**pAddr) - 1):0];
    
    reg     [(pAddr - 1):0] WPtr, RPtr, WCnt;
    
    wire    Wr, Rd, CE;



assign Wr = WE & ~FF;
assign Rd = RE & ~EF;
assign CE = Wr ^ Rd;


always @(posedge Clk)
begin
    if(Rst | Clr)
        ACK <= #1 0;
    else
        ACK <= #1 Rd;
end


always @(posedge Clk)
begin
    if(Rst)
        WPtr <= #1 pRAMInitSize;
    else if(Clr)
        WPtr <= #1 0;
    else if(Wr)
        WPtr <= #1 WPtr + 1;
end


always @(posedge Clk)
begin
    if(Rst | Clr)
        RPtr <= #1 0;
    else if(Rd)
        RPtr <= #1 RPtr + 1;
end


always @(posedge Clk)
begin
    if(Rst)
        WCnt <= #1 pRAMInitSize;
    else if(Clr)
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
        EF <= #1 (pRAMInitSize == 0);
    else if(Clr)
        EF <= #1 1;
    else if(CE)
        EF <= #1 ((WE) ? 0 : (~|Cnt[pAddr:1]));
end


always @(posedge Clk)
begin
    if(Rst)
        AE <= #1 (pRAMInitSize == 1);
    else if(Clr)
        AE <= #1 0;
    else if(CE)
        AE <= #1 (Rd & (~|Cnt[pAddr:2]) & Cnt[1] & ~Cnt[0]) | (Wr & EF);
end        


always @(posedge Clk)
begin
    if(Rst)
        FF <= #1 (pRAMInitSize == (1 << pAddr));
    else if(Clr)
        FF <= #1 0;
    else if(CE)
        FF <= #1 ((RE) ? 0 : (&WCnt));
end


always @(posedge Clk)
begin
    if(Rst)
        AF <= #1 (pRAMInitSize == ((1 << pAddr) - 1));
    else if(Clr)
        AF <= #1 0;
    else if(CE)
        AF <= #1 (Wr & (~Cnt[pAddr] & (&Cnt[(pAddr-1):1]) & ~Cnt[0]))
                 | (Rd & FF);
end        


assign HF = ~EF & (Cnt[pAddr] | Cnt[(pAddr - 1)]);


initial
    $readmemh(pFRAM_Init, FRAM, 0, ((1 << pAddr) - 1));

always @(posedge Clk)
begin
    if(Wr)
        FRAM[WPtr] <= #1 DI;
end

always @(posedge Clk)
begin
    DO <= #1 FRAM[RPtr];
end

endmodule



