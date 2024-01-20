module SPI_mnrch(
  input clk, rst_n, wrt, MISO,
  input [15:0] wt_data,
  output logic done, SS_n, SCLK, MOSI,
  output [15:0] rd_data
);

logic init, set_done, ld_SCLK, MISO_smpl, done15, shft_imm, shft;
logic [15:0] shft_reg;
logic [4:0] SCLK_div;
logic [3:0] bit_cnt;

typedef enum reg [2:0] {IDLE, NOT_SHIFT, WORKHORSE, BACKPORCH} state_t;
state_t state, nxt_state;

// assign shft_reg_MISO = {shft_reg[14:0],MISO_smpl};
assign MOSI = shft_reg[15];
assign SCLK = SCLK_div[4];
assign shft_imm = (SCLK_div == 5'b11111) ? 1'b1 : 1'b0;
assign smpl = (SCLK_div == 5'b01111) ? 1'b1 : 1'b0;
assign done15 = &bit_cnt;
assign rd_data = shft_reg;

// 5 bit counter
always_ff @(posedge clk) begin
  if (ld_SCLK)
    SCLK_div <= 5'b10111;
  else
    SCLK_div <= SCLK_div + 1;
end

// bit counter
always_ff @(posedge clk) begin
  if (init)
    bit_cnt <= 4'h0;
  else if (shft)
    bit_cnt <= bit_cnt + 1;
end

// state machine FF
always_ff @(posedge clk, negedge rst_n) begin
  if (!rst_n)
    state <= IDLE;
  else
    state <= nxt_state;
end

// shifts in bit from serf on positive edge of SCLK
always_ff @(posedge clk) begin
  if (smpl)
    MISO_smpl <= MISO;
end

// shift register
// when leaving IDLE, register is loaded with data to write
// shifts in MISO bit that is sampled on positive edge of SCLK
always_ff @(posedge clk) begin
  if (init)
    shft_reg <= wt_data;
  else if (shft)
    shft_reg <= {shft_reg[14:0], MISO_smpl};
end

// uses init and set_done for front porch and back porch of SS_n
// SS_n needs to deassert before SCLK goes low and reassert after SCLK goes high
// done gets asserted once shft register contains all MISO bits
always_ff @(posedge clk, negedge rst_n) begin
  if (!rst_n) begin
    done <= 0;
    SS_n <= 1;
  end else if (init) begin
    done <= 0;
    SS_n <= 0;
  end else if (set_done) begin
    done <= 1;
    SS_n <= 1;
  end
end


always_comb begin
  set_done = 0;
  init = 0;
  ld_SCLK = 0;
  shft = 0;
  nxt_state = state;
  
  case(state)
    // moves to WORKHORSE once SCLK goes low for the first time but doesn't shift
    // bit shifts on second fall of SCLK
    NOT_SHIFT: if (shft_imm)
      nxt_state = WORKHORSE;
    // shifts MOSI out and MISO in
    WORKHORSE: if (done15)
      nxt_state = BACKPORCH;
      else if (shft_imm)
      shft = 1;
    // waits an extra SCLK edge for SS_n to assert
    BACKPORCH: if (shft_imm) begin
      shft = 1;
      ld_SCLK = 1;
      set_done = 1;
      nxt_state = IDLE;
    end
    // begins transaction
    // init deasserts SS_n
    default: if (wrt) begin
      init = 1;
      nxt_state = NOT_SHIFT;
      ld_SCLK = 1;
    end
  endcase
end
endmodule