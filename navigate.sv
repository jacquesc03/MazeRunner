module navigate(clk,rst_n,strt_hdng,strt_mv,stp_lft,stp_rght,mv_cmplt,hdng_rdy,moving,
                en_fusion,at_hdng,lft_opn,rght_opn,frwrd_opn,frwrd_spd);
				
  parameter FAST_SIM = 1;		// speeds up incrementing of frwrd register for faster simulation
				
  input clk,rst_n;					// 50MHz clock and asynch active low reset
  input strt_hdng;					// indicates should start a new heading
  input strt_mv;					// indicates should start a new forward move
  input stp_lft;					// indicates should stop at first left opening
  input stp_rght;					// indicates should stop at first right opening
  input hdng_rdy;					// new heading reading ready....used to pace frwrd_spd increments
  output logic mv_cmplt;			// asserted when heading or forward move complete
  output logic moving;				// enables integration in PID and in inertial_integrator
  output en_fusion;					// Only enable fusion (IR reading affect on nav) when moving forward at decent speed.
  input at_hdng;					// from PID, indicates heading close enough to consider heading complete.
  input lft_opn,rght_opn,frwrd_opn;	// from IR sensors, indicates available direction.  Might stop at rise of lft/rght
  output reg [10:0] frwrd_spd;		// unsigned forward speed setting to PID
  
  ////////////////////////////////
  // Needed internal registers //
  //////////////////////////////
  logic lft_opn_rise, lft_ff, rght_opn_rise, rght_ff;
  logic [5:0] frwrd_inc;

  /////////////////
  // SM outputs //
  ///////////////
  logic init_frwrd;
  logic inc_frwrd;
  logic dec_frwrd;
  logic dec_frwrd_fast;

  ////////////////////
  // Define States //
  //////////////////
  typedef enum reg [2:0] {IDLE, HEADING, MOVING, DECELERATE_NORM, DECELERATE_FAST} state_t;
  state_t state, nxt_state;
  
  localparam MAX_FRWRD = 11'h2A0;		// max forward speed
  localparam MIN_FRWRD = 11'h0D0;		// minimum duty at which wheels will turn
  
  ////////////////////////////////
  // Now form forward register //
  //////////////////////////////
  always_ff @(posedge clk, negedge rst_n)
    if (!rst_n)
	  frwrd_spd <= 11'h000;
	else if (init_frwrd)		// assert this signal when leaving IDLE due to strt_mv
	  frwrd_spd <= MIN_FRWRD;									// min speed to get motors moving
	else if (hdng_rdy && inc_frwrd && (frwrd_spd<MAX_FRWRD))	// max out at 2A0
	  frwrd_spd <= frwrd_spd + {5'h00,frwrd_inc};				// always accel at 1x frwrd_inc
	else if (hdng_rdy && (frwrd_spd>11'h000) && (dec_frwrd | dec_frwrd_fast))
	  frwrd_spd <= ((dec_frwrd_fast) && (frwrd_spd>{2'h0,frwrd_inc,3'b000})) ? frwrd_spd - {2'h0,frwrd_inc,3'b000} : // 8x accel rate
                    (dec_frwrd_fast) ? 11'h000 :	  // if non zero but smaller than dec amnt set to zero.
	                (frwrd_spd>{4'h0,frwrd_inc,1'b0}) ? frwrd_spd - {4'h0,frwrd_inc,1'b0} : // slow down at 2x accel rate
					11'h000;


  assign en_fusion = (frwrd_spd > (MAX_FRWRD/2)) ? 1'b1 : 1'b0;
  assign frwrd_inc = (FAST_SIM) ? 6'h18 : 6'h02;

  // Assigning the values of the edge detectors for left and right open
  // The flipflops for them are below
  assign lft_opn_rise = (lft_opn && !lft_ff) ? 1'b1 : 1'b0;
  assign rght_opn_rise = (rght_opn && !rght_ff) ? 1'b1 : 1'b0; 

  // FF for detecting rising edge for lft_opn
  always_ff @(posedge clk, negedge rst_n) begin
    if (!rst_n)
      lft_ff <= 0;
    else
      lft_ff <= lft_opn;
  end

  // FF for detecting rising edge for rght_opn
  always_ff @(posedge clk, negedge rst_n) begin
    if (!rst_n)
      rght_ff <= 0;
    else
      rght_ff <= rght_opn;
  end	

  ////////////////////////
  // Infer State Flops //
  //////////////////////
  always_ff @(posedge clk, negedge rst_n) begin
    if (!rst_n)
      state <= IDLE;
    else
      state <= nxt_state;
  end

  //////////////////////////////////////
  // state transition & output logic //
  ////////////////////////////////////
  always_comb begin
   //////////////////////
	 // Default outputs //
	 ////////////////////
    moving = 0;
    init_frwrd = 0;
    inc_frwrd = 0;
    dec_frwrd = 0;
    dec_frwrd_fast = 0;
    mv_cmplt = 0;
    nxt_state = state;

    case(state)
      MOVING: begin
        moving = 1;
        inc_frwrd = 1;
        if (!frwrd_opn)
          nxt_state = DECELERATE_FAST;        // the robot will decelerate
        else if ((lft_opn_rise & stp_lft) ||  // to stop if the left is open and
                  (rght_opn_rise & stp_rght)) // we want to stop left, or same for right
          nxt_state = DECELERATE_NORM;
      end
      HEADING: begin
        moving = 1;             // if we're at the desired
        if (at_hdng) begin      // heading we want to stop
          mv_cmplt = 1;         // and the move is complete
          nxt_state = IDLE;
        end 
      end
      DECELERATE_FAST: begin
        moving = 1;             // wall is in front of the
        dec_frwrd_fast = 1;     // robot and it needs to
        if (!frwrd_spd) begin   // quickely decelerate
          mv_cmplt = 1;
          nxt_state = IDLE;
        end
      end
      DECELERATE_NORM: begin
        moving = 1;             // robot needs to decelerate
        dec_frwrd = 1;
        if (!frwrd_spd) begin
          mv_cmplt = 1;
          nxt_state = IDLE;
        end
      end
      default: begin            
        if (strt_hdng) begin    // this is the same as IDLE
          moving = 1; 
          nxt_state = HEADING;
        end else if (strt_mv) begin
          init_frwrd = 1;
          nxt_state = MOVING;
        end 
      end
    endcase    
  end
endmodule
  