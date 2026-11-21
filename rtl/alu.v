`timescale 1ns / 1ps
// =============================================================================
// alu.v - Unidad aritmético-lógica de 32 bits (RV32I)
// -----------------------------------------------------------------------------
//   i_alu_ctrl | Operación | Resultado
//   -----------+-----------+-----------------------------------------------
//      0000    |   ADD     | A + B
//      0001    |   SUB     | A - B
//      0010    |   SLL     | A << B[4:0]
//      0011    |   SLT     | 1 si A < B con signo, si no 0
//      0100    |   SLTU    | 1 si A < B sin signo, si no 0
//      0101    |   XOR     | A ^ B
//      0110    |   SRL     | A >> B[4:0]  (rellena con ceros)
//      0111    |   SRA     | A >>> B[4:0] (rellena con el bit de signo)
//      1000    |   OR      | A | B
//      1001    |   AND     | A & B
//   otro       |    -      | 0
//
// Decisiones de diseño:
// - Los shifts usan solo los bits bajos de B: B[4:0] con NB_DATA = 32
//   (en RV32 el desplazamiento máximo es 31).
// - SLT compara con signo ($signed) y SLTU sin signo.
// - o_zero = 1 si el resultado es 0. Lo usa la lógica de branches:
//   beq/bne hacen SUB y miran si rs1 - rs2 = 0.
// - La suma y la resta no detectan overflow: RV32I no tiene excepciones
//   por overflow (el resultado simplemente da la vuelta).
// - Combinacional: el resultado sale en el mismo ciclo, en EX.
// - Los códigos tienen que coincidir con los de alu_control.v.
// =============================================================================
module alu #(
    parameter NB_DATA = 32    // ancho de los operandos
)(
    input  wire [NB_DATA-1:0] i_a,
    input  wire [NB_DATA-1:0] i_b,
    input  wire [3:0]  i_alu_ctrl,
    output reg  [NB_DATA-1:0] o_result,
    output wire        o_zero
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

    localparam NB_SHAMT = $clog2(NB_DATA);          // 5 bits para 32
    localparam [NB_DATA-1:0] ZERO = {NB_DATA{1'b0}};

    wire [NB_SHAMT-1:0] shamt = i_b[NB_SHAMT-1:0];

    always @(*) begin
        case (i_alu_ctrl)
            ALU_ADD:  o_result = i_a + i_b;
            ALU_SUB:  o_result = i_a - i_b;
            ALU_SLL:  o_result = i_a << shamt;
            ALU_SLT:  o_result = {{(NB_DATA-1){1'b0}}, $signed(i_a) < $signed(i_b)};
            ALU_SLTU: o_result = {{(NB_DATA-1){1'b0}}, i_a < i_b};
            ALU_XOR:  o_result = i_a ^ i_b;
            ALU_SRL:  o_result = i_a >> shamt;
            ALU_SRA:  o_result = $signed(i_a) >>> shamt;
            ALU_OR:   o_result = i_a | i_b;
            ALU_AND:  o_result = i_a & i_b;
            default:  o_result = ZERO;
        endcase
    end

    assign o_zero = (o_result == ZERO);

endmodule
