module MtrDrv(
  input clk, rst_n,
  input signed [11:0] lft_spd, rght_spd, vbatt,
  output lftPWM1, lftPWM2, rghtPWM1, rghtPWM2
);

logic signed [12:0] scale_factor, lft_sat, rght_sat;
logic signed [24:0] lft_prod, rght_prod;
logic signed [11:0] lft_scaled, rght_scaled;
logic signed [11:0] lft_duty, rght_duty;

//module instantiations
DutyScaleROM iDUT(.clk(clk), .batt_level(vbatt[9:4]), .scale(scale_factor));
PWM12 iDUTlft(.clk(clk), .rst_n(rst_n), .duty(lft_duty), .PWM1(lftPWM1), .PWM2(lftPWM2));
PWM12 iDUTrght(.clk(clk), .rst_n(rst_n), .duty(rght_duty), .PWM1(rghtPWM1), .PWM2(rghtPWM2));

//pipelining lft product
always_ff @(posedge clk) begin : proc_lft_prod
  lft_prod <= lft_spd*$signed(scale_factor);;
end

//pipelining rght product
always_ff @(posedge clk) begin : proc_rght_prod
  rght_prod <= rght_spd*$signed(scale_factor);
end


assign lft_sat = lft_prod[23:11];
assign rght_sat = rght_prod[23:11];

//saturating lft sat from 13 to 12
assign lft_scaled = (~lft_sat[12] && lft_sat[11]) ? 12'h7FF :
                 (lft_sat[12] && ~lft_sat[11]) ? 12'h800 :
                 lft_sat[11:0];

//saturating rght sat from 13 to 12
assign rght_scaled = (~rght_sat[12] && rght_sat[11]) ? 12'h7FF :
                 (rght_sat[12] && ~rght_sat[11]) ? 12'h800 :
                 rght_sat[11:0];

//pipelining lft_duty
always_ff @(posedge clk) begin : proc_lft_duty
  lft_duty <= lft_scaled + $signed(12'h800);
end

//pipilining rght_duty
always_ff @(posedge clk) begin : proc_rght_duty
  rght_duty <= $signed(12'h800) - rght_scaled;
end

endmodule