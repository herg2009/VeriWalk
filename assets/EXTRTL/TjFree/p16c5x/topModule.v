
`timescale 1ns / 1ps


module top #(
    parameter pRstVector = 12'h7FF,         
    parameter pWDT_Size  = 20,              
    parameter pRAMA_Init = "Src/RAMA.coe",  
    parameter pRAMB_Init = "Src/RAMB.coe"   
)(
    input   POR,                

    input   Clk,                
    input   ClkEn,              

    input   MCLR,               
    input   T0CKI,              

    input   WDTE,               

    output  reg [11:0] PC,      
    input   [11:0] ROM,         
    
    output  WE_TRISA, WE_TRISB, WE_TRISC,   
    output  WE_PORTA, WE_PORTB, WE_PORTC,   
    output  RE_PORTA, RE_PORTB, RE_PORTC,   

    output  [7:0] IO_DO,        
    input   [7:0] IO_DI,        


    output  reg Rst,            

    output  reg [5:0] OPTION,   
    
    output  reg [11:0] IR,      
    output  [ 9:0] dIR,         
    output  [11:0] ALU_Op,      
    output  [ 8:0] KI,          
    output  Err,                

    output  reg Skip,           

    output  reg [11:0] TOS,     
    output  reg [11:0] NOS,     

    output  [7:0] W,            

    output  [7:0] FA,           
    output  [7:0] DO,           
    output  [7:0] DI,           

    output  reg [7:0] TMR0,     
    output  reg [7:0] FSR,      
    output  [7:0] STATUS,       

    output  T0CKI_Pls,          

    output  reg WDTClr,         
    output  reg [pWDT_Size-1:0] WDT, 
    output  reg WDT_TC,
    output  WDT_TO,             

    output  reg [7:0] PSCntr,   
    output  PSC_Pls             
);



localparam pINDF   = 5'b0_0000;     
localparam pTMR0   = 5'b0_0001;     
localparam pPCL    = 5'b0_0010;     
localparam pSTATUS = 5'b0_0011;     
localparam pFSR    = 5'b0_0100;     
localparam pPORTA  = 5'b0_0101;     
localparam pPORTB  = 5'b0_0110;     
localparam pPORTC  = 5'b0_0111;     


wire    Rst_M16C5x;         

wire    CE;                 

reg     [2:0] PA;           
reg     [7:0] SFR;          

wire    Rst_TO;             
reg     TO;                 
wire    Rst_PD;             
reg     PD;                 
reg     PwrDn;              


wire    [5:0] Addrs;
reg     [7:0] RAMA[ 7:0];   
reg     [7:0] RAMB[63:0];   

wire    T0CS;               
wire    T0SE;               
wire    PSA;                
wire    [2:0] PS;           

reg     [2:0] dT0CKI;       
reg     PSC_Out;            
reg     [1:0] dPSC_Out;     

wire    GOTO, CALL, RETLW;  
wire    WE_SLEEP, WE_WDTCLR;
wire    WE_OPTION;

wire    WE_TMR0;            
wire    WE_PCL;
wire    WE_STATUS;
wire    WE_FSR;

wire    WE_PSW;             


wire    C, DC, Z;       
wire    Z_Tst, g;       


assign CE = ClkEn & ~PwrDn;         

assign Rst_M16C5x = (POR | MCLR | WDT_TO);      

always @(posedge Clk or posedge Rst_M16C5x)
begin
    if(Rst_M16C5x)
        Rst <= #1 ~0;
    else if(CE)
        Rst <= #1  0;
end


always @(posedge Clk)
begin
    if(Rst)
        IR <= #1 0;
    else if(CE)
        IR <= #1 ROM;
end


P16C5x_IDec IDEC (
                .Rst(Rst),
                .Clk(Clk),
                .CE(CE),
                
                .DI(ROM),
                .Skip(Skip),

                .dIR(dIR),
                .ALU_Op(ALU_Op),
                .KI(KI),

                .Err(Err)
            );


P16C5x_ALU  ALU (
                .Rst(Rst),
                .Clk(Clk),
                .CE(CE),
                
                .ALU_Op(ALU_Op),
                
                .DI(DI),
                .KI(KI[7:0]),
                .WE_PSW(WE_PSW),

                .DO(DO),
                .Z_Tst(Z_Tst),
                .g(g),
                
                .W(W),
                
                .Z(Z),
                .DC(DC),
                .C(C)
            );


assign GOTO      = dIR[0];
assign CALL      = dIR[1];
assign RETLW     = dIR[2];
assign WE_SLEEP  = dIR[3];
assign WE_WDTCLR = dIR[4];
assign WE_TRISA  = dIR[5];
assign WE_TRISB  = dIR[6];
assign WE_TRISC  = dIR[7];
assign WE_OPTION = dIR[8];
assign LITERAL   = dIR[9];      


assign Tst = ALU_Op[8];

always @(*)
begin
    Skip <= WE_SLEEP | WE_PCL
            | ((Tst) ? ((ALU_Op[7] & ALU_Op[6]) ? g    : Z_Tst)
                     : ((GOTO | CALL | RETLW)   ? 1'b1 : 1'b0 ));
end


assign INDF = ALU_Op[10];
assign FA   = ((INDF) ? FSR
                      : ((KI[4]) ? {FSR[6:5], KI[4:0]}
                                 : {    2'b0, KI[4:0]}));


assign WE_F = ALU_Op[11];


assign WE_TMR0   =  WE_F & (FA[4:0] == pTMR0);
assign WE_PCL    =  WE_F & (FA[4:0] == pPCL);
assign WE_STATUS =  WE_F & (FA[4:0] == pSTATUS);
assign WE_FSR    =  WE_F & (FA[4:0] == pFSR);
assign WE_PORTA  =  WE_F & (FA[4:0] == pPORTA) & ~LITERAL;
assign WE_PORTB  =  WE_F & (FA[4:0] == pPORTB) & ~LITERAL;
assign WE_PORTC  =  WE_F & (FA[4:0] == pPORTC) & ~LITERAL;
assign RE_PORTA  = ~WE_F & (FA[4:0] == pPORTA) & ~LITERAL & ~WE_TRISA;
assign RE_PORTB  = ~WE_F & (FA[4:0] == pPORTB) & ~LITERAL & ~WE_TRISB;
assign RE_PORTC  = ~WE_F & (FA[4:0] == pPORTC) & ~LITERAL & ~WE_TRISC;


assign WE_PSW = WE_STATUS & (ALU_Op[5:4] == 2'b00) & (ALU_Op[8] == 1'b0);


assign Ld_PCL = CALL | WE_PCL;

always @(posedge Clk)
begin
    if(Rst)
        PC <= #1 pRstVector;    
    else if(CE)
        PC <= #1 (GOTO ? {PA, KI}
                       : (Ld_PCL ? {PA, 1'b0, DO}
                                 : (RETLW ? TOS : PC + 1)));
end


always @(posedge Clk)
begin
    if(POR)
        TOS <= #1 pRstVector;       
    else if(CE)
        TOS <= #1 (CALL ? PC : (RETLW ? NOS : TOS));
end

always @(posedge Clk)
begin
    if(POR)
        NOS <= #1 pRstVector;       
    else if(CE)
        NOS <= #1 (CALL ? TOS : NOS);
end


always @(posedge Clk)
begin
    if(POR)
        OPTION <= #1 8'b0011_1111;
    else if(CE)
        OPTION <= #1 ((WE_OPTION) ? W : OPTION);
end


always @(posedge Clk)
begin
    if(Rst)
        WDTClr <= #1 0;
    else
        WDTClr <= #1 (WE_WDTCLR | WE_SLEEP) & ~PwrDn;
end


assign Rst_TO = (POR | (MCLR & PD) | WE_WDTCLR);

always @(posedge Clk)
begin
    if(Rst_TO)
        TO <= #1  0;
    else if(WDT_TO)
        TO <= #1 ~0;
end


assign Rst_PD = POR | (WE_WDTCLR & ~PwrDn);

always @(posedge Clk)
begin
    if(Rst_PD)
        PD <= #1 0;
    else if(CE)
        PD <= #1 ((WE_SLEEP) ? 1'b1 : PD);
end


always @(posedge Clk)
begin
    if(Rst)
        PwrDn <= #1 0;
    else if(ClkEn)
        PwrDn <= #1 ((WE_SLEEP) ? 1'b1 : PwrDn);
end


assign Addrs = {FA[6:5], FA[3:0]};


assign WE_RAMA = WE_F & ~FA[4] & FA[3];

initial
  $readmemh(pRAMA_Init, RAMA, 0, 7);

always @(posedge Clk)
begin
    if(CE)
        if(WE_RAMA)
            RAMA[Addrs[2:0]] <= #1 DO;
end


assign WE_RAMB = WE_F & FA[4];

initial
  $readmemh(pRAMB_Init, RAMB, 0, 63);

always @(posedge Clk)
begin
    if(CE)
        if(WE_RAMB)
            RAMB[Addrs] <= #1 DO;
end


always @(posedge Clk)
begin
    if(POR)
        PA  <= #1 0;
    else if(CE)
        PA  <= #1 ((WE_STATUS) ? DO[7:5] : PA);
end

always @(posedge Clk)
begin
    if(POR)
        FSR <= #1 0;
    else if(CE)
        FSR <= #1 ((WE_FSR) ? DO : FSR);
end


assign STATUS = {PA, ~TO, ~PD, Z, DC, C};


always @(*)
begin
    case(FA[2:0])
        3'b000 :  SFR <= 0;
        3'b001 :  SFR <= TMR0;
        3'b010 :  SFR <= PC[7:0];
        3'b011 :  SFR <= STATUS;
        3'b100 :  SFR <= FSR;
        3'b101 :  SFR <= IO_DI;
        3'b110 :  SFR <= IO_DI;
        3'b111 :  SFR <= IO_DI;
    endcase
end


assign DI = (FA[4] ? RAMB[Addrs] : (FA[3] ? RAMA[Addrs[2:0]] : SFR));


assign IO_DO = ((|{WE_TRISA, WE_TRISB, WE_TRISC}) ? W : DO);


assign T0CS = OPTION[5];     
assign T0SE = OPTION[4];     
assign PSA  = OPTION[3];     
assign PS   = OPTION[2:0];   


assign WDT_Rst = Rst | WDTClr;

always @(posedge Clk)
begin
    if(WDT_Rst)
        WDT <= #1 0;
    else if(WDTE)
        WDT <= #1 WDT + 1;
end


always @(posedge Clk)
begin
    if(WDT_Rst)
        WDT_TC <= #1 0;
    else
        WDT_TC <= #1 &WDT;
end


assign WDT_TO = (PSA ? PSC_Pls : WDT_TC);


always @(posedge Clk)
begin
    if(Rst)
        dT0CKI <= #1 0;
    else begin
        dT0CKI[0] <= #1 T0CKI;                              
        dT0CKI[1] <= #1 dT0CKI[0];                          
        dT0CKI[2] <= #1 (T0SE ? (dT0CKI[1] & ~dT0CKI[0])    
                              : (dT0CKI[0] & ~dT0CKI[1]));  
    end
end

assign T0CKI_Pls = dT0CKI[2]; 


assign Tmr0_CS = (T0CS ? T0CKI_Pls : CE);


assign Rst_PSC   = (PSA ? WDTClr : WE_TMR0) | Rst;
assign CE_PSCntr = (PSA ? WDT_TC : Tmr0_CS);

always @(posedge Clk)
begin
    if(Rst_PSC)
        PSCntr <= #1 0;
    else if(CE_PSCntr)
        PSCntr <= #1 PSCntr + 1;
end


always @(*)
begin
    case (PS)
        3'b000 : PSC_Out <= PSCntr[0];
        3'b001 : PSC_Out <= PSCntr[1];
        3'b010 : PSC_Out <= PSCntr[2];
        3'b011 : PSC_Out <= PSCntr[3];
        3'b100 : PSC_Out <= PSCntr[4];
        3'b101 : PSC_Out <= PSCntr[5];
        3'b110 : PSC_Out <= PSCntr[6];
        3'b111 : PSC_Out <= PSCntr[7];
    endcase
end


always @(posedge Clk)
begin
    if(POR)
        dPSC_Out <= #1 0;
    else begin
        dPSC_Out[0] <= #1 PSC_Out;
        dPSC_Out[1] <= #1 PSC_Out & ~dPSC_Out[0];
    end
end

assign PSC_Pls = dPSC_Out[1];


assign CE_Tmr0 = (PSA ? Tmr0_CS : PSC_Pls);

always @(posedge Clk)
begin
    if(POR)
        TMR0 <= #1 0;
    else if(WE_TMR0)
        TMR0 <= #1 DO;
    else if(CE_Tmr0)
        TMR0 <= #1 TMR0 + 1;
end

endmodule


`timescale 1ns / 1ps


