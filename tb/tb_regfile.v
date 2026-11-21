`timescale 1ns / 1ps
// =============================================================================
// tb_regfile.v - Testbench autoverificable del banco de registros
// -----------------------------------------------------------------------------
// Verifica:
//   1. Después del reset, los 32 registros valen 0.
//   2. Escribir un registro y leerlo por rs1, rs2 y el puerto de debug.
//   3. x0 siempre vale 0, aunque se intente escribir.
//   4. Con i_we = 0 no se escribe nada.
//   5. Bypass: leer el registro que se está escribiendo en el mismo ciclo.
//   6. Escribir los 32 registros y leerlos todos (como la Debug Unit).
//   7. El reset vuelve todo a 0 (reprogramación).
// Las entradas cambian en el flanco negativo; termina con $fatal si falla.
// =============================================================================
module tb_regfile;

    localparam PERIOD = 10;   // periodo del clock en ns (100 MHz)

    reg         clk = 0;
    reg         rst = 1;
    reg         we = 0;
    reg  [4:0]  rd_addr = 0, rs1_addr = 0, rs2_addr = 0, dbg_addr = 0;
    reg  [31:0] rd_data = 0;
    wire [31:0] rs1_data, rs2_data, dbg_data;

    regfile dut (
        .i_clk(clk), .i_rst(rst),
        .i_we(we), .i_rd_addr(rd_addr), .i_rd_data(rd_data),
        .i_rs1_addr(rs1_addr), .i_rs2_addr(rs2_addr),
        .o_rs1_data(rs1_data), .o_rs2_data(rs2_data),
        .i_dbg_addr(dbg_addr), .o_dbg_data(dbg_data)
    );

    always #(PERIOD/2) clk = ~clk;

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

    // Escribe un registro (un ciclo de i_we = 1)
    task write_reg(input [4:0] addr, input [31:0] data);
        begin
            @(negedge clk);
            we = 1; rd_addr = addr; rd_data = data;
            @(negedge clk);
            we = 0;
        end
    endtask

    integer r;
    initial begin
        $dumpfile("tb_regfile.vcd");
        $dumpvars(0, tb_regfile);

        // ---------- 1. Reset ----------
        repeat (2) @(negedge clk);
        rst = 0;
        $display("[1] Despues del reset todos los registros valen 0");
        for (r = 0; r < 32; r = r + 1) begin
            dbg_addr = r; #1;
            check(dbg_data, 32'd0, "registro en 0 tras reset");
        end

        // ---------- 2. Escritura y lectura ----------
        $display("[2] Escribir x5 y leerlo por rs1, rs2 y debug");
        write_reg(5, 32'hDEAD_BEEF);
        rs1_addr = 5; rs2_addr = 5; dbg_addr = 5; #1;
        check(rs1_data, 32'hDEAD_BEEF, "x5 por rs1");
        check(rs2_data, 32'hDEAD_BEEF, "x5 por rs2");
        check(dbg_data, 32'hDEAD_BEEF, "x5 por debug");

        // Dos registros distintos a la vez
        write_reg(6, 32'h0000_0006);
        rs1_addr = 5; rs2_addr = 6; #1;
        check(rs1_data, 32'hDEAD_BEEF, "rs1 = x5");
        check(rs2_data, 32'h0000_0006, "rs2 = x6");

        // ---------- 3. x0 ----------
        $display("[3] x0 siempre vale 0");
        write_reg(0, 32'hFFFF_FFFF);
        rs1_addr = 0; rs2_addr = 0; dbg_addr = 0; #1;
        check(rs1_data, 32'd0, "x0 por rs1");
        check(rs2_data, 32'd0, "x0 por rs2");
        check(dbg_data, 32'd0, "x0 por debug");

        // ---------- 4. Sin enable no escribe ----------
        $display("[4] Con i_we = 0 no se escribe");
        @(negedge clk);
        we = 0; rd_addr = 5; rd_data = 32'h1234_5678;
        @(negedge clk);
        rs1_addr = 5; #1;
        check(rs1_data, 32'hDEAD_BEEF, "x5 sin cambios");

        // ---------- 5. Bypass ----------
        $display("[5] Bypass: leer el registro que se escribe en el mismo ciclo");
        @(negedge clk);
        we = 1; rd_addr = 7; rd_data = 32'hCAFE_0007;
        rs1_addr = 7; rs2_addr = 7; #1;
        check(rs1_data, 32'hCAFE_0007, "bypass por rs1");
        check(rs2_data, 32'hCAFE_0007, "bypass por rs2");
        @(negedge clk);             // el flanco positivo ya escribio x7
        we = 0;
        rs1_addr = 7; #1;
        check(rs1_data, 32'hCAFE_0007, "x7 quedo escrito");
        // El bypass no aplica a x0 (en otro ciclo, para no pisar la escritura de x7)
        @(negedge clk);
        we = 1; rd_addr = 0; rd_data = 32'hBAD0_0000; rs1_addr = 0; #1;
        check(rs1_data, 32'd0, "sin bypass hacia x0");
        @(negedge clk);
        we = 0;

        // ---------- 6. Los 32 registros ----------
        $display("[6] Escribir x1..x31 y leerlos todos por el puerto de debug");
        for (r = 1; r < 32; r = r + 1)
            write_reg(r, 32'hA000_0000 + r);
        for (r = 0; r < 32; r = r + 1) begin
            dbg_addr = r; #1;
            check(dbg_data, (r == 0) ? 32'd0 : 32'hA000_0000 + r, "lectura de debug");
        end

        // ---------- 7. Reset ----------
        $display("[7] El reset vuelve todos los registros a 0");
        @(negedge clk); rst = 1;
        @(negedge clk); rst = 0;
        for (r = 0; r < 32; r = r + 1) begin
            dbg_addr = r; #1;
            check(dbg_data, 32'd0, "registro en 0 tras segundo reset");
        end

        // ---------- Resultado ----------
        $display("--------------------------------------------");
        $display("Resultado: %0d verificaciones OK, %0d fallas", pass, fail);
        if (fail == 0) begin
            $display("REGFILE: TODO OK");
            $finish;
        end else begin
            $fatal(1, "REGFILE: %0d FALLAS", fail);
        end
    end

endmodule
