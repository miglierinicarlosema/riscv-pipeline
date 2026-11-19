`timescale 1ns / 1ps
// =============================================================================
// if_id.v - Registro de pipeline IF/ID
// -----------------------------------------------------------------------------
// Lleva: PC de la instrucción, PC + 4 y la instrucción.
// - PC   -> lo necesita ID para calcular destinos de branch/jal (PC + imm).
// - PC+4 -> es lo que jal/jalr escriben en rd (dirección de retorno).
// - i_en = 0    -> mantiene el valor (stall, paso a paso, HALT).
// - i_flush = 1 -> carga un NOP (anula la instrucción que entró detrás de un
//                  salto tomado). RISC-V NO tiene delay slot.
//   El flush solo actúa si i_en = 1: con el procesador detenido nada cambia.
// =============================================================================
module if_id (
    input  wire        clk,
    input  wire        rst,
    input  wire        i_en,
    input  wire        i_flush,
    input  wire [31:0] i_pc,
    input  wire [31:0] i_pc_plus4,
    input  wire [31:0] i_instr,
    output reg  [31:0] o_pc,
    output reg  [31:0] o_pc_plus4,
    output reg  [31:0] o_instr
);

    localparam NOP = 32'h0000_0013;   // addi x0, x0, 0

    always @(posedge clk) begin
        if (rst) begin
            o_pc       <= 32'd0;
            o_pc_plus4 <= 32'd0;
            o_instr    <= NOP;
        end else if (i_en) begin
            if (i_flush) begin
                o_pc       <= 32'd0;
                o_pc_plus4 <= 32'd0;
                o_instr    <= NOP;
            end else begin
                o_pc       <= i_pc;
                o_pc_plus4 <= i_pc_plus4;
                o_instr    <= i_instr;
            end
        end
    end

endmodule
