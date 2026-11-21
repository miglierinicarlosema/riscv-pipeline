`timescale 1ns / 1ps
// =============================================================================
// tb_id_ex.v - Testbench autoverificable del latch ID/EX
// -----------------------------------------------------------------------------
// Agrupa todas las entradas y todas las salidas en dos buses del mismo orden,
// así una sola comparación verifica las 24 señales.
// Verifica:
//   1. El reset deja una burbuja (control en 0, instrucción NOP).
//   2. Con i_en = 1 copia todas las entradas (dos juegos de valores distintos).
//   3. Con i_en = 0 mantiene el valor aunque cambien las entradas.
//   4. El flush inserta una burbuja.
//   5. Con i_en = 0, el flush no hace nada.
//   6. Después de una burbuja vuelve a copiar normalmente.
// Termina con $fatal si alguna verificación falla.
// =============================================================================
module tb_id_ex;

    localparam PERIOD = 10;   // periodo del clock en ns (100 MHz)

    localparam NOP = 32'h0000_0013;

    reg clk = 0, rst = 1, en = 0, flush = 0;

    // Entradas
    reg        reg_write, mem_read, mem_write, alu_src_a, alu_src_b;
    reg        branch, jump, jalr, uses_rs1, uses_rs2, halt, funct7_b5;
    reg [1:0]  wb_sel, alu_op;
    reg [31:0] pc, pc_plus4, rs1_data, rs2_data, imm, instr;
    reg [4:0]  rs1_addr, rs2_addr, rd_addr;
    reg [2:0]  funct3;

    // Salidas
    wire        q_reg_write, q_mem_read, q_mem_write, q_alu_src_a, q_alu_src_b;
    wire        q_branch, q_jump, q_jalr, q_uses_rs1, q_uses_rs2, q_halt, q_funct7_b5;
    wire [1:0]  q_wb_sel, q_alu_op;
    wire [31:0] q_pc, q_pc_plus4, q_rs1_data, q_rs2_data, q_imm, q_instr;
    wire [4:0]  q_rs1_addr, q_rs2_addr, q_rd_addr;
    wire [2:0]  q_funct3;

    id_ex dut (
        .i_clk(clk), .i_rst(rst), .i_en(en), .i_flush(flush),
        .i_reg_write(reg_write), .i_wb_sel(wb_sel), .i_mem_read(mem_read),
        .i_mem_write(mem_write), .i_alu_src_a(alu_src_a), .i_alu_src_b(alu_src_b),
        .i_alu_op(alu_op), .i_branch(branch), .i_jump(jump), .i_jalr(jalr),
        .i_uses_rs1(uses_rs1), .i_uses_rs2(uses_rs2), .i_halt(halt),
        .i_pc(pc), .i_pc_plus4(pc_plus4), .i_rs1_data(rs1_data), .i_rs2_data(rs2_data),
        .i_imm(imm), .i_rs1_addr(rs1_addr), .i_rs2_addr(rs2_addr), .i_rd_addr(rd_addr),
        .i_funct3(funct3), .i_funct7_b5(funct7_b5), .i_instr(instr),
        .o_reg_write(q_reg_write), .o_wb_sel(q_wb_sel), .o_mem_read(q_mem_read),
        .o_mem_write(q_mem_write), .o_alu_src_a(q_alu_src_a), .o_alu_src_b(q_alu_src_b),
        .o_alu_op(q_alu_op), .o_branch(q_branch), .o_jump(q_jump), .o_jalr(q_jalr),
        .o_uses_rs1(q_uses_rs1), .o_uses_rs2(q_uses_rs2), .o_halt(q_halt),
        .o_pc(q_pc), .o_pc_plus4(q_pc_plus4), .o_rs1_data(q_rs1_data), .o_rs2_data(q_rs2_data),
        .o_imm(q_imm), .o_rs1_addr(q_rs1_addr), .o_rs2_addr(q_rs2_addr), .o_rd_addr(q_rd_addr),
        .o_funct3(q_funct3), .o_funct7_b5(q_funct7_b5), .o_instr(q_instr)
    );

    always #(PERIOD/2) clk = ~clk;

    // Buses con todas las señales, en el mismo orden
    wire [225:0] in_bus  = {reg_write, wb_sel, mem_read, mem_write, alu_src_a, alu_src_b,
                            alu_op, branch, jump, jalr, uses_rs1, uses_rs2, halt,
                            pc, pc_plus4, rs1_data, rs2_data, imm,
                            rs1_addr, rs2_addr, rd_addr, funct3, funct7_b5, instr};
    wire [225:0] out_bus = {q_reg_write, q_wb_sel, q_mem_read, q_mem_write, q_alu_src_a, q_alu_src_b,
                            q_alu_op, q_branch, q_jump, q_jalr, q_uses_rs1, q_uses_rs2, q_halt,
                            q_pc, q_pc_plus4, q_rs1_data, q_rs2_data, q_imm,
                            q_rs1_addr, q_rs2_addr, q_rd_addr, q_funct3, q_funct7_b5, q_instr};
    // Burbuja esperada: todo en 0 salvo la instrucción, que es NOP
    wire [225:0] bubble_bus = {194'd0, NOP};

    integer pass = 0, fail = 0;

    task check(input [225:0] got, input [225:0] exp, input [8*40-1:0] what);
        begin
            if (got === exp) pass = pass + 1;
            else begin
                fail = fail + 1;
                $display("  FALLA: %0s (t=%0t)\n    obtenido %h\n    esperado %h", what, $time, got, exp);
            end
        end
    endtask

    // Carga un juego de valores en las entradas (distinto según "seed")
    task set_inputs(input [7:0] seed);
        begin
            {reg_write, mem_read, mem_write, alu_src_a, alu_src_b} = seed[4:0];
            {branch, jump, jalr, uses_rs1, uses_rs2, halt, funct7_b5} = ~seed[6:0];
            wb_sel = seed[1:0];      alu_op = seed[3:2];
            pc       = 32'h1000_0000 + seed;   pc_plus4 = 32'h1000_0004 + seed;
            rs1_data = 32'hAAAA_0000 + seed;   rs2_data = 32'hBBBB_0000 + seed;
            imm      = 32'hFFFF_FF00 + seed;   instr    = 32'hC0DE_0000 + seed;
            rs1_addr = seed[4:0];   rs2_addr = ~seed[4:0];   rd_addr = seed[5:1];
            funct3   = seed[2:0];
        end
    endtask

    reg [225:0] saved;

    initial begin
        $dumpfile("tb_id_ex.vcd");
        $dumpvars(0, tb_id_ex);
        set_inputs(8'h00);

        // 1. Reset
        repeat (2) @(negedge clk);
        rst = 0;
        $display("[1] El reset deja una burbuja");
        check(out_bus, bubble_bus, "burbuja tras reset");

        // 2. Copia con enable
        $display("[2] Con en = 1 copia todas las entradas");
        set_inputs(8'h5A); en = 1;
        @(negedge clk);
        check(out_bus, in_bus, "copia juego 0x5A");
        set_inputs(8'hA5);
        @(negedge clk);
        check(out_bus, in_bus, "copia juego 0xA5");

        // 3. Mantiene con en = 0
        $display("[3] Con en = 0 mantiene el valor");
        saved = out_bus;
        en = 0; set_inputs(8'h3C);
        repeat (3) @(negedge clk);
        check(out_bus, saved, "valor mantenido");

        // 4. Flush
        $display("[4] El flush inserta una burbuja");
        en = 1; flush = 1;
        @(negedge clk);
        check(out_bus, bubble_bus, "burbuja por flush");
        flush = 0;

        // 5. Flush sin enable
        $display("[5] Con en = 0 el flush no hace nada");
        set_inputs(8'h77);
        @(negedge clk);                 // en = 1: copia 0x77
        saved = out_bus;
        en = 0; flush = 1;
        @(negedge clk);
        check(out_bus, saved, "flush ignorado sin enable");
        flush = 0;

        // 6. Vuelve a copiar
        $display("[6] Despues de una burbuja vuelve a copiar");
        en = 1; set_inputs(8'hE1);
        @(negedge clk);
        check(out_bus, in_bus, "copia juego 0xE1");

        $display("--------------------------------------------");
        $display("Resultado: %0d verificaciones OK, %0d fallas", pass, fail);
        if (fail == 0) begin
            $display("ID_EX: TODO OK");
            $finish;
        end else begin
            $fatal(1, "ID_EX: %0d FALLAS", fail);
        end
    end

endmodule
