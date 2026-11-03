`timescale 1ns/1ps

module alu4 (
    input  [3:0] A,
    input  [3:0] B,
    input  [2:0] opcode,
    output reg [3:0] result,
    output reg       carry_borrow,
    output reg       zero
);

reg [4:0] temp;

always @(*) begin

    result = 4'b0000;
    carry_borrow = 1'b0;
    temp = 5'b00000;

    case (opcode)

        3'b000: begin
            // ADD
            temp = A + B;
            result = temp[3:0];
            carry_borrow = temp[4];
        end

        3'b001: begin
            // SUBTRACT
            result = A - B;
            carry_borrow = (A < B);
        end

        3'b010: begin
            // AND
            result = A & B;
        end

        3'b011: begin
            // OR
            result = A | B;
        end

        3'b100: begin
            // XOR
            result = A ^ B;
        end

        default: begin
            result = 4'b0000;
            carry_borrow = 1'b0;
        end

    endcase

    // Zero flag
    if (result == 4'b0000)
        zero = 1'b1;
    else
        zero = 1'b0;

end

endmodule