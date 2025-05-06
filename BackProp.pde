PShape shape = null;
PShape shape2 = null;
PShape shape3 = null;

float scale = 4;

void setup() {
  size(800, 600);
  
  shape  = texToSVG("\\newcommand \\e{\\text{e}} f(x) = x^2 \\frac{1}{2} \\e^x");
  shape2 = texToSVG("\\begin{bmatrix} \\cos a & - \\sin b \\\\ \\sin c & \\cos d \\end{bmatrix}  ");
  shape3 = texToSVG("x\\omega \\mathbf{a}");
  PShape child = shape.getChild(0);
  
  colorMode(RGB);
  child.getChild(0).setFill(color(255, 0, 0));
}

void draw() {
  background(255);
  scale(5);
  colorMode(HSB);
  shape.setFill(color(frameCount%255, 200, 255));
  shape(shape, 0, 0);
  shape(shape2, 0, shape.height);
  shape(shape3, 0, shape.height + shape2.height);
}
