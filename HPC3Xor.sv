module HPC3Xor #(
	parameter int d        = 1,
	parameter int pipeline = 1
)(
	input  logic      control_clk,
	input  logic      control_reset,
	input  logic[d:0] io_x,
	input  logic[d:0] io_y,
	output logic[d:0] io_z
);

    genvar i;
    generate
        for (i = 0; i <= d; i++) begin : gen_o
            xor2 Ins (
                .x(io_x[i]),
                .y(io_y[i]),
                .z(io_z[i])
            );
        end
    endgenerate

endmodule
