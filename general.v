module general(
    input clk,
	 	 
	 //uart interface
    input RxD,
    output TxD,
	 //uart and command interface
	 output reg [15:0] uart_ureg_datain,
	 input      [15:0] uart_ureg_dataout,
	 output reg [7:0] ureg_addr,
	 output reg ureg_write,
	 output reg ureg_rack,
	 output reg uart_ureg_write,
	 input      force_responce,
	 output     [15:0]testbits
); 

assign testbits = txbuf;
wire [15:0]txbuf;
	 wire RxD_data_ready;
	 wire TxD_start;
	 wire TxD_busy;
	 wire [7:0] GPin; 
	 wire [7:0] GPout;
    serialGPIO (.clk(clk), .TxD(TxD), .RxD(RxD), .GPin(GPin), .GPout(GPout), 
	             .RxD_data_ready(RxD_data_ready), .TxD_start(TxD_start), .TxD_busy(TxD_busy), .txbuf(txbuf) );
					 
	 //need to convert RxD_data_ready and TxD_busy to delayed singles
	 reg rx_data_ready;
	 reg ureg_write_sample;
	 reg rdrsample;
	 always @(posedge clk)begin
	    if (rdrsample == 0 && RxD_data_ready == 1) rx_data_ready <= 1; else rx_data_ready = 0;
		 if (ureg_write_sample == 0 && uart_ureg_write == 1) ureg_write <= 1; else ureg_write = 0;
		 rdrsample <= RxD_data_ready;
		 ureg_write_sample <= uart_ureg_write;
    end	
	 
	 //read acknowledge lets rest of chip know a read was made (so fifos can work)
	 reg [4:0]rsp_state_last = 0;
	 always @(posedge clk)begin if(rsp_state_last>5'h0 && rsp_state==5'h0)ureg_rack <= 1; else ureg_rack <= 0; 
										 rsp_state_last <= rsp_state; end
										 
	 //read RxD bytes into array (cr to reset)
	 reg [7:0] cmd;
	 reg [7:0] cmdtxdata;
	 reg [7:0] cdata;
	 //assign TxD_start = (rsp_state == 0) ? rx_data_ready : ~ TxD_busy ;
	 assign TxD_start = (rsp_state == 0) ? 0 : ~ TxD_busy ;
	 assign GPin = (rsp_state == 0) ? GPout : cmdtxdata;
	 reg [3:0] command_state = 0;	 
	 reg [4:0] rsp_state = 0;
	 reg [3:0] txd_state = 0;
	 always @(posedge clk) begin
	 	 if (rx_data_ready == 1 && GPout == 8'h0d) begin command_state <= 4'h0; 
			                                              rsp_state <= 5'h0; 
																		 txd_state <= 4'h0; end 
	    if (rx_data_ready == 1 ) begin 
			 case(command_state)  //reads command and address
	         4'h0 : begin if (GPout == 8'h72) begin command_state <= 4'h1; cmd <= GPout; end //wait for command r/w
		                   if (GPout == 8'h77) begin command_state <= 4'h1; cmd <= GPout; end
						 end
	         4'h1 : if (GPout == 8'h78) command_state <= 4'h2; // wait for x
				4'h2 : begin command_state <= 4'h3;
				          if (GPout >= 8'h30 && GPout <= 8'h39) ureg_addr[7:4] = GPout[3:0];
                      if (GPout >= 8'h61 && GPout <= 8'h66) ureg_addr[7:4] = GPout[3:0] + 4'h9;
						 end
				4'h3 : begin command_state <= 4'h4;
				          if (GPout >= 8'h30 && GPout <= 8'h39) ureg_addr[3:0] = GPout[3:0];
                      if (GPout >= 8'h61 && GPout <= 8'h66) ureg_addr[3:0] = GPout[3:0] + 4'h9;
						  end
				4'h4 : begin command_state <= 4'h0;
							 if (cmd == 8'h72) rsp_state <= 5'h9; 
				          if (cmd == 8'h77) txd_state <= 4'h7;
						 end
            default: command_state <= 4'h0;
          endcase				 
		 end	 	
	 
	    //send out command responce
		 if (force_responce == 1) rsp_state <= 5'hb; //forces responce from i2c commands
       if (rsp_state > 0 && TxD_busy == 0)
          case (rsp_state)
			    5'hb : begin rsp_state <= 5'ha; cmdtxdata <= 8'h0d; end
			    5'ha : begin rsp_state <= 5'h9; cmdtxdata <= 8'h0a; end
			    5'h9 : begin rsp_state <= 5'h8; cmdtxdata <= 8'h30; end
				 5'h8 : begin rsp_state <= 5'h7; cmdtxdata <= 8'h78; end
				 5'h7 : begin rsp_state <= 5'h6;
				          if (uart_ureg_dataout[15:12] < 4'ha) cmdtxdata <= 8'h30 + uart_ureg_dataout[15:12]; else 
							                                      cmdtxdata <= 8'h57 + uart_ureg_dataout[15:12]; end
				 5'h6 : begin rsp_state <= 5'h5;
				          if (uart_ureg_dataout[11:8]  < 4'ha) cmdtxdata <= 8'h30 + uart_ureg_dataout[11:8]; else 
							                                      cmdtxdata <= 8'h57 + uart_ureg_dataout[11:8]; end
				 5'h5 : begin rsp_state <= 5'h4;
				          if (uart_ureg_dataout[7:4]   < 4'ha) cmdtxdata <= 8'h30 + uart_ureg_dataout[7:4]; else 
							                                      cmdtxdata <= 8'h57 + uart_ureg_dataout[7:4]; end
				 5'h4 : begin rsp_state <= 5'h3;
				          if (uart_ureg_dataout[3:0]   < 4'ha) cmdtxdata <= 8'h30 + uart_ureg_dataout[3:0]; else 
							                                      cmdtxdata <= 8'h57 + uart_ureg_dataout[3:0]; end
				 5'h3 : begin rsp_state <= 5'h2; cmdtxdata <= 8'h0d; end	
				 5'h2 : begin rsp_state <= 5'h1; cmdtxdata <= 8'h0a; end			
				 5'h1 : begin rsp_state <= 5'h0; cmdtxdata <= 8'h20; rsp_state <= 5'h0; end	
			 
				 5'h0 : rsp_state <= 5'h0;
				 default : rsp_state <= 5'h0;
			  endcase

			 //sorts out write payload
			 if(txd_state > 0 && rx_data_ready == 1) 
             case (txd_state)	
		        4'h7  : if (GPout == 8'h78) txd_state <= 4'h6;
				  4'h6  : begin txd_state <= 4'h5;
				          if (GPout >= 8'h30 && GPout <= 8'h39) uart_ureg_datain[15:12] = GPout[3:0];
                      if (GPout >= 8'h61 && GPout <= 8'h66) uart_ureg_datain[15:12] = GPout[3:0] + 4'h9; end
				  4'h5  : begin txd_state <= 4'h4;
				          if (GPout >= 8'h30 && GPout <= 8'h39) uart_ureg_datain[11:8] = GPout[3:0];
                      if (GPout >= 8'h61 && GPout <= 8'h66) uart_ureg_datain[11:8] = GPout[3:0] + 4'h9; end
				  4'h4  : begin txd_state <= 4'h3;
				          if (GPout >= 8'h30 && GPout <= 8'h39) uart_ureg_datain[7:4] = GPout[3:0];
                      if (GPout >= 8'h61 && GPout <= 8'h66) uart_ureg_datain[7:4] = GPout[3:0] + 4'h9; end
				  4'h3  : begin txd_state <= 4'h2;
				          if (GPout >= 8'h30 && GPout <= 8'h39) uart_ureg_datain[3:0] = GPout[3:0];
                      if (GPout >= 8'h61 && GPout <= 8'h66) uart_ureg_datain[3:0] = GPout[3:0] + 4'h9;
							 txd_state <= 4'h2; uart_ureg_write <= 1;
							 end	
				  4'h2  : begin txd_state <= 4'h1; uart_ureg_write <= 1; end
				  4'h1  : begin txd_state <= 4'h0; uart_ureg_write <= 0; end
				  4'h0  : txd_state <= 4'h0;
				default : txd_state <= 4'h0;
            endcase			 
	 end
endmodule
