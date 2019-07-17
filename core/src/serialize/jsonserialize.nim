import json
import tables
import sequtils
import core/[core]

type    
    JsonParser* = object
        value:string

    JsonPrinterStatic* = object

let JsonPrinterStaticInst* = JsonPrinterStatic()

proc printObject(obj:Dynamic):string = 
    let fields = obj.getFields()
    if fields.isNil or fields.length < 1:    
        return "{}"
    
    result = "{"
    for i in 0..<fields.length:
        if result.len > 1: result.add(", ")

        let field = fields[i]
        result.addQuoted(field.name)
        result.add(": ")
        let val = obj.getField(field.name)
        case val.kind
        of TString:
            result.add("\"" & $val & "\"")
        else:
            result.add($val)
        
    result.add("}")

proc parseNode(node:JsonNode):Dynamic =
    case node.kind
    of JObject:
        var res = newDynamicObject()        
        for key, val in node.fields.pairs():
            res.setField(key, parseNode(val))
        return toDynamic(res)
    of JString:
        return toDynamic(node.getStr())
    of JInt:
        return toDynamic(node.getInt())
    of JFloat:
        return toDynamic(node.getFloat())
    else:
        discard

proc newJsonParser*(value:string):JsonParser =
    JsonParser(value:value)

proc doParse*(this:JsonParser):Dynamic =
    let rootNode = parseJson(this.value)
    return parseNode(rootNode)

proc print*(this:JsonPrinterStatic, value:Dynamic, replacer:pointer = nil, space:pointer = nil):string =    
    case value.kind
    of TObject:
        return printObject(value)
    else:
        raise newException(ValueError, "Unsupported Dynamic type")