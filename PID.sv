module PID (clk, rst_n, moving, dsrd_hdng, actl_hdng, hdng_vld, frwrd_spd, at_hdng, lft_spd, rght_spd);

input clk, rst_n, moving;
input signed [11:0] dsrd_hdng;
input signed [11:0] actl_hdng;
input hdng_vld;
input [10:0] frwrd_spd;
output at_hdng;
output logic [11:0] lft_spd;
output logic [11:0] rght_spd;

logic [11:0] error;
logic [13:0] pterm_out;
logic [11:0] iterm_out;
logic [12:0] dterm_out;
logic [14:0] pterm_out_ext, iterm_out_ext, dterm_out_ext;
logic signed [9:0] err_sat;
logic [9:0] abs_err_sat;
logic [14:0] pid_term;
logic [11:0] pid_term_div8;
logic moving_ff;

localparam COMPARE_VAL = 10'd30;

assign error = actl_hdng - dsrd_hdng;

// All terms instantiation
P_term pterm1 (.error(error), .P_term(pterm_out), .err_sat(err_sat));
I_term iterm1 (.clk(clk), .rst_n(rst_n), .hdng_vld(hdng_vld), .moving(moving), .err_sat(err_sat), .I_term(iterm_out));
Dterm dterm1 (.clk(clk), .rst_n(rst_n), .hdng_vld(hdng_vld), .err_sat(err_sat), .D_term(dterm_out));


//flopping all of the terms outputs
always_ff @(posedge clk) begin : proc_pterm_out_ext
	pterm_out_ext <= {{1{pterm_out[13]}}, pterm_out[13:0]};
end

always_ff @(posedge clk) begin : proc_iterm_out_ext
	iterm_out_ext <= {{3{iterm_out[11]}}, iterm_out[11:0]}; 
end

always_ff @(posedge clk) begin : proc_dterm_out_ext
	dterm_out_ext <= {{2{dterm_out[12]}}, dterm_out[12:0]}; ;
end

assign abs_err_sat = !err_sat[9] ? err_sat : -err_sat;
assign at_hdng = ((abs_err_sat) < COMPARE_VAL) ? 1 : 0;

assign pid_term = pterm_out_ext + iterm_out_ext + dterm_out_ext;

//pipelining pid_term
always_ff @(posedge clk) begin : proc_pid_term_div8
	pid_term_div8 <= pid_term[14:3];
end

//pipelining moving
always_ff @(posedge clk) begin : proc_moving_ff
	moving_ff <= moving;
end

//calculate left and right speed
assign rght_spd = (moving_ff) ? {1'b0, frwrd_spd[10:0]} - pid_term_div8 : 12'h000;
assign lft_spd = (moving_ff) ? {1'b0, frwrd_spd[10:0]} + pid_term_div8 : 12'h000;  

endmodule