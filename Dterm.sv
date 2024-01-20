module Dterm(clk, rst_n, hdng_vld, err_sat, D_term);
input clk, hdng_vld, rst_n; 
input signed [9:0] err_sat;
output signed [12:0] D_term;

logic signed [9:0] q1, prev_err;
logic signed [7:0] D_diff_saturated;
logic signed [10:0] D_diff_value;
localparam signed D_COEFF = 5'h0E;

// assign D_diff_value = err_sat - prev_err;

always_ff @(posedge clk) begin : proc_D_diff_value
	D_diff_value <= err_sat - prev_err;
end

assign D_diff_saturated = (!D_diff_value[10] && |D_diff_value[9:7]) ? 8'h7F :
						  (D_diff_value[10] && !(&D_diff_value[9:7])) ? 8'h80 :
				          D_diff_value[7:0];
				
				
assign D_term[12:0] = D_diff_saturated * D_COEFF;

// two pipelined FFs to capture the previous error
always_ff@(posedge clk, negedge rst_n) begin
	if(!rst_n) begin
		q1 <= 0;
		prev_err <= 0;
	end
	else if(hdng_vld) begin
		q1 <= err_sat;
		prev_err <= q1;
	end
end
endmodule



