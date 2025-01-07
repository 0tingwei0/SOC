module combinational_block #(parameter BIT_WIDTH = 8)(
	input wire[BIT_WIDTH-1:0] A0, A1,
	output wire [BIT_WIDTH-1:0] Y
);
assign Y = A0 + A1;

endmodule
