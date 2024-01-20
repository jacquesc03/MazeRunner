module piezo_drv (
	input clk,    // Clock
	input rst_n,  // Asynchronous reset active low
	input batt_low, 
	input fanfare, 
	output logic piezo, 
	output logic piezo_n
);

	parameter FAST_SIM = 1; // used to speed up simulation

	////////////////////////////
  // Declare internal nets //
  //////////////////////////
	`define G6 16'h3E48
	`define C7 16'h2EA9
	`define E7 16'h2508
	`define G7 16'h1F24

	////////////////////////////
  // Declare internal nets //
  //////////////////////////
	`define third 25'h0800000
	`define quarter 25'h0C00000
	`define sixthnth 25'h0400000
	`define half 25'h1000000

	////////////////////
  // Define States //
  //////////////////
	typedef enum reg [4:0] {IDLE, FF_G6, FF_C7, FF_E7, FF_G7, FF_E7Q, FF_G7H, LOW_G6, LOW_C7, LOW_E7} state_t;
	state_t state, nstate;

	//////////////////////////////////////
  // Outputs of SM are of type logic //
  ////////////////////////////////////
	logic strt_frq, strt_dur;
	logic [24:0] SM_duration_tmr;
	logic [15:0] SM_frequency_tmr;

	////////////////////////////
  // Declare internal nets //
  //////////////////////////
	logic [24:0] duration_tmr, Check_duration_tmr;
	logic [15:0] frequency_tmr, Check_frequency_tmr;
	logic [4:0] cntr;
	logic frq_done, dur_done, dur_done_ff;

	////////////////////////////////////////////////
  // Controlling the counter based on FAST_SIM //
  //////////////////////////////////////////////
	assign cntr = (FAST_SIM) ? 10'd16 : 1'b1;

	////////////////////////////
  // Frequency incrementer //
  //////////////////////////
	always_ff @(posedge clk, negedge rst_n) begin : proc_frequency_tmr
		if (~rst_n) begin
			frequency_tmr <= 0;
		end
		else if(strt_frq || frq_done) begin
			Check_frequency_tmr <= SM_frequency_tmr;
			frequency_tmr <= 0;
		end else begin
			frequency_tmr <= frequency_tmr + 1;
		end
	end

	///////////////////////////
  // Duration incrementer //
  /////////////////////////
	always_ff @(posedge clk, negedge rst_n) begin : proc_duration_tmr
		if (~rst_n) begin
			duration_tmr <= 0;
		end
		else if(strt_dur || dur_done_ff) begin
			duration_tmr <= 0;
			Check_duration_tmr <= SM_duration_tmr;
		end else begin
			duration_tmr <= duration_tmr + cntr;
		end
	end

	/////////////////////////////////////////////////////
  // Checks if the these values are at wanted value //
  ///////////////////////////////////////////////////
	assign frq_done = (frequency_tmr == Check_frequency_tmr) ? 1'b1 : 1'b0;
	assign dur_done = (duration_tmr == Check_duration_tmr) ? 1'b1 : 1'b0;

	////////////////////////////////////
  // Reset and preset for dur_done //
  //////////////////////////////////
	always_ff @(posedge clk, negedge rst_n) begin
		if (~rst_n)
			dur_done_ff <= 0;
		else if (dur_done)
			dur_done_ff <= 1;
		else
			dur_done_ff <= 0;
	end

	////////////////////////
  // Notting piezo //
  //////////////////////
	always_ff @(posedge clk or negedge rst_n) begin : proc_piezo
		if(~rst_n) begin
			piezo <= 0;
		end else if (frq_done) begin
			piezo <= ~piezo;
		end
	end

	assign piezo_n = ~piezo;

	////////////////////////
  // Infer State Flops //
  //////////////////////
	always_ff @(posedge clk, negedge rst_n) begin : SM_flop
		if (!rst_n)
			state <= IDLE;
		else
			state <= nstate;
	end : SM_flop

	//////////////////////////////////////
  // state transition & output logic //
  ////////////////////////////////////
  always_comb begin
   //////////////////////
	 // Default outputs //
	 ////////////////////
		strt_dur = 0;
		strt_frq = 0;
		SM_duration_tmr = 0;
		SM_frequency_tmr = 0;
		nstate = state;

		case (state)
			default : begin
				if(batt_low) begin
					nstate = LOW_G6;
					SM_frequency_tmr = `G6;
					SM_duration_tmr = `third;
					strt_dur = 1;
					strt_frq = 1;
				end else if (fanfare) begin
					nstate = FF_G6;
					SM_frequency_tmr = `G6;
					SM_duration_tmr = `third;
					strt_dur = 1;
					strt_frq = 1;
				end
			end

			FF_G6 : begin
				SM_frequency_tmr = `G6;
				SM_duration_tmr = `third;
				if(dur_done) begin
					nstate = FF_C7;
				end
			end

			FF_C7 : begin
				SM_frequency_tmr = `C7;
				SM_duration_tmr = `third;
				if(dur_done) begin
					nstate = FF_E7;
				end
			end

			FF_E7 : begin
				SM_frequency_tmr = `E7;
				SM_duration_tmr = `third;
				if(dur_done) begin
					nstate = FF_G7;
				end
			end

			FF_G7 : begin
				SM_frequency_tmr = `G7;
				SM_duration_tmr = `quarter;
				if(dur_done) begin
					nstate = FF_E7Q;
				end
			end

			FF_E7Q : begin
				SM_frequency_tmr = `E7;
				SM_duration_tmr = `sixthnth;
				if(dur_done) begin
					nstate = FF_G7H;
				end
			end

			FF_G7H : begin
				SM_frequency_tmr = `G7;
				SM_duration_tmr = `half;
				if(dur_done) begin
					nstate = IDLE;
				end
			end

			LOW_G6 : begin
				SM_frequency_tmr = `G6;
				SM_duration_tmr = `third;
				if(dur_done) begin
					nstate = LOW_C7;
				end
			end

			LOW_C7 : begin
				SM_frequency_tmr = `C7;
				SM_duration_tmr = `third;
				if(dur_done) begin
					nstate = LOW_E7;
				end
			end

			LOW_E7 : begin
				SM_frequency_tmr = `E7;
				SM_duration_tmr = `third;
				if(dur_done) begin
					nstate = IDLE;
				end
			end
		endcase
	end

endmodule : piezo_drv