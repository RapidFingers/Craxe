package craxe.builders.crystal;

/**
 * Type of new line
 */
enum NewLineType {
	None;
	Indent(v:IndentType);
}

enum IndentType {
	Remove;
	Same;
	Inc;
	Dec;
}

/**
 * Buffer item
 */
enum BufferItem {
	Data(s:String);
	Line(v:IndentType);
	Indent(v:IndentType);
}

/**
 * For string builder with indent
 */
class IndentStringBuilder {
	/**
	 * Count of spaces to indent
	 */
	static inline final INDENT_SPACE_COUNT = 4;

	/**
	 * Size of indent
	 */
	final indentSize:Int;

	/**
	 * String builder
	 */
	var buffer:Array<BufferItem>;

	/**
	 * Indent string
	 */
	var indentStr:String;

	/**
	 * Current indent
	 */
	public var indent(default, set):Int;

	public function set_indent(value:Int):Int {
		return indent;
	}

	/**
	 * Cursor on new line
	 */
	public var newLine(default, null):NewLineType;

	/**
	 * Calculate indent string
	 */
	private function calcIndent(ind:Int):String {
		var indStr = "";
		for (i in 0...ind * indentSize)
			indStr += " ";

		return indStr;
	}

	/**
	 * Constructor
	 */
	public function new(indentSize = INDENT_SPACE_COUNT) {
		this.indentSize = indentSize;
		buffer = new Array<BufferItem>();
		indent = 0;
		indentStr = "";
	}

	/**
	 * Increment indent
	 */
	public inline function inc() {
		buffer.push(Indent(Inc));
	}

	/**
	 * Decrement indent
	 */
	public inline function dec() {
		buffer.push(Indent(Dec));
	}

	/**
	 * Add value to buffer without indent
	 */
	public inline function add(value:String) {
		buffer.push(Data(value));
		newLine = None;
	}

	/**
	 * Add new Line
	 */
	public inline function addNewLine(indent:NewLineType = NewLineType.None) {
		newLine = indent;
		switch indent {
			case Indent(v):
				buffer.push(Line(v));
			default:
		}
	}

	/**
	 * Return string
	 */
	public inline function toString() {
		var res = new StringBuf();

		var ind = 0;
		var indStr = "";

		function proccIndent(v:IndentType) {
			switch v {
				case Remove:
					ind = 0;
				case Same:
				case Inc:
					ind += 1;
				case Dec:
					ind -= 1;
					if (ind < 0)
						ind = 0;
			}			
		}

		var state = 0;

		for (item in buffer) {
			switch item {
				case Data(s):
					if (state != 1) {
						indStr = calcIndent(ind);
						res.add(indStr);
					}

					res.add(s);
					state = 1;
				case Line(v):
					state = 2;
					res.add("\n");
					proccIndent(v);
				case Indent(v):
					state = 3;
					proccIndent(v);
			}
		}

		return res.toString();
	}
}
