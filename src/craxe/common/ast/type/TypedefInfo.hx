package craxe.common.ast.type;

import haxe.macro.Type;
import haxe.macro.Type.DefType;

/**
 * Info about typedef
 */
class TypedefInfo {    
    /**
     * AST typedef info
     */
    public final typedefInfo:DefType;

    /**
     * Type parameters
     */
    public final params:Array<Type>;    

    /**
     * Constructor     
     */
    public function new(typedefInfo:DefType, params:Array<Type>) {
        this.typedefInfo = typedefInfo;
        this.params = params;
    }
}