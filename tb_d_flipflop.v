`timescale 1ns/1ps

module tb_d_flipflop;

reg D, clk, rst;
wire Q;

d_flipflop uut (
    .D(D),
    .clk(clk),
    .rst(rst),
    .Q(Q)
);

always #5 clk = ~clk;

initial begin
    clk = 0;
    rst = 1;
    D = 0;

    #10 rst = 0;
    #10 D = 1;
    #10 D = 0;
    #10 D = 1;
    #10 D = 1;
    #10 D = 0;

    #10 $finish;
end

initial begin
    $monitor("Time=%0t | D=%b | clk=%b | rst=%b | Q=%b",
             $time, D, clk, rst, Q);
end

endmodule
