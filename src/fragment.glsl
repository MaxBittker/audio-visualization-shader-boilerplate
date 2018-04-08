precision highp float;
uniform float t;
uniform vec2 resolution;
uniform vec4 bands;
uniform sampler2D backBuffer;
uniform sampler2D spectrum;
// uniform sampler2D webcam;
// uniform vec2 videoResolution;
varying vec2 uv;

vec2 doModel(vec3 p);

// clang-format off
#pragma glslify: hsv2rgb = require('glsl-hsv2rgb')
#pragma glslify: luma = require(glsl-luma)
#pragma glslify: noise3d = require('glsl-noise/simplex/3d')
#pragma glslify: noise = require('glsl-fractal-brownian-noise/4d')
#pragma glslify: noise4d = require('glsl-noise/simplex/4d')
#pragma glslify: worley3D = require(glsl-worley/worley3D.glsl)
#pragma glslify: raytrace = require('glsl-raytrace', map = doModel, steps = 90)
#pragma glslify: normal = require('glsl-sdf-normal', map = doModel)
#pragma glslify: camera = require('glsl-turntable-camera')
#pragma glslify: orenn = require('glsl-diffuse-oren-nayar')
#pragma glslify: gauss = require('glsl-specular-gaussian')
#pragma glslify: sdPlane	= require('glsl-sdf-primitives/sdPlane')
#pragma glslify: calcAO = require('glsl-sdf-ops/ao', map = doModel )
// #pragma glslify: aU = require('glsl-sdf-ops/aU', map = doModel )

// clang-format on
vec2 pixel = vec2(1.0) / resolution;

#define PI 3.14159265359
#define PHI (1.618033988749895)
#define saturate(x) clamp(x, 0., 1.)
#define GDFVector0 vec3(1, 0, 0)
#define GDFVector1 vec3(0, 1, 0)
#define GDFVector2 vec3(0, 0, 1)
#define GDFVector3 normalize(vec3(1, 1, 1))
#define GDFVector4 normalize(vec3(-1, 1, 1))
#define GDFVector5 normalize(vec3(1, -1, 1))
#define GDFVector6 normalize(vec3(1, 1, -1))
#define GDFVector7 normalize(vec3(0, 1, PHI + 1.))
#define GDFVector8 normalize(vec3(0, -1, PHI + 1.))
#define GDFVector9 normalize(vec3(PHI + 1., 0, 1))
#define GDFVector10 normalize(vec3(-PHI - 1., 0, 1))
#define GDFVector11 normalize(vec3(1, PHI + 1., 0))
#define GDFVector12 normalize(vec3(-1, PHI + 1., 0))
#define GDFVector13 normalize(vec3(0, PHI, 1))
#define GDFVector13b normalize(vec3(0, PHI, -1))
#define GDFVector14 normalize(vec3(0, -PHI, 1))
#define GDFVector14b normalize(vec3(0, -PHI, -1))
#define GDFVector15 normalize(vec3(1, 0, PHI))
#define GDFVector15b normalize(vec3(1, 0, -PHI))
#define GDFVector16 normalize(vec3(-1, 0, PHI))
#define GDFVector16b normalize(vec3(-1, 0, -PHI))
#define GDFVector17 normalize(vec3(PHI, 1, 0))
#define GDFVector17b normalize(vec3(PHI, -1, 0))
#define GDFVector18 normalize(vec3(-PHI, 1, 0))
#define GDFVector18b normalize(vec3(-PHI, -1, 0))
#define fGDFBegin float d = 0.;

// Version with variable exponent.
// This is slow and does not produce correct distances, but allows for bulging
// of objects.
#define fGDFExp(v) d += pow(abs(dot(p, v)), e);

// Version with without exponent, creates objects with sharp edges and flat
// faces
#define fGDF(v) d = max(d, abs(dot(p, v)));

#define fGDFExpEnd return pow(d, 1. / e) - r;
#define fGDFEnd return d - r;

// Primitives follow:

