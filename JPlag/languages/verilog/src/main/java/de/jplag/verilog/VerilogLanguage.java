package de.jplag.verilog;

import de.jplag.AbstractParser;
import de.jplag.Language;

/**
 * Verilog language support for JPlag.
 * This is a simplified implementation for RTL code similarity detection.
 */
public class VerilogLanguage extends Language {
    private final AbstractParser adapter = new VerilogParserAdapter();
    
    @Override
    public String[] suffixes() {
        return new String[]{"v", "vh", "sv"};
    }

    @Override
    public String getName() {
        return "Verilog";
    }

    @Override
    public String getIdentifier() {
        return "verilog";
    }

    @Override
    public int minimumTokenMatch() {
        return 8;
    }

    @Override
    public AbstractParser getParser() {
        return adapter;
    }
    
    @Override
    public boolean isPreFull() {
        return false;
    }
}
