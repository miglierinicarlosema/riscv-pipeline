`timescale 1ns / 1ps
// =============================================================================
// tb_alu_control.v - Testbench autoverificable del control de la ALU
// -----------------------------------------------------------------------------
// Recorre la tabla "Control de la ALU" del documento de la etapa ID:
// las 21 instrucciones que usan la ALU, más casos donde el bit 30 es parte
// del inmediato (addi, ori, andi con inmediato negativo), que tienen que
// dar la operacion normal y NO una resta ni un shift aritmetico.
// Codigos: 0 ADD, 1 SUB, 2 SLL, 3 SLT, 4 SLTU, 5 XOR, 6 SRL, 7 SRA, 8 OR, 9 AND.
// Termina con $fatal si alguna verificacion falla.
// =============================================================================
module tb_alu_control;

    reg  [1:0] alu_op;
    reg  [2:0] funct3;
    reg        b5;
    wire [3:0] ctrl;

    alu_control dut (.i_alu_op(alu_op), .i_funct3(funct3), .i_funct7_b5(b5), .o_alu_ctrl(ctrl));

    integer pass = 0, fail = 0;

    task check(input [1:0] op, input [2:0] f3, input bit30, input [3:0] exp,
               input [8*32-1:0] name);
        begin
            alu_op = op; funct3 = f3; b5 = bit30; #1;
            if (ctrl === exp) pass = pass + 1;
            else begin
                fail = fail + 1;
                $display("  FALLA: %0s -> obtenido %0d, esperado %0d", name, ctrl, exp);
            end
        end
    endtask

    initial begin
        check(2'b00, 3'b000, 1'b0, 4'd0, "lw/sw/jalr/lui (suma)");
        check(2'b00, 3'b101, 1'b1, 4'd0, "suma ignora funct3 y bit 30");
        check(2'b01, 3'b000, 1'b0, 4'd1, "beq (resta)");
        check(2'b01, 3'b001, 1'b0, 4'd1, "bne (resta)");
        check(2'b10, 3'b000, 1'b0, 4'd0, "add");
        check(2'b10, 3'b000, 1'b1, 4'd1, "sub");
        check(2'b10, 3'b001, 1'b0, 4'd2, "sll");
        check(2'b10, 3'b010, 1'b0, 4'd3, "slt");
        check(2'b10, 3'b011, 1'b0, 4'd4, "sltu");
        check(2'b10, 3'b100, 1'b0, 4'd5, "xor");
        check(2'b10, 3'b101, 1'b0, 4'd6, "srl");
        check(2'b10, 3'b101, 1'b1, 4'd7, "sra");
        check(2'b10, 3'b110, 1'b0, 4'd8, "or");
        check(2'b10, 3'b111, 1'b0, 4'd9, "and");
        check(2'b11, 3'b000, 1'b0, 4'd0, "addi");
        check(2'b11, 3'b000, 1'b1, 4'd0, "addi con bit 30 = 1 (-1024)");
        check(2'b11, 3'b001, 1'b0, 4'd2, "slli");
        check(2'b11, 3'b010, 1'b0, 4'd3, "slti");
        check(2'b11, 3'b011, 1'b0, 4'd4, "sltiu");
        check(2'b11, 3'b100, 1'b0, 4'd5, "xori");
        check(2'b11, 3'b101, 1'b0, 4'd6, "srli");
        check(2'b11, 3'b101, 1'b1, 4'd7, "srai");
        check(2'b11, 3'b110, 1'b0, 4'd8, "ori");
        check(2'b11, 3'b111, 1'b0, 4'd9, "andi");
        check(2'b11, 3'b110, 1'b1, 4'd8, "ori con bit 30 = 1");
        check(2'b11, 3'b111, 1'b1, 4'd9, "andi con bit 30 = 1");

        $display("--------------------------------------------");
        $display("Resultado: %0d verificaciones OK, %0d fallas", pass, fail);
        if (fail == 0) begin
            $display("ALU_CONTROL: TODO OK");
            $finish;
        end else begin
            $fatal(1, "ALU_CONTROL: %0d FALLAS", fail);
        end
    end

endmodule
