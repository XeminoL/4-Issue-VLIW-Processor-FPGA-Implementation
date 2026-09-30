// Instruction identity decode: SPEC.md Sections 3.2 and 11.5.
module main_decoder
    import vliw_pkg::*;
(
    input  logic [31:0] instr_i,
    output instr_tag_t  tag_o,
    output logic        legal_o
);
    localparam logic [6:0] OP_R     = 7'h33;
    localparam logic [6:0] OP_ADDI  = 7'h13;
    localparam logic [6:0] OP_LUI   = 7'h37;
    localparam logic [6:0] OP_LOAD  = 7'h03;
    localparam logic [6:0] OP_STORE = 7'h23;
    localparam logic [6:0] OP_BRANCH= 7'h63;
    localparam logic [6:0] OP_JAL   = 7'h6f;

    logic [6:0] opcode;
    logic [2:0] funct3;
    logic [6:0] funct7;

    assign opcode = instr_i[6:0];
    assign funct3 = instr_i[14:12];
    assign funct7 = instr_i[31:25];

    always_comb begin
        tag_o = TAG_INVALID;

        // Exact NOP is recognized before ordinary ADDI accounting.
        if (instr_i == NOP_WORD) begin
            tag_o = TAG_NOP;
        end else if (instr_i == HALT_WORD) begin
            tag_o = TAG_HALT;
        end else begin
            unique case (opcode)
                OP_R: begin
                    unique case ({funct7, funct3})
                        {7'h00, 3'b000}: tag_o = TAG_ADD;
                        {7'h20, 3'b000}: tag_o = TAG_SUB;
                        {7'h00, 3'b111}: tag_o = TAG_AND;
                        {7'h00, 3'b110}: tag_o = TAG_OR;
                        {7'h00, 3'b100}: tag_o = TAG_XOR;
                        {7'h00, 3'b010}: tag_o = TAG_SLT;
                        {7'h00, 3'b001}: tag_o = TAG_SLL;
                        {7'h00, 3'b101}: tag_o = TAG_SRL;
                        default:         tag_o = TAG_INVALID;
                    endcase
                end
                OP_ADDI:  tag_o = (funct3 == 3'b000) ? TAG_ADDI : TAG_INVALID;
                OP_LUI:   tag_o = TAG_LUI;
                OP_LOAD:  tag_o = (funct3 == 3'b010) ? TAG_LW : TAG_INVALID;
                OP_STORE: tag_o = (funct3 == 3'b010) ? TAG_SW : TAG_INVALID;
                OP_BRANCH: begin
                    unique case (funct3)
                        3'b000:  tag_o = TAG_BEQ;
                        3'b001:  tag_o = TAG_BNE;
                        default: tag_o = TAG_INVALID;
                    endcase
                end
                OP_JAL:  tag_o = TAG_JAL;
                default: tag_o = TAG_INVALID;
            endcase
        end
    end

    assign legal_o = (tag_o != TAG_INVALID);
endmodule