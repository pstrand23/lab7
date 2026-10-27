module SingleCycleProc(
		   input	     reset, //Active High
		   input [63:0]	     startpc,
		   output reg [63:0] currentpc,
		   output [63:0]     MemtoRegOut, // this should be
						   // attached to the
						   // output of the
						   // MemtoReg Mux
		   input	     CLK
		   );

   // Next PC connections
   wire [63:0] 			     nextpc;       // The next PC, to be updated on clock cycle

   // Instruction Memory connections
   wire [31:0] 			     instruction;  // The current instruction

   // Parts of instruction
   wire [4:0] 			     rd;            // The destination register
   wire [4:0] 			     rm;            // Read register 1 (Rn field, [9:5])
   wire [4:0] 			     rn;            // Read register 2 (after Reg2Loc mux)
   wire [10:0] 			     opcode;

   // Control wires
   wire 			     Reg2Loc;
   wire 			     ALUSrc;
   wire 			     MemtoReg;
   wire 			     RegWrite;
   wire 			     MemRead;
   wire 			     MemWrite;
   wire 			     Branch;
   wire 			     Uncondbranch;
   wire [3:0] 			     ALUOp;
   wire [1:0] 			     SignOp;

   // Register file connections
   wire [63:0] 			     regoutA;     // Output A
   wire [63:0] 			     regoutB;     // Output B

   // ALU connections
   wire [63:0] 			     aluout;
   wire 			     zero;
   wire [63:0] 			     aluB;        // ALU second operand (after ALUSrc mux)

   // Sign Extender connections
   wire [63:0] 			     extimm;

   // Data memory connections
   wire [63:0] 			     dmemout;

   // PC update logic
   always @(posedge CLK)
     begin
        if (reset)
          currentpc <= #3 startpc;
        else
          currentpc <= #3 nextpc;
     end

   // Parts of instruction
   assign rd = instruction[4:0];
   assign rm = instruction[9:5];
   assign rn = Reg2Loc ? instruction[4:0] : instruction[20:16];
   assign opcode = instruction[31:21];

   InstructionMemory imem(
			  .Data(instruction),
			  .Address(currentpc)
			  );

   SC_Control SingleCycleControl(
		   .Reg2Loc(Reg2Loc),
		   .ALUSrc(ALUSrc),
		   .MemtoReg(MemtoReg),
		   .RegWrite(RegWrite),
		   .MemRead(MemRead),
		   .MemWrite(MemWrite),
		   .Branch(Branch),
		   .Uncondbranch(Uncondbranch),
		   .ALUOp(ALUOp),
		   .SignOp(SignOp),
		   .opcode(opcode)
		   );

   RegisterFile regs(
		   .BusA(regoutA),
		   .BusB(regoutB),
		   .BusW(MemtoRegOut),
		   .RA(rm),
		   .RB(rn),
		   .RW(rd),
		   .RegWr(RegWrite),
		   .Clk(CLK)
		   );

   SignExtender signext(
		   .SignExOut(extimm),
		   .Instruction(instruction[25:0]),
		   .SignOp(SignOp)
		   );

   // ALUSrc mux: register value (0) or sign-extended immediate (1)
   assign aluB = ALUSrc ? extimm : regoutB;

   ALU alu(
		   .BusW(aluout),
		   .BusA(regoutA),
		   .BusB(aluB),
		   .ALUCtrl(ALUOp),
		   .Zero(zero)
		   );

   DataMemory dmem(
		   .ReadData(dmemout),
		   .Address(aluout),
		   .WriteData(regoutB),
		   .MemoryRead(MemRead),
		   .MemoryWrite(MemWrite),
		   .Clock(CLK)
		   );

   // MemtoReg mux: ALU result (0) or memory data (1)
   assign MemtoRegOut = MemtoReg ? dmemout : aluout;

   // Sign extender already shifted branch offsets left 2, so no extra shift here
   NextPClogic nextpclogic(
		   .NextPC(nextpc),
		   .CurrentPC(currentpc),
		   .SignExtImm64(extimm),
		   .Branch(Branch),
		   .ALUZero(zero),
		   .Uncondbranch(Uncondbranch)
		   );

endmodule
