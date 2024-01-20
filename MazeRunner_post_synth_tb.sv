`timescale 1ns/1ps
module MazeRunner_post_synth_tb();

  // << optional include or import >>
  
  reg clk,RST_n;
  reg send_cmd;					// assert to send command to MazeRunner_tb
  reg [15:0] cmd;				// 16-bit command to send
  reg [11:0] batt;				// battery voltage 0xDA0 is nominal
  
  logic cmd_sent;				
  logic resp_rdy;				// MazeRunner has sent a pos acknowledge
  logic [7:0] resp;				// resp byte from MazeRunner (hopefully 0xA5)
  logic hall_n;					// magnet found?
  
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
				  .hall_n(hall_n),.piezo(),.piezo_n(),.IR_lft_en(IR_lft_en),
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
	
					 
  initial begin
	batt = 12'hDA0;  	// this is value to use with RunnerPhysics
  clk = 0;
  cmd = 0;
  RST_n = 0;
  send_cmd = 0;
  @(posedge clk);
  @(negedge clk);
  RST_n = 1;
  @(posedge clk);
  iPHYS.heading_robot = 20'h00000; // start North
  iPHYS.magnet_pos_xx = 7'h08;
  iPHYS.magnet_pos_yy = 7'h38;
  cmd = 16'h0000;
  send_cmd = 1;
  @(posedge clk);
  send_cmd = 0;

  // checks that calibrate command executes
  fork
    begin : calibrate_timeout
      repeat(1000000) @(posedge clk);
      $display("ERROR: resp_rdy never asserted");
      $stop();
    end
    begin
      @(posedge resp_rdy);
      disable calibrate_timeout;
      assert(resp === 8'hA5) $display("Response received");
      else begin
        $error("ERROR: Did not receive correct response");
      end
      $display("Calibrate executed");
    end
  join

  // tests turning left
  @(posedge clk);
  cmd = 16'h23FF;
  send_cmd = 1;
  @(posedge clk);
  send_cmd = 0;
  fork
    begin : rotate1timeout
      repeat(3000000) @(posedge clk);
      $display("ERROR: resp_rdy never asserted");
      $stop();
    end
    begin
      @(posedge resp_rdy);
      disable rotate1timeout;
      assert(resp === 8'hA5) $display("Response received");
      else begin
        $error("ERROR: Did not receive correct response");
      end
      assert(iPHYS.heading_robot > 20'h3DF00 && iPHYS.heading_robot < 20'h41F00) $display("Turned left");
      else begin
      $error("ERROR: Did not turn left");
      $stop;
      end

      // checks that x and y position are still correct
      assert(iPHYS.xx > 15'h26B0 && iPHYS.xx < 15'h2950) $display("Still in correct xx");
      else begin
      $error("ERROR: Not in correct xx");
      $stop;
      end
      assert(iPHYS.yy > 15'h06B0 && iPHYS.yy < 15'h0950) $display("Still in correct yy");
      else begin
      $error("ERROR: Not in correct yy");
      $stop;
      end

    end
  join

  $display("YAHOO!!!");
  $stop();
  end
  
  always
    #5 clk = ~clk;
	
endmodule