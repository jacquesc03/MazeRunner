module RemoteComm(
input clk, rst_n,		// clock and active low reset
input RX,				// serial data input
input snd_cmd,			// indicates to tranmit 24-bit command (cmd)
input [15:0] cmd,		// 16-bit command

output TX,				// serial data output
output logic cmd_snt,		// indicates transmission of command complete
output resp_rdy,		// indicates 8-bit response has been received
output [7:0] resp		// 8-bit response from DUT
);

logic sel, set_cmd_snt, trmt, tx_done;
logic [7:0] cmd_inter, tx_data;

typedef enum reg [1:0] {IDLE, HIGH_BYTE, LOW_BYTE} state_t;
  
state_t state, nstate;

///////////////////////////////////////////////
// Instantiate basic 8-bit UART transceiver //
/////////////////////////////////////////////
UART iUART(.clk(clk), .rst_n(rst_n), .RX(RX), .TX(TX), .tx_data(tx_data), .trmt(trmt),
           .tx_done(tx_done), .rx_data(resp), .rx_rdy(resp_rdy), .clr_rx_rdy(resp_rdy));

// stores cmd[7:0] in register until high_byte is sent
always_ff @(posedge clk)
    if(snd_cmd)
        cmd_inter <= cmd[7:0];

assign tx_data = sel ? cmd[15:8] : cmd_inter[7:0];

// cmd_snt FF, goes low when sending a command or when global reset
// set when tx_done is asserted from UART
always_ff @(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
        cmd_snt <= 0;
    end else if(snd_cmd) begin
        cmd_snt <= 0;
    end else if(set_cmd_snt) begin
        cmd_snt <= 1;
    end
end

// state machine FF
always_ff @(posedge clk, negedge rst_n)
    if (!rst_n)
      state <= IDLE;
    else
      state <= nstate;

always_comb begin
    trmt = 0;
    sel = 0;
    set_cmd_snt = 0;
    nstate = state;
    
    case(state)
        // sends low byte 
        HIGH_BYTE: begin
            if(tx_done) begin
                sel = 0;
                trmt = 1;
                nstate = LOW_BYTE;
            end
        end
        // finished sending cmd
        LOW_BYTE:
            if(tx_done) begin
                set_cmd_snt = 1;
                nstate = IDLE;
            end
        // IDLE state, sends high cmd byte first
        default:
            if(snd_cmd) begin
                sel = 1;
                trmt = 1;
                nstate = HIGH_BYTE;
            end
    endcase 
end
endmodule	