float fDodecahedron(vec3 p, float r) {
  fGDFBegin fGDF(GDFVector13) fGDF(GDFVector14) fGDF(GDFVector15)
      fGDF(GDFVector16) fGDF(GDFVector17) fGDF(GDFVector18) fGDFEnd
}

float fIcosahedron(vec3 p, float r) {
  fGDFBegin fGDF(GDFVector3) fGDF(GDFVector4) fGDF(GDFVector5) fGDF(GDFVector6)
      fGDF(GDFVector7) fGDF(GDFVector8) fGDF(GDFVector9) fGDF(GDFVector10)
          fGDF(GDFVector11) fGDF(GDFVector12) fGDFEnd
}

float vmax(vec3 v) { return max(max(v.x, v.y), v.z); }

// Plane with normal n (n is normalized) at some distance from the origin
float fPlane(vec3 p, vec3 n, float distanceFromOrigin) {
  return dot(p, n) + distanceFromOrigin;
}

// Rotate around a coordinate axis (i.e. in a plane perpendicular to that axis)
// by angle <a>. Read like this: R(p.xz, a) rotates "x towards z". This is fast
// if <a> is a compile-time constant and slower (but still practical) if not.
void pR(inout vec2 p, float a) { p = cos(a) * p + sin(a) * vec2(p.y, -p.x); }

// Reflect space at a plane
float pReflect(inout vec3 p, vec3 planeNormal, float offset) {
  float t = dot(p, planeNormal) + offset;
  if (t < 0.) {
    p = p - (2. * t) * planeNormal;
  }
  return sign(t);
}

// --------------------------------------------------------
// http://www.neilmendoza.com/glsl-rotation-about-an-arbitrary-axis/
// --------------------------------------------------------

mat3 rotationMatrix(vec3 axis, float angle) {
  axis = normalize(axis);
  float s = sin(angle);
  float c = cos(angle);
  float oc = 1.0 - c;

  return mat3(oc * axis.x * axis.x + c, oc * axis.x * axis.y - axis.z * s,
              oc * axis.z * axis.x + axis.y * s,
              oc * axis.x * axis.y + axis.z * s, oc * axis.y * axis.y + c,
              oc * axis.y * axis.z - axis.x * s,
              oc * axis.z * axis.x - axis.y * s,
              oc * axis.y * axis.z + axis.x * s, oc * axis.z * axis.z + c);
}

// --------------------------------------------------------
// knighty
// https://www.shadertoy.com/view/MsKGzw
// --------------------------------------------------------

int Type = 5;
vec3 nc;
void initIcosahedron() { // setup folding planes and vertex
  float cospin = cos(PI / float(Type)), scospin = sqrt(0.75 - cospin * cospin);
  nc = vec3(-0.5, -cospin,
            scospin); // 3rd folding plane. The two others are xz and yz planes
}

void pModIcosahedron(inout vec3 p) {
  p = abs(p);
  pReflect(p, nc, 0.);
  p.xy = abs(p.xy);
  pReflect(p, nc, 0.);
  p.xy = abs(p.xy);
  pReflect(p, nc, 0.);
}

vec3 vMin(vec3 p, vec3 a, vec3 b, vec3 c) {
  float la = length(p - a);
  float lb = length(p - b);
  float lc = length(p - c);
  if (la < lb) {
    if (la < lc) {
      return a;
    } else {
      return c;
    }
  } else {
    if (lb < lc) {
      return b;
    } else {
      return c;
    }
  }
}

// Nearest icosahedron vertex
vec3 icosahedronVertex(vec3 p) {
  if (p.z > 0.) {
    if (p.x > 0.) {
      if (p.y > 0.) {
        return vMin(p, GDFVector13, GDFVector15, GDFVector17);
      } else {
        return vMin(p, GDFVector14, GDFVector15, GDFVector17b);
      }
    } else {
      if (p.y > 0.) {
        return vMin(p, GDFVector13, GDFVector16, GDFVector18);
      } else {
        return vMin(p, GDFVector14, GDFVector16, GDFVector18b);
      }
    }
  } else {
    if (p.x > 0.) {
      if (p.y > 0.) {
        return vMin(p, GDFVector13b, GDFVector15b, GDFVector17);
      } else {
        return vMin(p, GDFVector14b, GDFVector15b, GDFVector17b);
      }
    } else {
      if (p.y > 0.) {
        return vMin(p, GDFVector13b, GDFVector16b, GDFVector18);
      } else {
        return vMin(p, GDFVector14b, GDFVector16b, GDFVector18b);
      }
    }
  }
}

