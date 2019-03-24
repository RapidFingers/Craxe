package craxe.builders;

import craxe.ast2obj.OClass;

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
	public final classes:Array<OClass>;

    /**
     * Constructor
     */
    public function new(classes:Array<OClass>) {
        this.classes = classes;
    }

    /**
	 * Build sources
	 */
	public function build() {
        throw "Not implemented";
    }
}