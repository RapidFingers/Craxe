package craxe.nim.native;

/**
 * Nim's "var" pass modificator to be possible modify value types
 */
@:forward
abstract Var<T>(T) from T to T {}