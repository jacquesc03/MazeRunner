module I_term (
input clk,
input rst_n,
input hdng_vld, 
input moving,
input [9:0] err_sat,
output [11:0] I_term
);

logic [15:0] sign_extended_err, sum, nxt_integrator, integrator, hdng_vld_value;
logic ov;


assign sign_extended_err = { {6{err_sat[9]}}, err_sat[9:0] }; // sign extends error to 16 bits
assign sum = sign_extended_err + integrator; 

// detects if overflow occured
assign ov = ((sign_extended_err[15] == integrator[15]) && (sum[15] != integrator[15])) ? 1 : 0; 

assign I_term = integrator[15:4];

// prevents integrator from getting wound up if the car isn't moving
// keeps the same value in the integrator if overflow occurs or if the error term is invalid
assign nxt_integrator = (!moving) ? 16'h0000 :
						(hdng_vld & (!ov)) ? sum :
						integrator;

always_ff @(posedge clk, negedge rst_n)
	if(!rst_n)
		integrator <= 16'h0000;
	else
		integrator <= nxt_integrator;

endmodule