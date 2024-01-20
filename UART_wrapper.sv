module UART_wrapper(
	input clk, rst_n, RX, trmt,
	input [7:0] resp,
	output logic cmd_rdy, clr_cmd_rdy, tx_done, TX,
	output [15:0] cmd
);

	////////////////////////////
  // Declare internal nets //
  //////////////////////////
	logic rx_rdy, clr_rx_rdy, store_data;
	logic [7:0] rx_data;
	logic [7:0] high_byte;

	////////////////////
  // Define States //
  //////////////////
	typedef enum reg {IDLE, RUN} state_t;
	state_t state, nstate;

	//////////////////////////////////////////////////////////////
  // Instantiate UART to handle the transmitter and receiver //
  ////////////////////////////////////////////////////////////
	UART iUART(.clk(clk), .rst_n(rst_n), .RX(RX), .TX(TX), .tx_data(resp), .trmt(trmt),
						.tx_done(tx_done), .rx_data(rx_data), .rx_rdy(rx_rdy), .clr_rx_rdy(clr_rx_rdy));

	///////////////////////////////////////////////////////////////
  // Stores high byte of command until low byte gets received //
  /////////////////////////////////////////////////////////////
	always_ff @(posedge clk) begin
		if(store_data)
			high_byte <= rx_data;
	end

	assign cmd = {high_byte, rx_data};

	////////////////////////
  // Infer State Flops //
  //////////////////////
	always_ff @(posedge clk, negedge rst_n)
		if (!rst_n)
			state <= IDLE;
		else
			state <= nstate;

	//////////////////////////////////////
  // state transition & output logic //
  ////////////////////////////////////
  always_comb begin
   //////////////////////
	 // Default outputs //
	 ////////////////////
	store_data = 0;
	clr_rx_rdy = 0;
	cmd_rdy = 0;
	nstate = state;

	case (state)
		RUN: begin
			if(rx_rdy) begin
				clr_rx_rdy = 1;
				cmd_rdy = 1;
				store_data = 0;
				nstate = IDLE;
			end
		end
		//IDLE state
		default: begin
			if(rx_rdy) begin
				cmd_rdy = 0;
				clr_rx_rdy = 1;
				store_data = 1;
				nstate = RUN;
			end
		end
	endcase
end
endmodule