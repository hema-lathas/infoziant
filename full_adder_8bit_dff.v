`timescale 1ns/1ps

// 8-bit full adder with rising-edge D flip-flop storage.
// Stored result: {Cout_q, Sum_q} (9 bits total).
module full_adder_8bit_dff (
    input  wire       clk,
    input  wire       rst,      // synchronous, active-high reset
    input  wire [7:0] A,
    input  wire [7:0] B,
    input  wire       Cin,
    output reg  [7:0] Sum_q,
    output reg        Cout_q
);

    wire [8:0] add_result;
    assign add_result = {1'b0, A} + {1'b0, B} + Cin;

    always @(posedge clk) begin
        if (rst) begin
            Sum_q  <= 8'b00000000;
            Cout_q <= 1'b0;
        end else begin
            Sum_q  <= add_result[7:0];
            Cout_q <= add_result[8];
        end
    end

endmodule
