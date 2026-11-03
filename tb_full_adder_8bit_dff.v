`timescale 1ns/1ps

module tb_full_adder_8bit_dff;

    reg clk, rst;
    reg [7:0] A, B;
    reg Cin;
    wire [7:0] Sum_q;
    wire Cout_q;

    full_adder_8bit_dff dut (
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

        A = 8'd3;   B = 8'd5;  Cin = 0; #10;
        A = 8'd255; B = 8'd1;  Cin = 0; #10;
        A = 8'd100; B = 8'd50; Cin = 1; #10;
        A = 8'd25;  B = 8'd10; Cin = 0; #10;

        $finish;
    end

endmodule
