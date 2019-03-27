package craxe.ast2obj;

/**
 * Class constructor info
 */
class OConstructor {
    /**
     * Arguments
     */
    public var args:Array<OMethodArg> = [];

    /**
     * Constructor expression
     */
    public var expression:OExpression;
    
    /**
     *  Constructor
     */
    public function new() {}
}