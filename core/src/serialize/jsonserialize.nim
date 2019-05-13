import json
import tables
import core/[core, dynamic]

type    
    JsonParser* = object
        value:string

    JsonPrinterStatic* = object

let JsonPrinterStaticInst* = JsonPrinterStatic()

proc printObject(fields:Table[string, Dynamic]):string =
    if fields.len < 1:
        return "{}"
    
    result = "{"
    for key, val in pairs(fields):
        if result.len > 1: result.add(", ")
        result.addQuoted(key)
        result.add(": ")
        case val.kind
        of TString:
            result.add("\"" & $val & "\"")
        else:
            result.add($val)
        
    result.add("}")

proc parseNode(node:JsonNode):Dynamic =
    case node.kind
    of JObject:
        result = newDynamicObject()
        for key, val in node.fields.pairs():
            result.setField(key, parseNode(val))
    of JString:
        return node.getStr()
    of JInt:
        return node.getInt()
    of JFloat:
        return node.getFloat()
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
        return printObject(value.getFields())
    else:
        raise newException(ValueError, "Unsupported Dynamic type")