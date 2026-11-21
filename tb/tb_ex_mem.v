`timescale 1ns / 1ps
// =============================================================================
// tb_ex_mem.v - Testbench autoverificable del latch EX/MEM
// -----------------------------------------------------------------------------
// Agrupa todas las entradas y salidas en dos buses del mismo orden.
// Verifica: reset (burbuja), copia con en = 1, mantiene con en = 0.
// Termina con $fatal si alguna verificación falla.
// =============================================================================
module tb_ex_mem;

    localparam PERIOD = 10;   // periodo del clock en ns (100 MHz)
    localparam NOP    = 32'h0000_0013;

    reg clk = 0, rst = 1, en = 0;

    reg        reg_write, mem_read, mem_write, halt;
    reg [1:0]  wb_sel;
    reg [31:0] alu_result, store_data, pc_plus4, instr;
    reg [4:0]  rd_addr;
    reg [2:0]  funct3;

    wire        q_reg_write, q_mem_read, q_mem_write, q_halt;
    wire [1:0]  q_wb_sel;
    wire [31:0] q_alu_result, q_store_data, q_pc_plus4, q_instr;
    wire [4:0]  q_rd_addr;
    wire [2:0]  q_funct3;

    ex_mem dut (
        .i_clk(clk), .i_rst(rst), .i_en(en),
        .i_reg_write(reg_write), .i_wb_sel(wb_sel), .i_mem_read(mem_read),
        .i_mem_write(mem_write), .i_halt(halt),
        .i_alu_result(alu_result), .i_store_data(store_data), .i_rd_addr(rd_addr),
        .i_funct3(funct3), .i_pc_plus4(pc_plus4), .i_instr(instr),
        .o_reg_write(q_reg_write), .o_wb_sel(q_wb_sel), .o_mem_read(q_mem_read),
        .o_mem_write(q_mem_write), .o_halt(q_halt),
        .o_alu_result(q_alu_result), .o_store_data(q_store_data), .o_rd_addr(q_rd_addr),
        .o_funct3(q_funct3), .o_pc_plus4(q_pc_plus4), .o_instr(q_instr)
    );

    always #(PERIOD/2) clk = ~clk;

    wire [141:0] in_bus  = {reg_write, wb_sel, mem_read, mem_write, halt,
                            alu_result, store_data, rd_addr, funct3, pc_plus4, instr};
    wire [141:0] out_bus = {q_reg_write, q_wb_sel, q_mem_read, q_mem_write, q_halt,
                            q_alu_result, q_store_data, q_rd_addr, q_funct3, q_pc_plus4, q_instr};
    wire [141:0] bubble_bus = {110'd0, NOP};

    integer pass = 0, fail = 0;

    task check(input [141:0] got, input [141:0] exp, input [8*32-1:0] what);
        begin
            if (got === exp) pass = pass + 1;
            else begin
                fail = fail + 1;
                $display("  FALLA: %0s\n    obtenido %h\n    esperado %h", what, got, exp);
            end
        end
    endtask

    task set_inputs(input [7:0] seed);
        begin
            {reg_write, mem_read, mem_write, halt} = seed[3:0];
            wb_sel     = seed[5:4];
            alu_result = 32'hA000_0000 + seed;   store_data = 32'h5000_0000 + seed;
            pc_plus4   = 32'h0000_0100 + seed;   instr      = 32'hC0DE_0000 + seed;
            rd_addr    = seed[4:0];              funct3     = seed[7:5];
        end
    endtask

    reg [141:0] saved;

    initial begin
        $dumpfile("tb_ex_mem.vcd");
        $dumpvars(0, tb_ex_mem);
        set_inputs(8'h00);
        repeat (2) @(negedge clk);
        rst = 0;

        $display("[1] El reset deja una burbuja");
        check(out_bus, bubble_bus, "burbuja tras reset");

        $display("[2] Con en = 1 copia todas las entradas");
        set_inputs(8'h5A); en = 1;
        @(negedge clk);
        check(out_bus, in_bus, "copia juego 0x5A");
        set_inputs(8'hA5);
        @(negedge clk);
        check(out_bus, in_bus, "copia juego 0xA5");

        $display("[3] Con en = 0 mantiene el valor");
        saved = out_bus; en = 0; set_inputs(8'h3C);
        repeat (3) @(negedge clk);
        check(out_bus, saved, "valor mantenido");

        $display("[4] Reset con datos cargados");
        @(negedge clk); rst = 1;
        @(negedge clk); rst = 0;
        check(out_bus, bubble_bus, "burbuja tras segundo reset");

        $display("--------------------------------------------");
        $display("Resultado: %0d verificaciones OK, %0d fallas", pass, fail);
        if (fail == 0) begin
            $display("EX_MEM: TODO OK");
            $finish;
        end else begin
            $fatal(1, "EX_MEM: %0d FALLAS", fail);
        end
    end

endmodule
