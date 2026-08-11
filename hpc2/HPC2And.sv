module HPC2And #(
    parameter int d        = 1,
    parameter int pipeline = 1 // If pipeline = 0, x input has to arrive one cycle later than y.
)(
    input  logic                   control_clk,
    input  logic                   control_reset,
    input  logic [d:0]             io_x,
    input  logic [d:0]             io_y,
    input  logic [((d+1)*d)/2-1:0] io_r,
    output logic [d:0]             io_z
);

    logic r_m          [d:0][d:0];
    logic r_out        [d:0][d:0];
    logic s_in         [d:0][d:0];
    logic s_out        [d:0][d:0];
    logic p_0_in       [d:0][d:0];
    logic p_0_out      [d:0][d:0];
    logic p_1_in       [d:0][d:0];
    logic p_1_out      [d:0][d:0];
    logic zi           [d:0][d:0];

    logic zi_sum       [d:0][d+1:0];
    logic [d:0] mul, x_reg, y_out, mul_out;

    // Ordering fresh masks
    always_comb begin
        int c;
        c = 0;

        for (int i = 0; i <= d; i++) begin
            for (int j = i+1; j <= d; j++) begin
                r_m[i][j] = io_r[c];
                r_m[j][i] = io_r[c];
                c++;
            end
        end
    end

    genvar I, J;
    generate
        for (I = 0; I <= d; I++) begin : gen_i
            // x is only consumed behind the register stage, i.e. one cycle after y and r.
            // The optional input register balances this asymmetry.
            if (pipeline == 1) begin : gen_x_pipe
                dff x_i (.clk(control_clk), .d(io_x[I]), .q(x_reg[I]));
            end else begin : gen_no_x_pipe
                assign x_reg[I] = io_x[I];
            end

            // Signal connection
            assign mul[I] = x_reg[I] & y_out[I];
            assign zi[I][I] = mul_out[I];

            // Registers
            dff y_i (.clk(control_clk), .d(io_y[I]), .q(y_out[I]));
            dff mul_reg (.clk(control_clk), .d(mul[I]), .q(mul_out[I]));

            for (J = 0; J <= d; J++) begin : gen_j
                if (I != J) begin : gen_i_neq_j
                    // Signal connection
                    assign s_in[I][J] = io_y[J] ^ r_m[I][J];
                    assign p_0_in[I][J] = (~x_reg[I]) & r_out[I][J];
                    assign p_1_in[I][J] = s_out[I][J] & x_reg[I];
                    assign zi[I][J] = p_0_out[I][J] ^ p_1_out[I][J];

                    // Registers
                    dff r_reg (.clk(control_clk), .d(r_m[I][J]), .q(r_out[I][J]));
                    dff s_reg (.clk(control_clk), .d(s_in[I][J]), .q(s_out[I][J]));
                    dff p_0_reg (.clk(control_clk), .d(p_0_in[I][J]), .q(p_0_out[I][J]));
                    dff p_1_reg (.clk(control_clk), .d(p_1_in[I][J]), .q(p_1_out[I][J]));
                end
            end
        end
    endgenerate

    // Output
    always_comb begin
        for (int i = 0; i <= d; i++) begin
            zi_sum[i][0] = 1'b0;
            for (int j = 0; j <= d; j++) begin
                zi_sum[i][j + 1] = zi_sum[i][j] ^ zi[i][j];
            end

            io_z[i] = zi_sum[i][d + 1];
        end
    end

endmodule