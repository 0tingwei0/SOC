module adder (
	input wire clk,    // Clock
	input wire rst_n,  // Synchronous reset active low
	input wire [15:0] A0, A1,
	output reg [15:0] Y
);

reg [15:0] A0_reg, A1_reg;
wire [15:0]Y_;


always @(posedge clk) begin 
	if(~rst_n) begin
		A0_reg <= 0;
	end else begin
		A0_reg <= A0;
	end
end


always @(posedge clk) begin 
	if(~rst_n) begin
		A1_reg <= 0;
	end else begin
		A1_reg <= A1;
	end
end

always @(posedge clk) begin 
	if(~rst_n) begin
		Y <= 0;
	end else begin
		Y <= Y_;
	end
end

combinational_block #(.BIT_WIDTH(16)) ADDR (.A0(A0_reg), .A1(A1_reg), .Y(Y_));

endmodule