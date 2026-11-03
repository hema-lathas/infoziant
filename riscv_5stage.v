`timescale 1ns/1ps

// Beginner-friendly 32-bit RISC-V subset, 5 pipeline stages:
//   Stage 1: IF  - Instruction Fetch
//   Stage 2: ID  - Instruction Decode + Register File read
//   Stage 3: EX  - Execute (ALU, branch compare, branch target)
//   Stage 4: MEM - Data Memory access (LW read / SW write)
//   Stage 5: WB  - Write Back to register file
//
// Supported: ADD, SUB, AND, OR, ADDI, LW, SW, BEQ
// Separate instruction and data memories.
//
// Hazard handling (needed because 5 stages overlap 5 instructions):
//   * Data forwarding   : EX/MEM -> EX and MEM/WB -> EX  (fixes RAW hazards)
//   * Register bypass   : WB -> ID (write and read same register, same cycle)
//   * Load-use stall    : 1-cycle bubble when an instruction needs a LW result
//   * Branch flush      : BEQ resolved in EX; the 2 wrong-path instructions
//                         behind it are turned into bubbles (NOPs)

module riscv_5stage (
    input wire clk,
    input wire reset
);

    localparam [31:0] NOP = 32'h00000013; // ADDI x0,x0,0

    // ALU control codes
    localparam [2:0] ALU_ADD = 3'd0,
                     ALU_SUB = 3'd1,
                     ALU_AND = 3'd2,
                     ALU_OR  = 3'd3;

    // ------------------------------------------------------------------
    // Architectural state
    // ------------------------------------------------------------------
    reg [31:0] pc;
    reg [31:0] instruction_mem [0:63];
    reg [31:0] data_mem        [0:63];
    reg [31:0] registers       [0:31];

    // ------------------------------------------------------------------
    // Pipeline registers
    // ------------------------------------------------------------------
    // IF/ID
    reg [31:0] if_id_instruction;
    reg [31:0] if_id_pc;

    // ID/EX
    reg [31:0] id_ex_pc;
    reg [31:0] id_ex_read_data1;
    reg [31:0] id_ex_read_data2;
    reg [31:0] id_ex_imm;
    reg [4:0]  id_ex_rs1;
    reg [4:0]  id_ex_rs2;
    reg [4:0]  id_ex_rd;
    reg [2:0]  id_ex_alu_ctrl;
    reg        id_ex_alu_src;     // 1 = use immediate as ALU operand B
    reg        id_ex_reg_write;
    reg        id_ex_mem_read;
    reg        id_ex_mem_write;
    reg        id_ex_mem_to_reg;
    reg        id_ex_branch;

    // EX/MEM
    reg [31:0] ex_mem_alu_result;
    reg [31:0] ex_mem_store_data;
    reg [4:0]  ex_mem_rd;
    reg        ex_mem_reg_write;
    reg        ex_mem_mem_read;
    reg        ex_mem_mem_write;
    reg        ex_mem_mem_to_reg;

    // MEM/WB
    reg [31:0] mem_wb_alu_result;
    reg [31:0] mem_wb_mem_data;
    reg [4:0]  mem_wb_rd;
    reg        mem_wb_reg_write;
    reg        mem_wb_mem_to_reg;

    // ==================================================================
    // STAGE 5 (WB) value - defined first because ID and EX use it
    // ==================================================================
    wire [31:0] wb_data = mem_wb_mem_to_reg ? mem_wb_mem_data
                                            : mem_wb_alu_result;

    // ==================================================================
    // STAGE 2: ID - decode + register read
    // ==================================================================
    wire [6:0] opcode = if_id_instruction[6:0];
    wire [4:0] rd     = if_id_instruction[11:7];
    wire [2:0] funct3 = if_id_instruction[14:12];
    wire [4:0] rs1    = if_id_instruction[19:15];
    wire [4:0] rs2    = if_id_instruction[24:20];
    wire [6:0] funct7 = if_id_instruction[31:25];

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

    // Register read with x0 = 0 and WB->ID bypass
    // (if WB is writing the register we are reading right now, take the
    //  new value instead of the stale one in the register file)
    wire [31:0] read_data1 =
        (rs1 == 5'd0) ? 32'd0 :
        (mem_wb_reg_write && mem_wb_rd == rs1) ? wb_data : registers[rs1];

    wire [31:0] read_data2 =
        (rs2 == 5'd0) ? 32'd0 :
        (mem_wb_reg_write && mem_wb_rd == rs2) ? wb_data : registers[rs2];

    // Control signals generated in ID
    reg [31:0] id_imm;
    reg [2:0]  id_alu_ctrl;
    reg        id_alu_src;
    reg        id_reg_write;
    reg        id_mem_read;
    reg        id_mem_write;
    reg        id_mem_to_reg;
    reg        id_branch;
    reg        id_uses_rs1;
    reg        id_uses_rs2;

    always @(*) begin
        id_imm        = 32'd0;
        id_alu_ctrl   = ALU_ADD;
        id_alu_src    = 1'b0;
        id_reg_write  = 1'b0;
        id_mem_read   = 1'b0;
        id_mem_write  = 1'b0;
        id_mem_to_reg = 1'b0;
        id_branch     = 1'b0;
        id_uses_rs1   = 1'b0;
        id_uses_rs2   = 1'b0;

        case (opcode)
            7'b0110011: begin // R-type: ADD SUB AND OR
                id_uses_rs1  = 1'b1;
                id_uses_rs2  = 1'b1;
                id_reg_write = 1'b1;
                case (funct3)
                    3'b000: id_alu_ctrl = (funct7 == 7'b0100000) ? ALU_SUB
                                                                 : ALU_ADD;
                    3'b111: id_alu_ctrl = ALU_AND;
                    3'b110: id_alu_ctrl = ALU_OR;
                    default: id_reg_write = 1'b0; // unsupported
                endcase
            end

            7'b0010011: begin // ADDI
                if (funct3 == 3'b000) begin
                    id_uses_rs1  = 1'b1;
                    id_imm       = imm_i;
                    id_alu_src   = 1'b1;
                    id_reg_write = 1'b1;
                end
            end

            7'b0000011: begin // LW
                if (funct3 == 3'b010) begin
                    id_uses_rs1   = 1'b1;
                    id_imm        = imm_i;
                    id_alu_src    = 1'b1;
                    id_reg_write  = 1'b1;
                    id_mem_read   = 1'b1;
                    id_mem_to_reg = 1'b1;
                end
            end

            7'b0100011: begin // SW
                if (funct3 == 3'b010) begin
                    id_uses_rs1   = 1'b1;
                    id_uses_rs2   = 1'b1;
                    id_imm        = imm_s;
                    id_alu_src    = 1'b1;
                    id_mem_write  = 1'b1;
                end
            end

            7'b1100011: begin // BEQ
                if (funct3 == 3'b000) begin
                    id_uses_rs1 = 1'b1;
                    id_uses_rs2 = 1'b1;
                    id_imm      = imm_b;
                    id_branch   = 1'b1;
                end
            end

            default: begin
                // NOP or unsupported instruction: all controls stay 0
            end
        endcase
    end

    // ==================================================================
    // STAGE 3: EX - forwarding, ALU, branch decision
    // ==================================================================
    // Forwarding unit
    //   2'b00 = value read in ID (no hazard)
    //   2'b10 = from EX/MEM  (instruction one ahead)
    //   2'b01 = from MEM/WB  (instruction two ahead)
    wire fwd_a_from_mem = ex_mem_reg_write && (ex_mem_rd != 5'd0) &&
                          (ex_mem_rd == id_ex_rs1);
    wire fwd_a_from_wb  = mem_wb_reg_write && (mem_wb_rd != 5'd0) &&
                          (mem_wb_rd == id_ex_rs1);
    wire fwd_b_from_mem = ex_mem_reg_write && (ex_mem_rd != 5'd0) &&
                          (ex_mem_rd == id_ex_rs2);
    wire fwd_b_from_wb  = mem_wb_reg_write && (mem_wb_rd != 5'd0) &&
                          (mem_wb_rd == id_ex_rs2);

    // The newest producer wins (EX/MEM is newer than MEM/WB)
    wire [31:0] fwd_data1 = fwd_a_from_mem ? ex_mem_alu_result :
                            fwd_a_from_wb  ? wb_data           :
                                             id_ex_read_data1;

    wire [31:0] fwd_data2 = fwd_b_from_mem ? ex_mem_alu_result :
                            fwd_b_from_wb  ? wb_data           :
                                             id_ex_read_data2;

    wire [31:0] alu_in_a = fwd_data1;
    wire [31:0] alu_in_b = id_ex_alu_src ? id_ex_imm : fwd_data2;

    reg [31:0] alu_result;
    always @(*) begin
        case (id_ex_alu_ctrl)
            ALU_ADD: alu_result = alu_in_a + alu_in_b;
            ALU_SUB: alu_result = alu_in_a - alu_in_b;
            ALU_AND: alu_result = alu_in_a & alu_in_b;
            ALU_OR:  alu_result = alu_in_a | alu_in_b;
            default: alu_result = 32'd0;
        endcase
    end

    // Branch resolved in EX (uses forwarded operands)
    wire        branch_taken  = id_ex_branch && (fwd_data1 == fwd_data2);
    wire [31:0] branch_target = id_ex_pc + id_ex_imm;

    // ==================================================================
    // STAGE 4: MEM - data memory
    // ==================================================================
    wire [31:0] mem_read_data = ex_mem_mem_read
                              ? data_mem[ex_mem_alu_result[7:2]]
                              : 32'd0;

    // ==================================================================
    // Hazard detection: load-use stall
    // ==================================================================
    // If the instruction in EX is a LW whose destination is needed by the
    // instruction now in ID, the data is not ready yet. Hold PC and IF/ID
    // for one cycle and insert a bubble into EX.
    wire load_use_stall = id_ex_mem_read && (id_ex_rd != 5'd0) &&
                          ((id_uses_rs1 && id_ex_rd == rs1) ||
                           (id_uses_rs2 && id_ex_rd == rs2));

    // ==================================================================
    // Pipeline register updates
    // ==================================================================
    integer i;
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            pc <= 32'd0;

            if_id_instruction <= NOP;
            if_id_pc          <= 32'd0;

            id_ex_pc          <= 32'd0;
            id_ex_read_data1  <= 32'd0;
            id_ex_read_data2  <= 32'd0;
            id_ex_imm         <= 32'd0;
            id_ex_rs1         <= 5'd0;
            id_ex_rs2         <= 5'd0;
            id_ex_rd          <= 5'd0;
            id_ex_alu_ctrl    <= ALU_ADD;
            id_ex_alu_src     <= 1'b0;
            id_ex_reg_write   <= 1'b0;
            id_ex_mem_read    <= 1'b0;
            id_ex_mem_write   <= 1'b0;
            id_ex_mem_to_reg  <= 1'b0;
            id_ex_branch      <= 1'b0;

            ex_mem_alu_result <= 32'd0;
            ex_mem_store_data <= 32'd0;
            ex_mem_rd         <= 5'd0;
            ex_mem_reg_write  <= 1'b0;
            ex_mem_mem_read   <= 1'b0;
            ex_mem_mem_write  <= 1'b0;
            ex_mem_mem_to_reg <= 1'b0;

            mem_wb_alu_result <= 32'd0;
            mem_wb_mem_data   <= 32'd0;
            mem_wb_rd         <= 5'd0;
            mem_wb_reg_write  <= 1'b0;
            mem_wb_mem_to_reg <= 1'b0;

            for (i = 0; i < 32; i = i + 1)
                registers[i] <= 32'd0;
        end else begin

            // ---------------- STAGE 5: WB ----------------
            if (mem_wb_reg_write && (mem_wb_rd != 5'd0))
                registers[mem_wb_rd] <= wb_data;

            // ---------------- STAGE 4: MEM -> MEM/WB ----------------
            if (ex_mem_mem_write)
                data_mem[ex_mem_alu_result[7:2]] <= ex_mem_store_data;

            mem_wb_alu_result <= ex_mem_alu_result;
            mem_wb_mem_data   <= mem_read_data;
            mem_wb_rd         <= ex_mem_rd;
            mem_wb_reg_write  <= ex_mem_reg_write;
            mem_wb_mem_to_reg <= ex_mem_mem_to_reg;

            // ---------------- STAGE 3: EX -> EX/MEM ----------------
            ex_mem_alu_result <= alu_result;
            ex_mem_store_data <= fwd_data2;   // forwarded value for SW
            ex_mem_rd         <= id_ex_rd;
            ex_mem_reg_write  <= id_ex_reg_write;
            ex_mem_mem_read   <= id_ex_mem_read;
            ex_mem_mem_write  <= id_ex_mem_write;
            ex_mem_mem_to_reg <= id_ex_mem_to_reg;

            // ---------------- STAGE 2: ID -> ID/EX ----------------
            if (branch_taken || load_use_stall) begin
                // Insert a bubble (all control signals off)
                id_ex_pc         <= 32'd0;
                id_ex_read_data1 <= 32'd0;
                id_ex_read_data2 <= 32'd0;
                id_ex_imm        <= 32'd0;
                id_ex_rs1        <= 5'd0;
                id_ex_rs2        <= 5'd0;
                id_ex_rd         <= 5'd0;
                id_ex_alu_ctrl   <= ALU_ADD;
                id_ex_alu_src    <= 1'b0;
                id_ex_reg_write  <= 1'b0;
                id_ex_mem_read   <= 1'b0;
                id_ex_mem_write  <= 1'b0;
                id_ex_mem_to_reg <= 1'b0;
                id_ex_branch     <= 1'b0;
            end else begin
                id_ex_pc         <= if_id_pc;
                id_ex_read_data1 <= read_data1;
                id_ex_read_data2 <= read_data2;
                id_ex_imm        <= id_imm;
                id_ex_rs1        <= rs1;
                id_ex_rs2        <= rs2;
                id_ex_rd         <= rd;
                id_ex_alu_ctrl   <= id_alu_ctrl;
                id_ex_alu_src    <= id_alu_src;
                id_ex_reg_write  <= id_reg_write;
                id_ex_mem_read   <= id_mem_read;
                id_ex_mem_write  <= id_mem_write;
                id_ex_mem_to_reg <= id_mem_to_reg;
                id_ex_branch     <= id_branch;
            end

            // ---------------- STAGE 1: IF -> IF/ID, PC ----------------
            if (branch_taken) begin
                // Redirect PC; flush the instruction fetched this cycle.
                // (The instruction in ID was already turned into a bubble above.)
                pc                <= branch_target;
                if_id_instruction <= NOP;
                if_id_pc          <= branch_target;
            end else if (load_use_stall) begin
                // Freeze PC and IF/ID: the same instruction is decoded again
            end else begin
                if_id_instruction <= instruction_mem[pc[7:2]];
                if_id_pc          <= pc;
                pc                <= pc + 32'd4;
            end
        end
    end

endmodule
