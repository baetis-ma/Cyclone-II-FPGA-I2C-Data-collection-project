module fpga(
    input clk,
	 	 
	 //uart interface
    input RxD,
    output TxD,

	 //i2c
	 output i2c_sck,
	 output i2c_nsda_out,
	 input  i2c_sda_in,
	 //misc
	 output [2:0] led,
	 input  switch,
	 //test
	 output reg sawout,
	 output [7:0] testout
); 


general(
    .clk(clk),
    .RxD(RxD),
    .TxD(TxD),
    .uart_ureg_datain(uart_ureg_datain),
    .uart_ureg_dataout(uart_ureg_dataout),
    .ureg_addr(ureg_addr),
    .ureg_write(ureg_write),
	 .ureg_rack(ureg_rack),
	 .uart_ureg_write(uart_ureg_write),
	 .force_responce(force_responce),
	 .testbits(testbits)
); 
	 wire [15:0]uart_ureg_datain;
    wire [15:0]uart_ureg_dataout;
	 wire [7:0]ureg_addr;
	 wire uart_ureg_write;
    wire ureg_write;
	 wire [15:0]testbits;

//cyclone 2 doesn't do tristate so sda in/out	
i2c_interface(
    .clk(clk),
	 .i2c_timer(clk_i2c),  //with my 2n2222 and 100ohm you can't run at full speed
	 .i2c_sck(i2c_sck),
	 .i2c_sda(i2c_sda_out),
	 .i2c_sda_in(i2c_sda_in),
	 .i2c_strobe(i2c_strobe),
	 .i2c_data_write(i2c_data_write),
	 .i2c_data_read(i2c_data_read),
	 .force_responce(force_responce),

	 .testout(testcnt)
);
    wire [7:0]testcnt;
	 wire i2c_sda_out;
	 assign i2c_nsda_out = ~ i2c_sda_out;
	 wire [8:0] i2c_read_data;
    reg i2c_strobe;
	 always @(posedge clk) if (ureg_addr == 8'h20 && ureg_write == 1) i2c_strobe = 1; else i2c_strobe = 0; 
	 
	 i2c_autoread (
	      .clk(clk),
    //i2c
          .mode(i2c_mode),                    //shuts off i2c_int to comms
          .i2c_adata_out(i2c_adata_read),   //already there 
          .i2c_adata_write(force_resp),         //like force_rsp (use to test)
          .i2c_adata_cmd(i2c_adata_cmd),     //sda data from here, + start/stop flags
          .i2c_adata_start(i2c_adata_start),         //start read gated by timebase
    //ureg
           .i2c_adata_cmdreg(i2c_adata_cmdreg),  //cmd reg from ureg space
           .i2c_adata_cmdreg_write(i2c_adata_cmdreg_write),  //decoded cmd reg write, and start
           .i2c_adata_status(i2c_adata_status),  //the module status
           .i2c_adata_fifo_out(i2c_adata_fifo_out),//fifo output data
           .i2c_adata_fifo_read(i2c_adata_fifo_read)      //fifo read increment
    );
	 reg [15:0]i2c_adata_cmdreg;
	 assign i2c_adata_fifo_read = (ureg_addr == 8'h31) ? ureg_rack : 0;
	 assign i2c_adata_cmdreg_write = (ureg_addr == 8'h30) ? ureg_write : 0;
	 
	 
    //user registers
	 reg [15:0] ident0 = 16'h1234;	 
	 reg [15:0] ident1 = 16'h5678;
	 reg [15:0] ident2 = 16'h9abc;	 
	 reg [15:0] ident3 = 16'hcdef;
	 reg [15:0] pwmtone = 16'h0000;
	 reg [15:0] fifo_cntl;
	 
	 // i2c regs
	 reg  [15:0] i2c_data_write;
	 wire [15:0] i2c_data_read;
	 
	 
	 // user regigister decode logic
	 assign uart_ureg_dataout = (ureg_addr == 8'h00) ? ident0 :
	                            (ureg_addr == 8'h01) ? ident1 :
	                            (ureg_addr == 8'h02) ? ident2 :
	                            (ureg_addr == 8'h03) ? ident3 :
										 (ureg_addr == 8'h10) ? testbits :
										 (ureg_addr == 8'h20) ? i2c_data_read :
										 (ureg_addr == 8'h30) ? i2c_adata_cmdreg :
										 (ureg_addr == 8'h31) ? i2c_adata_fifo_out :
										 (ureg_addr == 8'h32) ? i2c_adata_status :
										 
										 (ureg_addr == 8'h40) ? fifo_cntl :
										 (ureg_addr == 8'h41) ? fifoout :
										 (ureg_addr == 8'h42) ? fifo_status :										 
										 (ureg_addr == 8'h60) ? pwmtone :  //0x1000=6.111KHz (~1.492*pwmtone = freq Hz)
										 16'h0095;
	 
	 always @(posedge clk) begin
	      if (ureg_write == 1) begin   //writable from uart_interface
				if (ureg_addr == 8'h20) i2c_data_write   <= uart_ureg_datain;
				if (ureg_addr == 8'h30) i2c_adata_cmdreg <= uart_ureg_datain;
				if (ureg_addr == 8'h40) fifo_cntl        <= uart_ureg_datain;	//0x41 fifo r/w					
				if (ureg_addr == 8'h60) pwmtone          <= uart_ureg_datain;
			end
			//single shots
			if ( fifo_cntl[0] ==1 ) fifo_cntl[0] <= 0;
	 end  
	 
	 //fifo 256x16 hooked up to user regs
	 wire [15:0]fifoout;
	 wire [15:0]fifo_status;
	 wire fifo_write;
	 
	 wire fifo_read;
	 wire ureg_rack;
	 assign fifo_read =  (ureg_addr == 8'h41) ? ureg_rack : 0;
	 assign fifo_write = (ureg_addr == 8'h41) ? ureg_write : 0;
	 //fifo4k (
	 //   .clock(clk),
	 //   .data(uart_ureg_datain),
	 //   .rdreq(fifo_read),
	//	 .sclr(fifo_cntl[0] ),
	//    .wrreq(fifo_write),
	//    .empty(fifo_status[14]),
	//    .full(fifo_status[15]),
	//    .q(fifoout),
	//    .usedw(fifo_status[7:0])   );
	 
	 //pwm sinewave synthesiser
    reg  [8:0]pulsewidth;
	 reg [25:0]pwsaw;
	 always @(posedge clk) begin
	     pulsewidth <= pulsewidth + 1;
        pwsaw <= pwsaw + pwmtone;
		  if (pulsewidth > lut0out) sawout <= 0; else sawout <= 1;  
	 end
	 
	 wire [8:0]lut0out;
    costable (
	   .address_a(pwsaw[25:17]),
	   .address_b(),
	   .clock(clk),
   	.q_a(lut0out),
	   .q_b()    );
	
	 //low frequency timers
    reg clk_1ms = 0;
    reg [15:0] cnt_1ms = 16'b0;
	 reg clk_i2c = 0;
	 reg [10:0] cnt_i2c = 11'b0;
	 reg clk_1s = 0;
	 reg [9:0] cnt_1s = 10'b0;
	 always @(posedge clk)
	    begin
	       cnt_1ms <= cnt_1ms + 1;
			 cnt_i2c <= cnt_i2c + 1;
		    if (cnt_1ms == 16'hc34f) cnt_1s <= cnt_1s + 1;
			 if (cnt_1ms == 16'hc34f) cnt_1ms <= 0;
			 if (cnt_1ms == 16'hc34f) clk_1ms <= 1; else clk_1ms = 0;
			 if (cnt_i2c == 11'h200) cnt_i2c <= 8'h00;
			 if (cnt_i2c == 11'h200) clk_i2c <= 1; else clk_i2c = 0;		 
			 if (cnt_1s  == 10'h3e8) cnt_1s <= 0;
			 if (cnt_1s  == 10'h3e8) clk_1s <= ~ clk_1s;
	    end
		 
	 //blinking lights
	 reg [2:0]cnt;
	 always @(posedge clk)if (ureg_rack == 1) cnt <= cnt + 1;
    assign led[0] = ~ cnt[0];
	 assign led[1] = ~ cnt[1];
	 assign led[2] = ~ cnt[2];
    //assign led[0] = ~ testcnt[0];
	 //assign led[1] = ~ testcnt[1];
	 //assign led[2] = ~ testcnt[2];
	 assign testout = testcnt;
	 
	 endmodule
