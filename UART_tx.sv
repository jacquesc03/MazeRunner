module UART_tx (
	input clk, rst_n, trmt,
	input [7:0] tx_data,
	output logic TX,
	output logic tx_done
);

	logic [11:0] baud_cnt;
	logic [8:0] tx_shft_reg, tx_shft_reg_input;
	logic [3:0] bit_cnt;
	logic shift;
	logic init, transmit, set_done, clr_done; // state machine outputs

	typedef enum reg {IDLE, RUNNING} state_t;

	state_t state, nxt_state;

	always_ff @(posedge clk, negedge rst_n)
		if(!rst_n)
			state <= IDLE;
		else
			state <= nxt_state;

	always_comb begin
		init = 0;
		transmit = 0;
		set_done = 0;
		clr_done = 0;
		nxt_state = state;
		
		case (state)
		RUNNING: begin
			if(bit_cnt == 4'hA) begin
				set_done = 1;
				nxt_state = IDLE;
			end else
				transmit = 1;
		end
		// IDLE case
		default: begin
			if(trmt) begin
				init = 1;
				clr_done = 1;
				transmit = 1;
				nxt_state = RUNNING;
			end
		end
			
		endcase

	end 

	// asserts tx_done 
	always_ff @(posedge clk, negedge rst_n) begin
		if(!rst_n)
			tx_done <= 0;
		else if (init)
			tx_done <= 0;
		else if(set_done)
			tx_done <= 1'b1;
	end

	always_ff @(posedge clk) // counter that keeps track of number of times shifted
		if(init)
			bit_cnt <= 0;
		else if(shift)
			bit_cnt <= bit_cnt + 1;

	always_ff @(posedge clk) // counts up to 2604, the equivalent to one period of baud rate at 50MHz clock
		if(init | shift)
			baud_cnt <= 0;
		else if(transmit)
			baud_cnt <= baud_cnt + 1;
			
	always_ff @(posedge clk) begin // asserts shift once counter reaches 2604
		if (baud_cnt == 12'hA2C)
			shift <= 1;
		else
			shift <= 0;
	end	

	always_ff @(posedge clk, negedge rst_n) // shift register that contains TX data
		if(!rst_n)
			tx_shft_reg <= 8'hFF;
		else if(init)
			tx_shft_reg <= {tx_data, 1'b0};
		else if(shift)
			tx_shft_reg <= {1'b1, tx_shft_reg[8:1]};
		
	always_ff @(posedge clk) begin
		TX <= tx_shft_reg[0];
	end	
endmodule