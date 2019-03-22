package ast2obj;

class OExpression {
    public var prevExpression:OExpression = null;
    public var nextExpression:OExpression = null;
    
    public var id:Int;
    
    public function new() {
    }
    
    public function findPrev<T>(type:Class<T>):T {
        var p = prevExpression;
        var r = null;
        while (p != null && !Std.is(p, OBlock)) {
            if (Std.is(p, type)) {
                r = p;
                break;
            }
            
            if (Std.is(p, OBinOp)) {
                p = cast(p, OBinOp).expression;
            } else {
                p = p.prevExpression;
            }
        }
        return cast r;
    }
}