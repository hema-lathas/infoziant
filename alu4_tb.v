`timescale 1ns/1ps

module alu4_tb;

reg [3:0] A;
reg [3:0] B;
reg [2:0] opcode;

wire [3:0] result;
wire       carry_borrow;
wire       zero;

alu4 uut (
    .A(A),
    .B(B),
    .opcode(opcode),
    .result(result),
    .carry_borrow(carry_borrow),
    .zero(zero)
);

initial begin

    $display("==============================================");
    $display("        4-BIT ALU SIMULATION");
    $display("==============================================");
    $display("Time   A     B     OP      Result   Carry/Borrow Zero");
    $display("------------------------------------------------------");

    $monitor("%4t   %b   %b    %b      %b          %b        %b",
             $time, A, B, opcode, result, carry_borrow, zero);

    // ADD: 5 + 3 = 8
    A = 4'b0101;
    B = 4'b0011;
    opcode = 3'b000;
    #20;

    // ADD: 15 + 1 = 0 with carry
    A = 4'b1111;
    B = 4'b0001;
    opcode = 3'b000;
    #20;

    // SUB: 5 - 3 = 2
    A = 4'b0101;
    B = 4'b0011;
    opcode = 3'b001;
    #20;

    // SUB: 3 - 5 = 14
    A = 4'b0011;
    B = 4'b0101;
    opcode = 3'b001;
    #20;

    // AND: 5 & 3 = 1
    A = 4'b0101;
    B = 4'b0011;
    opcode = 3'b010;
    #20;

    // OR: 5 | 3 = 7
    A = 4'b0101;
    B = 4'b0011;
    opcode = 3'b011;
    #20;

    // XOR: 5 ^ 3 = 6
    A = 4'b0101;
    B = 4'b0011;
    opcode = 3'b100;
    #20;

    // Zero result demonstration
    A = 4'b0101;
    B = 4'b0101;
    opcode = 3'b001;
    #20;

    $display("==============================================");
    $display("        SIMULATION COMPLETED");
    $display("==============================================");

   

end

endmodule