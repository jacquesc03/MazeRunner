module cmd_proc (
	input clk,    // Clock
	input rst_n,  // Asynchronous reset active low
	input [15:0] cmd,
	input cmd_rdy,
	output logic clr_cmd_rdy,
	output logic send_resp,
	output logic strt_cal,
	input cal_done,
	output logic in_cal,
	input sol_cmplt,
	output logic strt_hdng,
	output logic strt_mv,
	output logic stp_lft,
	output logic stp_rght,
	output logic [11:0] dsrd_hdng,
	input mv_cmplt,
	output logic cmd_md
);

logic [11:0] dsrd_hdng_val;
logic stp_lft_ff, stp_rght_ff;

//flopping the dsrd hdng output
always_ff @(posedge clk, negedge rst_n) begin
	if (!rst_n) begin
		dsrd_hdng <= 12'h000;
	end else if (strt_hdng)
		dsrd_hdng <= dsrd_hdng_val;
end

//flopping stop left and stop right
always_ff @(posedge clk) begin
	if(strt_mv) begin
		stp_lft <= stp_lft_ff;
		stp_rght <= stp_rght_ff;
	end
end

// State Machine 
typedef enum logic [2:0] {IDLE, HEADING, CAL, MAZE_SOLVE, MOVE} state_t;
state_t state, nxt_state;

always_ff @(posedge clk or negedge rst_n) begin
	if(~rst_n) 
		state <= IDLE;
	else 
		state <= nxt_state;
end

always_comb begin
	send_resp = 0;
	cmd_md = 1;
	strt_cal = 0;
	clr_cmd_rdy = 0;
	in_cal = 0;
	dsrd_hdng_val = 0;
	strt_hdng = 0;
	strt_mv = 0;
	stp_lft_ff = 0;
	stp_rght_ff = 0;
	nxt_state = state;

	case (state)
		HEADING: begin
			if(mv_cmplt) begin
				send_resp = 1;
				nxt_state = IDLE;
			end
		end
		CAL: begin
			if(cal_done) begin
				send_resp = 1;
				nxt_state = IDLE;
			end
		end
		MOVE: begin
			if(mv_cmplt) begin
				send_resp = 1;
				nxt_state = IDLE;
			end
		end
		MAZE_SOLVE: begin
			if(sol_cmplt) begin
				send_resp = 1;
				nxt_state = IDLE;
			end else
				cmd_md = 0;
		end
		default: begin
			if(cmd_rdy) begin
				clr_cmd_rdy = 1;
				case (cmd) inside
					// calibrate command
					16'b000?????????????: begin
						strt_cal = 1;
						in_cal = 1;
						nxt_state = CAL;
					end 
					16'b001?????????????: begin
						dsrd_hdng_val = cmd[11:0];
						strt_hdng = 1;
						nxt_state = HEADING;
					end
					16'b010?????????????: begin
						strt_mv = 1;
						nxt_state = MOVE;
						if(cmd[1])
							stp_lft_ff = 1;
						if(cmd[0])
							stp_rght_ff = 1;
					end
					16'b011?????????????: begin
						cmd_md = 0;
						nxt_state = MAZE_SOLVE;
					end
				endcase
			end 
		end
	endcase
end
endmodule : cmd_proc
