`timescale 1ns / 1ps
// =============================================================================
// alu_control.v - Control de la ALU (segundo nivel de control)
// -----------------------------------------------------------------------------
// Elige la operación exacta de la ALU a partir de:
//   - i_alu_op (2 bits, viene de control.v por el latch ID/EX):
//       00 = suma (loads, stores, jalr, lui)
//       01 = resta (beq, bne)
//       10 = tipo R  -> depende de funct3 y del bit 30
//       11 = tipo I  -> depende de funct3 (bit 30 solo en srli/srai)
//   - i_funct3 (bits [14:12] de la instrucción)
//   - i_funct7_b5 (bit 30 de la instrucción)
//
// Decisión importante: en tipo I (alu_op = 11) el bit 30 es parte del
// inmediato. Por eso con funct3 = 000 siempre es ADD (addi), aunque el bit 30
// valga 1 (por ejemplo addi x1, x0, -1024). Solo en funct3 = 101 se mira el
// bit 30 para distinguir srli de srai.
// Los códigos de salida tienen que coincidir con los de alu.v.
// =============================================================================
module alu_control (
    input  wire [1:0] i_alu_op,
    input  wire [2:0] i_funct3,
    input  wire       i_funct7_b5,
    output reg  [3:0] o_alu_ctrl
);

    localparam ALU_ADD  = 4'b0000;
    localparam ALU_SUB  = 4'b0001;
    localparam ALU_SLL  = 4'b0010;
    localparam ALU_SLT  = 4'b0011;
    localparam ALU_SLTU = 4'b0100;
    localparam ALU_XOR  = 4'b0101;
    localparam ALU_SRL  = 4'b0110;
    localparam ALU_SRA  = 4'b0111;
    localparam ALU_OR   = 4'b1000;
    localparam ALU_AND  = 4'b1001;

    localparam ALUOP_ADD = 2'b00;
    localparam ALUOP_SUB = 2'b01;
    localparam ALUOP_R   = 2'b10;
    localparam ALUOP_I   = 2'b11;

    // Operación según funct3 (común a tipo R y tipo I)
    reg [3:0] by_funct3;
    always @(*) begin
        case (i_funct3)
            3'b000:  by_funct3 = ALU_ADD;     // add / addi (sub se resuelve abajo)
            3'b001:  by_funct3 = ALU_SLL;     // sll / slli
            3'b010:  by_funct3 = ALU_SLT;     // slt / slti
            3'b011:  by_funct3 = ALU_SLTU;    // sltu / sltiu
            3'b100:  by_funct3 = ALU_XOR;     // xor / xori
            3'b101:  by_funct3 = i_funct7_b5 ? ALU_SRA : ALU_SRL;  // sra(i) / srl(i)
            3'b110:  by_funct3 = ALU_OR;      // or / ori
            default: by_funct3 = ALU_AND;     // 111: and / andi
        endcase
    end

    always @(*) begin
        case (i_alu_op)
            ALUOP_ADD: o_alu_ctrl = ALU_ADD;
            ALUOP_SUB: o_alu_ctrl = ALU_SUB;
            ALUOP_R:   o_alu_ctrl = (i_funct3 == 3'b000 && i_funct7_b5) ? ALU_SUB : by_funct3;
            ALUOP_I:   o_alu_ctrl = by_funct3;   // addi nunca es resta
            default:   o_alu_ctrl = ALU_ADD;     // no ocurre: los 4 valores están cubiertos
        endcase
    end

endmodule
