//many i2c devices offer modes where reads can be extended indefinately
//instead of complicating i2c_interface this moule works with that module
//to include repeats - set mode = 0 on i2c_interface to disable this feature
//cmd reg rate[15:13], samples[12:10], i2c addr [6:0]
module i2c_autoread (
    input clk,
    //i2c
    output     mode,                    //shuts off i2c_int to comms
    input      [9:0]i2c_adata_out,   //already there 
    input      i2c_adata_write,         //like force_rsp (use to test)
    output     [15:0]i2c_adata_cmd,     //sda data from here, + start/stop flags
    output     i2c_adata_start,         //start read gated by timebase
    //ureg
    input      [15:0]i2c_adata_cmdreg,  //cmd reg from ureg space
    input      i2c_adata_cmdreg_write,  //decoded cmd reg write, and start
    output     [15:0]i2c_adata_status,  //the module status
    output     [15:0]i2c_adata_fifo_out,//fifo output data
    input      i2c_adata_fifo_read      //fifo read increment
);

    wire [2:0]rate;
    assign rate = i2c_adata_cmdreg[15:13];
    wire [2:0]samples;
    assign samples = i2c_adata_cmdreg[12:10];
    wire   [19:0]timebase;  // for 50MHz clk - 0.1ms to 250msec
	 
    assign timebase = rate == 3'b000 ?     5000 :  
	                   rate == 3'b001 ?    15000 :
							 rate == 3'b010 ?    50000 :
	                   rate == 3'b011 ?   150000 :
							 rate == 3'b100 ?   500000 :	 
	                   rate == 3'b101 ?  1500000 :
							 rate == 3'b110 ?  5000000 :	15000000 ;						 
	 reg timebase_tick;
	 reg [25:0]timebase_cnt;
	 always @(posedge clk)begin
	     if (timebase_cnt == 0)timebase_tick <= 1; else timebase_tick = 0;
		  if (timebase_cnt == rate)timebase_cnt <= 0; else timebase_cnt <= timebase_cnt + 1;
    end	
	 
    reg [8:0]writeptr;
	 reg [8:0]readptr;
	 always @(posedge clk) begin
	     if (i2c_adata_cmdreg_write  == 1)begin writeptr<=0; readptr<=0; end
		  if (i2c_adata_write == 1)writeptr <= writeptr + 1;
		  if (i2c_adata_fifo_read == 1)readptr <= readptr + 1;
    end
    assign i2c_adata_status[15:8] = readptr[7:0];
	 assign i2c_adata_status[7:0] = writeptr[7:0];
	 


endmodule
