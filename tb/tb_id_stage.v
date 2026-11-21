`timescale 1ns / 1ps
// =============================================================================
// tb_id_stage.v - Prueba de integración IF + ID
// -----------------------------------------------------------------------------
// Conecta if_stage con id_stage (como lo hará el top del procesador) y:
//   1. Precarga x1 = 5 y x2 = 3 por el puerto de escritura de WB.
//   2. Carga un programa en la memoria de instrucciones (como la Debug Unit).
//   3. Avanza paso a paso y verifica, para cada instrucción que llega al latch
//      ID/EX: PC, registros leídos, inmediato, rd y señales de control.
//   4. Verifica que o_id_halt se active cuando el HALT llega a ID.
//   5. Verifica que con en = 0 los dos latches queden congelados.
//   6. Verifica el flush de ID/EX (burbuja) y la lectura de debug.
// Termina con $fatal si alguna verificación falla.
// =============================================================================
module tb_id_stage;

    localparam NOP  = 32'h0000_0013;
    localparam HALT = 32'hFFFF_FFFF;

    reg clk = 0, rst = 1, en = 0, flush = 0;
    reg        imem_we = 0;
    reg [7:0]  imem_waddr = 0;
    reg [31:0] imem_wdata = 0;
    reg        wb_we = 0;
    reg [4:0]  wb_rd = 0;
    reg [31:0] wb_data = 0;
    reg [4:0]  dbg_addr = 0;

    // IF -> ID
    wire [31:0] ifid_pc, ifid_pc4, ifid_instr, pc;

    // Salidas de ID
    wire        id_halt, uses1_id, uses2_id;
    wire [4:0]  rs1_id, rs2_id;
    wire [31:0] dbg_data;
    wire        reg_write, mem_read, mem_write, alu_src_a, alu_src_b;
    wire        branch, jump, jalr, uses_rs1, uses_rs2, halt, funct7_b5;
    wire [1:0]  wb_sel, alu_op;
    wire [31:0] ex_pc, ex_pc4, rs1_data, rs2_data, imm, ex_instr;
    wire [4:0]  rs1_addr, rs2_addr, rd_addr;
    wire [2:0]  funct3;

    if_stage #(.DEPTH(256)) u_if (
        .clk(clk), .rst(rst),
        .i_en(en), .i_stall(1'b0), .i_flush(1'b0),
        .i_pc_src(1'b0), .i_pc_target(32'd0),
        .i_imem_we(imem_we), .i_imem_waddr(imem_waddr), .i_imem_wdata(imem_wdata),
        .o_ifid_pc(ifid_pc), .o_ifid_pc_plus4(ifid_pc4), .o_ifid_instr(ifid_instr),
        .o_pc(pc)
    );

    id_stage u_id (
        .clk(clk), .rst(rst), .i_en(en), .i_flush(flush),
        .i_pc(ifid_pc), .i_pc_plus4(ifid_pc4), .i_instr(ifid_instr),
        .i_wb_we(wb_we), .i_wb_rd(wb_rd), .i_wb_data(wb_data),
        .i_dbg_addr(dbg_addr), .o_dbg_data(dbg_data),
        .o_id_halt(id_halt), .o_id_rs1_addr(rs1_id), .o_id_rs2_addr(rs2_id),
        .o_id_uses_rs1(uses1_id), .o_id_uses_rs2(uses2_id),
        .o_reg_write(reg_write), .o_wb_sel(wb_sel), .o_mem_read(mem_read),
        .o_mem_write(mem_write), .o_alu_src_a(alu_src_a), .o_alu_src_b(alu_src_b),
        .o_alu_op(alu_op), .o_branch(branch), .o_jump(jump), .o_jalr(jalr),
        .o_uses_rs1(uses_rs1), .o_uses_rs2(uses_rs2), .o_halt(halt),
        .o_pc(ex_pc), .o_pc_plus4(ex_pc4), .o_rs1_data(rs1_data), .o_rs2_data(rs2_data),
        .o_imm(imm), .o_rs1_addr(rs1_addr), .o_rs2_addr(rs2_addr), .o_rd_addr(rd_addr),
        .o_funct3(funct3), .o_funct7_b5(funct7_b5), .o_instr(ex_instr)
    );

    always #5 clk = ~clk;

    // Programa de prueba (verificable con RARS)
    reg [31:0] prog [0:6];
    initial begin
        prog[0] = 32'h002081b3;   // 0x00 add  x3, x1, x2
        prog[1] = 32'hffd00293;   // 0x04 addi x5, x0, -3
        prog[2] = 32'h00512423;   // 0x08 sw   x5, 8(x2)
        prog[3] = 32'hfe208ce3;   // 0x0c beq  x1, x2, -8
        prog[4] = 32'h123450b7;   // 0x10 lui  x1, 0x12345
        prog[5] = 32'h010000ef;   // 0x14 jal  x1, 16
        prog[6] = HALT;           // 0x18 HALT
    end

    integer pass = 0, fail = 0;
    reg [8*24-1:0] current;

    task chk(input [31:0] got, input [31:0] exp, input [8*12-1:0] what);
        begin
            if (got === exp) pass = pass + 1;
            else begin
                fail = fail + 1;
                $display("  FALLA: %0s -> %0s obtenido %h, esperado %h (t=%0t)",
                         current, what, got, exp, $time);
            end
        end
    endtask

    task step;
        begin
            @(negedge clk); en = 1;
            @(negedge clk); en = 0;
        end
    endtask

    // Verifica el contenido del latch ID/EX
    task check_idex(input [8*24-1:0] name, input [31:0] e_pc, input [31:0] e_instr,
                    input [31:0] e_rs1, input [31:0] e_rs2, input [31:0] e_imm,
                    input [4:0] e_rd, input e_rw, input [1:0] e_wb, input e_mw,
                    input e_asa, input e_asb, input [1:0] e_aop,
                    input e_br, input e_jp, input e_h);
        begin
            current = name;
            chk(ex_pc,     e_pc,     "pc");
            chk(ex_pc4,    e_pc + 4, "pc+4");
            chk(ex_instr,  e_instr,  "instr");
            chk(rs1_data,  e_rs1,    "rs1_data");
            chk(rs2_data,  e_rs2,    "rs2_data");
            chk(imm,       e_imm,    "imm");
            chk(rd_addr,   e_rd,     "rd");
            chk(reg_write, e_rw,     "reg_write");
            chk(wb_sel,    e_wb,     "wb_sel");
            chk(mem_write, e_mw,     "mem_write");
            chk(alu_src_a, e_asa,    "alu_src_a");
            chk(alu_src_b, e_asb,    "alu_src_b");
            chk(alu_op,    e_aop,    "alu_op");
            chk(branch,    e_br,     "branch");
            chk(jump,      e_jp,     "jump");
            chk(halt,      e_h,      "halt");
        end
    endtask

    integer k;
    reg [31:0] saved_ifid, saved_idex;

    initial begin
        $dumpfile("tb_id_stage.vcd");
        $dumpvars(0, tb_id_stage);

        repeat (2) @(negedge clk);
        rst = 0;

        // ---------- 1. Precarga de registros (por el puerto de WB) ----------
        $display("[1] Precarga x1 = 5 y x2 = 3");
        @(negedge clk); wb_we = 1; wb_rd = 1; wb_data = 32'd5;
        @(negedge clk); wb_rd = 2; wb_data = 32'd3;
        @(negedge clk); wb_we = 0;
        dbg_addr = 1; #1; current = "debug"; chk(dbg_data, 32'd5, "x1 (debug)");
        dbg_addr = 2; #1;                    chk(dbg_data, 32'd3, "x2 (debug)");

        // ---------- 2. Carga del programa ----------
        $display("[2] Carga del programa (7 instrucciones)");
        for (k = 0; k < 7; k = k + 1) begin
            @(negedge clk); imem_we = 1; imem_waddr = k; imem_wdata = prog[k];
        end
        @(negedge clk); imem_we = 0;
        current = "carga"; chk(pc, 32'd0, "PC quieto");

        // ---------- 3. Paso a paso ----------
        // Paso 1: la instrucción 0 entra a IF/ID. Paso 2: llega a ID/EX.
        $display("[3] Paso a paso: cada instruccion llega a ID/EX");
        step;
        current = "paso 1"; chk(ifid_instr, prog[0], "IF/ID.instr");
        chk(ex_instr, NOP, "ID/EX vacio");

        // Nota: en los campos que la tabla marca como "no importa" (el inmediato
        // de un tipo R o del HALT, el rd de un branch) se espera el valor que
        // realmente sale, para que el test sea exacto. Esos valores no afectan
        // a nada: la ALU no usa el inmediato si alu_src_b = 0, y no se escribe
        // rd si reg_write = 0.
        //            nombre             pc     instr    rs1    rs2    imm           rd rw wb    mw asa asb aop   br jp h
        step; check_idex("add x3, x1, x2", 32'h00, prog[0], 32'd5, 32'd3, 32'h00000002, 3, 1, 2'b00, 0, 0, 0, 2'b10, 0, 0, 0);
        step; check_idex("addi x5, x0, -3",32'h04, prog[1], 32'd0, 32'd0, 32'hfffffffd, 5, 1, 2'b00, 0, 0, 1, 2'b11, 0, 0, 0);
        step; check_idex("sw x5, 8(x2)",   32'h08, prog[2], 32'd3, 32'd0, 32'h00000008, 8, 0, 2'b00, 1, 0, 1, 2'b00, 0, 0, 0);
        step; check_idex("beq x1, x2, -8", 32'h0c, prog[3], 32'd5, 32'd3, 32'hfffffff8,25, 0, 2'b00, 0, 0, 0, 2'b01, 1, 0, 0);
        step; check_idex("lui x1, 0x12345",32'h10, prog[4], 32'd0, 32'd0, 32'h12345000, 1, 1, 2'b00, 0, 1, 1, 2'b00, 0, 0, 0);

        step; check_idex("jal x1, 16",     32'h14, prog[5], 32'd0, 32'd0, 32'h00000010, 1, 1, 2'b10, 0, 0, 0, 2'b00, 0, 1, 0);
        // Después de 7 pasos el HALT está en IF/ID, es decir, en ID
        $display("[4] HALT en ID activa o_id_halt");
        current = "HALT en ID"; chk(ifid_instr, HALT, "IF/ID.instr"); chk(id_halt, 1'b1, "o_id_halt");

        step; check_idex("HALT",           32'h18, HALT,    32'd0, 32'd0, 32'hffffffff,31, 0, 2'b00, 0, 0, 0, 2'b00, 0, 0, 1);

        // ---------- 5. Congelado ----------
        $display("[5] Con en = 0 IF/ID e ID/EX quedan congelados");
        saved_ifid = ifid_instr; saved_idex = ex_instr;
        repeat (4) @(negedge clk);
        current = "congelado";
        chk(ifid_instr, saved_ifid, "IF/ID.instr");
        chk(ex_instr,   saved_idex, "ID/EX.instr");

        // ---------- 6. Flush de ID/EX ----------
        $display("[6] Flush: burbuja en ID/EX");
        @(negedge clk); en = 1; flush = 1;
        @(negedge clk); en = 0; flush = 0;
        current = "burbuja";
        chk(ex_instr, NOP, "ID/EX.instr");
        chk(reg_write, 1'b0, "reg_write");
        chk(mem_write, 1'b0, "mem_write");
        chk(halt, 1'b0, "halt");

        // ---------- Resultado ----------
        $display("--------------------------------------------");
        $display("Resultado: %0d verificaciones OK, %0d fallas", pass, fail);
        if (fail == 0) begin
            $display("IF + ID: TODO OK");
            $finish;
        end else begin
            $fatal(1, "IF + ID: %0d FALLAS", fail);
        end
    end

endmodule
