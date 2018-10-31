package ast2obj;

class ONew extends OExpression {
    public var cls:OClass;
    public var expressions:Array<OExpression> = [];
}