// Nearest vertex and distance.
// Distance is roughly to the boundry between the nearest and next
// nearest icosahedron vertices, ensuring there is always a smooth
// join at the edges, and normalised from 0 to 1
vec4 icosahedronAxisDistance(vec3 p) {
  vec3 iv = icosahedronVertex(p);
  vec3 originalIv = iv;

  vec3 pn = normalize(p);
  pModIcosahedron(pn);
  pModIcosahedron(iv);

  float boundryDist = dot(pn, vec3(1, 0, 0));
  float boundryMax = dot(iv, vec3(1, 0, 0));
  boundryDist /= boundryMax;

  float roundDist = length(iv - pn);
  float roundMax = length(iv - vec3(0, 0, 1.));
  roundDist /= roundMax;
  roundDist = -roundDist + 1.;

  float blend = 1. - boundryDist;
  blend = pow(blend, 6.);

  float dist = mix(roundDist, boundryDist, blend);

  return vec4(originalIv, dist);
}

// Twists p around the nearest icosahedron vertex
void pTwistIcosahedron(inout vec3 p, float amount) {
  vec4 a = icosahedronAxisDistance(p);
  vec3 axis = a.xyz;
  float dist = a.a;
  mat3 m = rotationMatrix(axis, dist * amount);
  p *= m;
}

float smin(float a, float b, float k) {
  float res = exp(-k * a) + exp(-k * b);
  return -log(res) / k;
}

float sdTorus(vec3 p, vec2 t) {
  vec2 q = vec2(length(p.xz) - t.x, p.y);
  return length(q) - t.y;
}
float udBox(vec3 p, vec3 b) { return length(max(abs(p) - b, 0.0)); }
vec2 doModel(vec3 p) {
  p += noise3d(p * 10. + t * 0.5) * max(0., (p.x + 0.5) * 0.02);
  float wobble = sin(PI / 20. * t);
  float wobbleX2 = sin(PI / 20. * t * 2.);
  pR(p.xy, wobbleX2 * .5);
  pR(p.xz, wobbleX2 * .5);
  float a = 3.;
  pTwistIcosahedron(p, a);
  return vec2(fIcosahedron(p, 1.), 0.0);
  p += bands.xyz * 0.1;
  float r = 1.;
  r += noise4d(vec4((p * 5.0), t)) * 0.15 * bands.y;
  r += noise4d(vec4((p * 12.5 * bands.x), t)) * 0.05;
  // r += noise4d(vec4((p * 10.5), t)) * 0.001;
  // r += noise4d(vec4((p * 2.0), t)) * 0.3 * 0.5 * 0.5;
  // r += (noise4d(vec4((p * 4.) + bands.z * 0.1, t)) * 0.3 * 0.25 * 0.5);
  // r += (noise4d(vec4((p * 8.)+  bands.w*0.1, t)) * 0.3* 0.125 * 0.5);

  // r = noise(vec4(p, t), 2) * 0.4;
  // r -= 1.01 * texture2D(spectrum, vec2(r - 1.2)).x;
  float h = 0.;
  // h = texture2D(spectrum, vec2((p.y * 0.1) + 0.4, 0.)).x;

  float d = length(p) - r * 1.6;
  // d = sdPlane(p - vec3(.0, r, h * 0.5), vec4(0., 0.6, 0.5, 0.0));
  // d = max(-d, p.y - 0.5);
  // r -= abs(worley3D((p * 2.5), 1.0, false).x * 0.2);
  p += vec3(0., -0.5 + (1.0 * sin(t * 2.)), 0.).xxy;
  p *= vec3(bands.x + 0.5, 0.2, 1.).xxy;
  d = max(d, -(length(p) - (r * 1.0)));

  // d = min(udBox(p, vec3(r) ), d);
  // d = max(d, length(p - vec3(0., 0., -0.5)) - 1.5);
  // r = 1.00 - 0.01;
  // d = min(d, length(p) - r);
  float id = 0.0;
  return vec2(d, id);
}

