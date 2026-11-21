`timescale 1ns / 1ps
// =============================================================================
// instr_mem.v - Memoria de instrucciones (memoria de programa)
// -----------------------------------------------------------------------------
// Decisiones de diseño (documentar en el informe):
// - Lectura COMBINACIONAL (asíncrona): la instrucción sale en el mismo ciclo
//   en que el PC cambia, como en el datapath del libro. Vivado la implementa
//   como RAM distribuida (LUTRAM). Alternativa: Block RAM (lectura sincrónica,
//   1 ciclo de latencia), que obligaría a rediseñar IF.
// - Puerto de ESCRITURA separado, usado solo por la Debug Unit para cargar el
//   programa por UART sin resintetizar. La Debug Unit solo escribe con el
//   procesador detenido (i_en = 0).
// - Direccionamiento: el PC es una dirección en BYTES; cada instrucción ocupa
//   4 bytes, así que el índice de palabra es PC[AW+1:2].
//   La escritura usa directamente el índice de palabra (0, 1, 2, ...).
// - Contenido inicial: todo NOP (addi x0, x0, 0 = 0x00000013). Si se pasa
//   INIT_FILE, se carga ese archivo .hex (útil para simular).
// =============================================================================
module instr_mem #(
    parameter DEPTH     = 256,             // cantidad de instrucciones
    parameter INIT_FILE = ""
)(
    input  wire                     clk,
    // Lectura (desde el PC)
    // Solo se usan los bits [AW+1:2]: [1:0] valen siempre 0 (instrucciones
    // alineadas a 4 bytes) y los altos sobran porque la memoria es chica.
    /* verilator lint_off UNUSEDSIGNAL */
    input  wire [31:0]              i_rd_addr,   // dirección en bytes
    /* verilator lint_on UNUSEDSIGNAL */
    output wire [31:0]              o_rd_data,
    // Escritura (desde la Debug Unit)
    input  wire                     i_we,
    input  wire [$clog2(DEPTH)-1:0] i_wr_addr,   // índice de palabra
    input  wire [31:0]              i_wr_data
);

    localparam AW  = $clog2(DEPTH);
    localparam NOP = 32'h0000_0013;

    reg [31:0] mem [0:DEPTH-1];

    integer i;
    initial begin
        for (i = 0; i < DEPTH; i = i + 1)
            mem[i] = NOP;
        if (INIT_FILE != "")
            $readmemh(INIT_FILE, mem);
    end

    always @(posedge clk) begin
        if (i_we)
            mem[i_wr_addr] <= i_wr_data;
    end

    assign o_rd_data = mem[i_rd_addr[AW+1:2]];

endmodule