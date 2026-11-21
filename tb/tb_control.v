`timescale 1ns / 1ps
// =============================================================================
// tb_control.v - Testbench autoverificable de la unidad de control principal
// -----------------------------------------------------------------------------
// Para cada instrucción compara TODAS las señales con la tabla principal del
// documento "Etapa ID - Tabla de señales de control". Si una falla, imprime
// el nombre de la señal, lo obtenido y lo esperado.
// Cubre: los 8 tipos de instrucción (varias de cada uno), HALT, una
// instrucción inválida, un opcode 1111111 que no es HALT y el NOP.
// Termina con $fatal si alguna verificación falla.
// =============================================================================
module tb_control;

    reg  [31:0] instr;
    wire        reg_write, mem_read, mem_write, alu_src_a, alu_src_b;
    wire        branch, jump, jalr, uses_rs1, uses_rs2, halt;
    wire [1:0]  wb_sel, alu_op;
    wire [2:0]  imm_sel;

    control dut (
        .i_instr(instr),
        .o_reg_write(reg_write), .o_wb_sel(wb_sel),
        .o_mem_read(mem_read),   .o_mem_write(mem_write),
        .o_alu_src_a(alu_src_a), .o_alu_src_b(alu_src_b), .o_alu_op(alu_op),
        .o_branch(branch), .o_jump(jump), .o_jalr(jalr),
        .o_imm_sel(imm_sel),
        .o_uses_rs1(uses_rs1), .o_uses_rs2(uses_rs2),
        .o_halt(halt)
    );

    integer pass = 0, fail = 0;
    reg [8*32-1:0] current;   // instrucción que se está probando (para los mensajes)

    task chk(input [2:0] got, input [2:0] exp, input [8*12-1:0] signal);
        begin
            if (got === exp) pass = pass + 1;
            else begin
                fail = fail + 1;
                $display("  FALLA: %0s -> %0s obtenido %b, esperado %b", current, signal, got, exp);
            end
        end
    endtask

    // Aplica una instrucción y verifica todas las señales.
    // Orden de los argumentos = orden de las columnas de la tabla principal.
    task test(input [31:0] ins, input [8*32-1:0] name,
              input rw, input [1:0] wb, input mr, input mw,
              input asa, input asb, input [1:0] aop,
              input br, input jp, input jr, input [2:0] isel,
              input u1, input u2, input h);
        begin
            instr = ins; current = name; #1;
            chk(reg_write, rw,   "reg_write");
            chk(wb_sel,    wb,   "wb_sel");
            chk(mem_read,  mr,   "mem_read");
            chk(mem_write, mw,   "mem_write");
            chk(alu_src_a, asa,  "alu_src_a");
            chk(alu_src_b, asb,  "alu_src_b");
            chk(alu_op,    aop,  "alu_op");
            chk(branch,    br,   "branch");
            chk(jump,      jp,   "jump");
            chk(jalr,      jr,   "jalr");
            chk(imm_sel,   isel, "imm_sel");
            chk(uses_rs1,  u1,   "uses_rs1");
            chk(uses_rs2,  u2,   "uses_rs2");
            chk(halt,      h,    "halt");
        end
    endtask

    initial begin
        $dumpfile("tb_control.vcd");
        $dumpvars(0, tb_control);
        //                                         rw wb    mr mw asa asb aop   br jp jr isel    u1 u2 h
        $display("[1] Tipo R");
        test(32'h002081b3, "add x3, x1, x2",       1, 2'b00, 0, 0, 0, 0, 2'b10, 0, 0, 0, 3'b000, 1, 1, 0);
        test(32'h40208233, "sub x4, x1, x2",       1, 2'b00, 0, 0, 0, 0, 2'b10, 0, 0, 0, 3'b000, 1, 1, 0);
        test(32'h007342b3, "xor x5, x6, x7",       1, 2'b00, 0, 0, 0, 0, 2'b10, 0, 0, 0, 3'b000, 1, 1, 0);
        test(32'h00a4b433, "sltu x8, x9, x10",     1, 2'b00, 0, 0, 0, 0, 2'b10, 0, 0, 0, 3'b000, 1, 1, 0);

        $display("[2] Tipo I aritmetica");
        test(32'h00500093, "addi x1, x0, 5",       1, 2'b00, 0, 0, 0, 1, 2'b11, 0, 0, 0, 3'b000, 1, 0, 0);
        test(32'h00311093, "slli x1, x2, 3",       1, 2'b00, 0, 0, 0, 1, 2'b11, 0, 0, 0, 3'b000, 1, 0, 0);
        test(32'h40725193, "srai x3, x4, 7",       1, 2'b00, 0, 0, 0, 1, 2'b11, 0, 0, 0, 3'b000, 1, 0, 0);
        test(32'h0ff2f213, "andi x4, x5, 255",     1, 2'b00, 0, 0, 0, 1, 2'b11, 0, 0, 0, 3'b000, 1, 0, 0);
        test(32'h00000013, "nop (addi x0, x0, 0)", 1, 2'b00, 0, 0, 0, 1, 2'b11, 0, 0, 0, 3'b000, 1, 0, 0);

        $display("[3] Loads");
        test(32'hffc12303, "lw x6, -4(x2)",        1, 2'b01, 1, 0, 0, 1, 2'b00, 0, 0, 0, 3'b000, 1, 0, 0);
        test(32'h00344383, "lbu x7, 3(x8)",        1, 2'b01, 1, 0, 0, 1, 2'b00, 0, 0, 0, 3'b000, 1, 0, 0);

        $display("[4] Stores");
        test(32'h00512423, "sw x5, 8(x2)",         0, 2'b00, 0, 1, 0, 1, 2'b00, 0, 0, 0, 3'b001, 1, 1, 0);
        test(32'hfe118fa3, "sb x1, -1(x3)",        0, 2'b00, 0, 1, 0, 1, 2'b00, 0, 0, 0, 3'b001, 1, 1, 0);

        $display("[5] Branches");
        test(32'hfe208ce3, "beq x1, x2, -8",       0, 2'b00, 0, 0, 0, 0, 2'b01, 1, 0, 0, 3'b010, 1, 1, 0);
        test(32'h00419863, "bne x3, x4, 16",       0, 2'b00, 0, 0, 0, 0, 2'b01, 1, 0, 0, 3'b010, 1, 1, 0);

        $display("[6] Saltos");
        test(32'h010000ef, "jal x1, 16",           1, 2'b10, 0, 0, 0, 0, 2'b00, 0, 1, 0, 3'b100, 0, 0, 0);
        test(32'h008280e7, "jalr x1, 8(x5)",       1, 2'b10, 0, 0, 0, 1, 2'b00, 0, 1, 1, 3'b000, 1, 0, 0);
        test(32'h00008067, "jalr x0, 0(x1) (ret)", 1, 2'b10, 0, 0, 0, 1, 2'b00, 0, 1, 1, 3'b000, 1, 0, 0);

        $display("[7] LUI");
        test(32'h123450b7, "lui x1, 0x12345",      1, 2'b00, 0, 0, 1, 1, 2'b00, 0, 0, 0, 3'b011, 0, 0, 0);

        $display("[8] HALT e instrucciones invalidas");
        test(32'hffffffff, "HALT",                 0, 2'b00, 0, 0, 0, 0, 2'b00, 0, 0, 0, 3'b000, 0, 0, 1);
        test(32'h00000000, "0x00000000 (invalida)",0, 2'b00, 0, 0, 0, 0, 2'b00, 0, 0, 0, 3'b000, 0, 0, 0);
        test(32'h0000007f, "opcode 1111111 no HALT",0,2'b00, 0, 0, 0, 0, 2'b00, 0, 0, 0, 3'b000, 0, 0, 0);
        test(32'h00000073, "ecall (no soportada)", 0, 2'b00, 0, 0, 0, 0, 2'b00, 0, 0, 0, 3'b000, 0, 0, 0);

        $display("--------------------------------------------");
        $display("Resultado: %0d verificaciones OK, %0d fallas", pass, fail);
        if (fail == 0) begin
            $display("CONTROL: TODO OK");
            $finish;
        end else begin
            $fatal(1, "CONTROL: %0d FALLAS", fail);
        end
    end

endmodule