module P16C5x_ALU (
    input   Rst,
    input   Clk,
    input   CE,
    
    input   [11:0] ALU_Op,              
    input   WE_PSW,                     

    input   [7:0] DI,                   
    input   [7:0] KI,                   
    
    output  reg [7:0] DO,               
    output  Z_Tst,                      
    output  g,                          
    
    output  reg [7:0] W,                
    
    output  reg Z,                      
    output  reg DC,                     
    output  reg C                       
);


wire    [7:0] A, B, Y;

wire    [7:0] X;
wire    C3, C7;

wire    [1:0] LU_Op;
reg     [7:0] V;

wire    [1:0] S_Sel;
reg     [7:0] S;

wire    [2:0] Bit;
reg     [7:0] Msk;

wire    [7:0] U;
wire    [7:0] T;

wire    [1:0] D_Sel;


assign C_In  = ALU_Op[0];  
assign B_Inv = ALU_Op[1];  
assign B_Sel = ALU_Op[2];  
assign A_Sel = ALU_Op[3];  


assign A = ((A_Sel) ? KI : DI);
assign B = ((B_Sel) ?  W : 0 );
assign Y = ((B_Inv) ? ~B : B );


assign {C3, X[3:0]} = A[3:0] + Y[3:0] + C_In;
assign {C7, X[7:4]} = A[7:4] + Y[7:4] + C3;


