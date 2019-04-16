package craxe.common.ast;

import craxe.common.ast.type.*;

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
     * All found typedefs
     */
    var typedefs(default, null):Array<TypedefInfo>;

    /**
     * All found structures
     */
    var structures(default, null):Array<StructInfo>;

    /**
     * All found enums
     */
    var enums(default, null):Array<EnumInfo>;

    /**
     * Information about entry point
     */
    var entryPoint(default, null):EntryPointInfo;
}