package craxe.nim;

import craxe.common.ast.ClassInfo;
import craxe.common.IndentStringBuilder;

/**
 * Code generator for interface
 */
class InterfaceGenerator {
    /**
     * Constructor
     */
    public function new() {}

    /**
     * Generate tuple object with interface fields
     */
    public function generateInterfaceObject(sb:IndentStringBuilder, interfaceInfo:ClassInfo) {
        var iname = interfaceInfo.classType.name;
        sb.add('${iname} = tuple[');
        sb.addNewLine(Inc);
        sb.add("obj : ref RootObj");
        for (fields in interfaceInfo.instanceFields) {

        }
        sb.addNewLine(Dec);
        sb.add("]");        
    }

    /**
     * Generate converter to interface for class
     */
    public function generateInterfaceConverter(sb:IndentStringBuilder, classInfo:ClassInfo, interfaceInfo:ClassInfo) {
        var iname = interfaceInfo.classType.name;
        var cname = classInfo.classType.name;
        sb.add('converter to${iname}(this:${cname}) : ${iname} = ');
        sb.addNewLine(Inc);
        sb.add("return (");
        sb.addNewLine(Inc);

        sb.add("obj: this,");

        sb.addNewLine(Dec);
        sb.add(")");
        sb.addBreak();
    }

    /**
     * Generate type checking for interface
     */
    public function generateTypeCheck(sb:IndentStringBuilder, interfaceInfo:ClassInfo) {

    }
}