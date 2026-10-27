`timescale 1ns/1ps

module SC_Control_tb;
    reg  [10:0] opcode;
    wire        Reg2Loc, ALUSrc, MemtoReg, RegWrite, MemRead, MemWrite, Branch, Uncondbranch;
    wire [3:0]  ALUOp;
    wire [1:0]  SignOp;

    SC_Control dut(.Reg2Loc(Reg2Loc), .ALUSrc(ALUSrc), .MemtoReg(MemtoReg),
                   .RegWrite(RegWrite), .MemRead(MemRead), .MemWrite(MemWrite),
                   .Branch(Branch), .Uncondbranch(Uncondbranch),
                   .ALUOp(ALUOp), .SignOp(SignOp), .opcode(opcode));

    // Packed order: {SignOp, ALUOp, Reg2Loc, ALUSrc, MemtoReg, RegWrite,
    //                MemRead, MemWrite, Branch, Uncondbranch}
    wire [13:0] actual = {SignOp, ALUOp, Reg2Loc, ALUSrc, MemtoReg, RegWrite,
                          MemRead, MemWrite, Branch, Uncondbranch};

    // Expected values straight from the truth table; x = don't care (not checked)
    localparam [13:0] E_LDUR = {2'b01, 4'b0010, 1'bx, 1'b1, 1'b1, 1'b1, 1'b1, 1'b0, 1'b0, 1'b0};
    localparam [13:0] E_STUR = {2'b01, 4'b0010, 1'b1, 1'b1, 1'bx, 1'b0, 1'b0, 1'b1, 1'b0, 1'b0};
    localparam [13:0] E_ADD  = {2'bxx, 4'b0010, 1'b0, 1'b0, 1'b0, 1'b1, 1'b0, 1'b0, 1'b0, 1'b0};
    localparam [13:0] E_SUBI = {2'b00, 4'b0110, 1'bx, 1'b1, 1'b0, 1'b1, 1'b0, 1'b0, 1'b0, 1'b0};
    localparam [13:0] E_AND  = {2'bxx, 4'b0000, 1'b0, 1'b0, 1'b0, 1'b1, 1'b0, 1'b0, 1'b0, 1'b0};
    localparam [13:0] E_ORR  = {2'bxx, 4'b0001, 1'b0, 1'b0, 1'b0, 1'b1, 1'b0, 1'b0, 1'b0, 1'b0};
    localparam [13:0] E_SUBR = {2'bxx, 4'b0110, 1'b0, 1'b0, 1'b0, 1'b1, 1'b0, 1'b0, 1'b0, 1'b0};
    localparam [13:0] E_CBZ  = {2'b10, 4'b0111, 1'b1, 1'b0, 1'bx, 1'b0, 1'b0, 1'b0, 1'b1, 1'b0};
    localparam [13:0] E_B    = {2'b11, 4'bxxxx, 1'bx, 1'bx, 1'bx, 1'b0, 1'b0, 1'b0, 1'b0, 1'b1};
    localparam [13:0] E_NONE = 14'b0;

    integer errors = 0, tests = 0;
    integer i, n, seed;

    // True when every non-x expected bit matches
    function match(input [13:0] a, input [13:0] e);
        integer k;
        begin
            match = 1'b1;
            for (k = 0; k < 14; k = k + 1)
                if (e[k] !== 1'bx && a[k] !== e[k]) match = 1'b0;
        end
    endfunction

    // Mirrors the supported opcode set; used to reject random opcodes
    function supported(input [10:0] op);
        casez (op)
            11'b11111000010, 11'b11111000000, 11'b10001011000, 11'b11001011000,
            11'b1101000100?, 11'b10001010000, 11'b10101010000, 11'b10110100???,
            11'b000101?????:
                supported = 1'b1;
            default: supported = 1'b0;
        endcase
    endfunction

    task check(input [10:0] op, input [13:0] e, input [8*8-1:0] name);
        begin
            opcode = op;
            #5;
            tests = tests + 1;
            if (!match(actual, e)) begin
                errors = errors + 1;
                $display("ERROR %0s opcode=%b expected=%b actual=%b", name, op, e, actual);
            end
            #5;
        end
    endtask

    initial begin
        $dumpfile("SC_Control_tb.vcd");
        $dumpvars(0, SC_Control_tb);
        seed = 32'hC0FFEE;

        // Instructions with no don't-care bits
        check(11'b11111000010, E_LDUR, "LDUR");
        check(11'b11111000000, E_STUR, "STUR");
        check(11'b10001011000, E_ADD,  "ADD");
        check(11'b10001010000, E_AND,  "AND");
        check(11'b10101010000, E_ORR,  "ORR");
        check(11'b11001011000, E_SUBR, "SUBREG");

        // Every value of the don't-care bits
        for (i = 0; i < 2; i = i + 1)   // SUBI: 1101000100X
            check({10'b1101000100, i[0]}, E_SUBI, "SUBI");
        for (i = 0; i < 8; i = i + 1)   // CBZ: 10110100XXX
            check({8'b10110100, i[2:0]}, E_CBZ, "CBZ");
        for (i = 0; i < 32; i = i + 1)  // B: 000101XXXXX
            check({6'b000101, i[4:0]}, E_B, "B");

        // 10 random unsupported opcodes must give all zeros
        n = 0;
        while (n < 10) begin
            opcode = $random(seed);
            if (!supported(opcode)) begin
                check(opcode, E_NONE, "RANDOM");
                n = n + 1;
            end
        end

        if (errors == 0) $display("PASS: all %0d tests passed", tests);
        else             $display("FAIL: %0d of %0d tests failed", errors, tests);
        $finish;
    end
endmodule
