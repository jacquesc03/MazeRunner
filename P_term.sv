module P_term ( 
	input signed [11:0] error,
	output signed [13:0] P_term,
	output [9:0] err_sat
);

localparam signed P_COEFF = 4'h3;

logic signed [9:0] saturated_error;

// saturate error from 12 bits to 10 bits
assign saturated_error = (!error[11] && |error[10:9]) ? 10'h1FF :
						 (error[11] && !(&error[10:9])) ? 10'h200 :
						 error[9:0];

assign err_sat = saturated_error;

assign P_term = saturated_error * P_COEFF;

endmodule