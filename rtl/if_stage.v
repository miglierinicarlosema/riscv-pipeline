`timescale 1ns / 1ps
// =============================================================================
// if_stage.v - Etapa IF completa: PC + memoria de instrucciones + IF/ID
// -----------------------------------------------------------------------------
// Señales de control:
// - i_en      : enable GLOBAL, lo maneja la Debug Unit.
//               Continuo = 1 hasta el HALT; paso a paso = 1 durante 1 ciclo.
// - i_stall   : de la unidad de riesgos (load-use). Por ahora en 0.
// - i_flush   : anula la instrucción en IF/ID (salto tomado). Por ahora en 0.
// - i_pc_src / i_pc_target : salto tomado y su destino. Por ahora en 0.
//
// PC e IF/ID avanzan solo si (i_en && !i_stall). Nunca se toca el clock.
// =============================================================================
module if_stage #(
    parameter NB_DATA   = 32,      // ancho del PC
    parameter DEPTH     = 256,
    parameter INIT_FILE = ""
)(
    input  wire                     i_clk,
    input  wire                     i_rst,
    // Control
    input  wire                     i_en,
    input  wire                     i_stall,
    input  wire                     i_flush,
    input  wire                     i_pc_src,
    input  wire [NB_DATA-1:0]       i_pc_target,
    // Puerto de escritura de la memoria de programa (Debug Unit)
    input  wire                     i_imem_we,
    input  wire [$clog2(DEPTH)-1:0] i_imem_waddr,
    input  wire [31:0]              i_imem_wdata,
    // Salidas hacia ID (contenido del latch IF/ID)
    output wire [NB_DATA-1:0]       o_ifid_pc,
    output wire [NB_DATA-1:0]       o_ifid_pc_plus4,
    output wire [31:0]              o_ifid_instr,
    // Para la Debug Unit
    output wire [NB_DATA-1:0]       o_pc
);

    wire        advance = i_en & ~i_stall;
    wire [NB_DATA-1:0] pc_plus4;
    wire [31:0] instr;

    pc #(
        .NB_DATA     (NB_DATA)
    ) u_pc (
        .i_clk         (i_clk),
        .i_rst         (i_rst),
        .i_en        (advance),
        .i_pc_src    (i_pc_src),
        .i_pc_target (i_pc_target),
        .o_pc        (o_pc),
        .o_pc_plus4  (pc_plus4)
    );

    instr_mem #(
        .DEPTH     (DEPTH),
        .INIT_FILE (INIT_FILE)
    ) u_imem (
        .i_clk       (i_clk),
        .i_rd_addr (o_pc),
        .o_rd_data (instr),
        .i_we      (i_imem_we),
        .i_wr_addr (i_imem_waddr),
        .i_wr_data (i_imem_wdata)
    );

    if_id #(
        .NB_DATA    (NB_DATA)
    ) u_if_id (
        .i_clk        (i_clk),
        .i_rst        (i_rst),
        .i_en       (advance),
        .i_flush    (i_flush),
        .i_pc       (o_pc),
        .i_pc_plus4 (pc_plus4),
        .i_instr    (instr),
        .o_pc       (o_ifid_pc),
        .o_pc_plus4 (o_ifid_pc_plus4),
        .o_instr    (o_ifid_instr)
    );

endmodule
