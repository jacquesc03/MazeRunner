`timescale 1ns/1ps
module MazeRunner_tb();

  // << optional include or import >>
  
  reg clk,RST_n;
  reg send_cmd;					// assert to send command to MazeRunner_tb
  reg [15:0] cmd;				// 16-bit command to send
  reg [11:0] batt;				// battery voltage 0xDA0 is nominal
  
  logic cmd_sent;				
  logic resp_rdy;				// MazeRunner has sent a pos acknowledge
  logic [7:0] resp;				// resp byte from MazeRunner (hopefully 0xA5)
  logic hall_n;					// magnet found?
  logic piezo, piezo_n;
  
  /////////////////////////////////////////////////////////////////////////
  // Signals interconnecting MazeRunner to RunnerPhysics and RemoteComm //
  ///////////////////////////////////////////////////////////////////////
  wire TX_RX,RX_TX;
  wire INRT_SS_n,INRT_SCLK,INRT_MOSI,INRT_MISO,INRT_INT;
  wire lftPWM1,lftPWM2,rghtPWM1,rghtPWM2;
  wire A2D_SS_n,A2D_SCLK,A2D_MOSI,A2D_MISO;
  wire IR_lft_en,IR_cntr_en,IR_rght_en;  
  
  localparam FAST_SIM = 1'b1;

  //////////////////////
  // Instantiate DUT //
  ////////////////////
  MazeRunner iDUT(.clk(clk),.RST_n(RST_n),.INRT_SS_n(INRT_SS_n),.INRT_SCLK(INRT_SCLK),
                  .INRT_MOSI(INRT_MOSI),.INRT_MISO(INRT_MISO),.INRT_INT(INRT_INT),
				  .A2D_SS_n(A2D_SS_n),.A2D_SCLK(A2D_SCLK),.A2D_MOSI(A2D_MOSI),
				  .A2D_MISO(A2D_MISO),.lftPWM1(lftPWM1),.lftPWM2(lftPWM2),
				  .rghtPWM1(rghtPWM1),.rghtPWM2(rghtPWM2),.RX(RX_TX),.TX(TX_RX),
				  .hall_n(hall_n),.piezo(piezo),.piezo_n(piezo_n),.IR_lft_en(IR_lft_en),
				  .IR_rght_en(IR_rght_en),.IR_cntr_en(IR_cntr_en),.LED());
	
  ///////////////////////////////////////////////////////////////////////////////////////
  // Instantiate RemoteComm which models bluetooth module receiving & forwarding cmds //
  /////////////////////////////////////////////////////////////////////////////////////
  RemoteComm iCMD(.clk(clk), .rst_n(RST_n), .RX(TX_RX), .TX(RX_TX), .cmd(cmd), .snd_cmd(send_cmd),
               .cmd_snt(cmd_sent), .resp_rdy(resp_rdy), .resp(resp));
			   
				  
  RunnerPhysics iPHYS(.clk(clk),.RST_n(RST_n),.SS_n(INRT_SS_n),.SCLK(INRT_SCLK),.MISO(INRT_MISO),
                      .MOSI(INRT_MOSI),.INT(INRT_INT),.lftPWM1(lftPWM1),.lftPWM2(lftPWM2),
					  .rghtPWM1(rghtPWM1),.rghtPWM2(rghtPWM2),
                     .IR_lft_en(IR_lft_en),.IR_cntr_en(IR_cntr_en),.IR_rght_en(IR_rght_en),
					 .A2D_SS_n(A2D_SS_n),.A2D_SCLK(A2D_SCLK),.A2D_MOSI(A2D_MOSI),
					 .A2D_MISO(A2D_MISO),.hall_n(hall_n),.batt(batt));
	

  ///////////////////////////////
  // BIG GRAND TESTBENCH YAY! //
  /////////////////////////////			 
  initial begin
	batt = 12'hDA0;  	// this is value to use with RunnerPhysics (DA0)
  clk = 0;
  RST_n = 0;
  send_cmd = 0;
  @(posedge clk);
  @(negedge clk);
  RST_n = 1;
  repeat (3) @(posedge clk);


  ////////////////////////////////////////////////////////
  // Reset the robot and put it in starring spot (2,0) //
  //////////////////////////////////////////////////////
  // Waiting for batt_low to play
  fork
    begin : batt_low_piezo_1
      repeat(10000000) @(posedge clk);
      $display("ERROR: Timed out while checking batt_low_done (TEST 1 FAILED)");
      $stop();
    end
    begin
      repeat (3) @(posedge iDUT.iCHRG.dur_done);
      disable batt_low_piezo_1;
      assert (iDUT.iCHRG.dur_done) $display("Played batt_low tune first time (TEST 1)");
      else begin
        $display("batt_low tune didn't play :( (TEST 1 FAILED)");
        $stop();
      end
    end
  join

  @(posedge clk);
  cmd = '0;
  send_cmd = 1;
  @(posedge clk);
  send_cmd = 0;

  // Calibrate robot
  fork
    begin : command_sent_calibrate
      repeat(1000000) @(posedge clk);
      $display("ERROR: Timed out while checking cmd_sent (TEST 2 FAILED)");
      $stop();
    end
    begin
      @(posedge cmd_sent);
      disable command_sent_calibrate;
      assert (cmd_sent === 1) $display("We good for cmd_sent (TEST 2)");
      else begin
        $display("cmd_sent no bueno (TEST 2 FAILED)");
        $stop();
      end
    end
  join
	
  // Wait for response ready
  fork
    begin : ready_response_calibrate
      repeat(1000000) @(posedge clk);
      $display("ERROR: Timed out while checking resp_rdy (TEST 3 FAILED)");
      $stop();
    end
    begin
      @(posedge resp_rdy);
      disable ready_response_calibrate;
      assert (resp[7:0] === 8'hA5) $display("resp_rdy asserted, resp = 0xA5 (TEST 3)");
      else begin
        $display("not good for resp_rdy, not 0xA5 (TEST 3 FAILED)");
        $stop();
      end
    end
  join

  // Move North one square
  @(posedge clk);
  cmd = 16'h4002;
  send_cmd = 1;
  @(posedge clk);
  send_cmd = 0;

  fork
    begin : move1timeout
      repeat(3000000) @(posedge clk);
      $display("ERROR: resp_rdy never asserted (TEST 4 FAILED)");
      $stop();
    end
    begin
      @(posedge resp_rdy);
      disable move1timeout;
      assert(iPHYS.xx > 15'h26B0 && iPHYS.xx < 15'h2950) $display("Made it to x-coordiante 0x28 (TEST 4)");
      else begin
        $display("Value of xx is: %h", iPHYS.xx[14:7]);
        $error("ERROR: Did not make it to first square (TEST 4 FAILED)");
        $stop;
      end
      assert(iPHYS.yy > 15'h16B0 && iPHYS.yy < 15'h1950) $display("Made it to y-coordiante 0x18 (TEST 4)");
      else begin
        $display("Value of yy is: %h", iPHYS.yy[14:7]);
        $error("ERROR: Did not make it to first square (TEST 4 FAILED)");
        $stop;
      end
      assert(resp[7:0] == 8'hA5) $display("resp_rdy asserted, resp = 0xA5 (TEST 4)");
      else begin
        $error("ERROR: resp not 0xA5 (TEST 4 FAILED)");
        $stop;
      end
    end
  join


  // Turning West
  @(posedge clk);
  cmd = 16'h23FF;
  send_cmd = 1;
  @(posedge clk);
  send_cmd = 0;

  fork
    begin : rotate1timeout
      repeat(3000000) @(posedge clk);
      $display("ERROR: resp_rdy never asserted (TEST 5 FAILED)");
      $stop();
    end
    begin
      @(posedge resp_rdy);
      disable rotate1timeout;
      assert(iPHYS.heading_robot > 20'h3DF00 && iPHYS.heading_robot < 20'h41F00) $display("Turned West (TEST 5)");
      else begin
        $error("ERROR: Did not turn West (TEST 5 FAILED)");
        $stop;
      end
      // checks that x and y position are still correct
      assert(iPHYS.xx > 15'h26B0 && iPHYS.xx < 15'h2950) $display("Still in correct xx (TEST 5)");
      else begin
        $error("ERROR: Not in correct xx (TEST 5 FAILED)");
        $stop;
      end
      assert(iPHYS.yy > 15'h16B0 && iPHYS.yy < 15'h1950) $display("Still in correct yy (TEST 5)");
      else begin
        $error("ERROR: Not in correct yy (TEST 5 FAILED)");
        $stop;
      end
      assert(resp[7:0] == 8'hA5) $display("resp_rdy asserted, resp = 0xA5 (TEST 5)");
      else begin
        $error("ERROR: resp not 0xA5 (TEST 5 FAILED)");
        $stop;
      end
    end
  join

  // Moving West
  @(posedge clk);
  cmd = 16'h4001;
  send_cmd = 1;
  @(posedge clk);
  send_cmd = 0;

  fork
    begin : move2timeout
      repeat(3000000) @(posedge clk);
      $display("ERROR: resp_rdy never asserted (TEST 6 FAILED)");
      $stop();
    end
    begin
      @(posedge resp_rdy);
      disable move2timeout;
      assert(iPHYS.xx > 15'h16B0 && iPHYS.xx < 15'h1950) $display("Made it to x-coordiante 0x18 (TEST 6)");
      else begin
        $error("ERROR: Not in correct xx (TEST 6 FAILED)");
        $stop;
      end
      assert(iPHYS.yy > 15'h16B0 && iPHYS.yy < 15'h1950) $display("Made it to y-coordinate 0x18 (TEST 6)");
      else begin
        $error("ERROR: Not in correct yy (TEST 6 FAILED)");
        $stop;
      end
      assert(resp[7:0] == 8'hA5) $display("resp_rdy asserted, resp = 0xA5 (TEST 6)");
      else begin
        $error("ERROR: resp not 0xA5 (TEST 6 FAILED)");
        $stop;
      end
    end
  join

  // Turning North
  @(posedge clk);
  cmd = 16'h2000;
  send_cmd = 1;
  @(posedge clk);
  send_cmd = 0;

  fork
    begin : rotate2timeout
      repeat(3000000) @(posedge clk);
      $display("ERROR: resp_rdy never asserted (TEST 7 FAILED)");
      $stop();
    end
    begin
      @(posedge resp_rdy);
      disable rotate2timeout;
      assert(iPHYS.heading_robot > 20'hFDF00 || iPHYS.heading_robot < 20'h01F00) $display("Turned North (TEST 7)");
      else begin
        $error("ERROR: Did not turn North (TEST 7 FAILED)");
        $stop;
      end
      // checks that x and y position are still correct
      assert(iPHYS.xx > 15'h16B0 && iPHYS.xx < 15'h1950) $display("Still in correct xx (TEST 7)");
      else begin
        $error("ERROR: Not in correct xx (TEST 7 FAILED)");
        $stop;
      end
      assert(iPHYS.yy > 15'h16B0 && iPHYS.yy < 15'h1950) $display("Still in correct yy (TEST 7)");
      else begin
        $error("ERROR: Not in correct yy (TEST 7 FAILED)");
        $stop;
      end
      assert(resp[7:0] == 8'hA5) $display("resp_rdy asserted, resp = 0xA5 (TEST 7)");
      else begin
        $error("ERROR: resp not 0xA5 (TEST 7 FAILED)");
        $stop;
      end
    end
  join

  //////////////////////////////////////////////////////////////////
  // Reset the robot and put it in the bottom right corner (3,0) //
  ////////////////////////////////////////////////////////////////
  @(posedge clk);
  iPHYS.xx = 15'h3800;
  iPHYS.yy = 15'h800;
  iPHYS.magnet_pos_xx = 7'h08; // magnet pos is middle of (0,3)
  iPHYS.magnet_pos_yy = 7'h38;
  iPHYS.heading_robot = 20'h00000; // start North
  iPHYS.cntrIR = 12'hFFF;
  iPHYS.alpha_lft = 13'h0000;
	iPHYS.alpha_rght = 13'h0000;
	iPHYS.omega_lft = 16'h0000;
	iPHYS.omega_rght = 16'h0000;
  iPHYS.cntrIR = 12'hFFF;		// clear to start
  iPHYS.computeIRs();


  // Moving North to (3,2)
  @(posedge clk);
  cmd = 16'h4002;
  send_cmd = 1;
  @(posedge clk);
  send_cmd = 0;

  fork
    begin : move3timeout
      repeat(3000000) @(posedge clk);
      $display("ERROR: resp_rdy never asserted (TEST 8 FAILED)");
      $stop();
    end
    begin
      @(posedge resp_rdy);
      disable move3timeout;
      assert(iPHYS.xx > 15'h36B0 && iPHYS.xx < 15'h3950) $display("Made it to x-coordiante 0x38 (TEST 8)");
      else begin
        $display("Value of xx is: %h", iPHYS.xx[14:7]);
        $error("ERROR: Did not make it to (3,2) (TEST 8 FAILED)");
        $stop;
      end
      assert(iPHYS.yy > 15'h26B0 && iPHYS.yy < 15'h2950) $display("Made it to y-coordiante 0x28 (TEST 8)");
      else begin
        $display("Value of yy is: %h", iPHYS.yy[14:7]);
        $error("ERROR: Did not make it to (3,2) (TEST 8 FAILED)");
        $stop;
      end
      assert(resp[7:0] == 8'hA5) $display("resp_rdy asserted, resp = 0xA5 (TEST 8)");
      else begin
        $error("ERROR: resp not 0xA5 (TEST 8 FAILED)");
        $stop;
      end
    end
  join

  // Moving North to (3,3)
  @(posedge clk);
  cmd = 16'h4001;
  send_cmd = 1;
  @(posedge clk);
  send_cmd = 0;

  fork
    begin : move4timeout
      repeat(3000000) @(posedge clk);
      $display("ERROR: resp_rdy never asserted (TEST 9 FAILED)");
      $stop();
    end
    begin
      @(posedge resp_rdy);
      disable move4timeout;
      assert(iPHYS.xx > 15'h36B0 && iPHYS.xx < 15'h3950) $display("Made it to x-coordiante 0x38 (TEST 9)");
      else begin
        $display("Value of xx is: %h", iPHYS.xx[14:7]);
        $error("ERROR: Did not make it to (3,3) (TEST 9 FAILED)");
        $stop;
      end
      assert(iPHYS.yy > 15'h36B0 && iPHYS.yy < 15'h3950) $display("Made it to y-coordiante 0x38 (TEST 9)");
      else begin
        $display("Value of yy is: %h", iPHYS.yy[14:7]);
        $error("ERROR: Did not make it to (3,3) (TEST 9 FAILED)");
        $stop;
      end
      assert(resp[7:0] == 8'hA5) $display("resp_rdy asserted, resp = 0xA5 (TEST 9)");
      else begin
        $error("ERROR: resp not 0xA5 (TEST 9 FAILED)");
        $stop;
      end
    end
  join

  // Turning South
  @(posedge clk);
  cmd = 16'h27FF;
  send_cmd = 1;
  @(posedge clk);
  send_cmd = 0;

  fork
    begin : rotate3timeout
      repeat(3000000) @(posedge clk);
      $display("ERROR: resp_rdy never asserted (TEST 10 FAILED)");
      $stop();
    end
    begin
      @(posedge resp_rdy);
      disable rotate3timeout;
      assert(iPHYS.heading_robot > 20'h7DF00 && iPHYS.heading_robot < 20'h81F00) $display("Turned South (TEST 10)");
      else begin
        $error("ERROR: Did not turn South (TEST 10 FAILED)");
        $stop;
      end
      // checks that x and y position are still correct
      assert(iPHYS.xx > 15'h36B0 && iPHYS.xx < 15'h3950) $display("Still in correct xx (TEST 10)");
      else begin
        $error("ERROR: Not in correct xx (TEST 10 FAILED)");
        $stop;
      end
      assert(iPHYS.yy > 15'h36B0 && iPHYS.yy < 15'h3950) $display("Still in correct yy (TEST 10)");
      else begin
        $error("ERROR: Not in correct yy (TEST 10 FAILED)");
        $stop;
      end
      assert(resp[7:0] == 8'hA5) $display("resp_rdy asserted, resp = 0xA5 (TEST 10)");
      else begin
        $error("ERROR: resp not 0xA5 (TEST 10 FAILED)");
        $stop;
      end
    end
  join

  // Moving South to (3,2)
  @(posedge clk);
  cmd = 16'h4001;
  send_cmd = 1;
  @(posedge clk);
  send_cmd = 0;

  fork
    begin : move5timeout
      repeat(3000000) @(posedge clk);
      $display("ERROR: resp_rdy never asserted (TEST 11 FAILED)");
      $stop();
    end
    begin
      @(posedge resp_rdy);
      disable move5timeout;
      assert(iPHYS.xx > 15'h36B0 && iPHYS.xx < 15'h3950) $display("Made it to x-coordiante 0x38 (TEST 11)");
      else begin
        $display("Value of xx is: %h", iPHYS.xx[14:7]);
        $error("ERROR: Did not make it to (3,2) (TEST 11 FAILED)");
        $stop;
      end
      assert(iPHYS.yy > 15'h26B0 && iPHYS.yy < 15'h2950) $display("Made it to y-coordiante 0x28 (TEST 11)");
      else begin
        $display("Value of yy is: %h", iPHYS.yy[14:7]);
        $error("ERROR: Did not make it to (3,2) (TEST 11 FAILED)");
        $stop;
      end
      assert(resp[7:0] == 8'hA5) $display("resp_rdy asserted, resp = 0xA5 (TEST 11)");
      else begin
        $error("ERROR: resp not 0xA5 (TEST 11 FAILED)");
        $stop;
      end
    end
  join

  // Moving South to (3,0)
  @(posedge clk);
  cmd = 16'h4002;
  send_cmd = 1;
  @(posedge clk);
  send_cmd = 0;

  fork
    begin : move6timeout
      repeat(3000000) @(posedge clk);
      $display("ERROR: resp_rdy never asserted (TEST 12 FAILED)");
      $stop();
    end
    begin
      @(posedge resp_rdy);
      disable move6timeout;
      assert(iPHYS.xx > 15'h36B0 && iPHYS.xx < 15'h3950) $display("Made it to x-coordiante 0x38 (TEST 12)");
      else begin
        $display("Value of xx is: %h", iPHYS.xx[14:7]);
        $error("ERROR: Did not make it to (3,0) (TEST 12 FAILED)");
        $stop;
      end
      assert(iPHYS.yy > 15'h06B0 && iPHYS.yy < 15'h0950) $display("Made it to y-coordiante 0x08 (TEST 12)");
      else begin
        $display("Value of yy is: %h", iPHYS.yy[14:7]);
        $error("ERROR: Did not make it to (3,0) (TEST 12 FAILED)");
        $stop;
      end
      assert(resp[7:0] == 8'hA5) $display("resp_rdy asserted, resp = 0xA5 (TEST 12)");
      else begin
        $error("ERROR: resp not 0xA5 (TEST 12 FAILED)");
        $stop;
      end
    end
  join


  ///////////////////////////////////////////////////
  // Reset the robot and run MazeSolve from (2,0) //
  /////////////////////////////////////////////////
  @(posedge clk);
  iPHYS.xx = 15'h2800;
  iPHYS.yy = 15'h800;
  iPHYS.magnet_pos_xx = 7'h18; // magnet pos is middle of (1,2)
  iPHYS.magnet_pos_yy = 7'h28;
  iPHYS.heading_robot = 20'h00000; // start North
  iPHYS.cntrIR = 12'hFFF;
  iPHYS.alpha_lft = 13'h0000;
	iPHYS.alpha_rght = 13'h0000;
	iPHYS.omega_lft = 16'h0000;
	iPHYS.omega_rght = 16'h0000;
  iPHYS.cntrIR = 12'hFFF; // clear to start
  iPHYS.computeIRs();

  // Waiting for batt_low to play
  fork
    begin : batt_low_piezo_2
      repeat(10000000) @(posedge clk);
      $display("ERROR: Timed out while checking batt_low_done (TEST 13 FAILED)");
      $stop();
    end
    begin
      repeat (3) @(posedge iDUT.iCHRG.dur_done);
      disable batt_low_piezo_2;
      assert (iDUT.iCHRG.dur_done === 1) $display("Played batt_low tune second time (TEST 13)");
      else begin
        $display("batt_low tune didn't play :( (TEST 13 FAILED)");
        $stop();
      end
    end
  join

  @(posedge clk);
  cmd = '0;
  send_cmd = 1;
  @(posedge clk);
  send_cmd = 0;

  // Calibrate robot
  fork
    begin : command_sent_calibrate_solve
      repeat(1000000) @(posedge clk);
      $display("ERROR: Timed out while checking cmd_sent (TEST 14 FAILED)");
      $stop();
    end
    begin
      @(posedge cmd_sent);
      disable command_sent_calibrate_solve;
      assert (cmd_sent === 1) $display("We good for cmd_sent (TEST 14)");
      else begin
        $display("cmd_sent no bueno (TEST 14 FAILED)");
        $stop();
      end
    end
  join
	
  // Wait for response ready
  fork
    begin : ready_response_calibrate_solve
      repeat(1000000) @(posedge clk);
      $display("ERROR: Timed out while checking resp_rdy (TEST 15 FAILED)");
      $stop();
    end
    begin
      @(posedge resp_rdy);
      disable ready_response_calibrate_solve;
      assert (resp[7:0] === 8'hA5) $display("resp_rdy asserted, resp = 0xA5 (TEST 15)");
      else begin
        $display("not good for resp_rdy, not 0xA5 (TEST 15 FAILED)");
        $stop();
      end
    end
  join

  ////////////////////////////////////
  // Maze solve for right affinity //
  //////////////////////////////////
  @(posedge clk);
  cmd = 16'h6000;
  send_cmd = 1;
  @(posedge clk);
  send_cmd = 0;

  fork
    begin : solve_that_jawn_right
      repeat(80000000) @(posedge clk);
      $display("ERROR: Timed out while finding magnet (TEST 16)");
      $stop();
    end
    begin
      @(negedge hall_n);
      disable solve_that_jawn_right;
      assert (iDUT.iCHRG.fanfare === 1) $display("Bag (magnet) secured for right affinity (TEST 16)");
      else begin
        $display("Lost... (TEST 16)");
        $stop();
      end
    end
  join

  fork
    begin : fanfare_right
      repeat(10000000) @(posedge clk);
      $display("ERROR: Timed out while checking fanfare done (TEST 17)");
      $stop();
    end
    begin
      repeat (6) @(posedge iDUT.iCHRG.dur_done);
      disable fanfare_right;
      assert (iDUT.iCHRG.dur_done === 1) $display("CHARGE! (TEST 17)");
      else begin
        $display("no charge :( (TEST 17)");
        $stop();
      end
    end
  join

  @(posedge clk);
  iPHYS.xx = 15'h2800;
  iPHYS.yy = 15'h800;
  iPHYS.magnet_pos_xx = 7'h18; // magnet pos is middle of (0,1)
  iPHYS.magnet_pos_yy = 7'h08;
  iPHYS.heading_robot = 20'h00000; // start North
  iPHYS.cntrIR = 12'hFFF;
  iPHYS.alpha_lft = 13'h0000;
	iPHYS.alpha_rght = 13'h0000;
	iPHYS.omega_lft = 16'h0000;
	iPHYS.omega_rght = 16'h0000;
  iPHYS.cntrIR = 12'hFFF; // clear to start
  iPHYS.computeIRs();

  // Waiting for batt_low to play
  fork
    begin : batt_low_left
      repeat(10000000) @(posedge clk);
    end
    begin
      repeat (3) @(posedge iDUT.iCHRG.dur_done);
      disable batt_low_left;
      assert (iDUT.iCHRG.dur_done === 1);
    end
  join

  @(posedge clk);
  cmd = '0;
  send_cmd = 1;
  @(posedge clk);
  send_cmd = 0;

  // Calibrate robot
  fork
    begin : command_sent_left
      repeat(1000000) @(posedge clk);
    end
    begin
      @(posedge cmd_sent);
      disable command_sent_left;
      assert (cmd_sent === 1);
    end
  join
	
  // Wait for response ready
  fork
    begin : ready_response_left
      repeat(1000000) @(posedge clk);
    end
    begin
      @(posedge resp_rdy);
      disable ready_response_left;
      assert (resp[7:0] === 8'hA5);
    end
  join

  ///////////////////////////////////
  // Maze solve for left affinity //
  /////////////////////////////////
  @(posedge clk);
  cmd = 16'h6001;
  send_cmd = 1;
  @(posedge clk);
  send_cmd = 0;

  fork
    begin : solve_that_jawn_left
      repeat(80000000) @(posedge clk);
      $display("ERROR: Timed out while finding magnet (TEST 18)");
      $stop();
    end
    begin
      @(negedge hall_n);
      disable solve_that_jawn_left;
      assert (iDUT.iCHRG.fanfare === 1) $display("Bag (magnet) secured for left affinity (TEST 18)");
      else begin
        $display("Lost... (TEST 18)");
        $stop();
      end
    end
  join

  fork
    begin : fanfare_left
      repeat(10000000) @(posedge clk);
      $display("ERROR: Timed out while checking fanfare done (TEST 19)");
      $stop();
    end
    begin
      repeat (6) @(posedge iDUT.iCHRG.dur_done);
      disable fanfare_left;
      assert (iDUT.iCHRG.dur_done === 1) $display("CHARGE! (TEST 19)");
      else begin
        $display("no charge :( (TEST 19)");
        $stop();
      end
    end
  join

  $display("YAY 551");
  $stop();
  end

  always
    #5 clk = ~clk;
endmodule