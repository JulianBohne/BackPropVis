import java.util.ArrayList;
import java.util.HashMap;
import java.util.Map;
import java.util.Iterator;

/*  
 *  Represents an XML node in the tree
 */
public static class XMLNode {

    public String key;
    public String value;
    private Map<String, String> attribs;
    public ArrayList<XMLNode> children;

    public XMLNode(){ this(""); }

    public XMLNode(String key){ this(key, ""); }

    public XMLNode(String key, String value){
        this.key = key;
        this.value = value;
        attribs = new HashMap<String, String>();
        children = new ArrayList<XMLNode>();
    }

    public void addChild(XMLNode node){
        children.add(node);
    }

    public boolean removeChild(XMLNode node){
        return children.remove(node);
    }
    
    public XMLNode childOfType(String keyType) {
      for (XMLNode node : children) {
        if (node.key.equals(keyType)) {
          return node;
        }
      }
      return null;
    }
    
    public XMLNode childWithID(String id) {
      for (XMLNode node : children) {
        if (node.attribs.containsKey("id") && node.attribs.get("id").equals(id)) {
          return node;
        }
      }
      return null;
    }
    
    public Map<String, XMLNode> genIDMap() {
      return genIDMap(new HashMap<>());
    }
    
    public Map<String, XMLNode> genIDMap(Map<String, XMLNode> idMap) {
      if (attribs.containsKey("id")) idMap.put(attribs.get("id"), this);
      for (XMLNode child : children) {
        child.genIDMap(idMap);
      }
      return idMap;
    }
    
    public XMLNode deepCopy() {
      return parse(toString());
    }

    // Adds or sets an attribute of node
    public void setAttrib(String key, String value){
        attribs.put(key, value);
    }
    
    public boolean hasAttrib(String key) {
      return attribs.containsKey(key);
    }
    
    public void removeAttrib(String key) {
      attribs.remove(key);
    }

    // Returns the corresponding attribute value, null if it's not set
    public String getAttrib(String key){
        return attribs.get(key);
    }

    public Map<String, String> getAttribs(){
        return attribs;
    }

    // Nicely formatted String containing this node and all the children (recursive)
    // @TODO: Replace '&' and other stuff :)
    @Override
    public String toString(){
        StringBuilder bob = new StringBuilder("<");
        bob.append(key);

        for (Map.Entry<String, String> entry : attribs.entrySet()) {
            bob.append(" " + entry.getKey() + "=\"" + entry.getValue() + "\"");
        }

        if(value.equals("") && children.size() == 0){
            return bob.append("/>").toString();
        }

        bob.append(">");

        if(!value.equals("")){
            return bob.append(value + "</" + key + ">").toString();
        }

        bob.append("\n");

        for (XMLNode node : children) {
            bob.append("    " + node.toString()
               .replaceAll("\n", "\n    ") + "\n");
        }

        return bob.append("</" + key + ">").toString();
    }

    public static XMLNode parse(String source) throws IllegalStateException {
        return new XMLParser(source).parse();
    }

    /*
    * Easy to use XMLParser 
    * (the code convention is a tiny bit inconsistent at times, but it works)
    */
    public static class XMLParser {

        // Turning this on will output intermediate steps while parsing - You can modify this
        private static final boolean DEBUG = false;

        // Only this version of xml is supported (don't modify unless it makes sense ig)
        private static final String SUPPORTED_VERSION = "1.0";

        // Just a copy of the source for nice errors
        private String[] lines;

        // This iterates over the source text while parsing
        private StringIterator it;


        // If you use this constructor you'll have to set the source text with 'setSource' yourself
        // or pass it into 'parse'
        public XMLParser(){
            it = null;
        }

        // If you use this constructer you just need to call 'parse' to parse the source
        public XMLParser(String source){
            setSource(source);
        }

        // Sets source to parse 
        public void setSource(String source){
            source = source.replaceAll("\r\n", "\n")
                        .replaceAll("\r", "\n")
                        .replace("\t", "    "); // Tabs don't play nicely with my error formating
            lines  = source.split("\n");
            it = new StringIterator(source);
        }

        // Parses source text and returns root of XML tree
        public XMLNode parse(String source){
            setSource(source);
            return parse();
        }

