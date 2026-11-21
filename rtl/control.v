`timescale 1ns / 1ps
// =============================================================================
// control.v - Unidad de control principal (RV32I)
// -----------------------------------------------------------------------------
// Mira el opcode de la instrucción y genera las señales de control que viajan
// por los latches hasta EX, MEM y WB. Es la "tabla principal" del documento
// "Etapa ID - Tabla de señales de control", traducida a un case.
//
// Señales:
//   reg_write   1 = se escribe rd en WB
//   wb_sel      00 = ALU, 01 = memoria, 10 = PC+4
//   mem_read    1 = load
//   mem_write   1 = store
//   alu_src_a   0 = rs1, 1 = cero (lui)
//   alu_src_b   0 = rs2, 1 = inmediato
//   alu_op      00 = suma, 01 = resta (branches), 10 = tipo R, 11 = tipo I
//   branch      1 = beq / bne
//   jump        1 = jal / jalr
//   jalr        1 = destino rs1 + imm (si no, PC + imm)
//   imm_sel     000 = I, 001 = S, 010 = B, 011 = U, 100 = J (igual que imm_gen)
//   uses_rs1/2  1 = la instrucción lee rs1 / rs2 (para riesgos y forwarding)
//   halt        1 = instrucción HALT (0xFFFFFFFF)
//
// Decisiones de diseño:
// - Control en dos niveles: acá solo el opcode; la operación exacta de la ALU
//   la decide alu_control (en EX) con alu_op + funct3 + bit 30.
// - Toda señal tiene valor por defecto 0 al principio del always: una
//   instrucción inválida se comporta como NOP y no se infieren latches.
// - HALT se detecta comparando la instrucción COMPLETA con 0xFFFFFFFF.
//   Una instrucción con opcode 1111111 pero otros bits es inválida (NOP).
// - El nombre y los códigos de imm_sel tienen que coincidir con imm_gen.v.
// =============================================================================
module control (
    input  wire [31:0] i_instr,
    output reg         o_reg_write,
    output reg  [1:0]  o_wb_sel,
    output reg         o_mem_read,
    output reg         o_mem_write,
    output reg         o_alu_src_a,
    output reg         o_alu_src_b,
    output reg  [1:0]  o_alu_op,
    output reg         o_branch,
    output reg         o_jump,
    output reg         o_jalr,
    output reg  [2:0]  o_imm_sel,
    output reg         o_uses_rs1,
    output reg         o_uses_rs2,
    output reg         o_halt
);

    // Opcodes RV32I usados en el TP
    localparam OP_R      = 7'b0110011;
    localparam OP_I_ALU  = 7'b0010011;
    localparam OP_LOAD   = 7'b0000011;
    localparam OP_STORE  = 7'b0100011;
    localparam OP_BRANCH = 7'b1100011;
    localparam OP_JAL    = 7'b1101111;
    localparam OP_JALR   = 7'b1100111;
    localparam OP_LUI    = 7'b0110111;

    localparam HALT_INSTR = 32'hFFFF_FFFF;

    // wb_sel
    localparam WB_ALU = 2'b00;
    localparam WB_MEM = 2'b01;
    localparam WB_PC4 = 2'b10;

    // alu_op
    localparam ALUOP_ADD = 2'b00;
    localparam ALUOP_SUB = 2'b01;
    localparam ALUOP_R   = 2'b10;
    localparam ALUOP_I   = 2'b11;

    // imm_sel (mismos códigos que imm_gen.v)
    localparam IMM_I = 3'b000;
    localparam IMM_S = 3'b001;
    localparam IMM_B = 3'b010;
    localparam IMM_U = 3'b011;
    localparam IMM_J = 3'b100;

    wire [6:0] opcode = i_instr[6:0];

    always @(*) begin
        // Valores por defecto: todo en 0 (instrucción inválida = NOP)
        o_reg_write = 1'b0;
        o_wb_sel    = WB_ALU;
        o_mem_read  = 1'b0;
        o_mem_write = 1'b0;
        o_alu_src_a = 1'b0;
        o_alu_src_b = 1'b0;
        o_alu_op    = ALUOP_ADD;
        o_branch    = 1'b0;
        o_jump      = 1'b0;
        o_jalr      = 1'b0;
        o_imm_sel   = IMM_I;
        o_uses_rs1  = 1'b0;
        o_uses_rs2  = 1'b0;
        o_halt      = 1'b0;

        if (i_instr == HALT_INSTR) begin
            o_halt = 1'b1;
        end else begin
            case (opcode)
                OP_R: begin             // add sub sll srl sra and or xor slt sltu
                    o_reg_write = 1'b1;
                    o_wb_sel    = WB_ALU;
                    o_alu_op    = ALUOP_R;
                    o_uses_rs1  = 1'b1;
                    o_uses_rs2  = 1'b1;
                end
                OP_I_ALU: begin         // addi andi ori xori slti sltiu slli srli srai
                    o_reg_write = 1'b1;
                    o_wb_sel    = WB_ALU;
                    o_alu_src_b = 1'b1;
                    o_alu_op    = ALUOP_I;
                    o_imm_sel   = IMM_I;
                    o_uses_rs1  = 1'b1;
                end
                OP_LOAD: begin          // lb lh lw lbu lhu
                    o_reg_write = 1'b1;
                    o_wb_sel    = WB_MEM;
                    o_mem_read  = 1'b1;
                    o_alu_src_b = 1'b1;
                    o_alu_op    = ALUOP_ADD;
                    o_imm_sel   = IMM_I;
                    o_uses_rs1  = 1'b1;
                end
                OP_STORE: begin         // sb sh sw
                    o_mem_write = 1'b1;
                    o_alu_src_b = 1'b1;
                    o_alu_op    = ALUOP_ADD;
                    o_imm_sel   = IMM_S;
                    o_uses_rs1  = 1'b1;
                    o_uses_rs2  = 1'b1;
                end
                OP_BRANCH: begin        // beq bne
                    o_branch    = 1'b1;
                    o_alu_op    = ALUOP_SUB;
                    o_imm_sel   = IMM_B;
                    o_uses_rs1  = 1'b1;
                    o_uses_rs2  = 1'b1;
                end
                OP_JAL: begin           // jal
                    o_reg_write = 1'b1;
                    o_wb_sel    = WB_PC4;
                    o_jump      = 1'b1;
                    o_imm_sel   = IMM_J;
                end
                OP_JALR: begin          // jalr
                    o_reg_write = 1'b1;
                    o_wb_sel    = WB_PC4;
                    o_alu_src_b = 1'b1;
                    o_alu_op    = ALUOP_ADD;
                    o_jump      = 1'b1;
                    o_jalr      = 1'b1;
                    o_imm_sel   = IMM_I;
                    o_uses_rs1  = 1'b1;
                end
                OP_LUI: begin           // lui
                    o_reg_write = 1'b1;
                    o_wb_sel    = WB_ALU;
                    o_alu_src_a = 1'b1;
                    o_alu_src_b = 1'b1;
                    o_alu_op    = ALUOP_ADD;
                    o_imm_sel   = IMM_U;
                end
                default: ;              // inválida: quedan los valores por defecto
            endcase
        end
    end

endmodule
