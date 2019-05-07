package craxe.nim.http;

/**
 * Http method enum
 */
enum abstract HttpMethod(Int) {
    var HttpHead = 0;
    var HttpGet = 1;
    var HttpPost = 2;
    var HttpPut = 3;
    var HttpDelete = 4;
    var HttpTrace = 5;
    var HttpOptions = 6;
    var HttpConnect = 7;
    var HttpPatch = 8;
}