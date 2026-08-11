module HPC1And #(
    parameter int d        = 1,
    parameter int pipeline = 1
)(
    input  logic                   control_clk,
    input  logic                   control_reset,
    input  logic [d:0]             io_x,
    input  logic [d:0]             io_y,
    input  logic [((d+1)*d)-1:0]   io_r,
    output logic [d:0]             io_z
);

    localparam int M = ((d + 1) * d) / 2;

    logic [M-1:0] r_ref, r_mul;

    logic r_ref_m   [d:0][d:0];
    logic r_mul_m   [d:0][d:0];

    logic y_ref_sum [d:0][d+1:0];
    logic p_in      [d:0][d:0];
    logic p_out     [d:0][d:0];
    logic zi_sum    [d:0][d+1:0];

    logic [d:0] y_ref, y_reg, x_reg;

    always_comb begin
        r_ref = io_r[(2*M)-1 -: M];
        r_mul = io_r[M-1 -: M];
    end

    // Ordering fresh masks
    always_comb begin
        int c;
        c = 0;

        for (int i = 0; i <= d; i++) begin
            for (int j = 0; j <= d; j++) begin
                r_ref_m[i][j] = 1'b0;
                r_mul_m[i][j] = 1'b0;
            end
        end

        for (int i = 0; i <= d; i++) begin
            for (int j = i + 1; j <= d; j++) begin
                r_ref_m[i][j] = r_ref[c];
                r_ref_m[j][i] = r_ref[c];
                r_mul_m[i][j] = r_mul[c];
                r_mul_m[j][i] = r_mul[c];
                c++;
            end
        end
    end

    // SNI refresh of y
    always_comb begin
        for (int i = 0; i <= d; i++) begin
            y_ref_sum[i][0] = io_y[i];
            for (int j = 0; j <= d; j++) begin
                y_ref_sum[i][j + 1] = (i == j) ? y_ref_sum[i][j]
                                               : y_ref_sum[i][j] ^ r_ref_m[i][j];
            end

            y_ref[i] = y_ref_sum[i][d + 1];
        end
    end

    genvar I, J;
    generate
        for (I = 0; I <= d; I++) begin : gen_i
            dff y_ref_reg (.clk(control_clk), .d(y_ref[I]), .q(y_reg[I]));

            // x is not refreshed, so it only needs a register to arrive together with the refreshed y
            if (pipeline == 1) begin : gen_x_pipe
                dff x_i (.clk(control_clk), .d(io_x[I]), .q(x_reg[I]));
            end else begin : gen_no_x_pipe
                assign x_reg[I] = io_x[I];
            end

            // DOM-indep multiplication
            for (J = 0; J <= d; J++) begin : gen_j
                if (I == J) begin : gen_i_eq_j
                    assign p_in[I][J] = x_reg[I] & y_reg[J];
                end else begin : gen_i_neq_j
                    assign p_in[I][J] = (x_reg[I] & y_reg[J]) ^ r_mul_m[I][J];
                end

                dff p_reg (.clk(control_clk), .d(p_in[I][J]), .q(p_out[I][J]));
            end
        end
    endgenerate

    // Output
    always_comb begin
        for (int i = 0; i <= d; i++) begin
            zi_sum[i][0] = 1'b0;
            for (int j = 0; j <= d; j++) begin
                zi_sum[i][j + 1] = zi_sum[i][j] ^ p_out[i][j];
            end

            io_z[i] = zi_sum[i][d + 1];
        end
    end

endmodule
