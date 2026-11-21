`timescale 1ns / 1ps
// =============================================================================
// id_ex.v - Registro de pipeline ID/EX
// -----------------------------------------------------------------------------
// Lleva de ID a EX todo lo que necesitan las etapas siguientes:
//   - Señales de control para EX, MEM y WB (salen de control.v).
//   - Datos: valores leídos de rs1 y rs2, inmediato, PC y PC+4.
//   - Números de registro rs1, rs2 y rd (forwarding y escritura en WB).
//   - funct3 (alu_control, tamaño del acceso a memoria, beq/bne) y el bit 30
//     de la instrucción (alu_control: add/sub, srl/sra).
//   - uses_rs1 / uses_rs2 (para no hacer forwarding de registros que no se usan).
//   - La instrucción completa (para que la Debug Unit la muestre).
//
// Control:
//   i_en = 0    -> mantiene el valor (paso a paso detenido, HALT).
//   i_flush = 1 -> inserta una BURBUJA: todas las señales de control en 0
//                  (no escribe registros ni memoria, no salta) y la
//                  instrucción pasa a NOP. Se usa en el stall por load-use y
//                  para anular instrucciones después de un salto tomado.
//   El flush solo actúa con i_en = 1 (con el procesador detenido nada cambia).
// Reset sincrónico, activo en alto: deja una burbuja.
// =============================================================================
module id_ex (
    input  wire        clk,
    input  wire        rst,
    input  wire        i_en,
    input  wire        i_flush,
    // Señales de control
    input  wire        i_reg_write,
    input  wire [1:0]  i_wb_sel,
    input  wire        i_mem_read,
    input  wire        i_mem_write,
    input  wire        i_alu_src_a,
    input  wire        i_alu_src_b,
    input  wire [1:0]  i_alu_op,
    input  wire        i_branch,
    input  wire        i_jump,
    input  wire        i_jalr,
    input  wire        i_uses_rs1,
    input  wire        i_uses_rs2,
    input  wire        i_halt,
    // Datos
    input  wire [31:0] i_pc,
    input  wire [31:0] i_pc_plus4,
    input  wire [31:0] i_rs1_data,
    input  wire [31:0] i_rs2_data,
    input  wire [31:0] i_imm,
    input  wire [4:0]  i_rs1_addr,
    input  wire [4:0]  i_rs2_addr,
    input  wire [4:0]  i_rd_addr,
    input  wire [2:0]  i_funct3,
    input  wire        i_funct7_b5,     // bit 30 de la instrucción
    input  wire [31:0] i_instr,
    // Salidas
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
    output reg         o_uses_rs1,
    output reg         o_uses_rs2,
    output reg         o_halt,
    output reg  [31:0] o_pc,
    output reg  [31:0] o_pc_plus4,
    output reg  [31:0] o_rs1_data,
    output reg  [31:0] o_rs2_data,
    output reg  [31:0] o_imm,
    output reg  [4:0]  o_rs1_addr,
    output reg  [4:0]  o_rs2_addr,
    output reg  [4:0]  o_rd_addr,
    output reg  [2:0]  o_funct3,
    output reg         o_funct7_b5,
    output reg  [31:0] o_instr
);

    localparam NOP = 32'h0000_0013;   // addi x0, x0, 0

    // Burbuja: control en 0, datos en 0, instrucción NOP
    task bubble;
        begin
            o_reg_write <= 1'b0;  o_wb_sel    <= 2'b00;
            o_mem_read  <= 1'b0;  o_mem_write <= 1'b0;
            o_alu_src_a <= 1'b0;  o_alu_src_b <= 1'b0;  o_alu_op <= 2'b00;
            o_branch    <= 1'b0;  o_jump      <= 1'b0;  o_jalr   <= 1'b0;
            o_uses_rs1  <= 1'b0;  o_uses_rs2  <= 1'b0;  o_halt   <= 1'b0;
            o_pc        <= 32'd0; o_pc_plus4  <= 32'd0;
            o_rs1_data  <= 32'd0; o_rs2_data  <= 32'd0; o_imm    <= 32'd0;
            o_rs1_addr  <= 5'd0;  o_rs2_addr  <= 5'd0;  o_rd_addr <= 5'd0;
            o_funct3    <= 3'd0;  o_funct7_b5 <= 1'b0;
            o_instr     <= NOP;
        end
    endtask

    always @(posedge clk) begin
        if (rst) begin
            bubble;
        end else if (i_en) begin
            if (i_flush) begin
                bubble;
            end else begin
                o_reg_write <= i_reg_write;  o_wb_sel    <= i_wb_sel;
                o_mem_read  <= i_mem_read;   o_mem_write <= i_mem_write;
                o_alu_src_a <= i_alu_src_a;  o_alu_src_b <= i_alu_src_b;
                o_alu_op    <= i_alu_op;
                o_branch    <= i_branch;     o_jump      <= i_jump;
                o_jalr      <= i_jalr;
                o_uses_rs1  <= i_uses_rs1;   o_uses_rs2  <= i_uses_rs2;
                o_halt      <= i_halt;
                o_pc        <= i_pc;         o_pc_plus4  <= i_pc_plus4;
                o_rs1_data  <= i_rs1_data;   o_rs2_data  <= i_rs2_data;
                o_imm       <= i_imm;
                o_rs1_addr  <= i_rs1_addr;   o_rs2_addr  <= i_rs2_addr;
                o_rd_addr   <= i_rd_addr;
                o_funct3    <= i_funct3;     o_funct7_b5 <= i_funct7_b5;
                o_instr     <= i_instr;
            end
        end
    end

endmodule
