module UART_rx (
	input clk, rst_n, RX, clr_rdy,		// clock and asychronous reset
	output [7:0] rx_data,
	output logic rdy
);

	logic [11:0] baud_cnt;
	logic [11:0] init_baud_cnt;
	logic [8:0] rx_shft_reg;
	logic [3:0] bit_cnt;
	logic shift;
	logic RX_meta, RX_stable;

	logic start, receiving, set_rdy; // state machine outputs 

	typedef enum reg {IDLE, RUNNING} state_t;
	state_t state, nxt_state;

	assign rx_data = rx_shft_reg[7:0];
	assign init_baud_cnt = (start) ? 12'h516 : 12'hA2C;

	always_ff @(posedge clk, negedge rst_n) begin // prevents metastability of RX data
		if(!rst_n) begin
			RX_meta <= 1;
			RX_stable <= 1;
		end else begin
			RX_meta <= RX;
			RX_stable <= RX_meta;
		end
	end		

	always_ff @(posedge clk) begin // keeps track of number of bits received from RX
		if(start)
			bit_cnt <= 0;
		else if(shift)
			bit_cnt <= bit_cnt + 1'b1;
	end

	always_ff @(posedge clk) begin
		if(start | shift)
			baud_cnt <= init_baud_cnt;
		else if(receiving)
			baud_cnt <= baud_cnt - 1'b1;	
	end

	assign shift = (baud_cnt == 0) ? 1 : 0; // shifts RX data once baud_cnt becomes 0

	always_ff @(posedge clk) // receives RX data and shifts it into a 9 bit register, start bit falls off
		if(shift)
			rx_shft_reg <= {RX_stable, rx_shft_reg[8:1]};

	always_ff@(posedge clk, negedge rst_n) // state machine flip flop
		if(!rst_n)
			state <= IDLE;
		else
			state <= nxt_state;
			
	always_ff @(posedge clk, negedge rst_n)
		if(!rst_n)
			rdy <= 0;
		else if(clr_rdy)
			rdy <= 0;
		else if(start)
			rdy <= 0;
		else if(set_rdy)
			rdy <= 1;

	always_comb begin
		start = 0;
		receiving = 0;
		set_rdy = 0;
		nxt_state = state;

		case (state) 
			RUNNING: begin
				if(bit_cnt == 4'hA) begin
					set_rdy = 1;
					nxt_state = IDLE;
				end	else
					receiving = 1;
			end
			default: begin
				if(!RX_stable) begin
					start = 1;
					receiving = 1;
					nxt_state = RUNNING;
				end
			end
		endcase
	end
endmodule