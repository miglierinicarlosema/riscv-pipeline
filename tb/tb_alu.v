`timescale 1ns / 1ps
// =============================================================================
// tb_alu.v - Testbench autoverificable de la ALU
// -----------------------------------------------------------------------------
// Resultados esperados generados con un modelo de referencia en Python,
// independiente del Verilog. Para cada una de las 10 operaciones:
//   - 15 casos límite: overflow (0x7fffffff + 1), negativos, comparaciones
//     con y sin signo cruzadas (0x80000000 vs 0x7fffffff), shifts de 0 y 31
//     posiciones y shifts con B > 31 (solo cuentan los 5 bits bajos).
//   - 10 casos aleatorios.
// También verifica o_zero en cada caso y que un código inválido dé 0.
// Termina con $fatal si alguna verificación falla.
// =============================================================================
module tb_alu;

    reg  [31:0] a, b;
    reg  [3:0]  ctrl;
    wire [31:0] result;
    wire        zero;

    alu dut (.i_a(a), .i_b(b), .i_alu_ctrl(ctrl), .o_result(result), .o_zero(zero));

    integer pass = 0, fail = 0;

    task check(input [31:0] ia, input [31:0] ib, input [3:0] ic,
               input [31:0] exp, input [8*4-1:0] op);
        begin
            a = ia; b = ib; ctrl = ic; #1;
            if (result === exp && zero === (exp == 32'd0)) pass = pass + 1;
            else begin
                fail = fail + 1;
                $display("  FALLA: %0s a=%h b=%h -> obtenido %h (zero=%b), esperado %h",
                         op, ia, ib, result, zero, exp);
            end
        end
    endtask

    initial begin
        $display("ADD");
        check(32'h00000000, 32'h00000000, 4'd0, 32'h00000000, "ADD");
        check(32'h00000005, 32'h00000003, 4'd0, 32'h00000008, "ADD");
        check(32'h00000003, 32'h00000005, 4'd0, 32'h00000008, "ADD");
        check(32'h7fffffff, 32'h00000001, 4'd0, 32'h80000000, "ADD");
        check(32'h80000000, 32'h00000001, 4'd0, 32'h80000001, "ADD");
        check(32'hffffffff, 32'h00000001, 4'd0, 32'h00000000, "ADD");
        check(32'hffffffff, 32'hffffffff, 4'd0, 32'hfffffffe, "ADD");
        check(32'h80000000, 32'h7fffffff, 4'd0, 32'hffffffff, "ADD");
        check(32'h7fffffff, 32'h80000000, 4'd0, 32'hffffffff, "ADD");
        check(32'hfffffffd, 32'h00000005, 4'd0, 32'h00000002, "ADD");
        check(32'h12345678, 32'h00000000, 4'd0, 32'h12345678, "ADD");
        check(32'h12345678, 32'h0000001f, 4'd0, 32'h12345697, "ADD");
        check(32'h80000000, 32'h0000001f, 4'd0, 32'h8000001f, "ADD");
        check(32'hdeadbeef, 32'h00000024, 4'd0, 32'hdeadbf13, "ADD");
        check(32'h00000001, 32'hffffffe1, 4'd0, 32'hffffffe2, "ADD");
        check(32'h1e7ea419, 32'h51c9bc70, 4'd0, 32'h70486089, "ADD");
        check(32'h80a4df5a, 32'hf38b2ffc, 4'd0, 32'h74300f56, "ADD");
        check(32'h8306d03b, 32'ha5aec797, 4'd0, 32'h28b597d2, "ADD");
        check(32'hdc28ff90, 32'hf3f49249, 4'd0, 32'hd01d91d9, "ADD");
        check(32'h1a466884, 32'he255accb, 4'd0, 32'hfc9c154f, "ADD");
        check(32'h39292d22, 32'he5121482, 4'd0, 32'h1e3b41a4, "ADD");
        check(32'h99dd251d, 32'h9f199504, 4'd0, 32'h38f6ba21, "ADD");
        check(32'h8e7aa6e9, 32'h6bad6be2, 4'd0, 32'hfa2812cb, "ADD");
        check(32'hc88b2875, 32'h9293de8f, 4'd0, 32'h5b1f0704, "ADD");
        check(32'h8c3d5f16, 32'hd7a7a3cc, 4'd0, 32'h63e502e2, "ADD");
        $display("SUB");
        check(32'h00000000, 32'h00000000, 4'd1, 32'h00000000, "SUB");
        check(32'h00000005, 32'h00000003, 4'd1, 32'h00000002, "SUB");
        check(32'h00000003, 32'h00000005, 4'd1, 32'hfffffffe, "SUB");
        check(32'h7fffffff, 32'h00000001, 4'd1, 32'h7ffffffe, "SUB");
        check(32'h80000000, 32'h00000001, 4'd1, 32'h7fffffff, "SUB");
        check(32'hffffffff, 32'h00000001, 4'd1, 32'hfffffffe, "SUB");
        check(32'hffffffff, 32'hffffffff, 4'd1, 32'h00000000, "SUB");
        check(32'h80000000, 32'h7fffffff, 4'd1, 32'h00000001, "SUB");
        check(32'h7fffffff, 32'h80000000, 4'd1, 32'hffffffff, "SUB");
        check(32'hfffffffd, 32'h00000005, 4'd1, 32'hfffffff8, "SUB");
        check(32'h12345678, 32'h00000000, 4'd1, 32'h12345678, "SUB");
        check(32'h12345678, 32'h0000001f, 4'd1, 32'h12345659, "SUB");
        check(32'h80000000, 32'h0000001f, 4'd1, 32'h7fffffe1, "SUB");
        check(32'hdeadbeef, 32'h00000024, 4'd1, 32'hdeadbecb, "SUB");
        check(32'h00000001, 32'hffffffe1, 4'd1, 32'h00000020, "SUB");
        check(32'hbb049a79, 32'hc6cd75e9, 4'd1, 32'hf4372490, "SUB");
        check(32'hc4a334bf, 32'h7dabe929, 4'd1, 32'h46f74b96, "SUB");
        check(32'hc0433cbd, 32'hc5e818fa, 4'd1, 32'hfa5b23c3, "SUB");
        check(32'h96263ae6, 32'h70eb9a0a, 4'd1, 32'h253aa0dc, "SUB");
        check(32'h3d6c51e3, 32'h00a61f93, 4'd1, 32'h3cc63250, "SUB");
        check(32'h9d3c7dec, 32'h14aa4e71, 4'd1, 32'h88922f7b, "SUB");
        check(32'h1c593af5, 32'h49889310, 4'd1, 32'hd2d0a7e5, "SUB");
        check(32'hd11745ad, 32'h1919e93a, 4'd1, 32'hb7fd5c73, "SUB");
        check(32'h731c9452, 32'h02f0ee99, 4'd1, 32'h702ba5b9, "SUB");
        check(32'hd0944996, 32'he4163207, 4'd1, 32'hec7e178f, "SUB");
        $display("SLL");
        check(32'h00000000, 32'h00000000, 4'd2, 32'h00000000, "SLL");
        check(32'h00000005, 32'h00000003, 4'd2, 32'h00000028, "SLL");
        check(32'h00000003, 32'h00000005, 4'd2, 32'h00000060, "SLL");
        check(32'h7fffffff, 32'h00000001, 4'd2, 32'hfffffffe, "SLL");
        check(32'h80000000, 32'h00000001, 4'd2, 32'h00000000, "SLL");
        check(32'hffffffff, 32'h00000001, 4'd2, 32'hfffffffe, "SLL");
        check(32'hffffffff, 32'hffffffff, 4'd2, 32'h80000000, "SLL");
        check(32'h80000000, 32'h7fffffff, 4'd2, 32'h00000000, "SLL");
        check(32'h7fffffff, 32'h80000000, 4'd2, 32'h7fffffff, "SLL");
        check(32'hfffffffd, 32'h00000005, 4'd2, 32'hffffffa0, "SLL");
        check(32'h12345678, 32'h00000000, 4'd2, 32'h12345678, "SLL");
        check(32'h12345678, 32'h0000001f, 4'd2, 32'h00000000, "SLL");
        check(32'h80000000, 32'h0000001f, 4'd2, 32'h00000000, "SLL");
        check(32'hdeadbeef, 32'h00000024, 4'd2, 32'headbeef0, "SLL");
        check(32'h00000001, 32'hffffffe1, 4'd2, 32'h00000002, "SLL");
        check(32'haf67d461, 32'h7d836e77, 4'd2, 32'h30800000, "SLL");
        check(32'hadec6f11, 32'h5071950e, 4'd2, 32'h1bc44000, "SLL");
        check(32'h35d14880, 32'h65b00a2d, 4'd2, 32'h29100000, "SLL");
        check(32'h406329bc, 32'h59001ac9, 4'd2, 32'hc6537800, "SLL");
        check(32'hfadb8908, 32'hffb88309, 4'd2, 32'hb7121000, "SLL");
        check(32'hede7bd0c, 32'h5b4c8012, 4'd2, 32'hf4300000, "SLL");
        check(32'hce1d62e0, 32'h60581cca, 4'd2, 32'h758b8000, "SLL");
        check(32'hffe976ab, 32'hbef7e268, 4'd2, 32'he976ab00, "SLL");
        check(32'h837a7935, 32'ha341738c, 4'd2, 32'ha7935000, "SLL");
        check(32'h1389b372, 32'hb91dddd9, 4'd2, 32'he4000000, "SLL");
        $display("SLT");
        check(32'h00000000, 32'h00000000, 4'd3, 32'h00000000, "SLT");
        check(32'h00000005, 32'h00000003, 4'd3, 32'h00000000, "SLT");
        check(32'h00000003, 32'h00000005, 4'd3, 32'h00000001, "SLT");
        check(32'h7fffffff, 32'h00000001, 4'd3, 32'h00000000, "SLT");
        check(32'h80000000, 32'h00000001, 4'd3, 32'h00000001, "SLT");
        check(32'hffffffff, 32'h00000001, 4'd3, 32'h00000001, "SLT");
        check(32'hffffffff, 32'hffffffff, 4'd3, 32'h00000000, "SLT");
        check(32'h80000000, 32'h7fffffff, 4'd3, 32'h00000001, "SLT");
        check(32'h7fffffff, 32'h80000000, 4'd3, 32'h00000000, "SLT");
        check(32'hfffffffd, 32'h00000005, 4'd3, 32'h00000001, "SLT");
        check(32'h12345678, 32'h00000000, 4'd3, 32'h00000000, "SLT");
        check(32'h12345678, 32'h0000001f, 4'd3, 32'h00000000, "SLT");
        check(32'h80000000, 32'h0000001f, 4'd3, 32'h00000001, "SLT");
        check(32'hdeadbeef, 32'h00000024, 4'd3, 32'h00000001, "SLT");
        check(32'h00000001, 32'hffffffe1, 4'd3, 32'h00000000, "SLT");
        check(32'h57241955, 32'h16f44881, 4'd3, 32'h00000000, "SLT");
        check(32'h8eb5140f, 32'h89be9c1c, 4'd3, 32'h00000000, "SLT");
        check(32'h4ac87fc0, 32'h49a047dc, 4'd3, 32'h00000000, "SLT");
        check(32'h751b4c83, 32'h24114258, 4'd3, 32'h00000000, "SLT");
        check(32'he060a724, 32'ha51149bb, 4'd3, 32'h00000000, "SLT");
        check(32'hb437bdb5, 32'hb766ff10, 4'd3, 32'h00000001, "SLT");
        check(32'h93d20470, 32'h4f1a8a1d, 4'd3, 32'h00000001, "SLT");
        check(32'h06555096, 32'hd9090b89, 4'd3, 32'h00000000, "SLT");
        check(32'hb5fb12e0, 32'h5e6c9992, 4'd3, 32'h00000001, "SLT");
        check(32'h5d111a9d, 32'h7608d942, 4'd3, 32'h00000001, "SLT");
        $display("SLTU");
        check(32'h00000000, 32'h00000000, 4'd4, 32'h00000000, "SLTU");
        check(32'h00000005, 32'h00000003, 4'd4, 32'h00000000, "SLTU");
        check(32'h00000003, 32'h00000005, 4'd4, 32'h00000001, "SLTU");
        check(32'h7fffffff, 32'h00000001, 4'd4, 32'h00000000, "SLTU");
        check(32'h80000000, 32'h00000001, 4'd4, 32'h00000000, "SLTU");
        check(32'hffffffff, 32'h00000001, 4'd4, 32'h00000000, "SLTU");
        check(32'hffffffff, 32'hffffffff, 4'd4, 32'h00000000, "SLTU");
        check(32'h80000000, 32'h7fffffff, 4'd4, 32'h00000000, "SLTU");
        check(32'h7fffffff, 32'h80000000, 4'd4, 32'h00000001, "SLTU");
        check(32'hfffffffd, 32'h00000005, 4'd4, 32'h00000000, "SLTU");
        check(32'h12345678, 32'h00000000, 4'd4, 32'h00000000, "SLTU");
        check(32'h12345678, 32'h0000001f, 4'd4, 32'h00000000, "SLTU");
        check(32'h80000000, 32'h0000001f, 4'd4, 32'h00000000, "SLTU");
        check(32'hdeadbeef, 32'h00000024, 4'd4, 32'h00000000, "SLTU");
        check(32'h00000001, 32'hffffffe1, 4'd4, 32'h00000001, "SLTU");
        check(32'h6c167229, 32'h17371472, 4'd4, 32'h00000000, "SLTU");
        check(32'h66160227, 32'he41686cd, 4'd4, 32'h00000001, "SLTU");
        check(32'h95f19a51, 32'h8df05f25, 4'd4, 32'h00000000, "SLTU");
        check(32'h7f9ac098, 32'hde0279e1, 4'd4, 32'h00000001, "SLTU");
        check(32'h1dcf884c, 32'h6ce9da66, 4'd4, 32'h00000001, "SLTU");
        check(32'h81a0ba05, 32'hcd73de00, 4'd4, 32'h00000001, "SLTU");
        check(32'hc0099eba, 32'hdde3a361, 4'd4, 32'h00000001, "SLTU");
        check(32'h99a46df0, 32'he01c683e, 4'd4, 32'h00000001, "SLTU");
        check(32'h7db4304d, 32'h65ed0de4, 4'd4, 32'h00000000, "SLTU");
        check(32'heab06e9b, 32'h864fa3f3, 4'd4, 32'h00000000, "SLTU");
        $display("XOR");
        check(32'h00000000, 32'h00000000, 4'd5, 32'h00000000, "XOR");
        check(32'h00000005, 32'h00000003, 4'd5, 32'h00000006, "XOR");
        check(32'h00000003, 32'h00000005, 4'd5, 32'h00000006, "XOR");
        check(32'h7fffffff, 32'h00000001, 4'd5, 32'h7ffffffe, "XOR");
        check(32'h80000000, 32'h00000001, 4'd5, 32'h80000001, "XOR");
        check(32'hffffffff, 32'h00000001, 4'd5, 32'hfffffffe, "XOR");
        check(32'hffffffff, 32'hffffffff, 4'd5, 32'h00000000, "XOR");
        check(32'h80000000, 32'h7fffffff, 4'd5, 32'hffffffff, "XOR");
        check(32'h7fffffff, 32'h80000000, 4'd5, 32'hffffffff, "XOR");
        check(32'hfffffffd, 32'h00000005, 4'd5, 32'hfffffff8, "XOR");
        check(32'h12345678, 32'h00000000, 4'd5, 32'h12345678, "XOR");
        check(32'h12345678, 32'h0000001f, 4'd5, 32'h12345667, "XOR");
        check(32'h80000000, 32'h0000001f, 4'd5, 32'h8000001f, "XOR");
        check(32'hdeadbeef, 32'h00000024, 4'd5, 32'hdeadbecb, "XOR");
        check(32'h00000001, 32'hffffffe1, 4'd5, 32'hffffffe0, "XOR");
        check(32'h423674a6, 32'hd82fb0f1, 4'd5, 32'h9a19c457, "XOR");
        check(32'h6b82e6c9, 32'h90624fe3, 4'd5, 32'hfbe0a92a, "XOR");
        check(32'hed1d9d16, 32'hfb759e0f, 4'd5, 32'h16680319, "XOR");
        check(32'h7aac319f, 32'h8350a73f, 4'd5, 32'hf9fc96a0, "XOR");
        check(32'h849acfb5, 32'hce1fd3d9, 4'd5, 32'h4a851c6c, "XOR");
        check(32'h067f0cfc, 32'h93550840, 4'd5, 32'h952a04bc, "XOR");
        check(32'h397a7623, 32'hc40d31b5, 4'd5, 32'hfd774796, "XOR");
        check(32'h2106119e, 32'hd1711cbd, 4'd5, 32'hf0770d23, "XOR");
        check(32'h0c83e786, 32'hf675299b, 4'd5, 32'hfaf6ce1d, "XOR");
        check(32'hb464c554, 32'h85f184e0, 4'd5, 32'h319541b4, "XOR");
        $display("SRL");
        check(32'h00000000, 32'h00000000, 4'd6, 32'h00000000, "SRL");
        check(32'h00000005, 32'h00000003, 4'd6, 32'h00000000, "SRL");
        check(32'h00000003, 32'h00000005, 4'd6, 32'h00000000, "SRL");
        check(32'h7fffffff, 32'h00000001, 4'd6, 32'h3fffffff, "SRL");
        check(32'h80000000, 32'h00000001, 4'd6, 32'h40000000, "SRL");
        check(32'hffffffff, 32'h00000001, 4'd6, 32'h7fffffff, "SRL");
        check(32'hffffffff, 32'hffffffff, 4'd6, 32'h00000001, "SRL");
        check(32'h80000000, 32'h7fffffff, 4'd6, 32'h00000001, "SRL");
        check(32'h7fffffff, 32'h80000000, 4'd6, 32'h7fffffff, "SRL");
        check(32'hfffffffd, 32'h00000005, 4'd6, 32'h07ffffff, "SRL");
        check(32'h12345678, 32'h00000000, 4'd6, 32'h12345678, "SRL");
        check(32'h12345678, 32'h0000001f, 4'd6, 32'h00000000, "SRL");
        check(32'h80000000, 32'h0000001f, 4'd6, 32'h00000001, "SRL");
        check(32'hdeadbeef, 32'h00000024, 4'd6, 32'h0deadbee, "SRL");
        check(32'h00000001, 32'hffffffe1, 4'd6, 32'h00000000, "SRL");
        check(32'he306f0c4, 32'haba4c70e, 4'd6, 32'h00038c1b, "SRL");
        check(32'h1a42721e, 32'hb7a1774f, 4'd6, 32'h00003484, "SRL");
        check(32'h9f4fb02b, 32'h6dedc86a, 4'd6, 32'h0027d3ec, "SRL");
        check(32'h78549014, 32'h2475263c, 4'd6, 32'h00000007, "SRL");
        check(32'h7b6bc3c6, 32'he261e34a, 4'd6, 32'h001edaf0, "SRL");
        check(32'h3a9afa39, 32'hd9814559, 4'd6, 32'h0000001d, "SRL");
        check(32'he2cbbb93, 32'h1f3c42b2, 4'd6, 32'h000038b2, "SRL");
        check(32'ha06d7a69, 32'hb3618e1c, 4'd6, 32'h0000000a, "SRL");
        check(32'h74f09af5, 32'hac9f21df, 4'd6, 32'h00000000, "SRL");
        check(32'h782afe6b, 32'hb6eafff5, 4'd6, 32'h000003c1, "SRL");
        $display("SRA");
        check(32'h00000000, 32'h00000000, 4'd7, 32'h00000000, "SRA");
        check(32'h00000005, 32'h00000003, 4'd7, 32'h00000000, "SRA");
        check(32'h00000003, 32'h00000005, 4'd7, 32'h00000000, "SRA");
        check(32'h7fffffff, 32'h00000001, 4'd7, 32'h3fffffff, "SRA");
        check(32'h80000000, 32'h00000001, 4'd7, 32'hc0000000, "SRA");
        check(32'hffffffff, 32'h00000001, 4'd7, 32'hffffffff, "SRA");
        check(32'hffffffff, 32'hffffffff, 4'd7, 32'hffffffff, "SRA");
        check(32'h80000000, 32'h7fffffff, 4'd7, 32'hffffffff, "SRA");
        check(32'h7fffffff, 32'h80000000, 4'd7, 32'h7fffffff, "SRA");
        check(32'hfffffffd, 32'h00000005, 4'd7, 32'hffffffff, "SRA");
        check(32'h12345678, 32'h00000000, 4'd7, 32'h12345678, "SRA");
        check(32'h12345678, 32'h0000001f, 4'd7, 32'h00000000, "SRA");
        check(32'h80000000, 32'h0000001f, 4'd7, 32'hffffffff, "SRA");
        check(32'hdeadbeef, 32'h00000024, 4'd7, 32'hfdeadbee, "SRA");
        check(32'h00000001, 32'hffffffe1, 4'd7, 32'h00000000, "SRA");
        check(32'hedf165da, 32'hf5a9ca5f, 4'd7, 32'hffffffff, "SRA");
        check(32'hfcbad167, 32'hfa97002c, 4'd7, 32'hffffcbad, "SRA");
        check(32'h8bae8e66, 32'h4041f5ee, 4'd7, 32'hfffe2eba, "SRA");
        check(32'h8f4ecb4f, 32'h66eebc57, 4'd7, 32'hffffff1e, "SRA");
        check(32'hab74fe57, 32'hff8b2a6a, 4'd7, 32'hffeadd3f, "SRA");
        check(32'h4ec0a954, 32'h8c53765f, 4'd7, 32'h00000000, "SRA");
        check(32'hccbfd2ec, 32'ha598d0db, 4'd7, 32'hfffffff9, "SRA");
        check(32'h807c7e30, 32'hb2c55523, 4'd7, 32'hf00f8fc6, "SRA");
        check(32'h7a98b9ac, 32'hce0d8d87, 4'd7, 32'h00f53173, "SRA");
        check(32'he26b524a, 32'h66e61127, 4'd7, 32'hffc4d6a4, "SRA");
        $display("OR");
        check(32'h00000000, 32'h00000000, 4'd8, 32'h00000000, "OR");
        check(32'h00000005, 32'h00000003, 4'd8, 32'h00000007, "OR");
        check(32'h00000003, 32'h00000005, 4'd8, 32'h00000007, "OR");
        check(32'h7fffffff, 32'h00000001, 4'd8, 32'h7fffffff, "OR");
        check(32'h80000000, 32'h00000001, 4'd8, 32'h80000001, "OR");
        check(32'hffffffff, 32'h00000001, 4'd8, 32'hffffffff, "OR");
        check(32'hffffffff, 32'hffffffff, 4'd8, 32'hffffffff, "OR");
        check(32'h80000000, 32'h7fffffff, 4'd8, 32'hffffffff, "OR");
        check(32'h7fffffff, 32'h80000000, 4'd8, 32'hffffffff, "OR");
        check(32'hfffffffd, 32'h00000005, 4'd8, 32'hfffffffd, "OR");
        check(32'h12345678, 32'h00000000, 4'd8, 32'h12345678, "OR");
        check(32'h12345678, 32'h0000001f, 4'd8, 32'h1234567f, "OR");
        check(32'h80000000, 32'h0000001f, 4'd8, 32'h8000001f, "OR");
        check(32'hdeadbeef, 32'h00000024, 4'd8, 32'hdeadbeef, "OR");
        check(32'h00000001, 32'hffffffe1, 4'd8, 32'hffffffe1, "OR");
        check(32'h6edd77d8, 32'h33d91808, 4'd8, 32'h7fdd7fd8, "OR");
        check(32'h4b5c1a95, 32'hd4f398ee, 4'd8, 32'hdfff9aff, "OR");
        check(32'h44df8a13, 32'h025ff87c, 4'd8, 32'h46dffa7f, "OR");
        check(32'h0879d955, 32'h265c28ea, 4'd8, 32'h2e7df9ff, "OR");
        check(32'ha7d83351, 32'he1cd7be8, 4'd8, 32'he7dd7bf9, "OR");
        check(32'h98e6e5b7, 32'hf5ee8c72, 4'd8, 32'hfdeeedf7, "OR");
        check(32'h754e64f4, 32'hcdb54088, 4'd8, 32'hfdff64fc, "OR");
        check(32'h85dc0a68, 32'hed4d19b8, 4'd8, 32'heddd1bf8, "OR");
        check(32'h7d510557, 32'h5c24c1ae, 4'd8, 32'h7d75c5ff, "OR");
        check(32'hebe80fa9, 32'h33288e16, 4'd8, 32'hfbe88fbf, "OR");
        $display("AND");
        check(32'h00000000, 32'h00000000, 4'd9, 32'h00000000, "AND");
        check(32'h00000005, 32'h00000003, 4'd9, 32'h00000001, "AND");
        check(32'h00000003, 32'h00000005, 4'd9, 32'h00000001, "AND");
        check(32'h7fffffff, 32'h00000001, 4'd9, 32'h00000001, "AND");
        check(32'h80000000, 32'h00000001, 4'd9, 32'h00000000, "AND");
        check(32'hffffffff, 32'h00000001, 4'd9, 32'h00000001, "AND");
        check(32'hffffffff, 32'hffffffff, 4'd9, 32'hffffffff, "AND");
        check(32'h80000000, 32'h7fffffff, 4'd9, 32'h00000000, "AND");
        check(32'h7fffffff, 32'h80000000, 4'd9, 32'h00000000, "AND");
        check(32'hfffffffd, 32'h00000005, 4'd9, 32'h00000005, "AND");
        check(32'h12345678, 32'h00000000, 4'd9, 32'h00000000, "AND");
        check(32'h12345678, 32'h0000001f, 4'd9, 32'h00000018, "AND");
        check(32'h80000000, 32'h0000001f, 4'd9, 32'h00000000, "AND");
        check(32'hdeadbeef, 32'h00000024, 4'd9, 32'h00000024, "AND");
        check(32'h00000001, 32'hffffffe1, 4'd9, 32'h00000001, "AND");
        check(32'h42969a50, 32'hb1515fff, 4'd9, 32'h00101a50, "AND");
        check(32'h7c4e4248, 32'h7776c655, 4'd9, 32'h74464240, "AND");
        check(32'h82e26123, 32'hc446ab8c, 4'd9, 32'h80422100, "AND");
        check(32'hd3801b73, 32'h7f45b096, 4'd9, 32'h53001012, "AND");
        check(32'hced66b44, 32'h6f29a9f1, 4'd9, 32'h4e002940, "AND");
        check(32'h8ece78b0, 32'ha9f5307c, 4'd9, 32'h88c43030, "AND");
        check(32'he842997d, 32'h089b5123, 4'd9, 32'h08021121, "AND");
        check(32'hd4d6d278, 32'h4a41f8e4, 4'd9, 32'h4040d060, "AND");
        check(32'h511070a7, 32'h7528ea79, 4'd9, 32'h51006021, "AND");
        check(32'heab42bd6, 32'hcfd8c364, 4'd9, 32'hca900344, "AND");
        $display("Codigos invalidos");
        check(32'hffffffff, 32'hffffffff, 4'd10, 32'h00000000, "INV");
        check(32'hffffffff, 32'hffffffff, 4'd15, 32'h00000000, "INV");

        $display("--------------------------------------------");
        $display("Resultado: %0d verificaciones OK, %0d fallas", pass, fail);
        if (fail == 0) begin
            $display("ALU: TODO OK");
            $finish;
        end else begin
            $fatal(1, "ALU: %0d FALLAS", fail);
        end
    end

endmodule