assign LU_Op = ALU_Op[1:0];

always @(*)
begin
    case (LU_Op)
        2'b00 : V <= ~A;
        2'b01 : V <=  A | B;
        2'b10 : V <=  A & B;
        2'b11 : V <=  A ^ B;
    endcase
end


assign S_Sel = ALU_Op[1:0];

always @(*)
begin
    case (S_Sel)
        2'b00 : S <= B;                  
        2'b01 : S <= {A[3:0], A[7:4]};   
        2'b10 : S <= {C, A[7:1]};        
        2'b11 : S <= {A[6:0], C};        
    endcase
end


assign Bit = ALU_Op[2:0];
assign Set = ALU_Op[3];
assign Tst = ALU_Op[8];

always @(*)
begin
    case(Bit)
        3'b000  : Msk <= 8'b0000_0001;
        3'b001  : Msk <= 8'b0000_0010;
        3'b010  : Msk <= 8'b0000_0100;
        3'b011  : Msk <= 8'b0000_1000;
        3'b100  : Msk <= 8'b0001_0000;
        3'b101  : Msk <= 8'b0010_0000;
        3'b110  : Msk <= 8'b0100_0000;
        3'b111  : Msk <= 8'b1000_0000;
    endcase
end

assign U = ((Set) ? (DI | Msk) : (DI & ~Msk));

