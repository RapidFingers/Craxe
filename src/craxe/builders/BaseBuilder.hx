package craxe.builders;

import craxe.ast2obj.OEnum;
import craxe.ast2obj.OClass;

/**
 * Types to generate code
 */
typedef GeneratedTypes = {
    /**
     * Classes to generate
     */
    var classes(default, null):Array<OClass>;

    /**
     * Enums to generate
     */
    var enums(default, null):Array<OEnum>;
}

/**
 * Base source code builder
 */
class BaseBuilder {
    /**
	 * Name of entry point
	 */
	public static inline final MAIN_METHOD = "main";

    /**
	 * Classes to build source
	 */
	public final types:GeneratedTypes;

    /**
     * Constructor
     */
    public function new(types:GeneratedTypes) {
        this.types = types;
    }

    /**
	 * Build sources
	 */
	public function build() {
        throw "Not implemented";
    }
}