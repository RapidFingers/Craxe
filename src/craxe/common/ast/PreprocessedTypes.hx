package craxe.common.ast;

/**
 * Types from AST to generate code
 */
typedef PreprocessedTypes = {
    /**
     * Classes to generate
     */
    var classes(default, null):Array<ClassInfo>;

    /**
     * Enums to generate
     */
    var enums(default, null):Array<EnumInfo>;

    /**
     * Information about entry point
     */
    var entryPoint(default, null):EntryPointInfo;
}
