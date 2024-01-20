module MtrDrv_tb();

  logic clk, rst_n, lftPWM1, lftPWM2, rghtPWM1, rghtPWM2;
  logic [11:0] vbatt, lft_spd, rght_spd;

  MtrDrv iDUTdrv(.clk(clk), .rst_n(rst_n), .lft_spd(lft_spd),
  .rght_spd(rght_spd), .vbatt(vbatt), .lftPWM1(lftPWM1),
  .lftPWM2(lftPWM2), .rghtPWM1(rghtPWM1), .rghtPWM2(rghtPWM2));

  initial begin
    clk = 0;
    rst_n = 0;
    @(negedge clk);
    rst_n = 1;
    @(posedge clk);
    lft_spd = '0;
    rght_spd = '0;
    vbatt = '0;

    // Zero in should give 50% dity cycle out reguardless of vbatt
    repeat (10) @(posedge lftPWM1);
    vbatt[11:4] = 12'hA1;

    // Zero in should give 50% dity cycle out reguardless of vbatt
    repeat (10) @(posedge lftPWM1);

    lft_spd = 12'h3FF;
    rght_spd= 12'h3FF;
    vbatt[11:4] = 8'hDB;
    repeat (10) @(posedge lftPWM1);

    vbatt[11:4] = 8'hD0;
    repeat (10) @(posedge lftPWM1);

    vbatt[11:4] = 8'hFF;
    lft_spd = 12'hC00;
    rght_spd = 12'hC00;
    repeat (10) @(posedge lftPWM1);


    $stop();

  end

  always
  #5 clk = ~clk;
endmodule