        // Parses source text and returns root of XML tree
        public XMLNode parse() throws IllegalStateException {

            if(it == null) throw new IllegalStateException("No source set. Try setting that with myParser.setSource() or add it in the constructor");

            skipWhitespace();
            
            if(!it.hasNext()){
                if(DEBUG) System.out.println("The source is empty.");
                return null;
            }

            if(it.peek(2).equals("<?")){
                parseXMLTag();
            }

            skipWhitespace();

            while(it.peek(2).equals("<!")){
                skipExclamTag();
                skipWhitespace();
            }

            if(!it.hasNext()){
                if(DEBUG) System.out.println("No root node found.");
                return null;
            }

            XMLNode root = parseNode();

            skipWhitespace();
            if(it.hasNext()){
                throwError("Expected EOF, but found: " + it.peek());
            }

            return root;
        }

        // Parses XML node and returns it
        private XMLNode parseNode(){
            skipWhitespace();

            expect('<');
            it.skip();

            expect();
            if(it.peek() == '!'){
                it.skip();
                expect("--");
                it.skip(2);

                skipComment();

                return null;
            }

            if(DEBUG) System.out.println("We got a node boys");

            XMLNode node = new XMLNode();

            node.key = parseNodeKey();
            
            if(DEBUG) System.out.println("And the name is " + node.key);

            parseNodeAttribs(node);

            skipWhitespace();

            expect();
            switch(it.next()){
                case '/':
                    expect('>');
                    it.skip();
                    if(DEBUG) System.out.println(node.key + " just closed itself");
                    break;
                case '>':
                    skipWhitespace();
                    if(it.peek() == '<'){
                        if(DEBUG) System.out.println(node.key + " got kids <3 (probably)");
                        parseNodeChildren(node);
                    }else {
                        if(DEBUG) System.out.println(node.key + " got a value");
                        parseNodeValue(node);
                    }

                    if(DEBUG) System.out.println("Now closing tag of " + node.key);
                    skipWhitespace(); // Closing tag
                    expect("</" + node.key);
                    it.skip(2 + node.key.length()); // Skip </NodeKey
                    skipWhitespace();
                    expect('>');
                    it.skip();
                    break;
                default:
                    throwError("Expected '/' or '>', but found: " + it.peek());
            }
            return node;
        }

        // parse all node attributes and add them to node
        private void parseNodeAttribs(XMLNode node){
            skipWhitespace();

            expect();
            char c = it.peek();
            while(c != '/' && c != '>'){
                parseNodeAttrib(node);
                skipWhitespace();
                expect();
                c = it.peek();
            }
        }

        // Parse one attribute and add it to node
        private void parseNodeAttrib(XMLNode node){
            skipWhitespace();

            StringBuilder bob_key = new StringBuilder();
            StringBuilder bob_value = new StringBuilder();

            // Parse attribute key
            expect();
            char c = it.peek();
            while(c != '=' && !Character.isWhitespace(c)){
                expectKeyChar();
                it.skip();
                bob_key.append(c);
                expect();
                c = it.peek();
            }

            skipWhitespace();
            expect('=');
            it.skip();

            // Check which type of quotes are used
            skipWhitespace();
            expect();
            char quotes = it.next();
            if(quotes != '\'' && quotes != '"'){
                throwError(it.pLine(), it.pColumn(), "Expected \" or ', but found " + quotes);
            }

            skipWhitespace();

            // Parse attribute value
            expect();
            c = it.peek();
            while(c != quotes){
                expectValueChar();
                if(c == '&'){
                    bob_value.append(parseEscapeChar());
                }else{
                    bob_value.append(c);
                }
                it.skip();
                expect();
                c = it.peek();
            }

            expect(quotes);
            it.skip();

            // Add attribute to node
            node.setAttrib(bob_key.toString(), bob_value.toString());
        }

        // Parse children of XML node and add them to node
        private void parseNodeChildren(XMLNode node){
            skipWhitespace();

            expect(2);
            XMLNode possible;
            while(!it.peek(2).equals("</")){
                possible = parseNode();
                if(possible != null) node.addChild(possible);
                skipWhitespace();
            }
        }

        // Parses XML node value and puts it into node <TagName>Node Value</TagName>
        private void parseNodeValue(XMLNode node){
            StringBuilder bob = new StringBuilder();
            while(expect(2) && !it.peek(2).equals("</")){
                expectValueChar();
                if(it.peek() == '&'){
                    bob.append(parseEscapeChar());
                }else{
                    bob.append(it.next());
                }
            }
            node.value = bob.toString();
        }

