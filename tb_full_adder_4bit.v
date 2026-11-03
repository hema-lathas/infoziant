`timescale 1ns/1ps

module tb_full_adder_4bit;

    reg  [3:0] A, B;
    reg        Cin;
    wire [3:0] Sum;
    wire       Cout;

    integer i, j, k;
    reg [4:0] expected;

    full_adder_4bit uut (
        .A(A),
        .B(B),
        .Cin(Cin),
        .Sum(Sum),
        .Cout(Cout)
    );

    initial begin
        $dumpfile("full_adder_4bit.vcd");
        $dumpvars(0, tb_full_adder_4bit);

        // Test every possible input combination: 16 x 16 x 2 = 512 tests
        for (i = 0; i < 16; i = i + 1) begin
            for (j = 0; j < 16; j = j + 1) begin
                for (k = 0; k < 2; k = k + 1) begin
                    A = i;
                    B = j;
                    Cin = k;
                    expected = i + j + k;
                    #10;

                    if ({Cout, Sum} !== expected) begin
                        $display("FAIL: A=%b B=%b Cin=%b | got Cout=%b Sum=%b, expected=%b",
                                 A, B, Cin, Cout, Sum, expected);
                        $finish;
                    end
                end
            end
        end

        $display("PASS: All 512 test cases passed.");
        $finish;
    end

endmodule
