// Constant-evaluated by scripts/check_package.py.
module tb_vliw_pkg;
    import vliw_pkg::*;
    localparam bit CHECK_ARCH = XLEN == 32 && LANES == 4 &&
        REG_COUNT == 32 && BUNDLE_BITS == 128 && REG_BITS == 5 &&
        OPERAND_PORTS == 8 && BUNDLE_BYTES == 16 && WORD_BYTES == 4;
    localparam bit CHECK_WORDS = NOP_WORD == 32'h13 && HALT_WORD == 32'hb;
    localparam bit CHECK_MEMORY = IMEM_BUNDLES == 1 && DMEM_WORDS == 1 &&
        $bits(IMEM_BYTES) >= 33 && $bits(DMEM_BYTES) >= 33 &&
        IMEM_BYTES == 64'd16 && DMEM_BYTES == 64'd4;
    localparam bit CHECK_WIDTHS = $bits(fault_t) == 41 &&
        $bits(decode_t) == 62 && $bits(d_packet_t) == 202 &&
        $bits(e_packet_t) == 578 && $bits(m_packet_t) == 288 &&
        $bits(w_packet_t) == 288 && $bits(producer_t) == 39;
    localparam bit CHECK_ALU = {ALU_ADD,ALU_SUB,ALU_AND,ALU_OR,ALU_XOR,
        ALU_SLL,ALU_SRL,ALU_SLT,ALU_PASS_B} == 36'h01234568a;
    localparam bit CHECK_IMM = {IMM_I,IMM_S,IMM_B,IMM_U,IMM_J,IMM_NONE} ==
        {3'd0,3'd1,3'd2,3'd3,3'd4,3'd7};
    localparam bit CHECK_CONTROL = {MEM_NONE,MEM_LW,MEM_SW} == 6'b000110 &&
        {CTRL_NONE,CTRL_BEQ,CTRL_BNE,CTRL_JAL} == 8'h1b &&
        {TERMINAL_NONE,TERMINAL_HALT,TERMINAL_FAULT} == 6'b000110 &&
        {MODE_RUN,MODE_DRAIN_HALT,MODE_DRAIN_FAULT,MODE_STOP} == 8'h1b;
    localparam bit CHECK_FAULTS = {FAULT_NONE,FAULT_ILLEGAL_ENCODING,
        FAULT_ILLEGAL_SLOT,FAULT_CONTROL_PARTNER,FAULT_DUPLICATE_DEST,
        FAULT_CROSS_SLOT_DEP,FAULT_FETCH_ALIGN,FAULT_FETCH_RANGE,
        FAULT_DATA_ALIGN,FAULT_DATA_RANGE,FAULT_TARGET_ALIGN,FAULT_TARGET_RANGE}
        == 48'h0123456789ab;
    localparam bit CHECK_TAGS = {TAG_NOP,TAG_ADD,TAG_SUB,TAG_AND,TAG_OR,
        TAG_XOR,TAG_SLT,TAG_SLL,TAG_SRL,TAG_ADDI,TAG_LUI,TAG_LW,TAG_SW,
        TAG_BEQ,TAG_BNE,TAG_JAL,TAG_HALT,TAG_INVALID} ==
        {5'd0,5'd1,5'd2,5'd3,5'd4,5'd5,5'd6,5'd7,5'd8,5'd9,
         5'd10,5'd11,5'd12,5'd13,5'd14,5'd15,5'd16,5'd31};
    localparam bit CHECK_FORWARD = {FWD_SAVED,FWD_MEM0,FWD_MEM1,FWD_MEM2,
        FWD_MEM3,FWD_WB0,FWD_WB1,FWD_WB2,FWD_WB3,FWD_BLOCKED}
        == 40'h0123456789;

    function automatic bit layouts();
        fault_t f;
        decode_t dec;
        d_packet_t d;
        e_packet_t e;
        m_packet_t m;
        w_packet_t w;
        producer_t p;
        f = {1'b1,4'hb,4'h5,32'h12345678};
        if (f.valid != 1'b1 || f.code != FAULT_TARGET_RANGE ||
            f.slots != 4'h5 || f.addr != 32'h12345678) return 1'b0;
        dec = {5'b10101,5'd1,5'd2,5'd3,32'habcdef01,4'h8,1'b1,2'd1,2'd3,1'b1};
        if (!dec.legal || dec.active || !dec.use_a || dec.use_b ||
            !dec.write_rd || dec.rs1 != 5'd1 || dec.rs2 != 5'd2 ||
            dec.rd != 5'd3 || dec.imm != 32'habcdef01 ||
            dec.alu_op != ALU_SLT || !dec.b_imm || dec.mem_op != MEM_LW ||
            dec.ctrl_op != CTRL_JAL || !dec.halt) return 1'b0;
        d = {1'b1,32'h10,32'd3,32'd2,32'd1,NOP_WORD,f};
        if (!d.valid || d.pc != 32'h10 || d.instr[0] != NOP_WORD ||
            d.instr[1] != 32'd1 || d.instr[2] != 32'd2 ||
            d.instr[3] != 32'd3 || d.fault !== f) return 1'b0;
        e = {1'b1,32'h20,62'd3,62'd2,62'd1,dec,
             32'd7,32'd6,32'd5,32'd4,32'd3,32'd2,32'd1,32'd0,f};
        if (!e.valid || e.pc != 32'h20 || e.dec[0] !== dec ||
            e.dec[1] != 62'd1 || e.dec[2] != 62'd2 ||
            e.dec[3] != 62'd3 || e.fault !== f) return 1'b0;
        for (int i = 0; i < 8; i++)
            if (e.operand[i] != 32'(i)) return 1'b0;
        m = {1'b1,32'h30,32'h40,4'ha,5'd4,5'd3,5'd2,5'd1,4'h5,
             32'd4,32'd3,32'd2,32'd1,1'b1,1'b0,32'h100,32'hdeadbeef,1'b1};
        if (!m.valid || m.pc != 32'h30 || m.next_pc != 32'h40 ||
            m.active != 4'ha || m.wen != 4'h5 || !m.load || m.store ||
            m.addr != 32'h100 || m.store_data != 32'hdeadbeef ||
            !m.branch_taken) return 1'b0;
        for (int i = 0; i < 4; i++)
            if (m.rd[i] != 5'(i+1) || m.result[i] != 32'(i+1)) return 1'b0;
        w = m;
        if (w !== m) return 1'b0;
        p = {1'b1,5'd17,1'b1,32'hcafebabe};
        if (!p.valid || p.rd != 5'd17 || !p.ready ||
            p.data != 32'hcafebabe) return 1'b0;
        f = '0; dec = '0; d = '0; e = '0; m = '0; w = '0; p = '0;
        return {f,dec,d,e,m,w,p} === '0;
    endfunction
    localparam bit CHECK_LAYOUTS = layouts();
endmodule
