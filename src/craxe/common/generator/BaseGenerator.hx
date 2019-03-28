package craxe.common.generator;

import craxe.common.ast.PreprocessedTypes;

/**
 * Base source code generator
 */
class BaseGenerator {
    /**
	 * Name of entry point
	 */
	public static inline final MAIN_METHOD = "main";

    /**
	 * Types to generate code
	 */
	public final types:PreprocessedTypes;

    /**
     * Constructor
     */
    public function new(types:PreprocessedTypes) {
        this.types = types;
    }

    /**
	 * Build sources
	 */
	public function build() {
        throw "Not implemented";
    }
}