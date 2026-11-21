`timescale 1ns / 1ps
// =============================================================================
// tb_ex_stage.v - Testbench autoverificable de la etapa EX
// -----------------------------------------------------------------------------
// Carga directamente los valores del latch ID/EX (como si vinieran de ID) y
// verifica, para cada instrucción:
//   - Decisión de salto (o_pc_src) y destino (o_pc_target): combinacionales.
//   - Después de un ciclo con en = 1, el contenido del latch EX/MEM:
//     resultado de la ALU, dato a guardar, rd, PC+4 y señales de MEM/WB.
// Casos: tipo R, tipo I (incluido addi con bit 30 = 1 y srai), slt/sltu, lui,
// load, store, beq/bne tomados y no tomados, jal, jalr (destino impar ->
// bit 0 en 0), forwarding desde MEM y desde WB, enable y reset.
// Termina con $fatal si alguna verificación falla.
// =============================================================================
module tb_ex_stage;

    localparam PERIOD = 10;   // periodo del clock en ns (100 MHz)
    localparam NOP    = 32'h0000_0013;

    reg clk = 0, rst = 1, en = 0;

    // Entradas (latch ID/EX + forwarding)
    reg        reg_write, mem_read, mem_write, alu_src_a, alu_src_b;
    reg        branch, jump, jalr, halt, funct7_b5;
    reg [1:0]  wb_sel, alu_op, fwd_a, fwd_b;
    reg [2:0]  funct3;
    reg [4:0]  rd_addr;
    reg [31:0] pc, pc_plus4, rs1_data, rs2_data, imm, instr, exmem_result, wb_data;

    // Salidas
    wire        pc_src;
    wire [31:0] pc_target;
    wire        q_reg_write, q_mem_read, q_mem_write, q_halt;
    wire [1:0]  q_wb_sel;
    wire [31:0] q_alu_result, q_store_data, q_pc_plus4, q_instr;
    wire [4:0]  q_rd_addr;
    wire [2:0]  q_funct3;

    ex_stage dut (
        .i_clk(clk), .i_rst(rst), .i_en(en),
        .i_reg_write(reg_write), .i_wb_sel(wb_sel), .i_mem_read(mem_read),
        .i_mem_write(mem_write), .i_alu_src_a(alu_src_a), .i_alu_src_b(alu_src_b),
        .i_alu_op(alu_op), .i_branch(branch), .i_jump(jump), .i_jalr(jalr), .i_halt(halt),
        .i_pc(pc), .i_pc_plus4(pc_plus4), .i_rs1_data(rs1_data), .i_rs2_data(rs2_data),
        .i_imm(imm), .i_rd_addr(rd_addr), .i_funct3(funct3), .i_funct7_b5(funct7_b5),
        .i_instr(instr),
        .i_fwd_a(fwd_a), .i_fwd_b(fwd_b), .i_exmem_result(exmem_result), .i_wb_data(wb_data),
        .o_pc_src(pc_src), .o_pc_target(pc_target),
        .o_reg_write(q_reg_write), .o_wb_sel(q_wb_sel), .o_mem_read(q_mem_read),
        .o_mem_write(q_mem_write), .o_halt(q_halt),
        .o_alu_result(q_alu_result), .o_store_data(q_store_data), .o_rd_addr(q_rd_addr),
        .o_funct3(q_funct3), .o_pc_plus4(q_pc_plus4), .o_instr(q_instr)
    );

    always #(PERIOD/2) clk = ~clk;

    integer pass = 0, fail = 0;
    reg [8*28-1:0] current;

    task chk(input [31:0] got, input [31:0] exp, input [8*12-1:0] what);
        begin
            if (got === exp) pass = pass + 1;
            else begin
                fail = fail + 1;
                $display("  FALLA: %0s -> %0s obtenido %h, esperado %h", current, what, got, exp);
            end
        end
    endtask

    // Valores por defecto: una burbuja en ID/EX, sin forwarding
    task clear;
        begin
            reg_write = 0; wb_sel = 2'b00; mem_read = 0; mem_write = 0;
            alu_src_a = 0; alu_src_b = 0; alu_op = 2'b00;
            branch = 0; jump = 0; jalr = 0; halt = 0;
            funct3 = 3'b000; funct7_b5 = 0; rd_addr = 5'd0;
            pc = 32'h0000_0100; pc_plus4 = 32'h0000_0104;
            rs1_data = 0; rs2_data = 0; imm = 0; instr = NOP;
            fwd_a = 2'b00; fwd_b = 2'b00;
            exmem_result = 32'hEEEE_EEEE; wb_data = 32'hBBBB_BBBB;
        end
    endtask

    // Verifica el salto (combinacional), da un paso y verifica EX/MEM
    task go(input [8*28-1:0] name, input [31:0] e_result, input [31:0] e_store,
            input e_pc_src, input [31:0] e_target);
        begin
            current = name;
            #1;
            chk(pc_src, e_pc_src, "pc_src");
            if (e_pc_src) chk(pc_target, e_target, "pc_target");
            @(negedge clk); en = 1;
            @(negedge clk); en = 0;
            chk(q_alu_result, e_result,  "alu_result");
            chk(q_store_data, e_store,   "store_data");
            chk(q_rd_addr,    rd_addr,   "rd");
            chk(q_reg_write,  reg_write, "reg_write");
            chk(q_wb_sel,     wb_sel,    "wb_sel");
            chk(q_mem_read,   mem_read,  "mem_read");
            chk(q_mem_write,  mem_write, "mem_write");
            chk(q_funct3,     funct3,    "funct3");
            chk(q_pc_plus4,   pc_plus4,  "pc+4");
            chk(q_instr,      instr,     "instr");
        end
    endtask

    reg [31:0] saved;

    initial begin
        $dumpfile("tb_ex_stage.vcd");
        $dumpvars(0, tb_ex_stage);
        clear;
        repeat (2) @(negedge clk);
        rst = 0;

        $display("[1] Tipo R y tipo I");
        clear; reg_write = 1; alu_op = 2'b10; rd_addr = 3; rs1_data = 5; rs2_data = 3; instr = 32'h002081b3;
        go("add x3, x1, x2",          32'd8, 32'd3, 0, 0);

        clear; reg_write = 1; alu_op = 2'b10; funct7_b5 = 1; rd_addr = 4; rs1_data = 5; rs2_data = 3; instr = 32'h40208233;
        go("sub x4, x1, x2",          32'd2, 32'd3, 0, 0);

        clear; reg_write = 1; alu_op = 2'b11; alu_src_b = 1; rd_addr = 5; imm = 32'hfffffffd; instr = 32'hffd00293;
        go("addi x5, x0, -3",         32'hfffffffd, 32'd0, 0, 0);

        clear; reg_write = 1; alu_op = 2'b11; alu_src_b = 1; funct7_b5 = 1; rd_addr = 1;
        rs1_data = 32'h1000; imm = 32'hfffffc00; instr = 32'hc0008093;
        go("addi x1, x1, -1024",      32'h00000c00, 32'd0, 0, 0);

        clear; reg_write = 1; alu_op = 2'b11; alu_src_b = 1; funct3 = 3'b101; funct7_b5 = 1; rd_addr = 3;
        rs1_data = 32'h80000000; imm = 32'h00000407; instr = 32'h40725193;
        go("srai x3, x4, 7",          32'hff000000, 32'd0, 0, 0);

        clear; reg_write = 1; alu_op = 2'b10; funct3 = 3'b011; rd_addr = 8; rs1_data = 1; rs2_data = 32'hffffffff;
        go("sltu (1 < 0xffffffff)",   32'd1, 32'hffffffff, 0, 0);

        clear; reg_write = 1; alu_op = 2'b10; funct3 = 3'b010; rd_addr = 8; rs1_data = 1; rs2_data = 32'hffffffff;
        go("slt (1 < -1 es falso)",   32'd0, 32'hffffffff, 0, 0);

        $display("[2] LUI (operando A en cero)");
        clear; reg_write = 1; alu_src_a = 1; alu_src_b = 1; rd_addr = 1;
        rs1_data = 32'hdeadbeef; imm = 32'h12345000; instr = 32'h123450b7;
        go("lui x1, 0x12345",         32'h12345000, 32'd0, 0, 0);

        $display("[3] Load y store");
        clear; reg_write = 1; wb_sel = 2'b01; mem_read = 1; alu_src_b = 1; funct3 = 3'b010; rd_addr = 6;
        rs1_data = 32'h2000; imm = 32'hfffffffc; instr = 32'hffc12303;
        go("lw x6, -4(x2)",           32'h00001ffc, 32'd0, 0, 0);

        clear; mem_write = 1; alu_src_b = 1; funct3 = 3'b010; rd_addr = 8;
        rs1_data = 32'h2000; rs2_data = 32'h0000cafe; imm = 32'd8; instr = 32'h00512423;
        go("sw x5, 8(x2)",            32'h00002008, 32'h0000cafe, 0, 0);

        $display("[4] Branches");
        clear; branch = 1; alu_op = 2'b01; rs1_data = 5; rs2_data = 5; imm = 32'hfffffff8; instr = 32'hfe208ce3;
        go("beq tomado (5 = 5)",      32'd0, 32'd5, 1, 32'h000000f8);

        clear; branch = 1; alu_op = 2'b01; rs1_data = 5; rs2_data = 3; imm = 32'hfffffff8; instr = 32'hfe208ce3;
        go("beq no tomado (5 != 3)",  32'd2, 32'd3, 0, 0);

        clear; branch = 1; alu_op = 2'b01; funct3 = 3'b001; rs1_data = 5; rs2_data = 3; imm = 32'h10; instr = 32'h00419863;
        go("bne tomado (5 != 3)",     32'd2, 32'd3, 1, 32'h00000110);

        clear; branch = 1; alu_op = 2'b01; funct3 = 3'b001; rs1_data = 7; rs2_data = 7; imm = 32'h10; instr = 32'h00419863;
        go("bne no tomado (7 = 7)",   32'd0, 32'd7, 0, 0);

        $display("[5] Saltos incondicionales");
        clear; reg_write = 1; wb_sel = 2'b10; jump = 1; rd_addr = 1; imm = 32'h10; instr = 32'h010000ef;
        go("jal x1, 16",              32'd0, 32'd0, 1, 32'h00000110);

        clear; reg_write = 1; wb_sel = 2'b10; jump = 1; jalr = 1; alu_src_b = 1; rd_addr = 1;
        rs1_data = 32'h2003; imm = 32'd8; instr = 32'h008280e7;
        go("jalr x1, 8(x5) impar",    32'h0000200b, 32'd0, 1, 32'h0000200a);

        $display("[6] Forwarding");
        clear; reg_write = 1; alu_op = 2'b10; rd_addr = 3; rs1_data = 32'h11111111; rs2_data = 32'h22222222;
        fwd_a = 2'b10; fwd_b = 2'b01; exmem_result = 32'd100; wb_data = 32'd23;
        go("add con fwd A=MEM, B=WB", 32'd123, 32'd23, 0, 0);

        clear; mem_write = 1; alu_src_b = 1; funct3 = 3'b010; rs1_data = 32'h2000; rs2_data = 32'h99999999;
        imm = 32'd4; fwd_b = 2'b10; exmem_result = 32'h0000beef;
        go("sw con fwd del dato",     32'h00002004, 32'h0000beef, 0, 0);

        clear; branch = 1; alu_op = 2'b01; rs1_data = 1; rs2_data = 2; imm = 32'h20;
        fwd_a = 2'b01; fwd_b = 2'b01; wb_data = 32'd42;
        go("beq con fwd (42 = 42)",   32'd0, 32'd42, 1, 32'h00000120);

        $display("[7] Enable y reset");
        current = "en = 0";
        saved = q_alu_result;
        clear; reg_write = 1; alu_op = 2'b10; rs1_data = 32'd1000; rs2_data = 32'd1;
        repeat (3) @(negedge clk);
        chk(q_alu_result, saved, "alu_result");
        current = "reset";
        @(negedge clk); rst = 1;
        @(negedge clk); rst = 0;
        chk(q_reg_write, 1'b0, "reg_write");
        chk(q_mem_write, 1'b0, "mem_write");
        chk(q_instr, NOP, "instr");

        $display("--------------------------------------------");
        $display("Resultado: %0d verificaciones OK, %0d fallas", pass, fail);
        if (fail == 0) begin
            $display("EX: TODO OK");
            $finish;
        end else begin
            $fatal(1, "EX: %0d FALLAS", fail);
        end
    end

endmodule
