//////////////////////////////////////////////////////
// Interfaces with ST 6-axis inertial sensor.  In  //
// this application we only use Z-axis gyro for   //
// heading of mazeRunner.  Fusion correction     //
// comes from IR_Dtrm when en_fusion is high.   //
/////////////////////////////////////////////////
module inert_intf(clk,rst_n,strt_cal,cal_done,heading,rdy,IR_Dtrm,
                  SS_n,SCLK,MOSI,MISO,INT,moving,en_fusion);

  parameter FAST_SIM = 1;	// used to speed up simulation
  
  input clk, rst_n;
  input MISO;							// SPI input from inertial sensor
  input INT;							// goes high when measurement ready
  input strt_cal;						// initiate claibration of yaw readings
  input moving;							// Only integrate yaw when going
  input en_fusion;						// do fusion corr only when forward at decent clip
  input [8:0] IR_Dtrm;					// derivative term of IR sensors (used for fusion)
  
  output cal_done;				// pulses high for 1 clock when calibration done
  output signed [11:0] heading;	// heading of robot.  000 = Orig dir 3FF = 90 CCW 7FF = 180 CCW
  output rdy;					// goes high for 1 clock when new outputs ready (from inertial_integrator)
  output SS_n,SCLK,MOSI;		// SPI outputs
 

  ////////////////////////////////////////////
  // Declare any needed internal registers //
  //////////////////////////////////////////
   logic int_ff1, int_ff2;
   logic [15:0] timer, cmd;
  
  //////////////////////////////////////
  // Outputs of SM are of type logic //
  ////////////////////////////////////
  logic vld_pre, wrt, C_Y_L, C_Y_H, vld;

  //////////////////////////////////////////////////////////////
  // Declare any needed internal signals that connect blocks //
  ////////////////////////////////////////////////////////////
  wire done;
  wire [15:0] inert_data;		// Data back from inertial sensor (only lower 8-bits used)
  wire signed [15:0] yaw_rt;
  logic [7:0] yaw_H, yaw_L;
  assign yaw_rt = {yaw_H, yaw_L};

  ////////////////////////
  // Holding Registers //
  //////////////////////
  always_ff @(posedge clk, negedge rst_n) begin
    if (!rst_n) begin
      yaw_H <= '0;
      yaw_L <= '0;
    end else if (C_Y_H)
      yaw_H <= inert_data[7:0];
    else if (C_Y_L)
      yaw_L <= inert_data[7:0];
   end
  
  
  ///////////////////////////////////////
  // Create enumerated type for state //
  /////////////////////////////////////
  typedef enum reg [3:0] {INIT1, INIT2, INIT3, READING, YAWL, YAWH} state_t;
  state_t state, nxt_state;
  
  ////////////////////////////////////////////////////////////
  // Instantiate SPI monarch for Inertial Sensor interface //
  //////////////////////////////////////////////////////////
  SPI_mnrch iSPI(.clk(clk),.rst_n(rst_n),.SS_n(SS_n),.SCLK(SCLK),
                 .MISO(MISO),.MOSI(MOSI),.wrt(wrt),.done(done),
				 .rd_data(inert_data),.wt_data(cmd));
				  
  ////////////////////////////////////////////////////////////////////
  // Instantiate Angle Engine that takes in angular rate readings  //
  // and gaurdrail info and produces a heading reading            //
  /////////////////////////////////////////////////////////////////
  inertial_integrator #(FAST_SIM) iINT(.clk(clk), .rst_n(rst_n), .strt_cal(strt_cal),
                        .vld(vld),.rdy(rdy),.cal_done(cal_done), .yaw_rt(yaw_rt),.moving(moving),
						.en_fusion(en_fusion),.IR_Dtrm(IR_Dtrm),.heading(heading));
	

  ////////////////////////
  // Infer State Flops //
  //////////////////////
  always_ff @(posedge clk, negedge rst_n) begin
    if (!rst_n)
      state <= INIT1;
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
    wrt = 0;
    C_Y_L = 0;
    C_Y_H = 0;
    vld_pre = 0;
    nxt_state = state;
    cmd = '0;

    case(state)
      default: if (&timer) begin
        wrt = 1;                      // same as INIT1, initializing 
        cmd = 16'h0D02;               // sensors
        nxt_state = INIT2;
      end
      INIT2: if (done) begin
        wrt = 1;                      // still initializing sensors
        cmd = 16'h1160;
        nxt_state = INIT3;
      end
      INIT3: if (done) begin
        wrt = 1;                      // still initializing sensors
        cmd = 16'h1440;
        nxt_state = READING;
      end
      READING: if (int_ff2) begin
        wrt = 1;                      // new data is ready!!
        cmd = 16'hA6xx;
        nxt_state = YAWL;
      end
      YAWL: if (done) begin
        wrt = 1;                      // transfering low bit
        C_Y_L = 1;                    // of the yaw data
        cmd = 16'hA7xx;
        nxt_state = YAWH;
      end
      YAWH: if (done) begin
        vld_pre = 1;                  // transfering high bit
        C_Y_H = 1;                    // of the yaw data
        nxt_state = READING;
      end
    endcase   
  end
  
  ///////////////////////////////////////
  // Preventing metastability for INT //
  /////////////////////////////////////
  always_ff @(posedge clk) begin 
    if (!rst_n) begin
      int_ff1 <= 0;
      int_ff2 <= 0;
    end else
      int_ff1 <= INT;
      int_ff2 <= int_ff1;
  end
  
  ////////////////////
  // Timer counter //
  //////////////////
  always_ff @(posedge clk, negedge rst_n) begin
    if (!rst_n)
      timer <= '0;
    else
      timer <= timer + 1;
  end

  //////////////////////////
  // Flopping for timing //
  ////////////////////////
  always_ff @(posedge clk, negedge rst_n) begin
    if (!rst_n)
      vld <= '0;
    else
      vld <= vld_pre;
  end
endmodule
	  