        // Returns corresponding character to escape sequence
        private char parseEscapeChar(){
            StringBuilder bob = new StringBuilder();
            char c;
            do{
                expect();
                c = it.next();
                bob.append(c);
            }while(c != ';');
            String s = bob.toString();
            switch(s){
                case "&quot;":
                    return '"';
                case "&apos;":
                    return '\'';
                case "&amp;":
                    return '&';
                case "&lt;":
                    return '<';
                case "&gt;":
                    return '>';
                default:
                    throwError("Unrecognized escape sequence: " + s);
                    return ' ';
            }
        }

        // Returns key of key value pair in tag <NodeKey />
        private String parseNodeKey(){
            StringBuilder bob = new StringBuilder();

            expect();
            char c = it.peek();
            while(!Character.isWhitespace(c) && c != '>' && c != '/'){
                expectKeyChar();
                it.skip();
                bob.append(c);
                expect();
                c = it.peek();
            }
            return bob.toString();
        }

        // Check if the <?xml ... ?> tag is ok
        private void parseXMLTag(){
            if(DEBUG) System.out.println("Parsing <?xml?> Tag.");
            expect("<?");
            it.skip(2); // Skip <?
            skipWhitespace();
            expect("xml");
            it.skip(3);

            XMLNode tmp = new XMLNode();
            skipWhitespace();
            int cLine = it.line(), cCol = it.column();
            parseNodeAttrib(tmp);
            String version = tmp.getAttrib("version");

            if(version == null){
                throwError(cLine, cCol, "Expected 'version' as first attribute in <?xml?> tag.");
                return;
            }

            if(!version.equals(SUPPORTED_VERSION)){
                throwError(cLine, cCol, "Only version " + SUPPORTED_VERSION + " supported.");
            }

            while(expect() && it.next() != '?');
            expect('>');
            it.skip();
        }

        // Skips tags that begin with <!
        private void skipExclamTag(){
            if(DEBUG) System.out.println("Skipping <!> Tag.");
            expect("<!");
            it.skip(2);
            expect();
            if(it.peek() == '!'){
                expect(2);
                if(it.peek(2).equals("!-")){
                    expect(3);
                    if(it.peek(3).equals("!--")){
                        it.skip(3);
                        skipComment();
                    }
                }
            }
            while(expect() && it.next() != '>');
        }

        // skips comment tag in XML file (<!-- COMMENT -->, but the <!-- is already gone)
        private void skipComment(){
            if(DEBUG) System.out.println("Skipping comment");
            expect(2);
            while(!it.peek(2).equals("--")){
                it.skip();
                expect(2);
            }
            it.skip(2); // skip --
            expect('>');
            it.skip();
        }

        // skips whitespace until next non whitespace character
        private void skipWhitespace(){
            while(it.hasNext() && Character.isWhitespace(it.peek())) it.skip();
        }

        // Returns true if c is allowed in an XML key, false otherwise
        private boolean checkKeyChar(char c){
            return (Character.isAlphabetic(c) || c == ':' || c == '_' || c =='-');
        }

        // Expects that the next character is allowed in an XML key -> Throws IllegalStateException if it's not
        private boolean expectKeyChar(){
            expect();
            if(checkKeyChar(it.peek())) return true;
            throwError("Keys/Attribute names can only contain [a-z], [A-Z], ':' and '_'");
            return false;
        }

        // Returns true if c is allowed in an XML value, false otherwise
        private boolean checkValueChar(char c){
            return !(c == '"' || c == '\'' || c == '<' || c == '>'); // Not checking for '&', because it's handled differently
        }

        // Expects that the next character is allowed in an XML value -> Throws IllegalStateException if it's not
        private boolean expectValueChar(){
            expect();
            if(checkValueChar(it.peek())) return true;
            throwError("Values can't contain '\"', ''', '&', '<' or '>'\n" + 
                    "\tIf you want to use these, use '&quot;' = '\"', '&apos;' = ''', '&amp;' = '&', '&lt;' = '<' and '&gt;' = '>'");
            return false;
        }

        // Expects that at least one character is left -> Throws IllegalStateException if none are left
        private boolean expect(){
            if(it.hasNext()) return true;
            throwError("Unexpected EOF");
            return false;
        }

