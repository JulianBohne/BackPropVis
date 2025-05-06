// load XML errors from processing (not my XML thingy)
import javax.xml.parsers.ParserConfigurationException;
import org.xml.sax.SAXException;

// Read output of Process
import java.io.InputStreamReader;

String ex2px(String ex) {
  final float factor = 7.154414351037636;
  if (!ex.endsWith("ex")) {
    println("WARNING - ex2px input does not have unit \"ex\": " + ex);
  }
  return String.valueOf(Float.parseFloat(ex.substring(0, ex.length() - 2)) * factor) + "px";
}

void replaceUseTags(XMLNode node, Map<String, XMLNode> defByID) {
  for (int i = 0; i < node.children.size(); ++i) {
    XMLNode child = node.children.get(i);
    if (child.key.equals("use")) {
      XMLNode def = defByID.get(child.getAttrib("xlink:href").substring(1)).deepCopy();
      def.removeAttrib("id");
      node.children.set(i, def);
      for (Map.Entry<String, String> entry : child.attribs.entrySet()) {
        if (!entry.getKey().equals("xlink:href") && !entry.getKey().equals("x") && !entry.getKey().equals("y")) {
          def.setAttrib(entry.getKey(), entry.getValue());
        }
      }
      
      float offsetX = 0;
      float offsetY = 0;
      if (child.hasAttrib("x")) {
        offsetX = Float.parseFloat(child.getAttrib("x"));
      }
      if (child.hasAttrib("y")) {
        offsetY = Float.parseFloat(child.getAttrib("y"));
      }
      String transform = "";
      if (child.hasAttrib("transform")) {
        transform = child.getAttrib("transform") + " ";
      }
      def.setAttrib("transform", transform + "translate(" + offsetX + "," + offsetY + ")");
    } else {
      replaceUseTags(child, defByID);
    }
  }
}

String cleanSVGString(String baseSVGString) {
  XMLNode root = XMLNode.parse(baseSVGString);
  
  if (root == null) {
    println("Root is null, this was the baseSVGString:");
    println("`" + baseSVGString + "`");
    return baseSVGString;
  }
  
  root.setAttrib("height", ex2px(root.getAttrib("height")));
  root.setAttrib("width", ex2px(root.getAttrib("width")));
  
  XMLNode defs = root.childOfType("defs");
  root.removeChild(defs);
  
  Map<String, XMLNode> defByID = defs.genIDMap();
  
  XMLNode rootGroup = root.childOfType("g");
  rootGroup.removeAttrib("stroke");
  rootGroup.removeAttrib("fill");
  
  replaceUseTags(rootGroup, defByID);
  
  return root.toString();
}

static final String tex2svgCommand = "tex2svg.cmd"; // npm install --global mathjax-node-cli
PShape texToSVG(String texString) {
  
  XML loadedXML;
  String cachedFileName = "tmp/TEX-" + String.format("%010d", ((long)texString.hashCode()) - (long)Integer.MIN_VALUE) + ".xml";
  File cachedFile = dataFile(cachedFileName);
  cachedFileName = "data/" + cachedFileName;
  
  if (cachedFile.isFile()) {
    println("Trying cached XML: `" + texString + "` -> " + cachedFileName);
    loadedXML = loadXML(cachedFileName);
    if (loadedXML != null) {
      return new PShapeSVG(loadedXML);
    }
  }
  
  try {
    println("Executing: " + tex2svgCommand + " `" + texString + "`");
    
    ProcessBuilder pb = new ProcessBuilder(tex2svgCommand, texString);
    Process process = pb.start();
    InputStream is = process.getInputStream();
    InputStreamReader isr = new InputStreamReader(is);
    BufferedReader br = new BufferedReader(isr);
    String line;
    StringBuilder bob = new StringBuilder();
    
    while ((line = br.readLine()) != null) {
      bob.append(line);
      bob.append('\n');
    }
    
    String baseSVGString = bob.toString();
    
    String cleanedSVGString = cleanSVGString(baseSVGString);
    
    loadedXML = XML.parse(cleanedSVGString);
    
    saveXML(loadedXML, cachedFileName);
    
    PShape svgShape = new PShapeSVG(loadedXML);

    println("Success!");
    return svgShape;

  } catch (IOException e) {
    println("IO :(");
    e.printStackTrace();
  } catch (ParserConfigurationException e) {
    println("XML Parser Configuration :(");
    e.printStackTrace();
  } catch (SAXException e) {
    println("XML :(");
    e.printStackTrace();    
  } catch (NullPointerException e) {
    println("Check if you forgot to escape the backslashes :')");
    e.printStackTrace();
  }
  
  return null;
}
