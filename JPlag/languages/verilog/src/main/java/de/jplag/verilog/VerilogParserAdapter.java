package de.jplag.verilog;

import de.jplag.AbstractParser;
import de.jplag.Token;
import de.jplag.ParsingException;

import java.io.BufferedReader;
import java.io.File;
import java.io.FileReader;
import java.io.IOException;
import java.util.ArrayList;
import java.util.List;
import java.util.regex.Matcher;
import java.util.regex.Pattern;

/**
 * Simplified Verilog parser adapter.
 * Uses pattern matching to extract key RTL structures.
 */
public class VerilogParserAdapter extends AbstractParser {
    
    // Patterns for Verilog constructs
    private static final Pattern MODULE_PATTERN = Pattern.compile(
        "\\bmodule\\s+(\\w+)", Pattern.CASE_INSENSITIVE);
    private static final Pattern ENDMODULE_PATTERN = Pattern.compile(
        "\\bendmodule\\b", Pattern.CASE_INSENSITIVE);
    private static final Pattern INPUT_PATTERN = Pattern.compile(
        "\\binput\\b", Pattern.CASE_INSENSITIVE);
    private static final Pattern OUTPUT_PATTERN = Pattern.compile(
        "\\boutput\\b", Pattern.CASE_INSENSITIVE);
    private static final Pattern INOUT_PATTERN = Pattern.compile(
        "\\binout\\b", Pattern.CASE_INSENSITIVE);
    private static final Pattern WIRE_PATTERN = Pattern.compile(
        "\\bwire\\b", Pattern.CASE_INSENSITIVE);
    private static final Pattern REG_PATTERN = Pattern.compile(
        "\\breg\\b", Pattern.CASE_INSENSITIVE);
    private static final Pattern PARAMETER_PATTERN = Pattern.compile(
        "\\bparameter\\b", Pattern.CASE_INSENSITIVE);
    private static final Pattern INTEGER_PATTERN = Pattern.compile(
        "\\binteger\\b", Pattern.CASE_INSENSITIVE);
    private static final Pattern ASSIGN_PATTERN = Pattern.compile(
        "\\bassign\\b", Pattern.CASE_INSENSITIVE);
    private static final Pattern ALWAYS_PATTERN = Pattern.compile(
        "\\balways\\b", Pattern.CASE_INSENSITIVE);
    private static final Pattern INITIAL_PATTERN = Pattern.compile(
        "\\binitial\\b", Pattern.CASE_INSENSITIVE);
    private static final Pattern BEGIN_PATTERN = Pattern.compile(
        "\\bbegin\\b", Pattern.CASE_INSENSITIVE);
    private static final Pattern END_PATTERN = Pattern.compile(
        "\\bend\\b", Pattern.CASE_INSENSITIVE);
    private static final Pattern IF_PATTERN = Pattern.compile(
        "\\bif\\b", Pattern.CASE_INSENSITIVE);
    private static final Pattern ELSE_PATTERN = Pattern.compile(
        "\\belse\\b", Pattern.CASE_INSENSITIVE);
    private static final Pattern CASE_PATTERN = Pattern.compile(
        "\\bcase\\b", Pattern.CASE_INSENSITIVE);
    private static final Pattern ENDCASE_PATTERN = Pattern.compile(
        "\\bendcase\\b", Pattern.CASE_INSENSITIVE);
    private static final Pattern DEFAULT_PATTERN = Pattern.compile(
        "\\bdefault\\b", Pattern.CASE_INSENSITIVE);
    private static final Pattern FOR_PATTERN = Pattern.compile(
        "\\bfor\\b", Pattern.CASE_INSENSITIVE);
    private static final Pattern WHILE_PATTERN = Pattern.compile(
        "\\bwhile\\b", Pattern.CASE_INSENSITIVE);
    private static final Pattern REPEAT_PATTERN = Pattern.compile(
        "\\brepeat\\b", Pattern.CASE_INSENSITIVE);
    private static final Pattern FOREVER_PATTERN = Pattern.compile(
        "\\bforever\\b", Pattern.CASE_INSENSITIVE);
    private static final Pattern FUNCTION_PATTERN = Pattern.compile(
        "\\bfunction\\b", Pattern.CASE_INSENSITIVE);
    private static final Pattern TASK_PATTERN = Pattern.compile(
        "\\btask\\b", Pattern.CASE_INSENSITIVE);
    private static final Pattern DIRECTIVE_PATTERN = Pattern.compile(
        "^\\s*`", Pattern.MULTILINE);
    
