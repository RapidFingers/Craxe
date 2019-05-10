import json
import core/[core, dynamic]

type    
    JsonParser = object
    JsonPrinterStatic* = object

let JsonPrinterStaticInst* = JsonPrinterStatic()

proc newJsonParser(value:string):JsonParser =
    JsonParser()

proc print*(this:JsonPrinterStatic, value:Dynamic, replacer:pointer = nil, space:pointer = nil):string =    
    let fields = value.getFields()
    return $fields    