vec3 lighting(vec3 pos, vec3 nor, vec3 ro, vec3 rd) {
  float occ = calcAO(pos, nor);

  vec3 dir1 = normalize(vec3(1.));
  vec3 col1 = vec3(3.0, 2.0, 1.9);
  float grain = noise4d(vec4(nor * 80., t)) * 0.2;

  col1 = hsv2rgb(vec3(fract(dot(nor, rd) + grain) * 0.7, 0.3, 1.0));

  vec3 dif1 = col1 * orenn(dir1, -rd, nor, 0.15, 1.0);
  vec3 spc1 = col1 * gauss(dir1, -rd, nor, 0.15) * 0.2;

  vec3 dir2 = normalize(rd + nor);
  vec3 col2 = vec3(0.9, 0.9, 2.1);

  col2 = hsv2rgb(vec3((fract(dot(nor, dir2) + grain) * 0.8) + 0.4, 0.3, 2.8));

  vec3 dif2 = col2 * orenn(dir2, -rd, nor, 0.15, 1.0) * 1.0;
  vec3 spc2 = col2 * gauss(dir2, -rd, nor, 0.15) * 0.1;

  return vec3(0.1) + (dif1 + spc1 + dif2 + spc2) * occ * 0.9;
}

void main() {
  initIcosahedron();

  vec3 color;
  vec2 textCoord = uv * 0.5 + vec2(0.5);
  float colorBand = sin((t - uv.y * 25.) / 9.) + 1.0;
  float weight = 1.0;

  vec2 polar;
  polar.y = sqrt(uv.x * uv.x + uv.y * uv.y);
  // polar.y /= resolution.x / 2.0;
  polar.y = 1.0 - polar.y;
  polar.x = atan(uv.y, uv.x);
  polar.x -= 1.57079632679;
  if (polar.x < 0.0) {
    polar.x += 6.28318530718;
  }
  polar.x /= 6.28318530718;
  polar.x = 1.0 - polar.x;

  vec3 ro, rd;

  float rotation = 0.;
  float height = 0.0;
  float dist = 3.5;

  camera(rotation, height, dist, resolution.xy, ro, rd);

  vec2 tr = raytrace(ro, rd);
  vec3 pos;
  vec3 nor;
  if (tr.x > -0.5) {
    pos = ro + rd * tr.x;
    nor = normal(pos);
    color = lighting(pos, nor, ro, rd);
  }

  vec2 outward = normalize(vec2(0.0) - uv) * pixel * 2.;
  outward = vec2(0., 1.0) * pixel;
  vec2 randa = vec2(sin(t * 2.0), cos(t * 2.)) * pixel;
  vec2 sample = textCoord + outward;

  float mix = 0.1;
  vec3 color2 = 0.999 * (texture2D(backBuffer, sample).rgb * (1.0 - mix * 2.) +
                         texture2D(backBuffer, sample + randa).rgb * mix +
                         texture2D(backBuffer, sample - randa).rgb * mix);

  // color = texture2D(spectrum, abs(vec2(0.5) - sample)).rgb * 2.;

  if (length(color) < 0.01) {
    // color = color2;
  }
  // color += (color - color2 * 0.1) * 2.7;
  if (luma(color) < 0.8 + noise3d(vec3(uv * 200., length(bands)))) {
    // color = vec3(0.);
  } else {
    // color = vec3(1.0);
  }
  // color = max(color, color3);
  gl_FragColor.rgb = color;
  gl_FragColor.a = 1.0;
}