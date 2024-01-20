module reset_synch (
	input clk,    // Clock
	input RST_n,  // Asynchronous reset active low
	output logic rst_n
);

	//////////////////////////////////////////////////////
  // Any hold and set timing problems are eliminated //
	//      when we synchronize the reset signal      //
  ///////////////////////////////////////////////////

   ////////////////////////////
  // Declare internal nets //
  //////////////////////////
	logic inter_val;

	/////////////////////////////////////////
  // First FF for incoming reset signal //
  ///////////////////////////////////////
	always_ff @(posedge clk or negedge RST_n) begin : FF1
		if(~RST_n) begin
			inter_val <= 0;
		end else begin
			inter_val <= 1;
		end
	end

	//////////////////////////////////////////
  // Second FF for incoming reset signal //
  ////////////////////////////////////////
	always_ff @(posedge clk or negedge RST_n) begin : FF2
		if(~RST_n) begin
			rst_n <= 0;
		end else begin
			rst_n <= inter_val;
		end
	end

endmodule : reset_synch