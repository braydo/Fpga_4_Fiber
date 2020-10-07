// Apv Readout Channel
// The FSM identify the HEADER write it into the FIFO, followed by 128 analog samples and
// a TRAILER (12'h0).
// If the FIFO becomes FULL an ERROR is signalled and no forther writing are issued:
// this will cause disalignmets!!!

//`define DATA_FIFO_SIZE 11'd1023
//`define DATA_FIFO_MSB_ADDR 9
`define DATA_FIFO_SIZE 10'd4095
`define DATA_FIFO_MSB_ADDR 11
`define APV_EVENT_SIZE 10'd130
`define SAMPLE_EVENT_SIZE 10'd2

module ApvReadout(RSTb, CLK, ENABLE, ADC_PDATA, SYNC_PERIOD, SYNCED, ERROR,
	FIFO_DATA_OUT, FIFO_EMPTY, FIFO_FULL, FIFO_RD_CLK, FIFO_RD,
	HIGH_ONE, LOW_ZERO, FIFO_CLEAR, DAQ_MODE,
	NO_MORE_SPACE_FOR_EVENT, USED_FIFO_WORDS, ONE_MORE_EVENT,
	MARKER_CH, SAMPLE_PER_EVENT, END_FRAME
	);

input RSTb, CLK, ENABLE;
input [11:0] ADC_PDATA;
input [7:0] SYNC_PERIOD;
output SYNCED, ERROR;
output [12:0] FIFO_DATA_OUT;
output FIFO_EMPTY, FIFO_FULL;
input FIFO_RD_CLK, FIFO_RD;
input [11:0] HIGH_ONE, LOW_ZERO;
input FIFO_CLEAR;
input [2:0] DAQ_MODE;
output NO_MORE_SPACE_FOR_EVENT;
output [11:0] USED_FIFO_WORDS;
output ONE_MORE_EVENT;
input [7:0] MARKER_CH;
input [4:0] SAMPLE_PER_EVENT;
output END_FRAME;

