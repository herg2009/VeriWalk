# JPlag Verilog Language Module

This module adds Verilog HDL support to JPlag for detecting similarities in RTL code.

## Features

- Supports `.v`, `.vh`, and `.sv` file extensions
- Detects key Verilog RTL structures:
  - Module declarations
  - Port declarations (input, output, inout)
  - Signal declarations (wire, reg, parameter, integer)
  - Procedural blocks (always, initial)
  - Control structures (if-else, case-endcase)
  - Assignments (continuous and procedural)
  - Loop constructs (for, while, repeat, forever)
  - Module instantiations

## Usage

### Command Line Interface

```bash
# Basic usage
jplag -l verilog /path/to/verilog/submissions

# With similarity threshold
jplag -l verilog -m 0.5 /path/to/verilog/submissions

# With minimum token match
jplag -l verilog -t 6 /path/to/verilog/submissions

# Export results as CSV
jplag -l verilog --csv-export /path/to/verilog/submissions
```

### Java API

```java
import de.jplag.verilog.VerilogLanguage;
import de.jplag.JPlag;
import de.jplag.JPlagOptions;
import de.jplag.JPlagResult;

Language language = new VerilogLanguage();
Set<File> submissionDirectories = Set.of(new File("/path/to/verilog/files"));
JPlagOptions options = new JPlagOptions(language, submissionDirectories, Set.of());

try {
    JPlagResult result = JPlag.run(options);
    // Process results
} catch (ExitException e) {
    // Error handling
}
```

## Token Types

The module extracts the following token types from Verilog code:

| Token Type | Description |
|------------|-------------|
| MODULE_DECL | Module declaration |
| MODULE_BEGIN | Module body start |
| MODULE_END | Module body end |
| PORT_INPUT | Input port declaration |
| PORT_OUTPUT | Output port declaration |
| PORT_INOUT | Inout port declaration |
| DECL_WIRE | Wire declaration |
| DECL_REG | Reg declaration |
| DECL_PARAM | Parameter declaration |
| BLOCK_ALWAYS | Always block |
| BLOCK_INITIAL | Initial block |
| ASSIGN_CONT | Continuous assignment |
| COND_IF | If statement |
| COND_CASE | Case statement |
| ENDCASE | Endcase statement |

## Limitations

This is a simplified implementation that uses pattern matching rather than full parsing. It may not handle:
- Complex macro expansions
- Generate blocks
- Advanced SystemVerilog features
- Syntax errors in Verilog code

For production use with complex RTL codebases, consider extending this module with a full ANTLR-based parser.

## Building

The module is automatically built as part of the JPlag Maven build:

```bash
cd /path/to/JPlag
mvn clean package
```

## Testing

Place test Verilog files in `src/test/resources/de/jplag/verilog/` and run:

```bash
mvn test
```
