`timescale 1ns / 1ps
// =============================================================================
// tb_imm_gen.v - Testbench autoverificable del generador de inmediatos
// -----------------------------------------------------------------------------
// Vectores generados con un script que CODIFICA cada instruccion a partir del
// inmediato (el camino inverso al modulo), verificables con RARS.
// Incluye valores maximos y minimos de cada formato y los bits "mezclados"
// de B y J (bit 11 y bit 12), que es donde mas errores aparecen.
// Termina con $fatal si alguna verificacion falla.
// =============================================================================
module tb_imm_gen;

    reg  [31:0] instr;
    reg  [2:0]  imm_sel;
    wire [31:0] imm;

    imm_gen dut (
        .i_instr   (instr[31:7]),
        .i_imm_sel (imm_sel),
        .o_imm     (imm)
    );

    integer pass = 0, fail = 0;

    // Aplica una instruccion y verifica el inmediato
    task check(input [31:0] ins, input [2:0] sel, input [31:0] exp,
               input [8*40-1:0] what);
        begin
            instr = ins; imm_sel = sel; #1;
            if (imm === exp) pass = pass + 1;
            else begin
                fail = fail + 1;
                $display("  FALLA: %0s (%h) -> obtenido %h, esperado %h", what, ins, imm, exp);
            end
        end
    endtask

    initial begin
        $dumpfile("tb_imm_gen.vcd");
        $dumpvars(0, tb_imm_gen);

        $display("Formato I");
        check(32'h00500093, 3'd0, 32'h00000005, "addi x1, x0, 5");
        check(32'hffd00293, 3'd0, 32'hfffffffd, "addi x5, x0, -3");
        check(32'h7ff00093, 3'd0, 32'h000007ff, "addi x1, x0, 2047 (max)");
        check(32'h80000093, 3'd0, 32'hfffff800, "addi x1, x0, -2048 (min)");
        check(32'hc0000093, 3'd0, 32'hfffffc00, "addi x1, x0, -1024 (bit30=1)");
        check(32'hffc12303, 3'd0, 32'hfffffffc, "lw x6, -4(x2)");
        check(32'h008280e7, 3'd0, 32'h00000008, "jalr x1, 8(x5)");
        check(32'h40725193, 3'd0, 32'h00000407, "srai x3, x4, 7");

        $display("Formato S");
        check(32'h00512423, 3'd1, 32'h00000008, "sw x5, 8(x2)");
        check(32'hfe118fa3, 3'd1, 32'hffffffff, "sb x1, -1(x3)");
        check(32'h7e741fa3, 3'd1, 32'h000007ff, "sh x7, 2047(x8) (max)");
        check(32'h80952023, 3'd1, 32'hfffff800, "sw x9, -2048(x10) (min)");

        $display("Formato B");
        check(32'hfe208ce3, 3'd2, 32'hfffffff8, "beq x1, x2, -8");
        check(32'h00419863, 3'd2, 32'h00000010, "bne x3, x4, 16");
        check(32'h7e000fe3, 3'd2, 32'h00000ffe, "beq x0, x0, 4094 (max)");
        check(32'h80109063, 3'd2, 32'hfffff000, "bne x1, x1, -4096 (min)");
        check(32'h006280e3, 3'd2, 32'h00000800, "beq x5, x6, 2048 (bit11)");

        $display("Formato U");
        check(32'h123450b7, 3'd3, 32'h12345000, "lui x1, 0x12345");
        check(32'hfffff137, 3'd3, 32'hfffff000, "lui x2, 0xFFFFF");
        check(32'h800001b7, 3'd3, 32'h80000000, "lui x3, 0x80000");
        check(32'h00001237, 3'd3, 32'h00001000, "lui x4, 0x00001");

        $display("Formato J");
        check(32'h010000ef, 3'd4, 32'h00000010, "jal x1, 16");
        check(32'hff9ff06f, 3'd4, 32'hfffffff8, "jal x0, -8");
        check(32'h7ffff0ef, 3'd4, 32'h000ffffe, "jal x1, 1048574 (max)");
        check(32'h800000ef, 3'd4, 32'hfff00000, "jal x1, -1048576 (min)");
        check(32'h001000ef, 3'd4, 32'h00000800, "jal x1, 2048 (bit11)");
        check(32'h000010ef, 3'd4, 32'h00001000, "jal x1, 4096 (bit12)");

        $display("[*] imm_sel invalido da 0");
        check(32'hFFFF_FFFF, 3'd5, 32'h0000_0000, "imm_sel = 5");
        check(32'hFFFF_FFFF, 3'd7, 32'h0000_0000, "imm_sel = 7");

        $display("--------------------------------------------");
        $display("Resultado: %0d verificaciones OK, %0d fallas", pass, fail);
        if (fail == 0) begin
            $display("IMM_GEN: TODO OK");
            $finish;
        end else begin
            $fatal(1, "IMM_GEN: %0d FALLAS", fail);
        end
    end

endmodule
