`timescale 1ns / 1ps

module binary2bcd_double_dabble(
	input  [7:0]in_binary,
	output reg [7:0]packed_bcd,
	output reg [15:0]unpacked_bcd
);

reg [15:0]scratch_pad;
integer i;


always @(*)begin
	
	scratch_pad = {8'd0,in_binary};
	
	if(in_binary<8'd100)begin

		for(i = 0; i < 7; i = i + 1)begin
			scratch_pad = scratch_pad << 1;
			if (scratch_pad[11:8] > 4'd4)
				scratch_pad[11:8] = scratch_pad[11:8] + 4'd3;
			else
				scratch_pad = scratch_pad;
		end
		
		scratch_pad = scratch_pad << 1;
	end else begin
			scratch_pad = 16'bZ;			
	end
	
end

always @(*)begin

	packed_bcd = scratch_pad[15:8];
	unpacked_bcd = {4'd0, scratch_pad[15:12], 4'd0, scratch_pad[11:8]};
end

endmodule
