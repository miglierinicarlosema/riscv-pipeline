`timescale 1ns / 1ps
// =============================================================================
// id_stage.v - Etapa ID completa
// -----------------------------------------------------------------------------
// Une: unidad de control + generador de inmediatos + banco de registros +
//      latch ID/EX.
//
// Entradas principales:
//   - Contenido del latch IF/ID (PC, PC+4, instrucción), desde if_stage.
//   - Puerto de escritura del banco de registros, desde WB (rd, dato, enable).
//   - Puerto de lectura de debug del banco de registros (Debug Unit).
// Salidas:
//   - Contenido del latch ID/EX, hacia EX y la Debug Unit.
//   - o_id_halt: hay un HALT en ID (combinacional). El top lo usa para dejar
//     de buscar instrucciones en IF y vaciar el pipeline.
//   - o_id_rs1_addr / o_id_rs2_addr / o_id_uses_rs1 / o_id_uses_rs2:
//     registros que lee la instrucción que está en ID, para la unidad de
//     riesgos (stall por load-use), que se agrega más adelante.
//
// Control:
//   - i_en:    enable global (Debug Unit). Con 0, el latch ID/EX se mantiene.
//   - i_flush: burbuja en ID/EX (stall por load-use o salto tomado).
//
// Decisiones de diseño:
//   - La escritura del banco de registros (desde WB) no se frena con i_en:
//     mientras el procesador está detenido, el latch MEM/WB no cambia y la
//     escritura repite el mismo valor en el mismo registro, sin efecto.
//   - Los campos de la instrucción se sacan siempre de las mismas posiciones
//     (RISC-V los ubica igual en todos los formatos): rs1 = [19:15],
//     rs2 = [24:20], rd = [11:7], funct3 = [14:12], bit 30 = funct7[5].
// =============================================================================
module id_stage #(
    parameter NB_DATA = 32,   // ancho de datos y direcciones
    parameter NB_REG  = 5     // bits para numerar los registros
)(
    input  wire        i_clk,
    input  wire        i_rst,
    input  wire        i_en,
    input  wire        i_flush,
    // Desde IF/ID
    input  wire [NB_DATA-1:0] i_pc,
    input  wire [NB_DATA-1:0] i_pc_plus4,
    input  wire [31:0] i_instr,
    // Escritura del banco de registros (desde WB)
    input  wire        i_wb_we,
    input  wire [NB_REG-1:0]  i_wb_rd,
    input  wire [NB_DATA-1:0] i_wb_data,
    // Lectura de debug del banco de registros
    input  wire [NB_REG-1:0]  i_dbg_addr,
    output wire [NB_DATA-1:0] o_dbg_data,
    // Información de la instrucción en ID (para HALT y la unidad de riesgos)
    output wire        o_id_halt,
    output wire [NB_REG-1:0]  o_id_rs1_addr,
    output wire [NB_REG-1:0]  o_id_rs2_addr,
    output wire        o_id_uses_rs1,
    output wire        o_id_uses_rs2,
    // Contenido del latch ID/EX
    output wire        o_reg_write,
    output wire [1:0]  o_wb_sel,
    output wire        o_mem_read,
    output wire        o_mem_write,
    output wire        o_alu_src_a,
    output wire        o_alu_src_b,
    output wire [1:0]  o_alu_op,
    output wire        o_branch,
    output wire        o_jump,
    output wire        o_jalr,
    output wire        o_uses_rs1,
    output wire        o_uses_rs2,
    output wire        o_halt,
    output wire [NB_DATA-1:0] o_pc,
    output wire [NB_DATA-1:0] o_pc_plus4,
    output wire [NB_DATA-1:0] o_rs1_data,
    output wire [NB_DATA-1:0] o_rs2_data,
    output wire [NB_DATA-1:0] o_imm,
    output wire [NB_REG-1:0]  o_rs1_addr,
    output wire [NB_REG-1:0]  o_rs2_addr,
    output wire [NB_REG-1:0]  o_rd_addr,
    output wire [2:0]  o_funct3,
    output wire        o_funct7_b5,
    output wire [31:0] o_instr
);

    // ---------- Campos de la instrucción ----------
    wire [4:0] rs1_addr = i_instr[19:15];
    wire [4:0] rs2_addr = i_instr[24:20];
    wire [4:0] rd_addr  = i_instr[11:7];
    wire [2:0] funct3   = i_instr[14:12];
    wire       funct7_b5 = i_instr[30];

    // ---------- Unidad de control ----------
    wire       c_reg_write, c_mem_read, c_mem_write, c_alu_src_a, c_alu_src_b;
    wire       c_branch, c_jump, c_jalr, c_uses_rs1, c_uses_rs2, c_halt;
    wire [1:0] c_wb_sel, c_alu_op;
    wire [2:0] c_imm_sel;

    control u_control (
        .i_instr     (i_instr),
        .o_reg_write (c_reg_write),
        .o_wb_sel    (c_wb_sel),
        .o_mem_read  (c_mem_read),
        .o_mem_write (c_mem_write),
        .o_alu_src_a (c_alu_src_a),
        .o_alu_src_b (c_alu_src_b),
        .o_alu_op    (c_alu_op),
        .o_branch    (c_branch),
        .o_jump      (c_jump),
        .o_jalr      (c_jalr),
        .o_imm_sel   (c_imm_sel),
        .o_uses_rs1  (c_uses_rs1),
        .o_uses_rs2  (c_uses_rs2),
        .o_halt      (c_halt)
    );

    // ---------- Generador de inmediatos ----------
    wire [31:0] imm;

    imm_gen u_imm_gen (
        .i_instr   (i_instr[31:7]),
        .i_imm_sel (c_imm_sel),
        .o_imm     (imm)
    );

    // ---------- Banco de registros ----------
    wire [NB_DATA-1:0] rs1_data, rs2_data;

    regfile #(
        .NB_DATA    (NB_DATA),
        .NB_REG     (NB_REG)
    ) u_regfile (
        .i_clk        (i_clk),
        .i_rst        (i_rst),
        .i_we       (i_wb_we),
        .i_rd_addr  (i_wb_rd),
        .i_rd_data  (i_wb_data),
        .i_rs1_addr (rs1_addr),
        .i_rs2_addr (rs2_addr),
        .o_rs1_data (rs1_data),
        .o_rs2_data (rs2_data),
        .i_dbg_addr (i_dbg_addr),
        .o_dbg_data (o_dbg_data)
    );

    // ---------- Información para HALT y riesgos ----------
    assign o_id_halt     = c_halt;
    assign o_id_rs1_addr = rs1_addr;
    assign o_id_rs2_addr = rs2_addr;
    assign o_id_uses_rs1 = c_uses_rs1;
    assign o_id_uses_rs2 = c_uses_rs2;

    // ---------- Latch ID/EX ----------
    id_ex #(
        .NB_DATA     (NB_DATA),
        .NB_REG      (NB_REG)
    ) u_id_ex (
        .i_clk         (i_clk),
        .i_rst         (i_rst),
        .i_en        (i_en),
        .i_flush     (i_flush),
        .i_reg_write (c_reg_write),
        .i_wb_sel    (c_wb_sel),
        .i_mem_read  (c_mem_read),
        .i_mem_write (c_mem_write),
        .i_alu_src_a (c_alu_src_a),
        .i_alu_src_b (c_alu_src_b),
        .i_alu_op    (c_alu_op),
        .i_branch    (c_branch),
        .i_jump      (c_jump),
        .i_jalr      (c_jalr),
        .i_uses_rs1  (c_uses_rs1),
        .i_uses_rs2  (c_uses_rs2),
        .i_halt      (c_halt),
        .i_pc        (i_pc),
        .i_pc_plus4  (i_pc_plus4),
        .i_rs1_data  (rs1_data),
        .i_rs2_data  (rs2_data),
        .i_imm       (imm),
        .i_rs1_addr  (rs1_addr),
        .i_rs2_addr  (rs2_addr),
        .i_rd_addr   (rd_addr),
        .i_funct3    (funct3),
        .i_funct7_b5 (funct7_b5),
        .i_instr     (i_instr),
        .o_reg_write (o_reg_write),
        .o_wb_sel    (o_wb_sel),
        .o_mem_read  (o_mem_read),
        .o_mem_write (o_mem_write),
        .o_alu_src_a (o_alu_src_a),
        .o_alu_src_b (o_alu_src_b),
        .o_alu_op    (o_alu_op),
        .o_branch    (o_branch),
        .o_jump      (o_jump),
        .o_jalr      (o_jalr),
        .o_uses_rs1  (o_uses_rs1),
        .o_uses_rs2  (o_uses_rs2),
        .o_halt      (o_halt),
        .o_pc        (o_pc),
        .o_pc_plus4  (o_pc_plus4),
        .o_rs1_data  (o_rs1_data),
        .o_rs2_data  (o_rs2_data),
        .o_imm       (o_imm),
        .o_rs1_addr  (o_rs1_addr),
        .o_rs2_addr  (o_rs2_addr),
        .o_rd_addr   (o_rd_addr),
        .o_funct3    (o_funct3),
        .o_funct7_b5 (o_funct7_b5),
        .o_instr     (o_instr)
    );

endmodule
