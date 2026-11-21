`timescale 1ns / 1ps
// =============================================================================
// ex_stage.v - Etapa EX completa
// -----------------------------------------------------------------------------
// Une: muxes de forwarding + muxes de operandos + control de la ALU + ALU +
//      cálculo y decisión de saltos + latch EX/MEM.
//
// Forwarding (selección de cada operando, como en el libro §4.7):
//   i_fwd_a / i_fwd_b = 00 -> valor leído en ID (latch ID/EX)
//                       10 -> resultado de la instrucción en MEM (latch EX/MEM)
//                       01 -> dato que se está escribiendo en WB
//   Hasta que exista la unidad de forwarding, se conectan en 00.
//
// Operandos de la ALU:
//   A = alu_src_a ? 0 : rs1 (con forwarding)      -> el 0 es para lui
//   B = alu_src_b ? inmediato : rs2 (con forwarding)
//
// Saltos (decisión de diseño: se resuelven en EX):
//   - Destino: jalr -> (rs1 + inmediato) con el bit 0 en 0 (lo calcula la ALU)
//              resto -> PC + inmediato (sumador aparte; branches y jal)
//   - Se toma el salto si: jump (jal/jalr), o branch con la condición
//     cumplida: beq (funct3[0] = 0) -> la resta da 0
//               bne (funct3[0] = 1) -> la resta no da 0
//   - o_pc_src / o_pc_target van a IF. Cuando o_pc_src = 1, el top tiene que
//     anular (flush) las DOS instrucciones que entraron detrás del salto:
//     la de IF/ID y la de ID/EX.
//
// El dato que guardan los stores es rs2 con forwarding (o_store_data).
// =============================================================================
module ex_stage #(
    parameter NB_DATA = 32,   // ancho de datos y direcciones
    parameter NB_REG  = 5     // bits para numerar los registros
)(
    input  wire               i_clk,
    input  wire               i_rst,
    input  wire               i_en,
    // Desde el latch ID/EX: control
    input  wire               i_reg_write,
    input  wire [1:0]         i_wb_sel,
    input  wire               i_mem_read,
    input  wire               i_mem_write,
    input  wire               i_alu_src_a,
    input  wire               i_alu_src_b,
    input  wire [1:0]         i_alu_op,
    input  wire               i_branch,
    input  wire               i_jump,
    input  wire               i_jalr,
    input  wire               i_halt,
    // Desde el latch ID/EX: datos
    input  wire [NB_DATA-1:0] i_pc,
    input  wire [NB_DATA-1:0] i_pc_plus4,
    input  wire [NB_DATA-1:0] i_rs1_data,
    input  wire [NB_DATA-1:0] i_rs2_data,
    input  wire [NB_DATA-1:0] i_imm,
    input  wire [NB_REG-1:0]  i_rd_addr,
    input  wire [2:0]         i_funct3,
    input  wire               i_funct7_b5,
    input  wire [31:0]        i_instr,
    // Forwarding
    input  wire [1:0]         i_fwd_a,
    input  wire [1:0]         i_fwd_b,
    input  wire [NB_DATA-1:0] i_exmem_result,   // resultado en MEM (latch EX/MEM)
    input  wire [NB_DATA-1:0] i_wb_data,        // dato que se escribe en WB
    // Saltos (hacia IF)
    output wire               o_pc_src,
    output wire [NB_DATA-1:0] o_pc_target,
    // Contenido del latch EX/MEM
    output wire               o_reg_write,
    output wire [1:0]         o_wb_sel,
    output wire               o_mem_read,
    output wire               o_mem_write,
    output wire               o_halt,
    output wire [NB_DATA-1:0] o_alu_result,
    output wire [NB_DATA-1:0] o_store_data,
    output wire [NB_REG-1:0]  o_rd_addr,
    output wire [2:0]         o_funct3,
    output wire [NB_DATA-1:0] o_pc_plus4,
    output wire [31:0]        o_instr
);

    localparam FWD_ID  = 2'b00;
    localparam FWD_WB  = 2'b01;
    localparam FWD_MEM = 2'b10;

    localparam [NB_DATA-1:0] ZERO = {NB_DATA{1'b0}};

    // ---------- Forwarding ----------
    reg [NB_DATA-1:0] rs1_fwd, rs2_fwd;

    always @(*) begin
        case (i_fwd_a)
            FWD_ID:  rs1_fwd = i_rs1_data;
            FWD_MEM: rs1_fwd = i_exmem_result;
            FWD_WB:  rs1_fwd = i_wb_data;
            default: rs1_fwd = i_rs1_data;      // 11: no se usa
        endcase
        case (i_fwd_b)
            FWD_ID:  rs2_fwd = i_rs2_data;
            FWD_MEM: rs2_fwd = i_exmem_result;
            FWD_WB:  rs2_fwd = i_wb_data;
            default: rs2_fwd = i_rs2_data;      // 11: no se usa
        endcase
    end

    // ---------- Operandos ----------
    wire [NB_DATA-1:0] alu_a = i_alu_src_a ? ZERO  : rs1_fwd;
    wire [NB_DATA-1:0] alu_b = i_alu_src_b ? i_imm : rs2_fwd;

    // ---------- ALU ----------
    wire [3:0]         alu_ctrl;
    wire [NB_DATA-1:0] alu_result;
    wire               alu_zero;

    alu_control u_alu_control (
        .i_alu_op    (i_alu_op),
        .i_funct3    (i_funct3),
        .i_funct7_b5 (i_funct7_b5),
        .o_alu_ctrl  (alu_ctrl)
    );

    alu #(
        .NB_DATA    (NB_DATA)
    ) u_alu (
        .i_a        (alu_a),
        .i_b        (alu_b),
        .i_alu_ctrl (alu_ctrl),
        .o_result   (alu_result),
        .o_zero     (alu_zero)
    );

    // ---------- Saltos ----------
    wire branch_cond  = i_funct3[0] ? ~alu_zero : alu_zero;   // bne : beq
    wire branch_taken = i_branch && branch_cond;

    assign o_pc_src    = i_jump || branch_taken;
    assign o_pc_target = i_jalr ? {alu_result[NB_DATA-1:1], 1'b0}
                                : i_pc + i_imm;

    // ---------- Latch EX/MEM ----------
    ex_mem #(
        .NB_DATA      (NB_DATA),
        .NB_REG       (NB_REG)
    ) u_ex_mem (
        .i_clk        (i_clk),
        .i_rst        (i_rst),
        .i_en         (i_en),
        .i_reg_write  (i_reg_write),
        .i_wb_sel     (i_wb_sel),
        .i_mem_read   (i_mem_read),
        .i_mem_write  (i_mem_write),
        .i_halt       (i_halt),
        .i_alu_result (alu_result),
        .i_store_data (rs2_fwd),
        .i_rd_addr    (i_rd_addr),
        .i_funct3     (i_funct3),
        .i_pc_plus4   (i_pc_plus4),
        .i_instr      (i_instr),
        .o_reg_write  (o_reg_write),
        .o_wb_sel     (o_wb_sel),
        .o_mem_read   (o_mem_read),
        .o_mem_write  (o_mem_write),
        .o_halt       (o_halt),
        .o_alu_result (o_alu_result),
        .o_store_data (o_store_data),
        .o_rd_addr    (o_rd_addr),
        .o_funct3     (o_funct3),
        .o_pc_plus4   (o_pc_plus4),
        .o_instr      (o_instr)
    );

endmodule
