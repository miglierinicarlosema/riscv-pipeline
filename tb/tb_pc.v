`timescale 1ns / 1ps

module tb_pc;

    localparam PERIOD = 10;   // periodo del clock en ns (100 MHz)

    reg clk = 0;
    reg rst = 1;
    reg en = 0;
    reg pc_src = 0;
    reg [31:0] pc_target = 0;

    wire [31:0] pc_value;
    wire [31:0] pc_plus4;

    integer pass = 0;
    integer fail = 0;

    pc dut (
        .i_clk(clk),
        .i_rst(rst),
        .i_en(en),
        .i_pc_src(pc_src),
        .i_pc_target(pc_target),
        .o_pc(pc_value),
        .o_pc_plus4(pc_plus4)
    );

    always #(PERIOD/2) clk = ~clk;

    task check(
        input [31:0] got,
        input [31:0] expected,
        input [8*40-1:0] description
    );
        begin
            if (got === expected) begin
                pass = pass + 1;
                $display("[PASS] %0s", description);
            end else begin
                fail = fail + 1;
                $display("[FAIL] %0s: got=%h expected=%h",
                         description, got, expected);
            end
        end
    endtask

    initial begin
        $dumpfile("tb_pc.vcd");
        $dumpvars(0, tb_pc);

        // 1. Reset sincronico
        repeat (2) @(negedge clk);
        check(pc_value, 32'd0, "Reset del PC");
        check(pc_plus4, 32'd4, "PC + 4 inicial");
        rst = 0;

        // 2. Incremento secuencial
        en = 1;

        @(negedge clk);
        check(pc_value, 32'd4, "Primer incremento");

        @(negedge clk);
        check(pc_value, 32'd8, "Segundo incremento");
        check(pc_plus4, 32'd12, "PC + 4");

        // 3. PC deshabilitado
        en = 0;

        repeat (3) @(negedge clk);
        check(pc_value, 32'd8, "PC congelado");

        // 4. Salto
        en = 1;
        pc_src = 1;
        pc_target = 32'd100;

        @(negedge clk);
        check(pc_value, 32'd100, "Salto a direccion 100");
        check(pc_plus4, 32'd104, "PC + 4 despues del salto");

        // 5. Continuar despues del salto
        pc_src = 0;

        @(negedge clk);
        check(pc_value, 32'd104, "Incremento despues del salto");

        // 6. Reset con enable desactivado
        en = 0;
        rst = 1;

        @(negedge clk);
        check(pc_value, 32'd0, "Prioridad del reset");

        // Resultado
        $display("----------------------------------------");
        $display("Resultado PC: %0d OK, %0d fallas", pass, fail);

        if (fail == 0) begin
            $display("PC: TODO OK");
            $finish;
        end else begin
            $fatal(1, "PC: TEST FALLIDO");
        end
    end

endmodule
