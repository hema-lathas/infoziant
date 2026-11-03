`timescale 1ns/1ps

module tb_riscv_2stage;

    reg clk;
    reg reset;

    riscv_2stage dut (
        .clk(clk),
        .reset(reset)
    );

    always #5 clk = ~clk;

    // Encode simple RISC-V instructions for the test program
    function [31:0] enc_i;
        input integer imm;
        input integer rs1;
        input integer funct3;
        input integer rd;
        input [6:0] opcode;
        begin
            enc_i = {imm[11:0], rs1[4:0], funct3[2:0], rd[4:0], opcode};
        end
    endfunction

    function [31:0] enc_r;
        input integer funct7;
        input integer rs2;
        input integer rs1;
        input integer funct3;
        input integer rd;
        input [6:0] opcode;
        begin
            enc_r = {funct7[6:0], rs2[4:0], rs1[4:0],
                     funct3[2:0], rd[4:0], opcode};
        end
    endfunction

    function [31:0] enc_s;
        input integer imm;
        input integer rs2;
        input integer rs1;
        input integer funct3;
        input [6:0] opcode;
        begin
            enc_s = {imm[11:5], rs2[4:0], rs1[4:0],
                     funct3[2:0], imm[4:0], opcode};
        end
    endfunction

    function [31:0] enc_b;
        input integer offset;
        input integer rs2;
        input integer rs1;
        input integer funct3;
        input [6:0] opcode;
        reg [12:0] b;
        begin
            b = offset;
            enc_b = {b[12], b[10:5], rs2[4:0], rs1[4:0],
                     funct3[2:0], b[4:1], b[11], opcode};
        end
    endfunction

    integer k;

    initial begin
        clk = 0;
        reset = 1;

        // Clear memories and registers for a predictable simulation
        for (k = 0; k < 64; k = k + 1) begin
            dut.instruction_mem[k] = 32'h00000013; // NOP
            dut.data_mem[k] = 0;
        end

        // Program:
        // x1 = 5
        // x2 = 7
        // x3 = x1 + x2 = 12
        // x4 = x3 - x1 = 7
        // MEM[0] = x3
        // x5 = MEM[0] = 12
        // BEQ x4,x2,+8  (taken; skip the next instruction)
        // x6 = 99       (must be skipped)
        // x7 = 11
        dut.instruction_mem[0] = enc_i(5,  0, 0, 1, 7'b0010011);
        dut.instruction_mem[1] = enc_i(7,  0, 0, 2, 7'b0010011);
        dut.instruction_mem[2] = enc_r(0,  2, 1, 0, 3, 7'b0110011);
        dut.instruction_mem[3] = enc_r(7'b0100000, 1, 3, 0, 4, 7'b0110011);
        dut.instruction_mem[4] = enc_s(0, 3, 0, 2, 7'b0100011);
        dut.instruction_mem[5] = enc_i(0, 0, 2, 5, 7'b0000011);
        dut.instruction_mem[6] = enc_b(8, 2, 4, 0, 7'b1100011);
        dut.instruction_mem[7] = enc_i(99, 0, 0, 6, 7'b0010011);
        dut.instruction_mem[8] = enc_i(11, 0, 0, 7, 7'b0010011);

        #12;
        reset = 0;

        // Allow the program to pass through the pipeline
        repeat (18) @(posedge clk);
        #1;

        $display("--------------------------------------");
        $display("       2-Stage RISC-V Test Results");
        $display("--------------------------------------");
        $display("x1 = %0d (expected 5)",  dut.registers[1]);
        $display("x2 = %0d (expected 7)",  dut.registers[2]);
        $display("x3 = %0d (expected 12)", dut.registers[3]);
        $display("x4 = %0d (expected 7)",  dut.registers[4]);
        $display("x5 = %0d (expected 12)", dut.registers[5]);
        $display("x6 = %0d (expected 0; skipped)", dut.registers[6]);
        $display("x7 = %0d (expected 11)", dut.registers[7]);
        $display("MEM[0] = %0d (expected 12)", dut.data_mem[0]);
        $display("--------------------------------------");

        if (dut.registers[1] == 5 &&
            dut.registers[2] == 7 &&
            dut.registers[3] == 12 &&
            dut.registers[4] == 7 &&
            dut.registers[5] == 12 &&
            dut.registers[6] == 0 &&
            dut.registers[7] == 11 &&
            dut.data_mem[0] == 12)
            $display("TEST PASSED");
        else
            $display("TEST FAILED");

        $finish;
    end

endmodule
