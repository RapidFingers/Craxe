package craxe.common.ast;

/**
 * Types from AST to generate code
 */
typedef PreprocessedTypes = {
    /**
     * All found interfaces
     */
    var interfaces(default, null):Array<InterfaceInfo>;

    /**
     * All found classes
     */
    var classes(default, null):Array<ClassInfo>;

    /**
     * All found enums
     */
    var enums(default, null):Array<EnumInfo>;

    /**
     * Information about entry point
     */
    var entryPoint(default, null):EntryPointInfo;
}