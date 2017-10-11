module serialGPIO(
    input clk,
    input RxD,
    output TxD,

    output reg [7:0] GPout,  // general purpose outputs
    input [7:0] GPin,        // general purpose inputs
	 output RxD_data_ready,
	 input  TxD_start,
	 output TxD_busy,
	 output [15:0]txbuf
	 
);

wire [7:0] RxD_data;
async_receiver RX(.clk(clk), .RxD(RxD), .RxD_data_ready(RxD_data_ready), .RxD_data(RxD_data));
always @(posedge clk) if(RxD_data_ready) GPout <= RxD_data;
async_transmitter TX(.clk(clk), .TxD(TxD), .TxD_start(TxD_start), .TxD_data(GPin), .TxD_busy(TxD_busy));


endmodule
