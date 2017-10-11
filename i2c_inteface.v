module i2c_interface (
    input      clk,
	 input      i2c_timer,
	 
	 output reg i2c_sck = 1,
	 output reg i2c_sda = 1,
	 input      i2c_sda_in,	 
	 input      i2c_strobe,
	 input      [15:0] i2c_data_write,	 
	 output reg [8:0] i2c_data_read,
	 output reg force_responce,
	 output     [7:0]testout
	 );
	 
	 assign testout = i2c_state;
	 
	 reg i2c_timer_tick;
	 reg i2c_timer_last;	 
	 always @(posedge clk) begin 
	     if (i2c_timer == 1 && i2c_timer_last == 0)i2c_timer_tick <= 1;else i2c_timer_tick <=0;
	     i2c_timer_last <= i2c_timer; 
	 end	
	 
	 reg i2c_laststate;
	 always @(posedge clk)begin if (i2c_state == 8'h04 && i2c_laststate != 8'h05 )force_responce <= 1; else force_responce <= 0;
	                            i2c_laststate <= i2c_state; end 

	 reg [7:0] i2c_state;		  
	 always @(posedge clk) begin
	     if (i2c_strobe == 1) if (i2c_data_write[15] == 1)i2c_state <= 8'h2a; else i2c_state <= 8'h28; 
		  if ((i2c_timer_tick == 1)  && (i2c_state > 0)) begin
		      i2c_state <= i2c_state - 1;
            case (i2c_state)
                8'h2a :  begin i2c_sda <= 1 ; i2c_sck <= 1; end    //enrty for start float then sda then sck)
                8'h29  :  i2c_sda <= 0; 					              //entry for continuing byte frame	 
                8'h28  :  i2c_sck <= 0;
					 8'h27  :  i2c_sda <= i2c_data_write[7];
					 8'h26  :  i2c_data_read[7] <= i2c_sda_in; 
                8'h25  :  i2c_sck <= 1;
                8'h24  :  i2c_sck <= 0;
					 8'h23  :  i2c_sda <= i2c_data_write[6]; 
					 8'h22  :  i2c_data_read[6] <= i2c_sda_in; 
                8'h21  :  i2c_sck <= 1;
                8'h20  :  i2c_sck <= 0;
					 8'h1f  :  i2c_sda <= i2c_data_write[5]; 
					 8'h1e  :  i2c_data_read[5] <= i2c_sda_in; 	 
                8'h1d  :  i2c_sck <= 1;
                8'h1c  :  i2c_sck <= 0;
					 8'h1b  :  i2c_sda <= i2c_data_write[4]; 	 
					 8'h1a  :  i2c_data_read[4] <= i2c_sda_in;  
                8'h19  :  i2c_sck <= 1;
                8'h18  :  i2c_sck <= 0;
					 8'h17  :  i2c_sda <= i2c_data_write[3]; 
					 8'h16  :  i2c_data_read[3] <= i2c_sda_in; 	 
                8'h15  :  i2c_sck <= 1;
                8'h14  :  i2c_sck <= 0;
					 8'h13  :  i2c_sda <= i2c_data_write[2]; 
					 8'h12  :  i2c_data_read[2] <= i2c_sda_in;  
                8'h11  :  i2c_sck <= 1;
                8'h10  :  i2c_sck <= 0;
					 8'h0f  :  i2c_sda <= i2c_data_write[1]; 
					 8'h0e  :  i2c_data_read[1] <= i2c_sda_in; 
                8'h0d  :  i2c_sck <= 1;
                8'h0c  :  i2c_sck <= 0;
					 8'h0b  :  i2c_sda <= i2c_data_write[0]; 
					 8'h0a  :  i2c_data_read[0] <= i2c_sda_in; 
                8'h09  :  i2c_sck <= 1;
                8'h08  :  i2c_sck <= 0;
					 8'h07  :  i2c_sda <= i2c_data_write[8];  //ack slot
					 8'h06  :  i2c_data_read[8] <= i2c_sda_in;  //ack slot
                8'h05  :  i2c_sck <= 1;
                8'h04  :  i2c_sck <= 0;
					 
                8'h03  :  begin i2c_sda <= 0; if (i2c_data_write[14] == 0)i2c_state <= 8'h00; end       // no stop
					 8'h02  :  i2c_sda <=1;				 
					 8'h01  :  i2c_sda <=1;
					 8'h00  :  ;
					 default:  i2c_state <= 8'h00;
             endcase
	        end			 
		  end
endmodule