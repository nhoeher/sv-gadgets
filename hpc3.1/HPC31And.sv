module HPC31And #(
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

    logic [M-1:0] r_blind, r_corr;

    logic r_m       [d:0][d:0];
    logic p_m       [d:0][d:0];

    logic v_in      [d:0][d:0];
    logic v_out     [d:0][d:0];
    logic w_in      [d:0][d:0];
    logic w_out     [d:0][d:0];

    logic v_sum     [d:0][d+1:0];
    logic zi_sum    [d:0][d+1:0];

    logic [d:0] x_reg, y_reg, v;

    always_comb begin
        r_blind = io_r[(2*M)-1 -: M];
        r_corr  = io_r[M-1 -: M];
    end

    // Ordering fresh masks
    always_comb begin
        int c;
        c = 0;

        for (int i = 0; i <= d; i++) begin
            for (int j = 0; j <= d; j++) begin
                r_m[i][j] = 1'b0;
                p_m[i][j] = 1'b0;
            end
        end

        for (int i = 0; i <= d; i++) begin
            for (int j = i + 1; j <= d; j++) begin
                r_m[i][j] = r_blind[c];
                r_m[j][i] = r_blind[c];
                p_m[i][j] = r_corr[c];
                p_m[j][i] = r_corr[c];
                c++;
            end
        end
    end

    genvar I, J;
    generate
        for (I = 0; I <= d; I++) begin : gen_i
            dff x_i (.clk(control_clk), .d(io_x[I]), .q(x_reg[I]));
            dff y_i (.clk(control_clk), .d(io_y[I]), .q(y_reg[I]));

            for (J = 0; J <= d; J++) begin : gen_j
                if (I != J) begin : gen_i_neq_j
                    // V_{i,j} = y_j ^ r_{i,j}
                    assign v_in[I][J] = io_y[J] ^ r_m[I][J];
                    // W_{i,j} = (x_i & r_{i,j}) ^ p_{i,j}
                    assign w_in[I][J] = (io_x[I] & r_m[I][J]) ^ p_m[I][J];

                    dff v_reg (.clk(control_clk), .d(v_in[I][J]), .q(v_out[I][J]));
                    dff w_reg (.clk(control_clk), .d(w_in[I][J]), .q(w_out[I][J]));
                end else begin : gen_i_eq_j
                    assign v_in[I][J]  = 1'b0;
                    assign w_in[I][J]  = 1'b0;
                    assign v_out[I][J] = 1'b0;
                    assign w_out[I][J] = 1'b0;
                end
            end
        end
    endgenerate

    // Output
    always_comb begin
        for (int i = 0; i <= d; i++) begin
            v_sum[i][0]  = y_reg[i];
            zi_sum[i][0] = 1'b0;

            for (int j = 0; j <= d; j++) begin
                v_sum[i][j + 1]  = v_sum[i][j] ^ v_out[i][j];
                zi_sum[i][j + 1] = zi_sum[i][j] ^ w_out[i][j];
            end

            v[i] = v_sum[i][d + 1];
            io_z[i] = (x_reg[i] & v[i]) ^ zi_sum[i][d + 1];
        end
    end

endmodule
