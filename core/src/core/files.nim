type
    FileStatic = object

let FileStaticInst* = FileStatic()

# File
template getContent*(this:FileStatic, path:string): string =
    readFile(path)