        // Expects that amount many characters are left -> Throws IllegalStateException if less characters are left
        private boolean expect(int amount){
            if(it.amountLeft() >= amount) return true;
            it.skip(it.amountLeft());
            throwError("Unexpected EOF");
            return false;
        }

        // Expect a character in the StringIterator -> Throws IllegalStateException at current character if not found
        private boolean expect(char next){
            if(expect() && it.peek() == next){
                return true;
            }
            throwError("Expected " + next + " but found " + it.peek());
            return false;
        }

        // Expect a String in the StringIterator -> Throws IllegalStateException at current character if not found
        private boolean expect(String next){
            int nextLen = next.length();
            if(it.peek(nextLen).equals(next)){
                return true;
            }
            throwError("Expected " + next + ", but found " + it.peek(nextLen));
            return false;
        }

        // Throw a nicely formatted error at the current point in the string iterator
        private void throwError(String error) throws IllegalStateException{
            throwError(it.line(), it.column(), error);
        }

        // Throw an error at a specific line and column (the character where the error occurs is marked)
        private void throwError(int line, int column, String error) throws IllegalStateException{
            StringBuilder bob = new StringBuilder();
            bob.append("\nERROR:\t" + error + "\n");
            bob.append(line + ": " + lines[line-1] + "\n");
            for(int i = 0; i < (column-1) + Integer.toString(line).length() + 2; i ++){
                bob.append(" ");
            }
            bob.append("^\n");
            if(DEBUG) System.out.println(bob.toString());
            throw new IllegalStateException(bob.toString());
        }
    }

    /*
    * Used to iterate over a string
    * I feel like it is a tiny bit inefficient at times, but it works
    */
    public static class StringIterator implements Iterator<Character>{
        private String str;
        private int strLen; // string length
        private int cIndex; // index of current character
        private int lineCount;
        private int columCount; // Tabs will be counted as 1. Might cause misalignment
                                // Replace them with four spaces for better counting
        private int pLineCount; // Previous line
        private int pColumCount; // Previous column

        public StringIterator(String str){
            this.str = str;
            this.strLen = str.length();
            this.cIndex = 0;
            this.lineCount = 1;
            this.columCount = 1;
            this.pLineCount = 1;
            this.pColumCount = 1;
        }

        public int line(){
            return lineCount;
        }

        public int column(){
            return columCount;
        }

        public int pLine(){
            return pLineCount;
        }

        public int pColumn(){
            return pColumCount;
        }

        public boolean hasNext(){
            return cIndex < strLen;
        }

        // Returns the next character and moves on to the next
        public Character next(){
            if(!hasNext()) throw new IllegalAccessError("EOF Reached"); // No more text :(
            pLineCount = lineCount;
            pColumCount = columCount;
            char c = str.charAt(cIndex);
            if(c == '\n'){
                lineCount ++; // A new line occured
                columCount = 1;
            }else{
                columCount ++; // Not a new line, so just move the cursor
            }
            return str.charAt(cIndex ++);
        }

        // Skips one character
        public void skip(){
            if(hasNext()){
                // We still have to update all the cursor information
                pLineCount = lineCount;
                pColumCount = columCount;
                char c = str.charAt(cIndex);
                if(c == '\n'){
                    lineCount ++;
                    columCount = 1;
                }else{
                    columCount ++;
                }
                cIndex ++;
            }
        }
        
        // Peek one character, doesn't move on to the next character
        public char peek(){
            if(!hasNext()) throw new IllegalAccessError("EOF Reached"); // No characters? ',:/
            return str.charAt(cIndex);
        }

        // Returns the amount of characters left to read in the string
        public int amountLeft(){
            return strLen - cIndex;
        }

        // Skips multiple characters
        public void skip(int amount){
            // Using 'skip()' because it also updates important cursor data
            for(int i = 0; i < amount && hasNext(); i ++) skip();
        }

        // Get multiple characters
        public String next(int amount){
            StringBuilder bob = new StringBuilder();

            while(amount > 0 && hasNext()){
                bob.append(next());
            }

            return bob.toString();
        }

        // Peek multiple characters
        public String peek(int amount){
            amount = Math.min(Math.max(amount, 0), amountLeft());
            return str.substring(cIndex, cIndex + amount);
        }
    }
}
