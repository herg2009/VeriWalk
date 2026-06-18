`timescale 1ns / 1ps
module top
#(
	parameter pIOAddress = 24'hDC0400,
	parameter pMars = 1'b0
)
(
input rst_i,		
input clk_i,		

input cyc_i,		
input stb_i,		
output ack_o,		
input we_i,			
input [7:0] sel_i,	
input [23:0] adr_i,	
input [63:0] dat_i,	
output reg [63:0] dat_o,	

input tod,			
output reg alarm		
);

reg [1:0] tod_freq;
wire [7:0] max_jcnt = tod_freq==2'b00 ? 8'h99 : tod_freq==2'b01 ? 8'h59 : tod_freq==2'b10 ? 8'h49 : 8'h99;
reg tod_en;
reg mars;
reg snapshot;
wire IsLeapYear;
wire IsDuckYear;

reg [3:0] dayL, dayH;		
reg [3:0] monthL, monthH;	
reg [3:0] yearN0, yearN1, yearN2, yearN3;	
reg [3:0] jiffyL, secL, minL, hourL;
reg [3:0] jiffyH, secH, minH, hourH;

reg [3:0] dayLo, dayHo;		
reg [3:0] monthLo, monthHo;	
reg [3:0] yearN0o, yearN1o, yearN2o, yearN3o;	
reg [3:0] jiffyLo, secLo, minLo, hourLo;
reg [3:0] jiffyHo, secHo, minHo, hourHo;

reg [7:0] alarm_care;
wire [63:0] alarm_carex = {
	{8{alarm_care[7]}},
	{8{alarm_care[6]}},
	{8{alarm_care[5]}},
	{8{alarm_care[4]}},
	{8{alarm_care[3]}},
	{8{alarm_care[2]}},
	{8{alarm_care[1]}},
	{8{alarm_care[0]}}
};
reg [3:0] alm_dayL, alm_dayH;		
reg [3:0] alm_monthL, alm_monthH;	
reg [3:0] alm_yearN0, alm_yearN1, alm_yearN2, alm_yearN3;	
reg [3:0] alm_jiffyL, alm_secL, alm_minL, alm_hourL;
reg [3:0] alm_jiffyH, alm_secH, alm_minH, alm_hourH;


wire incJiffyH = jiffyL == 4'd9;
wire incSecL = {jiffyH,jiffyL}==max_jcnt;
wire incSecH = incSecL && secL==4'h9;
wire incMinL = incSecH && secH==4'h5;
wire incMinH = incMinL && minL==4'h9;
wire incHourL = incMinH && minH==4'h5;
wire incHourH = incHourL && hourL==4'h9;

wire incDayL    = mars ?
					{hourH,hourL,minH,minL,secH,secL,jiffyH,jiffyL} == {24'h243721,max_jcnt} :
					{hourH,hourL,minH,minL,secH,secL,jiffyH,jiffyL} == {24'h235959,max_jcnt}
					;
wire incDayH = incDayL && dayL==4'h9;

reg incMarsMonth;
always @(monthH,monthL,dayH,dayL)
	begin
	case({monthH,monthL})	
	8'h01:	incMarsMonth = {dayH,dayL}==8'h33;
	8'h02:	incMarsMonth = {dayH,dayL}==8'h33;
	8'h03:	incMarsMonth = {dayH,dayL}==8'h33;
	8'h04:	incMarsMonth = {dayH,dayL}==8'h34;
	8'h05:	incMarsMonth = {dayH,dayL}==8'h34;
	8'h06:	incMarsMonth = {dayH,dayL}==8'h33;
	8'h07:	incMarsMonth = {dayH,dayL}==8'h33;
	8'h08:	incMarsMonth = {dayH,dayL}==8'h33;
	8'h09:	incMarsMonth = {dayH,dayL}==8'h34;
	8'h10:	incMarsMonth = {dayH,dayL}==8'h34;
	8'h11:	incMarsMonth = {dayH,dayL}==8'h33;
	8'h12:	incMarsMonth = {dayH,dayL}==8'h33;
	8'h13:	incMarsMonth = {dayH,dayL}==8'h33;
	8'h14:	incMarsMonth = {dayH,dayL}==8'h34;
	8'h15:	incMarsMonth = {dayH,dayL}==8'h34;
	8'h16:	incMarsMonth = {dayH,dayL}==8'h33;
	8'h17:	incMarsMonth = {dayH,dayL}==8'h33;
	8'h18:	incMarsMonth = {dayH,dayL}==8'h33;
	8'h19:	incMarsMonth = {dayH,dayL}==8'h34;
	8'h20:	incMarsMonth = IsDuckYear ? {dayH,dayL}==8'h34 : {dayH,dayL}==8'h35;
	endcase
	end

reg incEarthMonth;
always @(monthH,monthL,dayH,dayL)
	begin
	case({monthH,monthL})	
	8'h01:	incEarthMonth = {dayH,dayL}==8'h31;
	8'h02:	incEarthMonth = IsLeapYear ? {dayH,dayL}==8'h29 : {dayH,dayL}==8'h28;
	8'h03:	incEarthMonth = {dayH,dayL}==8'h31;
	8'h04:	incEarthMonth = {dayH,dayL}==8'h30;
	8'h05:	incEarthMonth = {dayH,dayL}==8'h31;
	8'h06:	incEarthMonth = {dayH,dayL}==8'h30;
	8'h07:	incEarthMonth = {dayH,dayL}==8'h31;
	8'h08:	incEarthMonth = {dayH,dayL}==8'h31;
	8'h09:	incEarthMonth = {dayH,dayL}==8'h30;
	8'h10:	incEarthMonth = {dayH,dayL}==8'h31;
	8'h11:	incEarthMonth = {dayH,dayL}==8'h30;
	8'h12:	incEarthMonth = {dayH,dayL}==8'h31;
	endcase
	end

wire incMonthL  = incDayL && (mars ? incMarsMonth : incEarthMonth);
wire incMonthH  = incMonthL && monthL==4'd9;
wire incYearN0	= incMonthL && (mars ? {monthH,monthL} == 8'h20 : {monthH,monthL} == 8'h12);
wire incYearN1  = incYearN0 && yearN0 == 4'h9;
wire incYearN2  = incYearN1 && yearN1 == 4'h9;
wire incYearN3  = incYearN2 && yearN2 == 4'h9;


wire cs = cyc_i && stb_i && (adr_i[23:5]==pIOAddress[23:5]);

reg ack1;
always @(posedge clk_i)
	ack1 <= cs;
assign ack_o = cs ? (we_i ? 1'b1 : ack1) : 1'b0;

wire tods;
sync2s sync0(.rst(rst_i), .clk(clk_i), .i(tod), .o(tods));

wire tod_edge;
edge_det ed_tod(.rst(rst_i), .clk(clk_i), .ce(1'b1), .i(tods), .pe(tod_edge), .ne(), .ee());

wire isAlarm =
		{
			alm_jiffyH,alm_jiffyL,
			alm_secH,alm_secL,
			alm_minH,alm_minL,
			alm_hourH, alm_hourL,
			alm_dayH,alm_dayL,
			alm_monthH,alm_monthL,
			alm_yearN1,alm_yearN0,
			alm_yearN3,alm_yearN2
		} & alarm_carex ==
		{
			jiffyH,jiffyL,
			secH,secL,
			minH,minL,
			hourH,hourL,
			dayH,dayL,
			monthH,monthL,
			yearN1,yearN0,
			yearN3,yearN3
		} & alarm_carex;


reg oalarm;

always @(posedge clk_i)
	if (rst_i) begin
		oalarm <= 1'b0;
		mars <= pMars;
		tod_en <= 1'b1;
		tod_freq = 2'b00;

		jiffyL <= 4'h0;
		jiffyH <= 4'h0;
		secL <= 4'h0;
		secH <= 4'h0;
		minL <= 4'h6;
		minH <= 4'h0;
		hourL <= 4'h3;
		hourH <= 4'h1;

		dayL <= 4'h0;
		dayH <= 4'h1;
		monthL <= 4'h6;
		monthH <= 4'h0;
		yearN0 <= 4'h2;
		yearN1 <= 4'h1;
		yearN2 <= 4'h0;
		yearN3 <= 4'h2;

		alarm_care <= 8'hFF;
		alm_jiffyL <= 4'h0;
		alm_jiffyH <= 4'h0;
		alm_secL <= 4'h0;
		alm_secH <= 4'h0;
		alm_minL <= 4'h0;
		alm_minH <= 4'h0;
		alm_hourL <= 4'h0;
		alm_hourH <= 4'h0;

		alm_dayL <= 4'h0;
		alm_dayH <= 4'h0;
		alm_monthL <= 4'h0;
		alm_monthH <= 4'h0;
		alm_yearN0 <= 4'h0;
		alm_yearN1 <= 4'h0;
		alm_yearN2 <= 4'h0;
		alm_yearN3 <= 4'h0;
		
		snapshot <= 1'b0;

	end
	else begin

		oalarm <= isAlarm;
		snapshot <= 1'b0;	

		if (isAlarm & !oalarm)
			alarm <= 1'b1;

		
		if (cs & we_i) begin
			case(adr_i[4:3])

			2'd0:	begin
					if (sel_i[0]) begin jiffyL <= dat_i[3:0]; jiffyH <= dat_i[7:4]; end
					if (sel_i[1]) begin secL <= dat_i[3:0]; secH <= dat_i[7:4]; end
					if (sel_i[2]) begin minL <= dat_i[3:0]; minH <= dat_i[7:4]; end
					if (sel_i[3]) begin hourL <= dat_i[3:0]; hourH <= dat_i[7:4]; end
					if (sel_i[4]) begin dayL <= dat_i[3:0]; dayH <= dat_i[7:4]; end
					if (sel_i[5]) begin monthL <= dat_i[3:0]; monthH <= dat_i[7:4]; end
					if (sel_i[6]) begin yearN0 <= dat_i[3:0]; yearN1 <= dat_i[7:4]; end
					if (sel_i[7]) begin yearN2 <= dat_i[3:0]; yearN3 <= dat_i[7:4]; end
					end

			2'd1:	begin
					if (sel_i[0]) begin alm_jiffyL <= dat_i[3:0]; alm_jiffyH <= dat_i[7:4]; end
					if (sel_i[1]) begin alm_secL <= dat_i[3:0]; alm_secH <= dat_i[7:4]; end
					if (sel_i[2]) begin alm_minL <= dat_i[3:0]; alm_minH <= dat_i[7:4]; end
					if (sel_i[3]) begin alm_hourL <= dat_i[3:0]; alm_hourH <= dat_i[7:4]; end
					if (sel_i[4]) begin alm_dayL <= dat_i[3:0]; alm_dayH <= dat_i[7:4]; end
					if (sel_i[5]) begin alm_monthL <= dat_i[3:0]; alm_monthH <= dat_i[7:4]; end
					if (sel_i[6]) begin alm_yearN0 <= dat_i[3:0]; alm_yearN1 <= dat_i[7:4]; end
					if (sel_i[7]) begin alm_yearN2 <= dat_i[3:0]; alm_yearN3 <= dat_i[7:4]; end
					end

			2'd2:	begin
					if (sel_i[0]) alarm_care <= dat_i[7:0];
					if (sel_i[1]) 	begin
									tod_en <= dat_i[8];
									tod_freq <= dat_i[10:9];
									end
					if (sel_i[2]) mars <= dat_i[16];
					end

			
			2'd3:	snapshot <= 1'b1;

			endcase
		end
		if (cs) begin
			case(adr_i[4:3])
			2'd0:	dat_o <= {yearN3o,yearN2o,yearN1o,yearN0o,monthHo,monthLo,dayHo,dayLo,hourHo,hourLo,minHo,minLo,secHo,secLo,jiffyHo,jiffyLo};
			2'd1:	begin
						dat_o <= {alm_yearN3,alm_yearN2,alm_yearN1,alm_yearN0,alm_monthH,alm_monthL,alm_dayH,alm_dayL,alm_hourH,alm_hourL,alm_minH,alm_minL,alm_secH,alm_secL,alm_jiffyH,alm_jiffyL};
						alarm <= 1'b0;
					end
			2'd2:	dat_o <= {mars,5'b0,tod_freq,tod_en,alarm_care}; 
			2'd3:	dat_o <= 0;
			endcase
		end
		else
			dat_o <= 64'd0;


		
		if (tod_en & tod_edge) begin

			jiffyL <= jiffyL + 4'h1;

			if (incJiffyH) begin
				jiffyL <= 4'h0;
				jiffyH <= jiffyH + 4'h1;
			end

			
			if (incSecL) begin
				jiffyH <= 4'h0;
				secL <= secL + 4'h1;
			end
			if (incSecH) begin
				secL <= 4'h0;
				secH <= secH + 4'h1;
			end

			if (incMinL) begin
				minL <= minL + 4'h1;
				secH <= 4'h0;
			end
			if (incMinH) begin
				minL <= 4'h0;
				minH <= minH + 4'h1;
			end

			if (incHourL) begin
				minH <= 4'h0;
				hourL <= hourL + 4'h1;
			end
			if (incHourH) begin
				hourL <= 4'h0;
				hourH <= hourH + 4'h1;
			end

			
			
			
			if (incDayL) begin
				dayL <= dayL + 4'h1;
				jiffyL <= 4'h0;
				jiffyH <= 4'h0;
				secL <= 4'h0;
				secH <= 4'h0;
				minL <= 4'h0;
				minH <= 4'h0;
				hourL <= 4'h0;
				hourH <= 4'h0;
			end
			if (incDayH) begin
				dayL <= 4'h0;
				dayH <= dayH + 4'h1;
			end

			if (incMonthL) begin
				dayL <= 4'h1;
				dayH <= 4'h0;
				monthL <= monthL + 4'h1;
			end
			if (incMonthH) begin
				monthL <= 4'h0;
				monthH <= monthH + 4'h1;
			end

			if (incYearN0) begin
				monthL <= 4'h1;
				monthH <= 4'h0;
			end
			if (incYearN1) begin
				yearN0 <= 4'h0;
				yearN1 <= yearN1 + 4'h1;
			end
			if (incYearN2) begin
				yearN1 <= 4'h0;
				yearN2 <= yearN2 + 4'h1;
			end
			if (incYearN3) begin
				yearN2 <= 4'h0;
				yearN3 <= yearN3 + 4'h1;
			end
		end
	end


always @(posedge clk_i)
	if (rst_i) begin
		jiffyLo <= 4'h0;
		jiffyHo <= 4'h0;
		secLo <= 4'h0;
		secHo <= 4'h0;
		minLo <= 4'h0;
		minHo <= 4'h0;
		hourLo <= 4'h0;
		hourHo <= 4'h0;
		dayLo <= 4'h0;
		dayHo <= 4'h0;
		monthLo <= 4'h0;
		monthHo <= 4'h0;
		yearN0o <= 4'h0;
		yearN1o <= 4'h0;
		yearN2o <= 4'h0;
		yearN3o <= 4'h0;
	end
	else if (snapshot) begin
		jiffyLo <= jiffyL;
		jiffyHo <= jiffyH;
		secLo <= secL;
		secHo <= secH;
		minLo <= minL;
		minHo <= minH;
		hourLo <= hourL;
		hourHo <= hourH;
		dayLo <= dayL;
		dayHo <= dayH;
		monthLo <= monthL;
		monthHo <= monthH;
		yearN0o <= yearN0;
		yearN1o <= yearN1;
		yearN2o <= yearN2;
		yearN3o <= yearN3;
	end

wire [7:0] binyear = 
			yearN0
			+ {yearN1,3'b0} + {yearN1,1'b0}	
			;

wire [7:0] bincent = {yearN3,3'b0} + {yearN3,1'b0} + yearN2;

assign IsLeapYear = binyear[1:0]==2'b00 && ({yearN1,yearN0}!=8'h00 || (bincent[1:0]==2'b00 && {yearN1,yearN0}==8'h00));

assign IsDuckYear = yearN0==4'h1 || yearN0==4'h3 || yearN0==4'h6 || yearN0==4'h8;

endmodule


module edge_det(rst, clk, ce, i, pe, ne, ee);
input rst;		
input clk;		
input ce;		
input i;		
output pe;		
output ne;		
output ee;		

reg ed;
always @(posedge clk)
	if (rst)
		ed <= 1'b0;
	else if (ce)
		ed <= i;

assign pe = ~ed & i;	
assign ne = ed & ~i;	
assign ee = ed ^ i;		
	
endmodule


module sync2s(rst, clk, i, o);
	input rst;
	input clk;
	input i;
	output o;
	
	reg [1:0] s;
	always @(posedge clk)
		if (rst)
			s <= 0;
		else
			s <= {s[0],i};
			
	assign o = s[1];
	
endmodule



