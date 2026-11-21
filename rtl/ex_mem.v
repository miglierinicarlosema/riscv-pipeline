`timescale 1ns / 1ps
// =============================================================================
// ex_mem.v - Registro de pipeline EX/MEM
// -----------------------------------------------------------------------------
// Lleva de EX a MEM:
//   - Señales de control para MEM y WB: reg_write, wb_sel, mem_read,
//     mem_write, halt.
//   - Resultado de la ALU: dirección de memoria (loads/stores) o valor a
//     escribir en rd (tipo R, tipo I, lui).
//   - Dato a guardar en memoria (rs2 ya con forwarding), para los stores.
//   - rd: registro destino (WB y forwarding).
//   - funct3: tamaño del acceso a memoria y extensión de signo en loads.
//   - PC+4: lo que escriben jal / jalr en rd.
//   - La instrucción completa (para que la Debug Unit la muestre).
//
// Control:
//   i_en = 0 -> mantiene el valor (paso a paso detenido, HALT).
//   No tiene flush: cuando se toma un salto, la instrucción que está en EX
//   es el propio salto, que tiene que terminar (jal/jalr escriben rd).
// Reset sincrónico, activo en alto: deja una burbuja (control en 0, NOP).
// =============================================================================
module ex_mem #(
    parameter NB_DATA = 32,   // ancho de datos y direcciones
    parameter NB_REG  = 5     // bits para numerar los registros
)(
    input  wire               i_clk,
    input  wire               i_rst,
    input  wire               i_en,
    // Control
    input  wire               i_reg_write,
    input  wire [1:0]         i_wb_sel,
    input  wire               i_mem_read,
    input  wire               i_mem_write,
    input  wire               i_halt,
    // Datos
    input  wire [NB_DATA-1:0] i_alu_result,
    input  wire [NB_DATA-1:0] i_store_data,
    input  wire [NB_REG-1:0]  i_rd_addr,
    input  wire [2:0]         i_funct3,
    input  wire [NB_DATA-1:0] i_pc_plus4,
    input  wire [31:0]        i_instr,
    // Salidas
    output reg                o_reg_write,
    output reg  [1:0]         o_wb_sel,
    output reg                o_mem_read,
    output reg                o_mem_write,
    output reg                o_halt,
    output reg  [NB_DATA-1:0] o_alu_result,
    output reg  [NB_DATA-1:0] o_store_data,
    output reg  [NB_REG-1:0]  o_rd_addr,
    output reg  [2:0]         o_funct3,
    output reg  [NB_DATA-1:0] o_pc_plus4,
    output reg  [31:0]        o_instr
);

    localparam NOP = 32'h0000_0013;   // addi x0, x0, 0

    always @(posedge i_clk) begin
        if (i_rst) begin
            o_reg_write  <= 1'b0;   o_wb_sel    <= 2'b00;
            o_mem_read   <= 1'b0;   o_mem_write <= 1'b0;
            o_halt       <= 1'b0;
            o_alu_result <= {NB_DATA{1'b0}};
            o_store_data <= {NB_DATA{1'b0}};
            o_rd_addr    <= {NB_REG{1'b0}};
            o_funct3     <= 3'd0;
            o_pc_plus4   <= {NB_DATA{1'b0}};
            o_instr      <= NOP;
        end else if (i_en) begin
            o_reg_write  <= i_reg_write;   o_wb_sel    <= i_wb_sel;
            o_mem_read   <= i_mem_read;    o_mem_write <= i_mem_write;
            o_halt       <= i_halt;
            o_alu_result <= i_alu_result;
            o_store_data <= i_store_data;
            o_rd_addr    <= i_rd_addr;
            o_funct3     <= i_funct3;
            o_pc_plus4   <= i_pc_plus4;
            o_instr      <= i_instr;
        end
    end

endmodule
