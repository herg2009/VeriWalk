
`timescale 1 ns / 1 ns


module serirq_host(clk_i, nrst_i, 
                   serirq_mode_i, irq_o,
                   serirq_o, serirq_i, serirq_oe
);
    
    input              clk_i;
    input              nrst_i;      
    input              serirq_mode_i; 
    
    
    output reg         serirq_o;    
    input              serirq_i;    
    output reg         serirq_oe;   

    output reg  [31:0] irq_o;       

    reg         [12:0] state;       
    reg          [4:0] irq_cnt;     
    reg          [2:0] start_cnt;   
    reg          [2:0] stop_cnt;    
    reg                current_mode;

    always @(posedge clk_i or negedge nrst_i)
        if(~nrst_i)
        begin
            state <= 13'h000;
            serirq_oe <= 1'b0;
            serirq_o <= 4'b1;
            irq_cnt <= 5'h00;
                start_cnt <= 3'b000;
                stop_cnt <= 2'b00;
                irq_o <= 32'hFFFFFFFF;
                current_mode <= 1'b0;
        end
        else begin
            case(state)
                13'h000:
                    begin
                        serirq_oe <= 1'b0;
                        start_cnt <= 3'b000;
                        stop_cnt <= 2'b00;
                        serirq_o <= 1'b1;
                        if((current_mode == 1'b1) && (serirq_i == 1'b0)) begin
                            start_cnt <= 3'b010;
                            serirq_o <= 1'b0;
                            serirq_oe <= 1'b1;
                            state <= 13'h001;
                        end
                        else if(current_mode == 1'b0)
                        begin
                            start_cnt <= 3'b000;
                            state <= 13'h001;
                        end
                        else if((current_mode == 1'b1) && (serirq_mode_i == 1'b0)) 
                        begin 
                            start_cnt <= 3'b000;
                            state <= 13'h001;
                        end
                        else
                            state <= 13'h000;
                    end
                13'h001:
                    begin
                        serirq_o <= 1'b0;
                        serirq_oe <= 1'b1;
                        irq_cnt <= 5'h00;
                        start_cnt <= start_cnt + 1;
                        if(start_cnt == 3'b111) begin
                            state <= 13'h002;
                        end
                        else begin
                            state <= 13'h001;
                        end
                    end
                13'h002:
                    begin
                        serirq_o <= 1'b1;
                        state <= 13'h004;
                    end
                13'h004:
                    begin
                        serirq_oe <= 1'b0;
                        state <= 13'h008;
                    end
                13'h008:
                    begin
                        state <= 13'h010;
                    end
                13'h010:
                    begin
                        irq_o[irq_cnt] <= (serirq_i == 1'b0 ? 1'b0 : 1'b1);
                        state <= 13'h020;
                    end
                13'h020:
                    begin
                        if(irq_cnt == 5'h1f) begin
                            state <= 13'h040;
                        end else begin
                            state <= 13'h008;
                            irq_cnt <= irq_cnt + 1;
                        end
                    end
                13'h040:
                    begin
                        serirq_o <= 1'b0;
                        serirq_oe <= 1'b1;
                        stop_cnt <= stop_cnt + 1;
                        if(stop_cnt == (serirq_mode_i ? 2'b01 : 2'b10)) begin
                            state <= 13'h080;
                        end
                        else begin
                            state <= 13'h040;
                        end
                    end
                13'h080:
                    begin
                        serirq_o <= 1'b1;
                        state <= 13'h100;
                    end
                13'h100:
                    begin
                        serirq_oe <= 1'b0;
                        state <= 13'h000;
                        current_mode <= serirq_mode_i;
                    end
            endcase
        end
endmodule

                            


`timescale 1 ns / 1 ns


