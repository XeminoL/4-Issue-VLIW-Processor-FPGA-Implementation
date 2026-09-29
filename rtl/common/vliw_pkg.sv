// Shared P1 definitions: SPEC.md Sections 7, 10.1 and 11.
package vliw_pkg;
    localparam int unsigned XLEN = 32;
    localparam int unsigned LANES = 4;
    localparam int unsigned REG_COUNT = 32;
    localparam int unsigned BUNDLE_BITS = 128;
    localparam int unsigned REG_BITS = 5;
    localparam int unsigned OPERAND_PORTS = 8;
    localparam int unsigned BUNDLE_BYTES = 16;
    localparam int unsigned WORD_BYTES = 4;

    // Minimal legal defaults, not a board configuration. Module parameters
    // must propagate selected depths consistently to core and memories.
    parameter int unsigned IMEM_BUNDLES = 1;
    parameter int unsigned DMEM_WORDS = 1;
    // Widen before multiplication; modules must recompute for their depths.
    localparam logic [63:0] IMEM_BYTES = 64'd16 * IMEM_BUNDLES;
    localparam logic [63:0] DMEM_BYTES = 64'd4 * DMEM_WORDS;

    localparam logic [31:0] NOP_WORD = 32'h00000013;
    localparam logic [31:0] HALT_WORD = 32'h0000000b;

    typedef enum logic [3:0] {
        ALU_ADD = 4'h0, ALU_SUB = 4'h1, ALU_AND = 4'h2,
        ALU_OR = 4'h3, ALU_XOR = 4'h4, ALU_SLL = 4'h5,
        ALU_SRL = 4'h6, ALU_SLT = 4'h8, ALU_PASS_B = 4'ha
    } alu_op_t;
    typedef enum logic [2:0] {
        IMM_I = 3'd0, IMM_S = 3'd1, IMM_B = 3'd2,
        IMM_U = 3'd3, IMM_J = 3'd4, IMM_NONE = 3'd7
    } imm_sel_t;
    typedef enum logic [1:0] {
        MEM_NONE = 2'd0, MEM_LW = 2'd1, MEM_SW = 2'd2
    } mem_op_t;
    typedef enum logic [1:0] {
        CTRL_NONE = 2'd0, CTRL_BEQ = 2'd1,
        CTRL_BNE = 2'd2, CTRL_JAL = 2'd3
    } ctrl_op_t;
    typedef enum logic [1:0] {
        TERMINAL_NONE = 2'd0, TERMINAL_HALT = 2'd1, TERMINAL_FAULT = 2'd2
    } terminal_t;
    typedef enum logic [1:0] {
        MODE_RUN = 2'd0, MODE_DRAIN_HALT = 2'd1,
        MODE_DRAIN_FAULT = 2'd2, MODE_STOP = 2'd3
    } mode_t;
    typedef enum logic [3:0] {
        FAULT_NONE = 4'h0,
        FAULT_ILLEGAL_ENCODING = 4'h1,
        FAULT_ILLEGAL_SLOT = 4'h2,
        FAULT_CONTROL_PARTNER = 4'h3,
        FAULT_DUPLICATE_DEST = 4'h4,
        FAULT_CROSS_SLOT_DEP = 4'h5,
        FAULT_FETCH_ALIGN = 4'h6,
        FAULT_FETCH_RANGE = 4'h7,
        FAULT_DATA_ALIGN = 4'h8,
        FAULT_DATA_RANGE = 4'h9,
        FAULT_TARGET_ALIGN = 4'ha,
        FAULT_TARGET_RANGE = 4'hb
    } fault_code_t;

    // Instruction identities (SPEC 11.5), not opcode values.
    typedef enum logic [4:0] {
        TAG_NOP = 5'd0, TAG_ADD = 5'd1, TAG_SUB = 5'd2,
        TAG_AND = 5'd3, TAG_OR = 5'd4, TAG_XOR = 5'd5,
        TAG_SLT = 5'd6, TAG_SLL = 5'd7, TAG_SRL = 5'd8,
        TAG_ADDI = 5'd9, TAG_LUI = 5'd10, TAG_LW = 5'd11,
        TAG_SW = 5'd12, TAG_BEQ = 5'd13, TAG_BNE = 5'd14,
        TAG_JAL = 5'd15, TAG_HALT = 5'd16, TAG_INVALID = 5'd31
    } instr_tag_t;
    typedef enum logic [3:0] {
        FWD_SAVED = 4'd0,
        FWD_MEM0 = 4'd1, FWD_MEM1 = 4'd2, FWD_MEM2 = 4'd3, FWD_MEM3 = 4'd4,
        FWD_WB0 = 4'd5, FWD_WB1 = 4'd6, FWD_WB2 = 4'd7, FWD_WB3 = 4'd8,
        FWD_BLOCKED = 4'd9
    } forward_sel_t;

    // Fields follow specification order: first field is most significant.
    // Descending packed arrays put element zero at the least-significant end.
    // Reset/clear assigns '0 to the whole record, including enum fields.
    typedef struct packed {
        logic valid;
        fault_code_t code;
        logic [LANES-1:0] slots;
        logic [XLEN-1:0] addr;
    } fault_t;

    typedef struct packed {
        logic legal;
        logic active;
        logic use_a;
        logic use_b;
        logic write_rd;
        logic [REG_BITS-1:0] rs1;
        logic [REG_BITS-1:0] rs2;
        logic [REG_BITS-1:0] rd;
        logic [XLEN-1:0] imm;
        alu_op_t alu_op;
        logic b_imm;
        mem_op_t mem_op;
        ctrl_op_t ctrl_op;
        logic halt;
    } decode_t;

    typedef decode_t [LANES-1:0] decode_lanes_t;

    typedef struct packed {
        logic valid;
        logic [XLEN-1:0] pc;
        logic [LANES-1:0][XLEN-1:0] instr;
        fault_t fault;
    } d_packet_t;

    typedef struct packed {
        logic valid;
        logic [XLEN-1:0] pc;
        decode_lanes_t dec;
        // Port 2*s is source A; port 2*s+1 is source B.
        logic [OPERAND_PORTS-1:0][XLEN-1:0] operand;
        fault_t fault;
    } e_packet_t;

    // SPEC 7.7 fields sum to 288 bits, despite its stated 388-bit total.
    // Preserve the field list without invented padding.
    // Faulting/HALT bundles never enter M; there is no fault/terminal field.
    typedef struct packed {
        logic valid;
        logic [XLEN-1:0] pc;
        logic [XLEN-1:0] next_pc;
        logic [LANES-1:0] active;
        logic [LANES-1:0][REG_BITS-1:0] rd;
        logic [LANES-1:0] wen;
        logic [LANES-1:0][XLEN-1:0] result;
        logic load;
        logic store;
        logic [XLEN-1:0] addr;
        logic [XLEN-1:0] store_data;
        logic branch_taken;
    } m_packet_t;

    // Same metadata layout; writeback selects registered DMEM output for LW.
    // Do not capture new load data at the MEM-to-WB edge.
    typedef m_packet_t w_packet_t;

    typedef struct packed {
        logic valid;
        logic [REG_BITS-1:0] rd;
        logic ready;
        logic [XLEN-1:0] data;
    } producer_t;
endpackage : vliw_pkg
