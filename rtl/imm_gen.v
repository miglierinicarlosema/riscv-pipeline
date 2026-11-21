`timescale 1ns / 1ps
// =============================================================================
// imm_gen.v - Generador de inmediatos (RV32I)
// -----------------------------------------------------------------------------
// Arma el inmediato de 32 bits según el formato que indica i_imm_sel
// (lo genera la unidad de control a partir del opcode).
//
//   i_imm_sel | Formato | Usado por
//   ----------+---------+-----------------------------------------
//      000    |    I    | tipo I aritméticas, loads, jalr
//      001    |    S    | stores
//      010    |    B    | beq, bne
//      011    |    U    | lui
//      100    |    J    | jal
//   otro      |    -    | 0
//
// Decisiones de diseño:
// - El signo es siempre el bit 31 de la instrucción, en todos los formatos.
// - En B y J el bit 0 vale 0 (los saltos son a direcciones pares).
// - Solo recibe los bits [31:7] de la instrucción: los bits [6:0] son el
//   opcode y no forman parte de ningún inmediato.
// - Es combinacional (sin clock): el inmediato sale en el mismo ciclo, en ID.
// - Los códigos de i_imm_sel tienen que coincidir con los de control.v.
// =============================================================================
module imm_gen (
    input  wire [31:7] i_instr,     // instrucción sin el opcode
    input  wire [2:0]  i_imm_sel,
    output reg  [31:0] o_imm
);

    localparam IMM_I = 3'b000;
    localparam IMM_S = 3'b001;
    localparam IMM_B = 3'b010;
    localparam IMM_U = 3'b011;
    localparam IMM_J = 3'b100;

    always @(*) begin
        case (i_imm_sel)
            IMM_I:   o_imm = {{20{i_instr[31]}}, i_instr[31:20]};
            IMM_S:   o_imm = {{20{i_instr[31]}}, i_instr[31:25], i_instr[11:7]};
            IMM_B:   o_imm = {{19{i_instr[31]}}, i_instr[31], i_instr[7],
                              i_instr[30:25], i_instr[11:8], 1'b0};
            IMM_U:   o_imm = {i_instr[31:12], 12'b0};
            IMM_J:   o_imm = {{11{i_instr[31]}}, i_instr[31], i_instr[19:12],
                              i_instr[20], i_instr[30:21], 1'b0};
            default: o_imm = 32'd0;
        endcase
    end

endmodule