module serirq_slave(clk_i, nrst_i, 
                    irq_i,
                    serirq_o, serirq_i, serirq_oe
);
    
    input             clk_i;
    input             nrst_i;       
    
    
    output reg        serirq_o;     
    input             serirq_i;     
    output reg        serirq_oe;    

    input      [31:0] irq_i;        
    reg        [31:0] current_irq;

    reg        [12:0] state;        
    reg         [4:0] irq_cnt;      

    reg found_stop;
    reg found_start;
    reg serirq_mode;

    wire irq_changed = (serirq_mode & (current_irq != irq_i));
     
    always @(posedge clk_i or negedge nrst_i)
        if(~nrst_i)
        begin
            state <= 13'h000;
            serirq_oe <= 1'b0;
            serirq_o <= 4'b1;
            irq_cnt <= 5'h00;
            current_irq <= irq_i;
        end
        else begin
            case(state)
                13'h000:
                    begin
                        serirq_oe <= 1'b0;
                        irq_cnt <= 5'h00;
                        serirq_o <= 1'b1;

                        if(found_start == 1'b1) 
                        begin
                            current_irq <= irq_i;
                            if(irq_i[irq_cnt] == 1'b0) begin
                                serirq_oe <= 1'b1;
                                serirq_o <= 1'b0;
                            end
                            state <= 13'h010;
                        end
                        else if(irq_changed) begin
                            current_irq <= irq_i;
                            serirq_o <= 1'b0;
                            serirq_oe <= 1'b1;
                            state <= 13'h000;
                        end else
                            state <= 13'h000;
                    end
                13'h008:
                    begin
                        if(irq_i[irq_cnt] == 1'b0) begin
                            serirq_oe <= 1'b1;
                            serirq_o <= 1'b0;
                        end
                            if(found_stop == 1'b0)
                                state <= 13'h010;
                            else
                                state <= 13'h000;
                    end
                13'h010:
                    begin
                        serirq_o <= 1'b1;
                        if(found_stop == 1'b0)
                            state <= 13'h020;
                        else
                            state <= 13'h000;
                    end
                13'h020:
                    begin
                        serirq_oe <= 1'b0;
                        if(irq_cnt == 5'h1f)
                        begin
                            state <= 13'h200;
                        end
                        else begin
                            irq_cnt <= irq_cnt + 1;
                            if(found_stop == 1'b0)
                                state <= 13'h008;
                            else
                                state <= 13'h000;
                        end
                    end
                    13'h200:
                        begin
                            if(found_stop == 1'b0)
                                state <= 13'h200;
                            else
                                state <= 13'h000;
                        end
            endcase
        end

    reg [3:0] stop_clk_cnt;

    
    always @(posedge clk_i or negedge nrst_i)
        if(~nrst_i)
        begin
            found_stop <= 1'b0;
            found_start <= 1'b0;
            serirq_mode <= 1'b0;
            stop_clk_cnt <= 4'h0;
        end
        else begin
            if(serirq_i == 1'b0) begin
                stop_clk_cnt <= stop_clk_cnt + 1;
            end
            else begin
                case (stop_clk_cnt) 
                    4'h2:
                        begin
                            found_stop <= 1'b1;
                            found_start <= 1'b0;
                            serirq_mode <= 1'b1;
                        end
                    4'h3:
                        begin
                            found_stop <= 1'b1;
                            found_start <= 1'b0;
                            serirq_mode <= 1'b0;
                        end
                    4'h4:
                        begin
                            found_stop <= 1'b0;
                            found_start <= 1'b1;
                        end
                    4'h6:
                        begin
                            found_stop <= 1'b0;
                            found_start <= 1'b1;
                        end
                    4'h8:
                        begin
                            found_stop <= 1'b0;
                            found_start <= 1'b1;
                        end
                    default:
                        begin
                            found_stop <= 1'b0;
                            found_start <= 1'b0;
                        end
                    endcase
                    stop_clk_cnt <= 4'h0;
            end
        end
endmodule



`timescale 1 ns / 1 ns


module wb_dreq_host(clk_i, nrst_i,
                     dma_chan_o, dma_req_o,
                            ldrq_i
);
    
    input       clk_i;
    input       nrst_i;             

    
    output reg  [2:0] dma_chan_o;
    output reg        dma_req_o;

    
    input           ldrq_i;
    
    reg [1:0]   adr_cnt;
    reg [3:0]   state;
    
    always @(posedge clk_i or negedge nrst_i)
        if(~nrst_i)
        begin
            state <= 4'h0;
            dma_chan_o <= 3'h0;
            dma_req_o <= 3'h0;
            adr_cnt <= 2'b00;
        end
        else begin
            case(state)
                4'h0:
                    begin
                        dma_req_o <= 1'b0;
                        if(~ldrq_i) begin
                            state <= 4'h1;
                            adr_cnt <= 2'h2;
                        end
                    end
                4'h1:
                    begin
                        dma_chan_o[adr_cnt] <= ldrq_i;
                        adr_cnt <= adr_cnt - 1;
                        
                        if(adr_cnt == 2'h0)
                            state <= 4'h2;
                    end
                4'h2:
                    begin
                        dma_req_o <= ldrq_i;
                        state <= 4'h4;
                    end
                4'h4:
                    begin
                        dma_req_o <= 1'b0;
                        state <= 4'h0;
                    end
            endcase
        end

endmodule

                            


`timescale 1 ns / 1 ns


module wb_dreq_periph(clk_i, nrst_i,
                      dma_chan_i, dma_req_i,
                      ldrq_o
);
    
    input       clk_i;
    input       nrst_i;             

    
    input [2:0] dma_chan_i;
    input       dma_req_i;

    
    output reg  ldrq_o;
    
    reg [1:0]   adr_cnt;
    reg [3:0]   state;
    
    always @(posedge clk_i or negedge nrst_i)
        if(~nrst_i)
        begin
            state <= 4'h0;
            ldrq_o <= 1'b1; 
            adr_cnt <= 2'b00;
        end
        else begin
            case(state)
                4'h0:
                    begin
                        if(dma_req_i) begin
                            ldrq_o <= 1'b0;
                            state <= 4'h1;
                            adr_cnt <= 2'h2;
                        end
                    end
                4'h1:
                    begin
                        ldrq_o <= dma_chan_i[adr_cnt];
                        adr_cnt <= adr_cnt - 1;
                        
                        if(adr_cnt == 2'h0)
                            state <= 4'h2;
                    end
                4'h2:
                    begin
                        ldrq_o <= 1'b1;
                        state <= 4'h4;
                    end
                4'h4:
                    begin
                        ldrq_o <= 1'b1;
                        state <= 4'h0;
                    end
            endcase
        end

endmodule



`timescale 1 ns / 1 ns


module wb_lpc_host(clk_i, nrst_i, wbs_adr_i, wbs_dat_o, wbs_dat_i, wbs_sel_i, wbs_tga_i, wbs_we_i,
                   wbs_stb_i, wbs_cyc_i, wbs_ack_o, wbs_err_o,
                   dma_chan_i, dma_tc_i,
                   lframe_o, lad_i, lad_o, lad_oe
);
    
    input              clk_i;
    input              nrst_i;             
    input       [31:0] wbs_adr_i;
    output      [31:0] wbs_dat_o;
    input       [31:0] wbs_dat_i;
    input       [3:0]  wbs_sel_i;
    input       [1:0]  wbs_tga_i;
    input              wbs_we_i;
    input              wbs_stb_i;
    input              wbs_cyc_i;
    output reg         wbs_ack_o;
    output reg         wbs_err_o;
    
    
    output reg        lframe_o;     
    output reg        lad_oe;       
    input       [3:0] lad_i;        
    output reg  [3:0] lad_o;        

    
    input       [2:0] dma_chan_i;   
    input             dma_tc_i;     

    reg         [13:0] state;       
    reg         [2:0] adr_cnt;      
    reg         [3:0] dat_cnt;      
    reg         [2:0] xfr_len;      
    wire        [2:0] byte_cnt = dat_cnt[3:1];  
    wire              nibble_cnt = dat_cnt[0];    
    reg         [31:0] lpc_dat_i;           

    
    
    wire wbs_acc = wbs_cyc_i & wbs_stb_i;    
    wire wbs_wr  = wbs_acc & wbs_we_i;       

    
    wire    mem_xfr = (wbs_tga_i == 2'b00);
    wire    dma_xfr = (wbs_tga_i == 2'b11);
    wire    fw_xfr  = (wbs_tga_i == 2'b10);
    
    assign wbs_dat_o[31:0] = lpc_dat_i; 

    always @(posedge clk_i or negedge nrst_i)
        if(~nrst_i)
        begin
            state <= 14'h000;
            lframe_o <= 1'b0;
            wbs_ack_o <= 1'b0;
            wbs_err_o <= 1'b0;
            lad_oe <= 1'b0;
            lad_o <= 4'b0;
            adr_cnt <= 3'b0;
            dat_cnt <= 4'h0;
            xfr_len <= 3'b000;
            lpc_dat_i <= 32'h00000000;
        end
        else begin
            case(state)
                14'h000:
                    begin
                        wbs_ack_o <= 1'b0;
                        wbs_err_o <= 1'b0;
                        lframe_o <= 1'b0;
                        dat_cnt <= 4'h0;                        

                        if(wbs_acc)     
                            state <= 14'h001;
                        else
                            state <= 14'h000;
                    end
                14'h001:
                    begin
                        lframe_o <= 1'b1;
                        if(~fw_xfr) begin       
                            lad_o   <= 4'b0000;
                            state   <= 14'h002;
                        end
                        else begin              
                            if(wbs_wr)
                                lad_o <= 4'b1110;
                            else
                                lad_o <= 4'b1101;
                            
                            state   <= 14'h004;
                        end
                        lad_oe  <= 1'b1;
                        adr_cnt <= ((mem_xfr | fw_xfr) ? 3'b000 : 3'b100);
                    end
                14'h002:
                    begin
                        lframe_o    <= 1'b0;
                        lad_oe  <= 1'b1;                

                        if(~dma_xfr)
                            begin
                                lad_o   <= {1'b0,mem_xfr,wbs_wr,1'b0};      
                                state       <= 14'h004;
                            end
                        else 
                            begin
                                lad_o   <= {1'b1,1'b0,~wbs_wr,1'b0};        
                                state       <= 14'h008;
                            end
                    end
                14'h004:   
                    begin
                        lframe_o <= 1'b0;       
                        
                        
                        
                        
                        
                        
                        case(adr_cnt)
                            3'h0:
                                lad_o <= wbs_adr_i[31:28];
                            3'h1:
                                lad_o <= wbs_adr_i[27:24];
                            3'h2:
                                lad_o <= wbs_adr_i[23:20];
                            3'h3:
                                lad_o <= wbs_adr_i[19:16];
                            3'h4:
                                lad_o <= wbs_adr_i[15:12];
                            3'h5:
                                lad_o <= wbs_adr_i[11:8];
                            3'h6:
                                lad_o <= wbs_adr_i[7:4];
                            3'h7:
                                lad_o <= wbs_adr_i[3:0];
                        endcase
                        
                        adr_cnt <= adr_cnt + 1;
                        
                        if(adr_cnt == 4'h7) 
                            begin
                                if(~fw_xfr)
                                    if(wbs_wr)
                                        state <= 14'h020;
                                    else
                                        state <= 14'h080;
                                else    
                                    state <= 14'h010;
                            end
                        else
                            state <= 14'h004;
        
                        lad_oe  <= 1'b1;
                        xfr_len     <= 3'b001;      
                    end
                14'h008:
                    begin
                        lad_o   <= {dma_tc_i, dma_chan_i};
                        state <= 14'h010;
                    end
                14'h010:
                    begin
                        case(wbs_sel_i)
                            4'b0001:
                                begin
                                    xfr_len <= 3'b001;
                                    lad_o <= 4'h0;
                                end
                            4'b0011:
                                begin
                                    xfr_len <= 3'b010;
                                    lad_o <= 4'h1;
                                end
                            4'b1111:
                                begin
                                    xfr_len <= 3'b100;
                                    if(fw_xfr)              
                                        lad_o <= 4'h2;
                                    else                    
                                        lad_o <= 4'h3;
                                end
                            default:
                                begin
                                    xfr_len <= 3'b001;
                                    lad_o <= 4'h0;
                                end
                        endcase
                        if(wbs_wr)
                            state <= 14'h020;
                        else
                            state <= 14'h080;
                    end

                14'h020:
                    begin
                        lad_oe  <= 1'b1;
                        case(dat_cnt)   
                            4'h0:
                                lad_o <= wbs_dat_i[3:0];
                            4'h1:
                                lad_o <= wbs_dat_i[7:4];
                            4'h2:
                                lad_o <= wbs_dat_i[11:8];
                            4'h3:
                                lad_o <= wbs_dat_i[15:12];
                            4'h4:
                                lad_o <= wbs_dat_i[19:16];
                            4'h5:
                                lad_o <= wbs_dat_i[23:20];
                            4'h6:
                                lad_o <= wbs_dat_i[27:24];
                            4'h7:
                                lad_o <= wbs_dat_i[31:28];
                            default:
                                lad_o <= 4'hx;
                        endcase
                        
                        dat_cnt <= dat_cnt + 1;
                        
                        if(nibble_cnt == 1'b1) 
                            begin
                                if((fw_xfr) && (byte_cnt != xfr_len-1)) 
                                    state <= 14'h020;
                                else
                                    state <= 14'h080;
                            end
                        else
                            state <= 14'h020;
                    end
        
                14'h080:
                    begin
                        lad_o <= 4'b1111;       
                        lad_oe <= 1'b1;
                        state <= 14'h100;
                    end
                14'h100:
                    begin
                        lad_oe <= 1'b0;     
                        state <= 14'h800;
                    end
                14'h800:
                    begin
                        lad_oe <= 1'b0;     
                        if((lad_i == 4'b0000) || (lad_i == 4'b1001)) begin
                            if(wbs_wr) begin
                                state <= 14'h200;
                            end
                            else begin
                                state <= 14'h040;
                            end
                        end else if(lad_i == 4'b1010) begin
                            dat_cnt <= { xfr_len, 1'b1 };    
                            wbs_err_o <= 1'b1;    
                            state <= 14'h200;
                        end else begin
                            state <= 14'h800;
                        end
                    end
        
                14'h040:
                    begin
                        case(dat_cnt)
                            4'h0:
                                lpc_dat_i[3:0] <= lad_i;
                            4'h1:
                                lpc_dat_i[7:4] <= lad_i;
                            4'h2:
                                lpc_dat_i[11:8] <= lad_i;
                            4'h3:
                                lpc_dat_i[15:12] <= lad_i;
                            4'h4:
                                lpc_dat_i[19:16] <= lad_i;
                            4'h5:
                                lpc_dat_i[23:20] <= lad_i;
                            4'h6:
                                lpc_dat_i[27:24] <= lad_i;
                            4'h7:
                                lpc_dat_i[31:28] <= lad_i;
                        endcase
                        
                        dat_cnt <= dat_cnt + 1;
                        
                        if(nibble_cnt == 1'b1)          
                            if (byte_cnt == xfr_len-1)  
                                state <= 14'h200;
                            else begin
                                if(fw_xfr) 
                                    state <= 14'h040;
                                else
                                    state <= 14'h800;
                            end
                        else                            
                            state <= 14'h040;
                    end
                14'h200:
                    begin
                        lad_oe <= 1'b0;
                        if(byte_cnt == xfr_len) begin
                            state <= 14'h400;
                            wbs_ack_o <= wbs_acc;
                        end
                        else begin
                            if(wbs_wr) begin    
                                state <= 14'h020;
                            end
                            else begin  
                                state <= 14'h000;
                            end
                        end
                    end
                14'h400:
                    begin
                        wbs_ack_o <= 1'b0;
                        wbs_err_o <= 1'b0;
                        if(wbs_acc) begin
                            state <= 14'h400;
                        end
                        else begin
                            state <= 14'h000;
                        end
                    end
            endcase
        end

endmodule

                            


`timescale 1 ns / 1 ns



module wb_lpc_periph(clk_i, nrst_i, wbm_adr_o, wbm_dat_o, wbm_dat_i, wbm_sel_o, wbm_tga_o, wbm_we_o,
                     wbm_stb_o, wbm_cyc_o, wbm_ack_i, wbm_err_i,
                     dma_chan_o, dma_tc_o,
                     lframe_i, lad_i, lad_o, lad_oe
);

    
    input              clk_i;
    input              nrst_i;
    output reg  [31:0] wbm_adr_o;
    output reg  [31:0] wbm_dat_o;
    input       [31:0] wbm_dat_i;
    output reg   [3:0] wbm_sel_o;
    output reg   [1:0] wbm_tga_o;
    output reg         wbm_we_o;
    output reg         wbm_stb_o;
    output reg         wbm_cyc_o;
    input              wbm_ack_i;
    input              wbm_err_i;	 

    
    input              lframe_i;    
    output reg         lad_oe;      
    input        [3:0] lad_i;       
    output reg   [3:0] lad_o;       

    
    output       [2:0] dma_chan_o;  
    output             dma_tc_o;    

    reg         [13:0] state;       
    reg          [2:0] adr_cnt;     
    reg          [3:0] dat_cnt;     
    wire         [2:0] byte_cnt = dat_cnt[3:1];  
    wire               nibble_cnt = dat_cnt[0];  

    reg         [31:0] lpc_dat_i;   
    reg                mem_xfr;     
    reg                dma_xfr;     
    reg                fw_xfr;      
    reg          [2:0] xfr_len;     
    reg                dma_tc;      
    reg          [2:0] dma_chan;    

    
    
    reg         [31:0] lpc_adr_reg; 
    reg         [31:0] lpc_dat_o;   
    reg                lpc_write;   
    reg          [1:0] lpc_tga_o;
    reg                got_ack;     

    assign dma_chan_o = dma_chan;
    assign dma_tc_o = dma_tc;
    
    always @(posedge clk_i or negedge nrst_i)
    begin
        if(~nrst_i)
        begin
            state <= 14'h000;
            lpc_adr_reg <= 32'h00000000;
            lpc_dat_o <= 32'h00000000;
            lpc_write <= 1'b0;
            lpc_tga_o <= 2'b00;
            lad_oe <= 1'b0;
            lad_o <= 8'hFF;
            lpc_dat_i <= 32'h00000000;
            mem_xfr <= 1'b0;
            dma_xfr <= 1'b0;
            fw_xfr <= 1'b0;
            xfr_len <= 3'b000;
            dma_tc <= 1'b0;
            dma_chan <= 3'b000;
        end
        else begin
            case(state)
                14'h000:
                    begin
                        dat_cnt <= 4'h0;
                        if(lframe_i) begin
                            lad_oe <= 1'b0;
                            xfr_len <= 3'b001;
                                
                            if(lad_i == 4'b0000) begin
                                state <= 14'h002;
                                lpc_write <= 1'b0;
                                fw_xfr <= 1'b0;                                 
                            end
                            else if ((lad_i == 4'b1110) || (lad_i == 4'b1101)) begin
                                state <= 14'h004;
                                lpc_write <= (lad_i == 4'b1110) ? 1'b1 : 1'b0;
                                adr_cnt <= 3'b000;
                                fw_xfr <= 1'b1;
                                dma_xfr <= 1'b0;
                                lpc_tga_o <= 2'b10;
                            end
                            else
                                state <= 14'h000;
                        end
                        else
                            state <= 14'h000;
                    end
                14'h002:
                    begin
                        lpc_write <= (lad_i[3] ? ~lad_i[1] : lad_i[1]);  
                        adr_cnt <= (lad_i[2] ? 3'b000 : 3'b100);
                        if(lad_i[3]) begin 
                            lpc_tga_o <= 2'b11;
                            dma_xfr <= 1'b1;
                            mem_xfr <= 1'b0;
                            state <= 14'h008;									 
                        end
                        else if(lad_i[2]) begin 
                            lpc_tga_o <= 2'b00;
                            dma_xfr <= 1'b0;
                            mem_xfr <= 1'b1;
                            state <= 14'h004;
                        end
                        else begin
                            lpc_tga_o <= 2'b01;
                            dma_xfr <= 1'b0;
                            mem_xfr <= 1'b0;
                            state <= 14'h004;
                        end
                    end
                14'h004:
                    begin
                        case(adr_cnt)
                            3'h0: lpc_adr_reg[31:28] <= lad_i;
                            3'h1: lpc_adr_reg[27:24] <= lad_i;
                            3'h2: lpc_adr_reg[23:20] <= lad_i;
                            3'h3: lpc_adr_reg[19:16] <= lad_i;
                            3'h4: lpc_adr_reg[15:12] <= lad_i;
                            3'h5: lpc_adr_reg[11: 8] <= lad_i;
                            3'h6: lpc_adr_reg[ 7: 4] <= lad_i;
                            3'h7: lpc_adr_reg[ 3: 0] <= lad_i;
                        endcase
                        
                        adr_cnt <= adr_cnt + 1;
                        
                        if(adr_cnt == 3'h7) 
                            begin
                                if(~fw_xfr)
                                    if(lpc_write)
                                        state <= 14'h020;
                                    else
                                        state <= 14'h080;
                                else    
                                    state <= 14'h010;
                            end
                        else
                            state <= 14'h004;
                    end
                14'h008:
                    begin
                        lpc_adr_reg <= 32'h00000000;      
                        dma_tc <= lad_i[3];
                        dma_chan <= lad_i[2:0];
                        state <= 14'h010;
                    end
                14'h010:
                    begin
                        case(lad_i)
                            4'h0:    xfr_len <= 3'b001;
                            4'h1:    xfr_len <= 3'b010;
                            4'h2:    xfr_len <= 3'b100;   
                            4'h3:    xfr_len <= 3'b100;   
                            default: xfr_len <= 3'b001;
                        endcase
                        if(lpc_write)
                            state <= 14'h020;
                        else
                            state <= 14'h080;
                    end
                14'h020:
                    begin
                        case(dat_cnt)
                            4'h0: lpc_dat_o[ 3: 0] <= lad_i;
                            4'h1: lpc_dat_o[ 7: 4] <= lad_i;
                            4'h2: lpc_dat_o[11: 8] <= lad_i;
                            4'h3: lpc_dat_o[15:12] <= lad_i;
                            4'h4: lpc_dat_o[19:16] <= lad_i;
                            4'h5: lpc_dat_o[23:20] <= lad_i;
                            4'h6: lpc_dat_o[27:24] <= lad_i;
                            4'h7: lpc_dat_o[31:28] <= lad_i;
                        endcase
                        
                        dat_cnt <= dat_cnt + 1;
                        
                        if(nibble_cnt == 1'b1) 
                            begin
                                if((fw_xfr) && (byte_cnt != xfr_len-1)) 
                                    state <= 14'h020;
										  else
                                    state <= 14'h080;
                            end
                        else
                            state <= 14'h020;
        
                    end
        
                14'h080:
                    begin
                        
                        state <= 14'h100;
                    end
                14'h100:
                    begin
                        state <= (fw_xfr & lpc_write) ? 14'h2000 : 14'h800;
                        lad_o <= (fw_xfr & lpc_write) ? 4'b0000 : 4'b0101;
                        lad_oe <= 1'b1;     
                    end
                14'h800:
                    begin
                        lad_oe <= 1'b1;     
                        
                        if(((byte_cnt == xfr_len) & lpc_write) | ((byte_cnt == 0) & ~lpc_write)) begin
                            
                            if((wbm_err_i) && (~fw_xfr)) begin
                                dat_cnt <= { xfr_len, 1'b1 }; 
                                lad_o <= 4'b1010;   
                                state <= 14'h200;
                            end else if(got_ack) begin
                                if(lpc_write) begin
                                    lad_o <= 4'b0000;   
                                    state <= 14'h200;
                                end
                                else begin
                                    
                                    
                                    lad_o <= (((xfr_len == 1) & ~lpc_write) || (~dma_xfr)) ? 4'b0000 : 4'b1001;
                                    state <= 14'h040;
                                end
                            end
                            else begin
                                state <= 14'h800;
                                lad_o <= 4'b0101;
                            end
                        end
                        else begin  
                            if(lpc_write) begin
                                lad_o <= (dma_xfr) ? 4'b1001 : 4'b0000;
                                state <= 14'h200;
                            end
									 else begin
                                lad_o <= ((byte_cnt == xfr_len-1) || (~dma_xfr)) ? 4'b0000 : 4'b1001;   
                                state <= 14'h040;
                            end
                        end
                    end
                14'h2000:	
                    begin
                        lad_o <= 4'hF;
                        state <= 14'h400;
                    end
        
                14'h040:
                    begin
                        case(dat_cnt)
                            4'h0: lad_o <= lpc_dat_i[ 3: 0];
                            4'h1: lad_o <= lpc_dat_i[ 7: 4];
                            4'h2: lad_o <= lpc_dat_i[11: 8];
                            4'h3: lad_o <= lpc_dat_i[15:12];
                            4'h4: lad_o <= lpc_dat_i[19:16];
                            4'h5: lad_o <= lpc_dat_i[23:20];
                            4'h6: lad_o <= lpc_dat_i[27:24];
                            4'h7: lad_o <= lpc_dat_i[31:28];
                        endcase
                        
                        dat_cnt <= dat_cnt + 1;
                        
                        if(nibble_cnt == 1'b1)  
                            if (byte_cnt == xfr_len-1) 
                                state <= 14'h200;
                            else begin
                                if(fw_xfr) 
                                    state <= 14'h040;
                                else
                                    state <= 14'h800;
                            end
                        else
                            state <= 14'h040;
        
                        lad_oe <= 1'b1;
                    end
                14'h200:
                    begin
                        lad_oe <= 1'b1;
                        lad_o <= 4'hF;
                        state <= 14'h400;
                    end
                14'h400:
                    begin
                        lad_oe <= 1'b0;     
                        if(byte_cnt == xfr_len) begin
                            state <= 14'h000;
                        end
                        else begin
                            if(lpc_write) begin  
                                state <= 14'h1000;
                            end
                            else begin  
                                state <= 14'h000;
                            end
                        end

                    end
                    14'h1000:
                         state <= 14'h020;
            endcase
        end

        if(~nrst_i)
        begin
            wbm_adr_o <= 32'h00000000;
            wbm_dat_o <= 32'h00000000;
            wbm_stb_o <= 1'b0;
            wbm_cyc_o <= 1'b0;
            wbm_we_o <= 1'b0;
            wbm_sel_o <= 4'b0000;
            wbm_tga_o <= 2'b00;
            got_ack <= 1'b0;
        end
        else begin
            if ((state == 14'h080) && (((byte_cnt == xfr_len) & lpc_write) | ((byte_cnt == 0) & ~lpc_write)))
            begin
                
                wbm_stb_o <= 1'b1;
                wbm_cyc_o <= 1'b1;
                wbm_adr_o <= lpc_adr_reg;
                wbm_dat_o <= lpc_dat_o;					 
                wbm_we_o <= lpc_write;
                wbm_tga_o <= lpc_tga_o;
                got_ack <= 1'b0;
                case(xfr_len)
                    3'h0: wbm_sel_o <= 4'b0001;
                    3'h2: wbm_sel_o <= 4'b0011;
                    3'h4: wbm_sel_o <= 4'b1111;
                endcase
            end
            else if((wbm_stb_o == 1'b1) && (wbm_ack_i == 1'b1)) begin
                
                wbm_stb_o <= 1'b0;
                wbm_cyc_o <= 1'b0;
                wbm_we_o <= 1'b0;
                got_ack <= 1'b1;
                if(~wbm_we_o) begin
                    lpc_dat_i <= wbm_dat_i;
                end
             end
        end
    end
endmodule

                            


module top (clk_i, nrst_i, wb_adr_i, wb_dat_o, wb_dat_i, wb_sel_i, wb_we_i,
                   wb_stb_i, wb_cyc_i, wb_ack_o, wb_err_o, ws_i, datareg0, datareg1);

    input          clk_i;
    input          nrst_i;
    input    [3:0] wb_adr_i;
    output reg [31:0] wb_dat_o;
    input   [31:0] wb_dat_i;
    input    [3:0] wb_sel_i;
    input          wb_we_i;
    input          wb_stb_i;
    input          wb_cyc_i;
    output reg     wb_ack_o;
    output         wb_err_o;
    input    [7:0] ws_i;	 
    output  [31:0] datareg0;
    output  [31:0] datareg1;
    reg      [7:0] waitstate;

    
    
    wire wb_acc = wb_cyc_i & wb_stb_i;    
    wire wb_wr  = wb_acc & wb_we_i;       

    reg [7:0]   datareg0_0;
    reg [7:0]   datareg0_1;
    reg [7:0]   datareg0_2;
    reg [7:0]   datareg0_3;

    reg [7:0]   datareg1_0;
    reg [7:0]   datareg1_1;
    reg [7:0]   datareg1_2;
    reg [7:0]   datareg1_3;

    always @(posedge clk_i or negedge nrst_i)
        if (~nrst_i)                
            begin
                datareg0_0 <= 8'h00;
                datareg0_1 <= 8'h01;
                datareg0_2 <= 8'h02;
                datareg0_3 <= 8'h03;
                datareg1_0 <= 8'h10;
                datareg1_1 <= 8'h11;
                datareg1_2 <= 8'h12;
                datareg1_3 <= 8'h13;
                wb_ack_o <= 1'b0;
                waitstate <= 4'b0;
					 wb_dat_o <= 32'h00000000;
            end
        else if(wb_wr)          
            case (wb_sel_i)
                4'b0000:
                    case (wb_adr_i)         
                        4'b0000: datareg0_0 <= wb_dat_i[7:0];
                        4'b0001: datareg0_1 <= wb_dat_i[7:0];
                        4'b0010: datareg0_2 <= wb_dat_i[7:0];
                        4'b0011: datareg0_3 <= wb_dat_i[7:0];
                        4'b0100: datareg1_0 <= wb_dat_i[7:0];
                        4'b0101: datareg1_1 <= wb_dat_i[7:0];
                        4'b0110: datareg1_2 <= wb_dat_i[7:0];
                        4'b0111: datareg1_3 <= wb_dat_i[7:0];
                    endcase
                4'b0001:
                    case (wb_adr_i)         
                        4'b0000: datareg0_0 <= wb_dat_i[7:0];
                        4'b0001: datareg0_1 <= wb_dat_i[7:0];
                        4'b0010: datareg0_2 <= wb_dat_i[7:0];
                        4'b0011: datareg0_3 <= wb_dat_i[7:0];
                        4'b0100: datareg1_0 <= wb_dat_i[7:0];
                        4'b0101: datareg1_1 <= wb_dat_i[7:0];
                        4'b0110: datareg1_2 <= wb_dat_i[7:0];
                        4'b0111: datareg1_3 <= wb_dat_i[7:0];
                    endcase
                4'b0011:
                    {datareg0_1, datareg0_0} <= wb_dat_i[15:0];
                4'b1111:
                    {datareg0_3, datareg0_2, datareg0_1, datareg0_0} <= wb_dat_i[31:0];

            endcase
    
    always @(posedge clk_i)
        case (wb_sel_i)
            4'b0000:
                case (wb_adr_i)     
                    4'b0000: wb_dat_o[7:0] <= datareg0_0;
                    4'b0001: wb_dat_o[7:0] <= datareg0_1;
                    4'b0010: wb_dat_o[7:0] <= datareg0_2;
                    4'b0011: wb_dat_o[7:0] <= datareg0_3;
                    4'b0100: wb_dat_o[7:0] <= datareg1_0;
                    4'b0101: wb_dat_o[7:0] <= datareg1_1;
                    4'b0110: wb_dat_o[7:0] <= datareg1_2;
                    4'b0111: wb_dat_o[7:0] <= datareg1_3;
                endcase
            4'b0001:
                case (wb_adr_i)     
                    4'b0000: wb_dat_o[7:0] <= datareg0_0;
                    4'b0001: wb_dat_o[7:0] <= datareg0_1;
                    4'b0010: wb_dat_o[7:0] <= datareg0_2;
                    4'b0011: wb_dat_o[7:0] <= datareg0_3;
                    4'b0100: wb_dat_o[7:0] <= datareg1_0;
                    4'b0101: wb_dat_o[7:0] <= datareg1_1;
                    4'b0110: wb_dat_o[7:0] <= datareg1_2;
                    4'b0111: wb_dat_o[7:0] <= datareg1_3;
                endcase
            4'b0011:
                    wb_dat_o[15:0] <= {datareg0_1, datareg0_0};
            4'b1111:
                    wb_dat_o[31:0] <= {datareg0_3, datareg0_2, datareg0_1, datareg0_0};
        endcase
        
   
    always @(posedge clk_i or negedge nrst_i)
        if (nrst_i) begin            
            if (ws_i == 0) begin
                wb_ack_o <= wb_acc & !wb_ack_o;
                end else
            if((waitstate == 4'b0) && (ws_i != 0)) begin
                wb_ack_o <= 1'b0;
                if(wb_acc) begin
                    waitstate <= waitstate + 1;
                end
            end
            else begin
                if(wb_acc) waitstate <= waitstate + 1;
                if(waitstate == ws_i) begin
                    if(wb_acc) wb_ack_o <= 1'b1;
                    waitstate <= 1'b0;
                end
            end
        end

    assign datareg0 = { datareg0_3, datareg0_2, datareg0_1, datareg0_0 };
    assign datareg1 = { datareg1_3, datareg1_2, datareg1_1, datareg1_0 };

    
    assign wb_err_o = wb_ack_o & wb_adr_i[3];

endmodule



