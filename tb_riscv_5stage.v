`timescale 1ns/1ps

module tb_riscv_5stage;

    reg clk;
    reg reset;

    riscv_5stage dut (
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
    integer errors;

    task check;
        input [255:0] name;
        input [31:0]  actual;
        input [31:0]  expected;
        begin
            if (actual === expected)
                $display("  %-8s = %0d (expected %0d)  OK", name, actual, expected);
            else begin
                $display("  %-8s = %0d (expected %0d)  <-- MISMATCH", name, actual, expected);
                errors = errors + 1;
            end
        end
    endtask

    initial begin
        clk = 0;
        reset = 1;
        errors = 0;

        for (k = 0; k < 64; k = k + 1) begin
            dut.instruction_mem[k] = 32'h00000013; // NOP
            dut.data_mem[k] = 0;
        end

        // ---------------- Test program ----------------
        // 0  addi x1,x0,5
        // 1  addi x2,x0,7
        // 2  add  x3,x1,x2     RAW: x2 from EX/MEM, x1 from MEM/WB  -> 12
        // 3  sub  x4,x3,x1     RAW: x3 from EX/MEM                  -> 7
        // 4  sw   x3,0(x0)     store data forwarded                 -> MEM[0]=12
        // 5  lw   x5,0(x0)                                          -> 12
        // 6  add  x6,x5,x1     LOAD-USE: needs 1-cycle stall        -> 17
        // 7  beq  x4,x2,+8     taken (7==7), skips instr 8
        // 8  addi x7,x0,99     must be flushed                      -> 0
        // 9  addi x8,x0,11                                          -> 11
        // 10 beq  x1,x2,+8     NOT taken (5!=7)
        // 11 addi x9,x0,22     must execute                         -> 22
        // 12 addi x10,x0,33                                         -> 33
        // 13 lw   x11,0(x0)    load then branch (load-use on BEQ)   -> 12
        // 14 beq  x11,x3,+8    taken (12==12), skips instr 15
        // 15 addi x12,x0,77    must be flushed                      -> 0
        // 16 addi x13,x0,1                                          -> 1
        dut.instruction_mem[0]  = enc_i(5,  0, 0, 1, 7'b0010011);
        dut.instruction_mem[1]  = enc_i(7,  0, 0, 2, 7'b0010011);
        dut.instruction_mem[2]  = enc_r(0,  2, 1, 0, 3, 7'b0110011);
        dut.instruction_mem[3]  = enc_r(7'b0100000, 1, 3, 0, 4, 7'b0110011);
        dut.instruction_mem[4]  = enc_s(0, 3, 0, 2, 7'b0100011);
        dut.instruction_mem[5]  = enc_i(0, 0, 2, 5, 7'b0000011);
        dut.instruction_mem[6]  = enc_r(0,  1, 5, 0, 6, 7'b0110011);
        dut.instruction_mem[7]  = enc_b(8, 2, 4, 0, 7'b1100011);
        dut.instruction_mem[8]  = enc_i(99, 0, 0, 7, 7'b0010011);
        dut.instruction_mem[9]  = enc_i(11, 0, 0, 8, 7'b0010011);
        dut.instruction_mem[10] = enc_b(8, 2, 1, 0, 7'b1100011);
        dut.instruction_mem[11] = enc_i(22, 0, 0, 9, 7'b0010011);
        dut.instruction_mem[12] = enc_i(33, 0, 0, 10, 7'b0010011);
        dut.instruction_mem[13] = enc_i(0,  0, 2, 11, 7'b0000011);
        dut.instruction_mem[14] = enc_b(8, 3, 11, 0, 7'b1100011);
        dut.instruction_mem[15] = enc_i(77, 0, 0, 12, 7'b0010011);
        dut.instruction_mem[16] = enc_i(1,  0, 0, 13, 7'b0010011);

        #12;
        reset = 0;

        // Optional pipeline trace: one line per clock cycle
        // Shows which PC is in each stage.
        $display("cycle |  IF pc | ID pc | EX pc | stall flush");
        repeat (30) begin
            @(posedge clk);
            #1;
            $display("%5d | %6d | %5d | %5d |   %b      %b",
                     ($time-12)/10, dut.pc, dut.if_id_pc, dut.id_ex_pc,
                     dut.load_use_stall, dut.branch_taken);
        end

        $display("--------------------------------------");
        $display("       5-Stage RISC-V Test Results");
        $display("--------------------------------------");
        check("x1",  dut.registers[1],  5);
        check("x2",  dut.registers[2],  7);
        check("x3",  dut.registers[3],  12);
        check("x4",  dut.registers[4],  7);
        check("x5",  dut.registers[5],  12);
        check("x6",  dut.registers[6],  17);
        check("x7",  dut.registers[7],  0);
        check("x8",  dut.registers[8],  11);
        check("x9",  dut.registers[9],  22);
        check("x10", dut.registers[10], 33);
        check("x11", dut.registers[11], 12);
        check("x12", dut.registers[12], 0);
        check("x13", dut.registers[13], 1);
        check("MEM[0]", dut.data_mem[0], 12);
        $display("--------------------------------------");

        if (errors == 0)
            $display("TEST PASSED");
        else
            $display("TEST FAILED (%0d mismatches)", errors);

        $finish;
    end

endmodule
