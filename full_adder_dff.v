`timescale 1ns/1ps

// 4-bit full adder whose result is stored in a rising-edge D flip-flop.
// The stored 5-bit value is {carry_out, sum[3:0]}.
module full_adder_dff (
    input  wire       clk,
    input  wire       rst,       // synchronous, active-high reset
    input  wire [3:0] A,
    input  wire [3:0] B,
    input  wire       Cin,
    output reg  [3:0] Sum_q,
    output reg        Cout_q
);

    wire [4:0] add_result;

    assign add_result = {1'b0, A} + {1'b0, B} + Cin;

    always @(posedge clk) begin
        if (rst) begin
            Sum_q  <= 4'b0000;
            Cout_q <= 1'b0;
        end else begin
            Sum_q  <= add_result[3:0];
            Cout_q <= add_result[4];
        end
    end

endmodule
