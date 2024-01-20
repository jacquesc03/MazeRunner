module maze_solve (
	input clk,    // Clock
	input rst_n,  // Asynchronous reset active low
	input cmd_md,
	input cmd0,
	input lft_opn,
	input rght_opn,
	input mv_cmplt,
	input sol_cmplt,
	output logic strt_hdng,
	output logic [11:0] dsrd_hdng,
	output logic strt_mv,
	output logic stp_lft,
	output logic stp_rght
);

`define NORTH 12'h000
`define SOUTH 12'h7FF
`define EAST 12'hC00
`define WEST 12'h3FF

logic hdng_en;
logic [11:0] dsrd_hdng_val;

always_ff @(posedge clk or negedge rst_n) begin : dsrd_hdng_register
	if(~rst_n) begin
		dsrd_hdng <= 12'h000;
	end else if (hdng_en) begin
		dsrd_hdng <= dsrd_hdng_val;
	end
end

typedef enum logic [2:0] {IDLE, FRWD, HDNG_WAIT, ROTATE_WAIT, FRWD_WAIT} state_t;
state_t state, nxt_state;

always_ff @(posedge clk or negedge rst_n) begin : state_ff
	if(~rst_n) begin
		state <= IDLE;
	end else begin
		state <= nxt_state;
	end
end

always_comb begin : state_machine
	dsrd_hdng_val = 0;
	strt_mv = 0;
	strt_hdng = 0;
	hdng_en = 0;
	nxt_state = state;

	case (state)
		default : begin
			// kick off forward
			if(!cmd_md) begin
				strt_mv = 1;
				nxt_state = FRWD;
			end
		end
		FRWD : begin
			// case where magnet is found
			if(mv_cmplt && sol_cmplt)
				nxt_state = IDLE;
			else if(mv_cmplt & cmd0) begin // Left Affinity
				if(lft_opn) begin
					case (dsrd_hdng) // turns left
						`NORTH: 
							dsrd_hdng_val = `WEST;
						`WEST:  	
							dsrd_hdng_val = `SOUTH;
						`SOUTH: 	
							dsrd_hdng_val = `EAST;
						default: 	
							dsrd_hdng_val = `NORTH;
					endcase
				end else if (rght_opn) begin
					case (dsrd_hdng) // turns right
						`NORTH: 	
							dsrd_hdng_val = `EAST;
						`WEST:  	
							dsrd_hdng_val = `NORTH;
						`SOUTH: 	
							dsrd_hdng_val = `WEST;
						default: 	
							dsrd_hdng_val = `SOUTH;
					endcase
				end else begin
					case (dsrd_hdng) // turns 180
						`NORTH: 	
							dsrd_hdng_val = `SOUTH;
						`WEST:  	
							dsrd_hdng_val = `EAST;
						`SOUTH: 	
							dsrd_hdng_val = `NORTH;
						default: 	
							dsrd_hdng_val = `WEST;
					endcase
				end
				hdng_en = 1;
				nxt_state = HDNG_WAIT;
			end else if(mv_cmplt & !cmd0) begin // Right Affinity
				if(rght_opn) begin
					case (dsrd_hdng) // turns right
						`NORTH: 	
							dsrd_hdng_val = `EAST;
						`WEST:  	
							dsrd_hdng_val = `NORTH;
						`SOUTH: 	
							dsrd_hdng_val = `WEST;
						default: 	
							dsrd_hdng_val = `SOUTH;
					endcase
				end else if (lft_opn) begin
					case (dsrd_hdng) // turns left
						`NORTH: 
							dsrd_hdng_val = `WEST;
						`WEST:  	
							dsrd_hdng_val = `SOUTH;
						`SOUTH: 	
							dsrd_hdng_val = `EAST;
						default: 	
							dsrd_hdng_val = `NORTH;
					endcase
				end else begin
					case (dsrd_hdng) // turns 180
						`NORTH: 	
							dsrd_hdng_val = `SOUTH;
						`WEST:  	
							dsrd_hdng_val = `EAST;
						`SOUTH: 	
							dsrd_hdng_val = `NORTH;
						default: 	
							dsrd_hdng_val = `WEST;
					endcase
				end
				// updates heading register
				hdng_en = 1;
				nxt_state = HDNG_WAIT;
			end
		end
		HDNG_WAIT : begin 
			// waits one clock cycle for heading register to change
			strt_hdng = 1;
			nxt_state = ROTATE_WAIT;
		end
		// waits for maze runner to update heading
		ROTATE_WAIT : begin 
			if(mv_cmplt) begin
				nxt_state = FRWD_WAIT;
			end
		end
		// prevents race condition when kicking off forward
		FRWD_WAIT : begin
			strt_mv = 1;
			nxt_state = FRWD;
		end
	endcase
end

// tells navigate which opening to stop at based off affinity from cmd_proc
assign stp_lft = cmd0;
assign stp_rght = ~cmd0;

endmodule : maze_solve