assign T = DI & Msk;
assign g = ((Tst) ? ((Set) ? |T : ~|T) 
                  : 1'b0              );


assign D_Sel = ALU_Op[7:6];

always @(posedge Clk)
begin
    if(Rst)
        DO <= #1 0;
    else
        case (D_Sel)
            2'b00 : DO <= #1 X;     
            2'b01 : DO <= #1 V;     
            2'b10 : DO <= #1 S;     
            2'b11 : DO <= #1 U;     
        endcase
end



assign WE_W = ALU_Op[9];

always @(posedge Clk)
begin
    if(Rst)
        W <= #1 8'b0;
    else if(CE)
        W <= #1 ((WE_W) ? DO : W);
end


assign Z_Sel = ALU_Op[5];
assign Z_Tst = ~|DO;

always @(posedge Clk)
begin
    if(Rst)
        Z <= #1 1'b0;
    else if(CE)
        Z <= #1 ((Z_Sel) ? Z_Tst 
                         : ((WE_PSW) ? DO[2] : Z));
end


assign DC_Sel = ALU_Op[5] & ALU_Op[4];

always @(posedge Clk)
begin
    if(Rst)
        DC <= #1 1'b0;
    else if(CE)
        DC <= #1 ((DC_Sel) ? C3 
                           : ((WE_PSW) ? DO[1] : DC));
