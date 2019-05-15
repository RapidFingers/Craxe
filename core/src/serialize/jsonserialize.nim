import json
import tables
import sequtils
import core/[core, dynamic]

type    
    JsonParser* = object
        value:string

    JsonPrinterStatic* = object

let JsonPrinterStaticInst* = JsonPrinterStatic()

proc printObject(anon:AnonObject):string =
    if anon.names.len < 1:
        return "{}"
    
    result = "{"
    for i in 0..<anon.names.len:
        if result.len > 1: result.add(", ")

        result.addQuoted(anon.names[i])
        result.add(": ")
        let val = anon.values[i]
        case val.kind
        of TString:
            result.add("\"" & $val & "\"")
        else:
            result.add($val)
        
    result.add("}")

proc parseNode(node:JsonNode):Dynamic =
    case node.kind
    of JObject:
        var keys = toSeq(node.fields.keys)
        var res = newAnonObject(keys)
        var i = 0
        for key, val in node.fields.pairs():
            res.setField(i, parseNode(val))
            inc(i)
        return res
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
    of TAnonObject:
        return printObject(value.fanon)
    else:
        raise newException(ValueError, "Unsupported Dynamic type")