    @Override
    public List<Token> parse(File file) throws ParsingException {
        List<Token> tokens = new ArrayList<>();
        
        try (BufferedReader reader = new BufferedReader(new FileReader(file))) {
            String line;
            int lineNumber = 0;
            
            while ((line = reader.readLine()) != null) {
                lineNumber++;
                parseLine(line, file, lineNumber, tokens);
            }
        } catch (IOException e) {
            throw new ParsingException(file, "Error reading file: " + e.getMessage(), e);
        }
        
        return tokens;
    }
    
    private void parseLine(String line, File file, int lineNumber, List<Token> tokens) {
        // Skip empty lines and comments
        String trimmed = line.trim();
        if (trimmed.isEmpty() || trimmed.startsWith("//") || trimmed.startsWith("/*")) {
            return;
        }
        
        int column = 0;
        
        // Check for module declaration
        if (MODULE_PATTERN.matcher(line).find()) {
            tokens.add(new Token(VerilogTokenType.MODULE_DECL, file.getName(), 
                lineNumber, column, getLength(line, "module")));
        }
        
        // Check for endmodule
        if (ENDMODULE_PATTERN.matcher(line).find()) {
            tokens.add(new Token(VerilogTokenType.MODULE_END, file.getName(), 
                lineNumber, column, getLength(line, "endmodule")));
        }
        
        // Check for port declarations
        if (INPUT_PATTERN.matcher(line).find()) {
            tokens.add(new Token(VerilogTokenType.PORT_INPUT, file.getName(), 
                lineNumber, column, getLength(line, "input")));
        }
        
        if (OUTPUT_PATTERN.matcher(line).find()) {
            tokens.add(new Token(VerilogTokenType.PORT_OUTPUT, file.getName(), 
                lineNumber, column, getLength(line, "output")));
        }
        
        if (INOUT_PATTERN.matcher(line).find()) {
            tokens.add(new Token(VerilogTokenType.PORT_INOUT, file.getName(), 
                lineNumber, column, getLength(line, "inout")));
        }
        
        // Check for signal declarations
        if (WIRE_PATTERN.matcher(line).find() && !line.trim().startsWith("//")) {
            tokens.add(new Token(VerilogTokenType.DECL_WIRE, file.getName(), 
                lineNumber, column, getLength(line, "wire")));
        }
        
        if (REG_PATTERN.matcher(line).find()) {
            tokens.add(new Token(VerilogTokenType.DECL_REG, file.getName(), 
                lineNumber, column, getLength(line, "reg")));
        }
        
        if (PARAMETER_PATTERN.matcher(line).find()) {
            tokens.add(new Token(VerilogTokenType.DECL_PARAM, file.getName(), 
                lineNumber, column, getLength(line, "parameter")));
        }
        
        if (INTEGER_PATTERN.matcher(line).find()) {
            tokens.add(new Token(VerilogTokenType.DECL_INTEGER, file.getName(), 
                lineNumber, column, getLength(line, "integer")));
        }
        
        // Check for assignments
        if (ASSIGN_PATTERN.matcher(line).find()) {
            tokens.add(new Token(VerilogTokenType.ASSIGN_CONT, file.getName(), 
                lineNumber, column, getLength(line, "assign")));
        }
        
        // Check for procedural blocks
        if (ALWAYS_PATTERN.matcher(line).find()) {
            tokens.add(new Token(VerilogTokenType.BLOCK_ALWAYS, file.getName(), 
                lineNumber, column, getLength(line, "always")));
        }
        
        if (INITIAL_PATTERN.matcher(line).find()) {
            tokens.add(new Token(VerilogTokenType.BLOCK_INITIAL, file.getName(), 
                lineNumber, column, getLength(line, "initial")));
        }
        
        if (BEGIN_PATTERN.matcher(line).find()) {
            tokens.add(new Token(VerilogTokenType.BLOCK_BEGIN, file.getName(), 
                lineNumber, column, getLength(line, "begin")));
        }
        
        if (END_PATTERN.matcher(line).find() && !ENDMODULE_PATTERN.matcher(line).find() 
            && !ENDCASE_PATTERN.matcher(line).find()) {
            tokens.add(new Token(VerilogTokenType.BLOCK_END, file.getName(), 
                lineNumber, column, getLength(line, "end")));
        }
        
        // Check for control structures
        if (IF_PATTERN.matcher(line).find()) {
            tokens.add(new Token(VerilogTokenType.COND_IF, file.getName(), 
                lineNumber, column, getLength(line, "if")));
        }
        
        if (ELSE_PATTERN.matcher(line).find()) {
            tokens.add(new Token(VerilogTokenType.COND_ELSE, file.getName(), 
                lineNumber, column, getLength(line, "else")));
        }
        
        if (CASE_PATTERN.matcher(line).find()) {
            tokens.add(new Token(VerilogTokenType.COND_CASE, file.getName(), 
                lineNumber, column, getLength(line, "case")));
        }
        
        if (ENDCASE_PATTERN.matcher(line).find()) {
            tokens.add(new Token(VerilogTokenType.COND_CASE_END, file.getName(), 
                lineNumber, column, getLength(line, "endcase")));
        }
        
        if (DEFAULT_PATTERN.matcher(line).find()) {
            tokens.add(new Token(VerilogTokenType.COND_DEFAULT, file.getName(), 
                lineNumber, column, getLength(line, "default")));
        }
        
        // Check for loops
        if (FOR_PATTERN.matcher(line).find()) {
            tokens.add(new Token(VerilogTokenType.LOOP_FOR, file.getName(), 
                lineNumber, column, getLength(line, "for")));
        }
        
        if (WHILE_PATTERN.matcher(line).find()) {
            tokens.add(new Token(VerilogTokenType.LOOP_WHILE, file.getName(), 
                lineNumber, column, getLength(line, "while")));
        }
        
        if (REPEAT_PATTERN.matcher(line).find()) {
            tokens.add(new Token(VerilogTokenType.LOOP_REPEAT, file.getName(), 
                lineNumber, column, getLength(line, "repeat")));
        }
        
        if (FOREVER_PATTERN.matcher(line).find()) {
            tokens.add(new Token(VerilogTokenType.LOOP_FOREVER, file.getName(), 
                lineNumber, column, getLength(line, "forever")));
        }
        
        // Check for function/task
        if (FUNCTION_PATTERN.matcher(line).find()) {
            tokens.add(new Token(VerilogTokenType.FUNC_DECL, file.getName(), 
                lineNumber, column, getLength(line, "function")));
        }
        
        if (TASK_PATTERN.matcher(line).find()) {
            tokens.add(new Token(VerilogTokenType.TASK_DECL, file.getName(), 
                lineNumber, column, getLength(line, "task")));
        }
        
        // Check for compiler directives
        if (DIRECTIVE_PATTERN.matcher(line).find()) {
            tokens.add(new Token(VerilogTokenType.DIRECTIVE, file.getName(), 
                lineNumber, column, trimmed.length()));
        }
    }
    
    private int getLength(String line, String keyword) {
        int index = line.toLowerCase().indexOf(keyword.toLowerCase());
        if (index >= 0) {
            return keyword.length();
        }
        return 1;
    }
}
