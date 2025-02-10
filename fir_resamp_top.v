`timescale 1ns / 1ps
////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer:       J. Shima
//
// Create Date: 
// Design Name:    
// Module Name:    fir_resamp_top
// Project Name:   
// Target Device:  
// Tool versions:  
// Description:
//
// Dependencies:
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
////////////////////////////////////////////////////////////////////////////////
module fir_resamp_top(CLK, DIN, DOUT, ND, RDY, OV, RESET, B_0, B_1, B_2, B_3, B_4, ACC, BPTR);

	 // number of bits for in and out data
	 parameter word_size_in = 16;
	 parameter word_size_out = 16;

    // max and min fractional values based on output word size
	 parameter max_fract = 2**(word_size_out-1) - 1;
	 parameter min_fract = 2**(word_size_out-1);

	 // define accumulator length and number of guard bits
	 parameter guard_bits = 4;
     parameter coeff_word_size = 16;  //input data width of filter coeffs
	 parameter acc_len = word_size_in + coeff_word_size + guard_bits;
	 parameter addy_bits = 9;
	 parameter acc_ind1_out = acc_len-guard_bits-1;  //output ind of accum after rounding
	 parameter acc_ind2_out = acc_len-guard_bits-word_size_out;	//lsb of output from accum

	 // input/output port definitions
     input CLK;
	 input RESET;
     input signed [word_size_in-1:0] DIN;		 //input sample 
     output signed [word_size_out-1:0] DOUT;	 //output filt sample
	 output OV;		// arithemetic overflow flag
	 input  ND;    // new data point input flag
	 output RDY;   // output data point is valid flag
	 
	 // ports used for simulation
	 output signed [coeff_word_size-1:0] B_0, B_1, B_2, B_3, B_4;
	 output [addy_bits-1:0] BPTR;
	 output signed [acc_len-1:0] ACC;
	
    // parameters for polyphase resampler
	 parameter L = 375;  // upsample rate
	 parameter D = 256;  // decimation rate 
	 parameter taps_per_branch = 5;  // taps per polyphase branch						  
	 parameter fir_taps = (L * taps_per_branch);	 //number of total FIR taps
	 parameter hist_order = taps_per_branch-1;

	  // internal history buff and accumulator.  Hist order len is one minus the branch taps
	 reg signed [word_size_in-1:0] HistBuf[hist_order-1:0];
     reg signed [acc_len-1:0] accum, accum1, accum2, accum3, accum4, accum5; // multiply doubles bits, also put in guard bits
	 reg signed [word_size_in-1:0] LastHist;

    // ptr into polyphase coeff memory array
     reg [addy_bits-1:0] ptr = 0;
	 
	 // current polyphase branch coeffs retrieved from rom
//    reg signed [coeff_word_size-1:0] b0, b1, b2, b3, b4;  
	 wire signed [coeff_word_size-1:0] b0, b1, b2, b3, b4;  
	 reg compute_another_samp;
	 reg do_valid;

	 integer k;

	 parameter state0 = 1'b0;
 	 parameter state1 = 1'b1;
//	 parameter state2 = 2'b10;
//	 parameter state3 = 2'b11;

	 reg fir_sv = state0;
	 reg ce;

	  // send output of accum through rounding and saturation logic, lsb is rounded
	 assign DOUT = (OV == 0) ? accum[acc_ind1_out:acc_ind2_out] + accum[acc_ind2_out-1]
	 										: (accum[acc_len-1] == 1'b1) ? min_fract: max_fract;

    // overflow checks if accumulator exceeds allowable fractional values
	 // new OV logic - all guard bits + the sign bit must be the same if 
	 // we have no overflow, otherwise we have an overflow
	 // ** NOTE:  If you change the parameter "guard_bits" above you must
	 //           modify this statement to reflect the new guard bit length **
	 assign OV = (accum[acc_len-1:acc_len-guard_bits-1] == 5'b00000) ? 0 :
	 				 (accum[acc_len-1:acc_len-guard_bits-1] == 5'b11111) ? 0 : 1;

	 assign RDY = do_valid;

    // output signals assigned for sim
	 assign B_0 = b0;
	 assign B_1 = b1;
	 assign B_2 = b2;
	 assign B_3 = b3;
	 assign B_4 = b4;
	 assign ACC = accum;
	 assign BPTR = ptr;

    /////////////////// start of logic block ///////////////////////

    // get new FIR coefficients from ROM table - combinatorial LUTs
	fir_rom1 r1(ptr, b0);
    fir_rom2 r2(ptr, b1);
    fir_rom3 r3(ptr, b2); 
    fir_rom4 r4(ptr, b3);
    fir_rom5 r5(ptr, b4);
   
//	always@(posedge CLK) begin
//		b0 <= 1;
//		b1 <= 2;
//		b2 <= 3;
//		b3 <= 4;
//		b4 <= 5;
//	end

	 /////////// synchronous clk logic //////////////////

	 always@(posedge CLK) begin
		// synchronous reset
	 	if(RESET) begin

			 for(k=0; k<hist_order; k=k+1)  //clear hist
				HistBuf[k] <= 0;

			 ptr <= 0;		 //init ptr and accum to 0
			 accum <= 0;
			 compute_another_samp <= 0;
			 do_valid <= 0;

		end
		else begin	 //no reset, process incoming data samples

			// state machine for outputting new samples from interpolator
			case (fir_sv)
				state0:  begin
						// Generate filtered output pts using new input data
						// shift history buffer by 1 sample, then inject new sample into buffer
						// update to history buffer occurs on new data pt only
						if(ND) begin

							// shift new data sample into hist array, which will be valid next clk
							HistBuf[0] <= DIN;
							for(k=1; k<hist_order; k=k+1)
								HistBuf[k] <= HistBuf[k-1];

							// save the last sample being pushed out of history, since
							// we may need it to compute another interpolated sample next clk
							LastHist <= HistBuf[hist_order-1];

							// parallel fixed-pt MAC operation on fractional samples
         				accum <= fp_mul(b0, DIN)  
										+ fp_mul(b1, HistBuf[0])
										+ fp_mul(b2, HistBuf[1])
 	    								+ fp_mul(b3, HistBuf[2])
	  	  	   						+ fp_mul(b4, HistBuf[3]);
			
							// update branch ptr by D.  Make sure we rollover before we get to end of 
							// filter, since ptr lags by one clock in synchronous design here
							ptr <= (ptr >= L-D) ? ptr + D - L: ptr + D;

							// see if we are going to output another filter point, or if we should stop 
							// and update the history buffer when next input sample arrives
							compute_another_samp <= (ptr >= L-D) ? 0: 1;	 

							do_valid <= 1;

						   fir_sv <= state1;
							
						end
						else begin
							do_valid <= 0;
						end

				end  //state0 end

				state1: begin

					fir_sv <= state0;		
								
  					// Here we compute the 2nd point out of the polyphase struct if need be.
					// Since history buffer already updated from 1st samp, skew the buf pts used
					// in MAC calculation
					if(compute_another_samp) begin

  						accum <= fp_mul(b0, HistBuf[0])
									+ fp_mul(b1, HistBuf[1])
									+ fp_mul(b2, HistBuf[2])
 	    							+ fp_mul(b3, HistBuf[3])
	  	  	   					+ fp_mul(b4, LastHist);
				
						// update branch ptr by D.  Make sure we rollover before we get to end of 
						// filter, since ptr lags by one clock in synchronous design here
						ptr <= (ptr >= L-D) ? ptr + D - L: ptr + D;

						// just did last sample for this input pt., clear flag
						compute_another_samp <= 0;	

						do_valid <= 1;

					end
					else begin
				
						do_valid <= 0;

					end  //if compute_another_samp

				end // state end

			endcase // end of case SM

		end	 //if..else reset

	 end	  //always@

	 //------------------------------------------------------------------
    // function to do a fixed-pt 1.P x 1.Q fractional multiply.
	 // define output to be length of our accumulator so it will automatically be 
	 // sign extended when put back into accumulator (for add/sub operation)
	 function signed [acc_len-1:0] fp_mul;
	   input signed [coeff_word_size-1:0] A;
		input signed [word_size_in-1:0] B;

		begin		
			fp_mul = (A*B)<<1;
		end

	 endfunction

endmodule
