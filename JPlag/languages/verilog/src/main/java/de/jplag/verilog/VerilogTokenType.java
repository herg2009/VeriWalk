package de.jplag.verilog;

import de.jplag.TokenType;

/**
 * Token types for Verilog language.
 * Represents key syntactic structures in Verilog RTL code.
 */
public enum VerilogTokenType implements TokenType {
    // Module structure
    MODULE_BEGIN("MODULE{"),
    MODULE_END("}MODULE"),
    MODULE_DECL("MODULE"),
    
    // Port declarations
    PORT_INPUT("INPUT"),
    PORT_OUTPUT("OUTPUT"),
    PORT_INOUT("INOUT"),
    
    // Signal declarations
    DECL_WIRE("WIRE"),
    DECL_REG("REG"),
    DECL_PARAM("PARAM"),
    DECL_INTEGER("INTEGER"),
    
    // Assignments
    ASSIGN_CONT("CONT-ASSIGN"),
    ASSIGN_PROC("PROC-ASSIGN"),
    
    // Procedural blocks
    BLOCK_ALWAYS("ALWAYS"),
    BLOCK_INITIAL("INITIAL"),
    BLOCK_BEGIN("BEGIN"),
    BLOCK_END("END"),
    
    // Control structures
    COND_IF("IF"),
    COND_ELSE("ELSE"),
    COND_CASE("CASE"),
    COND_CASE_END("ENDCASE"),
    COND_DEFAULT("DEFAULT"),
    
    // Loop structures
    LOOP_FOR("FOR"),
    LOOP_WHILE("WHILE"),
    LOOP_REPEAT("REPEAT"),
    LOOP_FOREVER("FOREVER"),
    
    // Instantiation
    INST_MODULE("INST-MODULE"),
    
    // Operators and expressions
    OP_LOGIC("LOGIC-OP"),
    OP_ARITH("ARITH-OP"),
    OP_SHIFT("SHIFT-OP"),
    OP_CONCAT("CONCAT"),
    
    // Task and function
    FUNC_DECL("FUNCTION"),
    TASK_DECL("TASK"),
    
    // Compiler directives
    DIRECTIVE("DIRECTIVE");

    private final String description;

    VerilogTokenType(String description) {
        this.description = description;
    }

    @Override
    public String getDescription() {
        return description;
    }
    
    @Override
    public String toString() {
        return description;
    }
}
