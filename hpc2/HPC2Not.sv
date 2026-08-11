module HPC2Not #(
	parameter int d        = 1,
	parameter int pipeline = 1
)(
	input  logic      control_clk,
	input  logic      control_reset,
	input  logic[d:0] io_x,
	output logic[d:0] io_z
);

	assign io_z[0] = ~io_x[0];
	assign io_z[d:1] = io_x[d:1];

endmodule
