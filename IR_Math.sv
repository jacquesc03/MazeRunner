module IR_math (clk, rst_n, lft_opn, rght_opn, lft_IR, rght_IR, IR_Dtrm, en_fusion, dsrd_hdng, dsrd_hdng_adj);

parameter NOM_IR = 12'h900;

input lft_opn, rght_opn, clk, rst_n;
input [11:0] lft_IR, rght_IR;
input signed [8:0] IR_Dtrm;
input en_fusion;
input signed [11:0] dsrd_hdng;
output signed [11:0] dsrd_hdng_adj;

logic signed [12:0] IR_diff;
logic signed [11:0] IR_diff_adj;
logic signed [11:0] IR_adj;
logic signed [11:0] lft_IR_only;
logic signed [11:0] rght_IR_only;
logic signed [12:0] calculated_heading;



assign IR_diff = {1'b0, lft_IR} - {1'b0, rght_IR};
assign IR_diff_adj = IR_diff[12:1];

//pipelining lft_IR
always_ff @(posedge clk) begin : proc_lft_IR_only
	lft_IR_only <= lft_IR - NOM_IR;
end

//pipelining rght_IR
always_ff @(posedge clk) begin : proc_rght_IR_only
	rght_IR_only <= NOM_IR - rght_IR;
end

// cases for right and left open
assign IR_adj = (lft_opn && rght_opn) ? 12'h000 :
				(lft_opn) ? rght_IR_only :
				(rght_opn) ? lft_IR_only :
				IR_diff_adj;

//calculate the desired heading
assign calculated_heading = { {2{IR_Dtrm[8]}}, IR_Dtrm[8:0], 2'b00 } + { {8{IR_adj[11]}}, IR_adj[10:5] };
assign dsrd_hdng_adj = (en_fusion) ? (calculated_heading[12:1] + dsrd_hdng) : dsrd_hdng;

endmodule