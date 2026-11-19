// =============================================================================
// tb_if_stage.v - Testbench autoverificable de la etapa IF
// -----------------------------------------------------------------------------
// Simula lo que después hará la Debug Unit:
//   1. Cargar un programa en la memoria por el puerto de escritura (no $readmemh,
//      así se prueba el mismo camino que usará la UART).
//   2. Ejecutar paso a paso (i_en = 1 durante un solo ciclo).
//   3. Verificar que con i_en = 0 y con i_stall = 1 todo queda congelado.
//   4. Probar un salto + flush.
//   5. Reprogramar la memoria sin resintetizar y volver a ejecutar.
// Al final imprime cuántas verificaciones pasaron y cuántas fallaron.
// Las entradas se cambian en el flanco NEGATIVO para no competir con el
// flanco positivo en que muestrean los registros.
// =============================================================================
`timescale 1ns / 1ps

module tb_if_stage;

    localparam DEPTH = 256;
    localparam NOP   = 32'h0000_0013;
    localparam HALT  = 32'hFFFF_FFFF;

    reg         clk = 0;
    reg         rst = 1;
    reg         en = 0, stall = 0, flush = 0;
    reg         pc_src = 0;
    reg  [31:0] pc_target = 0;
    reg         imem_we = 0;
    reg  [7:0]  imem_waddr = 0;
    reg  [31:0] imem_wdata = 0;

    wire [31:0] ifid_pc, ifid_pc4, ifid_instr, pc;

    if_stage #(.DEPTH(DEPTH)) dut (
        .clk(clk), .rst(rst),
        .i_en(en), .i_stall(stall), .i_flush(flush),
        .i_pc_src(pc_src), .i_pc_target(pc_target),
        .i_imem_we(imem_we), .i_imem_waddr(imem_waddr), .i_imem_wdata(imem_wdata),
        .o_ifid_pc(ifid_pc), .o_ifid_pc_plus4(ifid_pc4), .o_ifid_instr(ifid_instr),
        .o_pc(pc)
    );

    always #5 clk = ~clk;   // 100 MHz en simulación

    // Programa de prueba (codificaciones RISC-V verificables con RARS)
    reg [31:0] prog [0:4];
    initial begin
        prog[0] = 32'h0050_0093;  // addi x1, x0, 5
        prog[1] = 32'h0030_0113;  // addi x2, x0, 3
        prog[2] = 32'h0020_81B3;  // add  x3, x1, x2
        prog[3] = 32'h4020_8233;  // sub  x4, x1, x2
        prog[4] = HALT;           // HALT (definido por nosotros)
    end

    integer pass = 0, fail = 0;

    task check(input [31:0] got, input [31:0] exp, input [8*40-1:0] what);
        begin
            if (got === exp) pass = pass + 1;
            else begin
                fail = fail + 1;
                $display("  FALLA: %0s -> obtenido %h, esperado %h (t=%0t)", what, got, exp, $time);
            end
        end
    endtask

    // Escribe una instrucción como lo hará la Debug Unit
    task write_instr(input [7:0] addr, input [31:0] data);
        begin
            @(negedge clk);
            imem_we = 1; imem_waddr = addr; imem_wdata = data;
            @(negedge clk);
            imem_we = 0;
        end
    endtask

    // Un paso: enable durante exactamente un ciclo
    task step;
        begin
            @(negedge clk); en = 1;
            @(negedge clk); en = 0;
        end
    endtask

    integer k;
    initial begin
        $dumpfile("tb_if_stage.vcd");
        $dumpvars(0, tb_if_stage);

        // ---------- Reset ----------
        repeat (2) @(negedge clk);
        rst = 0;
        $display("[1] Reset");
        check(pc, 32'd0, "PC despues de reset");
        check(ifid_instr, NOP, "IF/ID despues de reset");

        // ---------- Carga del programa con el procesador detenido ----------
        $display("[2] Carga del programa (en = 0)");
        for (k = 0; k < 5; k = k + 1) write_instr(k, prog[k]);
        check(pc, 32'd0, "PC no avanza durante la carga");

        // ---------- Paso a paso ----------
        $display("[3] Paso a paso");
        for (k = 0; k < 5; k = k + 1) begin
            step;
            check(pc,         (k + 1) * 4, "PC tras el paso");
            check(ifid_pc,    k * 4,       "IF/ID.pc");
            check(ifid_pc4,   k * 4 + 4,   "IF/ID.pc+4");
            check(ifid_instr, prog[k],     "IF/ID.instr");
        end

        // ---------- Detenido: nada cambia ----------
        $display("[4] Con en = 0 todo queda congelado");
        repeat (5) @(negedge clk);
        check(pc, 32'd20, "PC congelado");
        check(ifid_instr, HALT, "IF/ID congelado");

        // ---------- Stall ----------
        $display("[5] Stall: con en = 1 y stall = 1 tampoco avanza");
        @(negedge clk); en = 1; stall = 1;
        repeat (3) @(negedge clk);
        en = 0; stall = 0;
        check(pc, 32'd20, "PC con stall");
        check(ifid_instr, HALT, "IF/ID con stall");

        // ---------- Salto + flush ----------
        $display("[6] Salto a la direccion 8 con flush de IF/ID");
        @(negedge clk); en = 1; pc_src = 1; pc_target = 32'd8; flush = 1;
        @(negedge clk); en = 0; pc_src = 0; flush = 0;
        check(pc, 32'd8, "PC = destino del salto");
        check(ifid_instr, NOP, "IF/ID anulado (NOP)");
        step;
        check(ifid_instr, prog[2], "Primera instruccion en el destino");

        // ---------- Reprogramación sin resintetizar ----------
        $display("[7] Reprogramacion: nueva instruccion en la direccion 0 y reset");
        write_instr(0, 32'h00A0_0293);          // addi x5, x0, 10
        @(negedge clk); rst = 1;
        @(negedge clk); rst = 0;
        check(pc, 32'd0, "PC tras reset");
        step;
        check(ifid_instr, 32'h00A0_0293, "IF/ID con el programa nuevo");

        // ---------- Resultado ----------
        $display("--------------------------------------------");
        $display("Resultado: %0d verificaciones OK, %0d fallas", pass, fail);
        if (fail == 0) $display("ETAPA IF: TODO OK");
        $finish;
    end

endmodule