reg END_FRAME, HEADER_SEEN;
reg fifo_write, data_frame, analog_data;
reg [7:0] fsm_status;
reg [7:0] fsm2_status;
reg [7:0] bit_count;
reg [11:0] header_sr;
reg logic_one_reg, logic_zero_reg;
wire logic_one;
wire true_synced;
reg [12:0] fifo_data_in;
wire [`DATA_FIFO_MSB_ADDR:0] fifo_used_word_wr, usedwrd;
wire write_fifo_empty, write_fifo_full;
reg apv_mode, sample_mode;
wire no_more_space_for_sample;
wire [11:0] header_trailer, header;

reg [7:0] frame_counter;
wire [12:0] data_plus_offset_logic, data_offset_minus_pedestal_logic, data_offset_minus_pedestal_logic_mkr;
reg [7:0] n_channel;
reg complete_event;
wire MeanFifoEmpty;
reg [4:0] ApvSampleCounter;
wire [3:0] ApvSampleCounterMinusOne;
reg ClearApvSampleCounter;

assign ERROR = write_fifo_full;


assign NO_MORE_SPACE_FOR_EVENT = ((`DATA_FIFO_SIZE-fifo_used_word_wr) < `APV_EVENT_SIZE) ? 1'b1 : 1'b0;
assign no_more_space_for_sample = ((`DATA_FIFO_SIZE-fifo_used_word_wr) < `SAMPLE_EVENT_SIZE) ? 1'b1 : 1'b0;

//assign USED_FIFO_WORDS = {FIFO_FULL, usedwrd};
assign USED_FIFO_WORDS = usedwrd;

assign PEDESTAL_ADDRESS = bit_count[6:0];

assign ApvSampleCounterMinusOne = ApvSampleCounter - 1'b1;
assign header_trailer = HEADER_SEEN ? header : {ApvSampleCounterMinusOne, frame_counter};
assign logic_one  = (ADC_PDATA > HIGH_ONE) ? 1 : 0;
assign header = (NO_MORE_SPACE_FOR_EVENT) ? 12'hFFF : {header_sr[10:0], logic_one};
assign ONE_MORE_EVENT = ~MeanFifoEmpty;

assign data_offset_minus_pedestal_logic_mkr = (bit_count == MARKER_CH) ? {1'b0,12'hFFF} : {1'b0, ADC_PDATA};

SyncMachine SyncDetector(.RSTb(RSTb), .CLK(CLK), .ENABLE(ENABLE),
	.ONE(logic_one_reg), .ZERO(logic_zero_reg), .DATA_FRAME(data_frame), .PERIOD(SYNC_PERIOD),
	.SYNCED(SYNCED));


//ApvDataFifo_1024x13 DataFifo(
ApvDataFifo_4096x13 DataFifo(
	.aclr(FIFO_CLEAR),
	.data(fifo_data_in),
	.rdclk(FIFO_RD_CLK),
	.rdreq(FIFO_RD),
	.wrclk(CLK),
	.wrreq(fifo_write),
	.q(FIFO_DATA_OUT),
	.rdempty(FIFO_EMPTY),
	.rdfull(FIFO_FULL),
	.rdusedw(usedwrd),
	.wrusedw(fifo_used_word_wr),
	.wrempty(write_fifo_empty),
	.wrfull(write_fifo_full));

// Synchronizer
always @(posedge CLK)
begin
	apv_mode <= (DAQ_MODE == 3'b001 || DAQ_MODE == 3'b011) ? 1 : 0;	// Simple or Processed
	sample_mode <= (DAQ_MODE == 3'b010) ? 1 : 0;
	logic_one_reg  <= (ADC_PDATA > HIGH_ONE) ? 1 : 0;
	logic_zero_reg <= (ADC_PDATA < LOW_ZERO) ? 1 : 0;
	header_sr <= {header_sr[10:0], logic_one};
	fifo_data_in <= analog_data ? data_offset_minus_pedestal_logic_mkr : {1'b0, header_trailer};
end


// Frame Counter
always @(posedge CLK or posedge FIFO_CLEAR)
begin
	if( FIFO_CLEAR == 1 )
	begin
		frame_counter <= 0;
	end
	else
	begin
		if( HEADER_SEEN )
		begin
			frame_counter <= frame_counter + 1'b1;
		end
	end
end

// Sample Counter
always @(posedge CLK or posedge FIFO_CLEAR)
begin
	if( FIFO_CLEAR == 1 )
	begin
		ApvSampleCounter <= 0;
	end
	else
	begin
		if( HEADER_SEEN )
		begin
			ApvSampleCounter <= ApvSampleCounter + 1'b1;
		end
		if( ClearApvSampleCounter && ApvSampleCounter == SAMPLE_PER_EVENT )
			ApvSampleCounter <= 0;
	end
end


// Main FSM
always @(posedge CLK or negedge RSTb)
begin
	if( RSTb == 0 )
	begin
		fsm_status <= 0;
		bit_count <= 0;
		data_frame <= 0;
		fifo_write <= 0;
		analog_data <= 0;
		complete_event <= 0;
		END_FRAME <= 0;
		HEADER_SEEN <= 0;
		ClearApvSampleCounter <= 0;
	end
	else
	begin
		case( fsm_status )
			0: begin
				HEADER_SEEN <= 0;
				ClearApvSampleCounter <= 0;
				END_FRAME <= 0;
				analog_data <= 0;
				data_frame <= 0;
				fifo_write <= 0;
				if( ENABLE  & apv_mode & logic_one_reg & ~write_fifo_full )
					fsm_status <= 1;
				else
				begin
					if( ENABLE  & sample_mode )
						fsm_status <= 10;
					else
						fsm_status <= 0;
				end
			   end

// APV frame decoding
			1: begin
				bit_count <= 6;
				if( logic_one_reg )
					fsm_status <= 2;
				else
					fsm_status <= 0;
			   end
			2: begin
				if( logic_one_reg )
				begin
					data_frame <= 1;
					fsm_status <= 3;
				end
				else
					fsm_status <= 0;
			   end
			3: begin
				bit_count <= bit_count - 1;
				if( bit_count > 0 )
					fsm_status <= 3;
				else
				begin
					complete_event <= 0;
					HEADER_SEEN <= 1;
					fsm_status <= 4;
				end
			   end
			4: begin
				bit_count <= 0;
				HEADER_SEEN <= 0;
				if( NO_MORE_SPACE_FOR_EVENT == 0 )
				begin
					complete_event <= 1;
					fifo_write <= 1;
				end
				analog_data <= 1;
				fsm_status <= 5;
			   end
			5: begin	// Write 128 analog data words
				bit_count <= bit_count + 1;
				fsm_status <= 6;
			   end
			6: begin
				bit_count <= bit_count + 1;
				if( bit_count < 127 )
					fsm_status <= 6;
				else
				begin
//					END_FRAME <= 1;
					END_FRAME <= (ApvSampleCounter == SAMPLE_PER_EVENT) ? 1 : 0;
					analog_data <= 0;
					fsm_status <= 7;
				end
			   end
			7: begin	// Write trailer = {sample_counter,frame_counter}
				END_FRAME <= 0;
				ClearApvSampleCounter <= 1;
				data_frame <= 0;
				fsm_status <= 0;
			   end

// Store data until FIFO full and wait for FIFO empty to restart
			10: begin
				analog_data <= 1;
				fifo_write <= 1;
				fsm_status <= 11;
			    end
			11: begin
				if( no_more_space_for_sample )
				begin
					fifo_write <= 0;
					fsm_status <= 12;
				end
				else
					fsm_status <= 11;
			    end
			12: begin
				if( write_fifo_empty )
					fsm_status <= 0;
				else
					fsm_status <= 12;
			    end


			default: fsm_status <= 0;
		   endcase
	end
end


endmodule


// Check the presence of a SYNC pulse every PERIOD clock cycles.
// After 16 consecutive correct syncs the SYNCED output comes true.
// Checks are made only if DATA_FRAME is 0.
// This is a very simple implementation, used only to inform user through a register bit
// Does not work to block DAQ
module SyncMachine(RSTb, CLK, ENABLE, ONE, ZERO, DATA_FRAME, PERIOD, SYNCED);
input RSTb, CLK, ENABLE, ONE, ZERO, DATA_FRAME;
input [7:0] PERIOD;
output SYNCED;

reg SYNCED;
reg [4:0] sync_cnt;
reg [7:0] period_cnt;


// Period Counter
always @(posedge CLK or negedge RSTb)
begin
	if( RSTb == 0 )
	begin
		period_cnt <= 0;
	end
	else
	begin
		if( DATA_FRAME == 0 )
		begin
			if( ONE )
				period_cnt <= PERIOD;
			else
				if( ZERO )
					period_cnt <= period_cnt - 1;
		end
		else
			period_cnt <= 0;
	end
end

// Sync Counter
always @(posedge CLK or negedge RSTb)
begin
	if( RSTb == 0 )
	begin
		sync_cnt <= 0;
	end
	else
	begin
		if( ENABLE == 0 )
			sync_cnt <= 0;
		else
		begin
			if( ONE == 1 && period_cnt == 0 && sync_cnt < 16 )
				sync_cnt <= sync_cnt + 1;
			if( ONE == 1 && period_cnt != 0 )
				sync_cnt <= 0;
		end
	end
end

always @(posedge CLK or negedge RSTb)
begin
	if( RSTb == 0 )
		SYNCED <= 0;
	else
		SYNCED <= (sync_cnt == 16);
end


endmodule

