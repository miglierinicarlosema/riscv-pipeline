`timescale 1ns / 1ps
// =============================================================================
// pc.v - Program Counter
// -----------------------------------------------------------------------------
// - Reset sincrónico, activo en alto (mismo criterio en TODO el diseño).
// - i_en = 0 congela el PC. Así se implementan el modo paso a paso, el stall
//   y el HALT, SIN tocar el clock (requisito de la consigna).
// - i_pc_src elige el próximo PC: 0 -> PC + 4 (secuencial)
//                                 1 -> i_pc_target (salto/branch tomado)
//   Por ahora i_pc_src queda en 0: los saltos se conectan cuando exista ID/EX.
// =============================================================================
module pc #(
    parameter NB_DATA  = 32,               // ancho del PC
    parameter RESET_PC = 32'h0000_0000     // dirección de arranque
)(
    input  wire        i_clk,
    input  wire        i_rst,
    input  wire        i_en,
    input  wire        i_pc_src,
    input  wire [NB_DATA-1:0] i_pc_target,
    output reg  [NB_DATA-1:0] o_pc,
    output wire [NB_DATA-1:0] o_pc_plus4
);

    assign o_pc_plus4 = o_pc + 4;

    always @(posedge i_clk) begin
        if (i_rst)
            o_pc <= RESET_PC[NB_DATA-1:0];
        else if (i_en)
            o_pc <= i_pc_src ? i_pc_target : o_pc_plus4;
    end

endmodule
