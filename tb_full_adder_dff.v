
`timescale 1ns/1ps

module tb_full_adder_dff;

    reg clk, rst;
    reg [3:0] A, B;
    reg Cin;

    wire [3:0] Sum_q;
    wire Cout_q;

    full_adder_dff dut (
        .clk(clk),
        .rst(rst),
        .A(A),
        .B(B),
        .Cin(Cin),
        .Sum_q(Sum_q),
        .Cout_q(Cout_q)
    );

    always #5 clk = ~clk;

    initial begin
        clk = 0;
        rst = 1;
        A = 0; B = 0; Cin = 0;

        #10 rst = 0;

        A = 4'd3; B = 4'd5; Cin = 0;
        #10;

        A = 4'd15; B = 4'd1; Cin = 0;
        #10;

        A = 4'd7; B = 4'd2; Cin = 1;
        #10;

        A = 4'd4; B = 4'd3; Cin = 0;
        #10;

        $finish;
    end

endmodule

