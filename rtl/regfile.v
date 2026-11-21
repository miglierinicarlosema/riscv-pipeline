`timescale 1ns / 1ps
// =============================================================================
// regfile.v - Banco de 32 registros de 32 bits (x0..x31)
// -----------------------------------------------------------------------------
// - 2 puertos de lectura combinacional (rs1 y rs2), usados en ID.
// - 1 puerto de escritura sincrónico (rd), usado desde WB.
// - 1 puerto de lectura extra para la Debug Unit (leer los 32 registros
//   y mandarlos por UART, como pide la consigna).
//
// Decisiones de diseño (documentar en el informe):
// - x0 vale siempre 0: las escrituras a x0 se ignoran. En RISC-V es común
//   escribir en x0 (nop = addi x0, x0, 0; salto simple = jal x0, ...).
// - Bypass interno (write-first): si en el mismo ciclo WB escribe un registro
//   e ID lo lee, ID recibe el valor NUEVO. Reemplaza al "escribir en la
//   primera mitad del ciclo y leer en la segunda" del libro, sin usar el
//   flanco negativo del clock.
// - Reset sincrónico que pone los 32 registros en 0. Así, al reprogramar,
//   un reset deja los registros limpios (pregunta de la consigna).
//   Se implementa con flip-flops (1024 FF; la Zynq-7010 tiene unos 35.000).
// - El puerto de debug no tiene bypass: la Debug Unit lee con el procesador
//   detenido, cuando no hay escrituras en curso.
// =============================================================================
module regfile #(
    parameter NB_DATA = 32,   // ancho de cada registro
    parameter NB_REG  = 5     // bits para numerar los registros (2^5 = 32)
)(
    input  wire        i_clk,
    input  wire        i_rst,
    // Escritura (desde WB)
    input  wire        i_we,
    input  wire [NB_REG-1:0]  i_rd_addr,
    input  wire [NB_DATA-1:0] i_rd_data,
    // Lecturas (desde ID)
    input  wire [NB_REG-1:0]  i_rs1_addr,
    input  wire [NB_REG-1:0]  i_rs2_addr,
    output wire [NB_DATA-1:0] o_rs1_data,
    output wire [NB_DATA-1:0] o_rs2_data,
    // Lectura para la Debug Unit
    input  wire [NB_REG-1:0]  i_dbg_addr,
    output wire [NB_DATA-1:0] o_dbg_data
);

    localparam N_REGS = 1 << NB_REG;            // 32 registros
    localparam [NB_REG-1:0]  X0   = {NB_REG{1'b0}};
    localparam [NB_DATA-1:0] ZERO = {NB_DATA{1'b0}};

    reg [NB_DATA-1:0] regs [0:N_REGS-1];

    // Hay escritura válida si está habilitada y no es a x0
    wire write_ok = i_we && (i_rd_addr != X0);

    integer k;
    always @(posedge i_clk) begin
        if (i_rst) begin
            for (k = 0; k < N_REGS; k = k + 1)
                regs[k] <= ZERO;
        end else if (write_ok) begin
            regs[i_rd_addr] <= i_rd_data;
        end
    end

    // Lectura con bypass: x0 siempre 0; si se está escribiendo el mismo
    // registro en este ciclo, sale el dato nuevo.
    assign o_rs1_data = (i_rs1_addr == X0)                      ? ZERO      :
                        (write_ok && i_rd_addr == i_rs1_addr)   ? i_rd_data :
                                                                  regs[i_rs1_addr];

    assign o_rs2_data = (i_rs2_addr == X0)                      ? ZERO      :
                        (write_ok && i_rd_addr == i_rs2_addr)   ? i_rd_data :
                                                                  regs[i_rs2_addr];

    assign o_dbg_data = (i_dbg_addr == X0) ? ZERO : regs[i_dbg_addr];

endmodule
