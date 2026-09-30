module main_decoder
    import vliw_pkg::*;
(
    input  logic [31:0] instr_i,
    output instr_tag_t  tag_o,
    output logic        legal_o
);
    logic [6:0] opcode;
    logic [2:0] funct3;
    logic [6:0] funct7;

    assign opcode = instr_i[6:0];
    assign funct3 = instr_i[14:12];
    assign funct7 = instr_i[31:25];

    always_comb begin
        if (instr_i == NOP_WORD) begin
            tag_o = TAG_NOP;
        end else if (instr_i == HALT_WORD) begin
            tag_o = TAG_HALT;
        end else begin
            case (opcode)
                7'h33: begin
                    case ({funct7, funct3})
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
                7'h13: begin
                    case (funct3)
                        3'b000:  tag_o = TAG_ADDI;
                        default: tag_o = TAG_INVALID;
                    endcase
                end
                7'h37: tag_o = TAG_LUI;
                7'h03: begin
                    case (funct3)
                        3'b010:  tag_o = TAG_LW;
                        default: tag_o = TAG_INVALID;
                    endcase
                end
                7'h23: begin
                    case (funct3)
                        3'b010:  tag_o = TAG_SW;
                        default: tag_o = TAG_INVALID;
                    endcase
                end
                7'h63: begin
                    case (funct3)
                        3'b000:  tag_o = TAG_BEQ;
                        3'b001:  tag_o = TAG_BNE;
                        default: tag_o = TAG_INVALID;
                    endcase
                end
                7'h6f:   tag_o = TAG_JAL;
                default: tag_o = TAG_INVALID;
            endcase
        end
    end

    assign legal_o = (tag_o != TAG_INVALID);
endmodule