end


assign C_Sel = ALU_Op[4];
assign S_Dir = ALU_Op[1] & ALU_Op[0];
assign C_Drv = ((~ALU_Op[7] & ~ALU_Op[6]) ? C7
                                          : ((S_Dir) ? A[7] : A[0]));

always @(posedge Clk)
begin
    if(Rst)
        C <= #1 1'b0;
    else if(CE)
        C <= #1 ((C_Sel) ? C_Drv 
                         : ((WE_PSW) ? DO[0] : C));
end

endmodule


`timescale 1ns / 1ps


module P16C5x_IDec(
    input   Rst,
    input   Clk,
    input   CE,
    
    input   [11:0] DI,
    input   Skip,

    output  reg [ 9:0] dIR,
    output  reg [11:0] ALU_Op,
    output  reg [ 8:0] KI,

    output  reg Err
);


reg     [ 9:0] ROM1;            
wire    [ 3:0] ROM1_Addr;       
reg     [11:0] ROM2;            
wire    [ 3:0] ROM2_Addr;       
reg     [11:0] ROM3;            
wire    [ 5:0] ROM3_Addr;       

wire    ROM1_Valid;             

wire    dErr;                   
wire    [11:0] dALU_Op;         


assign ROM1_Addr = {DI[11], (DI[11] ? DI[10:8] : DI[2:0])};

always @(*)
begin
    case(ROM1_Addr)
        4'b0000 : ROM1 <= 10'b0_0_0000_0000;   
        4'b0001 : ROM1 <= 10'b0_0_0000_0000;   
        4'b0010 : ROM1 <= 10'b0_1_0000_0000;   
        4'b0011 : ROM1 <= 10'b0_0_0000_1000;   
        4'b0100 : ROM1 <= 10'b0_0_0001_0000;   
        4'b0101 : ROM1 <= 10'b0_0_0010_0000;   
        4'b0110 : ROM1 <= 10'b0_0_0100_0000;   
        4'b0111 : ROM1 <= 10'b0_0_1000_0000;   
        4'b1000 : ROM1 <= 10'b1_0_0000_0100;   
        4'b1001 : ROM1 <= 10'b1_0_0000_0010;   
        4'b1010 : ROM1 <= 10'b1_0_0000_0001;   
        4'b1011 : ROM1 <= 10'b1_0_0000_0001;   
        4'b1100 : ROM1 <= 10'b1_0_0000_0000;   
        4'b1101 : ROM1 <= 10'b1_0_0000_0000;   
        4'b1110 : ROM1 <= 10'b1_0_0000_0000;   
        4'b1111 : ROM1 <= 10'b1_0_0000_0000;   
    endcase
end

assign ROM1_Valid = (DI[11] ? DI[11] : ~|DI[10:3]);


assign ROM2_Addr = {DI[11], (DI[11] ? DI[10:8] : DI[2:0])};

always @(*)
begin
    case(ROM2_Addr)
        4'b0000 : ROM2 <= 12'b0000_00_00_00_00;   
        4'b0001 : ROM2 <= 12'b0000_00_00_00_00;   
        4'b0010 : ROM2 <= 12'b0000_00_00_00_00;   
        4'b0011 : ROM2 <= 12'b0000_00_00_00_00;   
        4'b0100 : ROM2 <= 12'b0000_00_00_00_00;   
        4'b0101 : ROM2 <= 12'b0000_00_00_00_00;   
        4'b0110 : ROM2 <= 12'b0000_00_00_00_00;   
        4'b0111 : ROM2 <= 12'b0000_00_00_00_00;   
        4'b1000 : ROM2 <= 12'b0010_00_00_10_00;   
        4'b1001 : ROM2 <= 12'b0000_00_00_10_00;   
        4'b1010 : ROM2 <= 12'b0000_00_00_00_00;   
        4'b1011 : ROM2 <= 12'b0000_00_00_00_00;   
        4'b1100 : ROM2 <= 12'b0010_00_00_10_00;   
        4'b1101 : ROM2 <= 12'b0010_01_10_11_01;   
        4'b1110 : ROM2 <= 12'b0010_01_10_11_10;   
        4'b1111 : ROM2 <= 12'b0010_01_10_11_11;   
    endcase
end


assign ROM3_Addr = DI[10:5];

always @(*)
begin
    case(ROM3_Addr)
        6'b000000 : ROM3 <= 12'b0000_00_00_00_00;   
                                   
        6'b000001 : ROM3 <= 12'b1100_10_00_01_00;   
        6'b000010 : ROM3 <= 12'b0010_10_00_00_00;   
        6'b000011 : ROM3 <= 12'b1100_10_00_00_00;   
                                   
        6'b000100 : ROM3 <= 12'b0110_00_11_01_11;   
        6'b000101 : ROM3 <= 12'b1100_00_11_01_11;   
        6'b000110 : ROM3 <= 12'b0110_00_10_00_10;   
        6'b000111 : ROM3 <= 12'b1100_00_10_00_10;   
                                   
        6'b001000 : ROM3 <= 12'b0110_01_10_01_01;   
        6'b001001 : ROM3 <= 12'b1100_01_10_01_01;   
        6'b001010 : ROM3 <= 12'b0110_01_10_01_10;   
        6'b001011 : ROM3 <= 12'b1100_01_10_01_10;   
        6'b001100 : ROM3 <= 12'b0110_01_10_01_11;   
        6'b001101 : ROM3 <= 12'b1100_01_10_01_11;   
        6'b001110 : ROM3 <= 12'b0110_00_11_01_00;   
        6'b001111 : ROM3 <= 12'b1100_00_11_01_00;   
                                   
        6'b010000 : ROM3 <= 12'b0110_00_10_00_00;   
        6'b010001 : ROM3 <= 12'b1100_00_10_00_00;   
        6'b010010 : ROM3 <= 12'b0110_01_00_00_00;   
        6'b010011 : ROM3 <= 12'b1100_01_00_00_00;   
        6'b010100 : ROM3 <= 12'b0110_00_10_00_01;   
        6'b010101 : ROM3 <= 12'b1100_00_10_00_01;   
        6'b010110 : ROM3 <= 12'b0111_00_00_00_10;   
        6'b010111 : ROM3 <= 12'b1101_00_00_00_10;   
                                   
        6'b011000 : ROM3 <= 12'b0110_10_01_00_10;   
        6'b011001 : ROM3 <= 12'b1100_10_01_00_10;   
        6'b011010 : ROM3 <= 12'b0110_10_01_00_11;   
        6'b011011 : ROM3 <= 12'b1001_10_01_00_11;   
        6'b011100 : ROM3 <= 12'b0110_10_00_00_01;   
        6'b011101 : ROM3 <= 12'b1100_10_00_00_01;   
        6'b011110 : ROM3 <= 12'b0111_00_00_00_01;   
        6'b011111 : ROM3 <= 12'b1101_00_00_00_01;   
                                   
        6'b100000 : ROM3 <= 12'b1100_11_00_0_000;   
        6'b100001 : ROM3 <= 12'b1100_11_00_0_001;   
        6'b100010 : ROM3 <= 12'b1100_11_00_0_010;   
        6'b100011 : ROM3 <= 12'b1100_11_00_0_011;   
        6'b100100 : ROM3 <= 12'b1100_11_00_0_100;   
        6'b100101 : ROM3 <= 12'b1100_11_00_0_101;   
        6'b100110 : ROM3 <= 12'b1100_11_00_0_110;   
        6'b100111 : ROM3 <= 12'b1100_11_00_0_111;   
                                   
        6'b101000 : ROM3 <= 12'b1100_11_00_1_000;   
        6'b101001 : ROM3 <= 12'b1100_11_00_1_001;   
        6'b101010 : ROM3 <= 12'b1100_11_00_1_010;   
        6'b101011 : ROM3 <= 12'b1100_11_00_1_011;   
        6'b101100 : ROM3 <= 12'b1100_11_00_1_100;   
        6'b101101 : ROM3 <= 12'b1100_11_00_1_101;   
        6'b101110 : ROM3 <= 12'b1100_11_00_1_110;   
        6'b101111 : ROM3 <= 12'b1100_11_00_1_111;   
                                   
        6'b110000 : ROM3 <= 12'b0101_11_00_0_000;   
        6'b110001 : ROM3 <= 12'b0101_11_00_0_001;   
        6'b110010 : ROM3 <= 12'b0101_11_00_0_010;   
        6'b110011 : ROM3 <= 12'b0101_11_00_0_011;   
        6'b110100 : ROM3 <= 12'b0101_11_00_0_100;   
        6'b110101 : ROM3 <= 12'b0101_11_00_0_101;   
        6'b110110 : ROM3 <= 12'b0101_11_00_0_110;   
        6'b110111 : ROM3 <= 12'b0101_11_00_0_111;   
                                   
        6'b111000 : ROM3 <= 12'b0101_11_00_1_000;   
        6'b111001 : ROM3 <= 12'b0101_11_00_1_001;   
        6'b111010 : ROM3 <= 12'b0101_11_00_1_010;   
        6'b111011 : ROM3 <= 12'b0101_11_00_1_011;   
        6'b111100 : ROM3 <= 12'b0101_11_00_1_100;   
        6'b111101 : ROM3 <= 12'b0101_11_00_1_101;   
        6'b111110 : ROM3 <= 12'b0101_11_00_1_110;   
        6'b111111 : ROM3 <= 12'b0101_11_00_1_111;   
    endcase
end


assign dErr =   (~|DI[11:1] & DI[0])                        
              | (~|DI[11:4] & DI[3])                        
              | (~|DI[11:5] & DI[4])                        
              | (~|DI[11:7] & DI[6] & ~|DI[5:4] & |DI[3:0]) 
              | (~|DI[11:7] & DI[6] & ~DI[5] & DI[4]);      


always @(posedge Clk)
begin
    if(Rst)
        dIR <= #1 0;
    else if(CE)
        dIR <= #1 ((Skip) ? 0
                          : ((ROM1_Valid) ? ROM1 : 0));
end


assign dALU_Op = (ROM1_Valid ? ROM2
                             : {ROM3[11],(ROM3[10] & ~|DI[4:0]), ROM3[9:0]});

always @(posedge Clk)
begin
    if(Rst)
        ALU_Op <= #1 0;
    else if(CE)
        ALU_Op <= #1 ((Skip | dErr) ? 0 : dALU_Op);
end


always @(posedge Clk)
begin
    if(Rst)
        KI <= #1 0;
    else if(CE)
        KI <= #1 ((Skip) ? KI : DI[8:0]);
end


always @(posedge Clk)
begin
    if(Rst)
        Err <= #1 0;
    else if(CE)
        Err <= #1 dErr;
end

endmodule



