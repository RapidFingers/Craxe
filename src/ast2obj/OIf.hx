package ast2obj;

class OIf extends OExpression {
    public var conditionExpression:OExpression;
    public var ifExpression:OExpression;
    public var elseExpression:OExpression;
}