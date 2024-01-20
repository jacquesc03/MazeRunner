module PWM12(
  input clk, rst_n, // Clock and synchronous active reset
  input unsigned [11:0] duty, 
  output logic PWM1, PWM2
);

  ////////////////////////////
  // Declare internal nets //
  //////////////////////////
  logic signed [11:0] cnt;

  localparam NONOVERLAP = 12'h02C;

  //////////////
  // Counter //
  ////////////
  always_ff @(posedge clk, negedge rst_n) begin
    if (!rst_n)
      cnt <= '0;
    else
      cnt <= cnt + 1;
  end

  ////////////////////////////////////////////
  // PWM1 and PWM2 will always be opposite //
  //    when PWM1 is high, PWM2 is low    //
  /////////////////////////////////////////

  ///////////////////////////////////
  // Combinational logic for PWM1 //
  /////////////////////////////////
  always_ff @(posedge clk, negedge rst_n) begin
    if (!rst_n)
      PWM1 <= 1'b0;
    else if (cnt>=duty)
      PWM1 <= 1'b0;
    else if (cnt>=NONOVERLAP)
      PWM1 <= 1'b1;
  end

  ///////////////////////////////////
  // Combinational logic for PWM2 //
  /////////////////////////////////
  always_ff @(posedge clk, negedge rst_n) begin
    if (!rst_n)
      PWM2 <= 1'b0;
    else if (&cnt)
      PWM2 <= 1'b0;
    else if (cnt>=(duty+NONOVERLAP))
      PWM2 <= 1'b1;
  end
endmodule