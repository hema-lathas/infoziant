`timescale 1ns/1ps

// Beginner-friendly 32-bit RISC-V subset, 2 pipeline stages:
// Stage 1: Instruction Fetch (IF)
// Stage 2: Decode, Execute, Memory Access and Write Back (EX)
//
// Supported: ADD, SUB, AND, OR, ADDI, LW, SW, BEQ
// Separate instruction and data memories.
// No forwarding or hazard unit is included.

module riscv_2stage (
    input wire clk,
    input wire reset
);

    reg [31:0] pc;
    reg [31:0] instruction_mem [0:63];
    reg [31:0] data_mem        [0:63];
    reg [31:0] registers       [0:31];

    // Pipeline register between IF and EX
    reg [31:0] if_id_instruction;
    reg [31:0] if_id_pc;

    wire [6:0] opcode = if_id_instruction[6:0];
    wire [4:0] rd     = if_id_instruction[11:7];
    wire [2:0] funct3 = if_id_instruction[14:12];
    wire [4:0] rs1    = if_id_instruction[19:15];
    wire [4:0] rs2    = if_id_instruction[24:20];
    wire [6:0] funct7 = if_id_instruction[31:25];

    wire [31:0] read_data1 = (rs1 == 0) ? 32'd0 : registers[rs1];
    wire [31:0] read_data2 = (rs2 == 0) ? 32'd0 : registers[rs2];

    wire [31:0] imm_i = {{20{if_id_instruction[31]}},
                          if_id_instruction[31:20]};

    wire [31:0] imm_s = {{20{if_id_instruction[31]}},
                          if_id_instruction[31:25],
                          if_id_instruction[11:7]};

    wire [31:0] imm_b = {{19{if_id_instruction[31]}},
                          if_id_instruction[31],
                          if_id_instruction[7],
                          if_id_instruction[30:25],
                          if_id_instruction[11:8],
                          1'b0};

    reg [31:0] alu_result;
    reg [31:0] write_data;
    reg        reg_write;
    reg        mem_write;
    reg        mem_read;
    reg        branch_taken;
    reg [31:0] branch_target;

    // Combinational instruction decode and ALU
    always @(*) begin
        alu_result   = 32'd0;
        write_data   = 32'd0;
        reg_write    = 1'b0;
        mem_write    = 1'b0;
        mem_read     = 1'b0;
        branch_taken = 1'b0;
        branch_target = if_id_pc + imm_b;

        case (opcode)
            7'b0110011: begin // R-type
                reg_write = 1'b1;
                case (funct3)
                    3'b000: begin
                        if (funct7 == 7'b0100000)
                            alu_result = read_data1 - read_data2; // SUB
                        else
                            alu_result = read_data1 + read_data2; // ADD
                    end
                    3'b111: alu_result = read_data1 & read_data2; // AND
                    3'b110: alu_result = read_data1 | read_data2; // OR
                    default: begin
                        alu_result = 32'd0;
                        reg_write = 1'b0;
                    end
                endcase
                write_data = alu_result;
            end

            7'b0010011: begin // ADDI
                if (funct3 == 3'b000) begin
                    alu_result = read_data1 + imm_i;
                    write_data = alu_result;
                    reg_write = 1'b1;
                end
            end

            7'b0000011: begin // LW
                if (funct3 == 3'b010) begin
                    alu_result = read_data1 + imm_i;
                    mem_read = 1'b1;
                    reg_write = 1'b1;
                    write_data = data_mem[alu_result[7:2]];
                end
            end

            7'b0100011: begin // SW
                if (funct3 == 3'b010) begin
                    alu_result = read_data1 + imm_s;
                    mem_write = 1'b1;
                end
            end

            7'b1100011: begin // BEQ
                if (funct3 == 3'b000) begin
                    branch_taken = (read_data1 == read_data2);
                    branch_target = if_id_pc + imm_b;
                end
            end

            default: begin
                // NOP or unsupported instruction
            end
        endcase
    end

    integer i;
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            pc <= 32'd0;
            if_id_instruction <= 32'h00000013; // ADDI x0,x0,0 (NOP)
            if_id_pc <= 32'd0;
            for (i = 0; i < 32; i = i + 1)
                registers[i] <= 32'd0;
        end else begin
            // Stage 2: memory write and register writeback
            if (mem_write)
                data_mem[alu_result[7:2]] <= read_data2;

            if (reg_write && (rd != 0))
                registers[rd] <= write_data;

            registers[0] <= 32'd0;

            // Stage 1: fetch next instruction.
            // If a branch is taken, discard the wrongly fetched instruction.
            if (branch_taken) begin
                pc <= branch_target;
                if_id_instruction <= 32'h00000013; // flush with NOP
                if_id_pc <= branch_target;
            end else begin
                if_id_instruction <= instruction_mem[pc[7:2]];
                if_id_pc <= pc;
                pc <= pc + 32'd4;
            end
        end
    end

endmodule
