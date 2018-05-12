precision highp float;
uniform float t;
uniform vec2 resolution;
uniform vec4 bands;
uniform float m[8]; // midi
uniform sampler2D backBuffer;
uniform sampler2D spectrum;
// uniform sampler2D webcam;
// uniform vec2 videoResolution;
varying vec2 uv;
float m0 = m[0];
float m1 = m[1];
float m2 = m[2];
float m3 = m[3];
float m4 = m[4];
float m5 = m[5];
float m6 = m[6];
float m7 = m[7];
vec2 doModel(vec3 p);

// clang-format off
#pragma glslify: rotateX = require("./rotateX")
#pragma glslify: rotateY = require("./rotateY")
#pragma glslify: rotateZ = require("./rotateZ")

#pragma glslify: hsv2rgb = require('glsl-hsv2rgb')
#pragma glslify: luma = require(glsl-luma)
#pragma glslify: smin = require(glsl-smooth-min/exp)
#pragma glslify: noise2d = require('glsl-noise/simplex/2d')
#pragma glslify: noise3d = require('glsl-noise/simplex/3d')
#pragma glslify: noise = require('glsl-fractal-brownian-noise/4d')
#pragma glslify: noise4d = require('glsl-noise/simplex/4d')
#pragma glslify: worley3D = require(glsl-worley/worley3D.glsl)
#pragma glslify: raytrace = require('glsl-raytrace', map = doModel, steps = 90)
#pragma glslify: normal = require('glsl-sdf-normal', map = doModel)
#pragma glslify: camera = require('glsl-turntable-camera')
#pragma glslify: orenn = require('glsl-diffuse-oren-nayar')
#pragma glslify: gauss = require('glsl-specular-gaussian')

#pragma glslify: sdSphere	= require('glsl-sdf-primitives/sdSphere')
#pragma glslify: sdPlane	= require('glsl-sdf-primitives/sdPlane')
#pragma glslify: sdBox	= require('glsl-sdf-primitives/sdBox')
#pragma glslify: sdCylinder	= require('glsl-sdf-primitives/sdCylinder')
#pragma glslify: sdTorus	= require('glsl-sdf-primitives/sdTorus')
#pragma glslify: sdHexPrism	= require('glsl-sdf-primitives/sdHexPrism')
#pragma glslify: sdCappedCone	= require('glsl-sdf-primitives/sdCappedCone')
#pragma glslify: sdCappedCylinder	= require('glsl-sdf-primitives/sdCappedCylinder')

#pragma glslify: calcAO = require('glsl-sdf-ops/ao', map = doModel )
// #pragma glslify: aU = require('glsl-sdf-ops/aU', map = doModel )

// clang-format on
vec2 pixel = vec2(1.0) / resolution;

#define PI 3.14159265359
#define PHI (1.618033988749895)
#define saturate(x) clamp(x, 0., 1.)

vec3 opTwist(vec3 p) {
  float c = cos(10.0 * p.y + 10.0);
  float s = sin(10.0 * p.y + 10.0);
  mat2 m = mat2(c, -s, s, c);
  return vec3(m * p.xz, p.y);
}

float bolt0(vec3 p) {
  p = rotateY(p, t * 2.);
  // p = rotateX(p, t);
  float r = 0.15;
  float d = sdCappedCylinder(p, vec2(r, 0.9));

  vec3 threadp = p;
  threadp = rotateY(threadp, p.y * 45.);

  d = smin(d, sdBox(threadp, vec3(0.1, 0.9, 0.1)), 30.0);

  vec3 hexp = (vec4(p + vec3(0, -.9, 0), 1.0)).xzy;
  float top = min(d, sdHexPrism(hexp, vec2(0.3, 0.15)));

  float dome = sdSphere((hexp + vec3(0., 0., -0.1)) * vec3(1., 1., 2.), 0.3);
  top = min(top, dome);

  d = min(top, d);
  float neck =
      min(d, sdCappedCylinder(p + vec3(0., -0.6, 0.), vec2(r + 0.05, 0.15)));
  d = min(d, neck);
  return d;
}

float bolt1(vec3 p) {
  p += vec3(0.5, 0., 0.);
  p = rotateY(p, t * 2.);
  // p = rotateZ(p, t);
  float r = 0.12;
  float d = sdCappedCylinder(p, vec2(r, 0.7));

  vec3 threadp = p;
  threadp = rotateY(threadp, p.y * 45.);

  d = smin(d, sdBox(threadp, vec3(0.07, 0.7, 0.07)), 30.0);

  float neck =
      min(d, sdCappedCylinder(p + vec3(0., -0.5, 0.), vec2(r + 0.02, 0.20)));
  d = min(d, neck);

  vec3 hexp = (vec4(p + vec3(0, -.7, 0), 1.0)).xzy;
  float dome = sdSphere((hexp + vec3(0., 0., 0.)) * vec3(1., 1., 1.5), 0.25);

  float top = dome;
  top = max(dome, sdPlane(p, normalize(vec4(0, -1.5, 0, 1.0))));

  top = min(top, sdCappedCylinder(p + vec3(0., -0.69, 0.), vec2(0.249, 0.03)));

  d = min(top, d);
  float notch = sdBox(p + vec3(0., -0.85, 0.0), vec3(0.04, 0.07, 0.8));
  d = max(d, -notch);
  return d;
}

float bolt2(vec3 p) {
  p -= vec3(0.5, 0.0, 0.5);
  p = rotateY(p, t);
  // p = rotateX(p, PI * noise2d(vec2(t * 0.5, 0.)));
  // p = rotateX(p, PI * noise2d(vec2(t * 0.5, 0.)));
  float r = smin((p.y * 0.9) + 0.9, 0.5, 30.) * 0.2;
  float d = sdCappedCylinder(p, vec2(r, 1.0));

  vec3 threadp = p;
  threadp = rotateY(threadp, p.y * 45.);

  d = smin(d,
           sdBox(threadp + vec3(0., 0.25, 0.), vec3(0., 0.8, 0.02 + (0.7 * r))),
           30.0);

  float neck =
      min(d, sdCappedCylinder(p + vec3(0., -0.8, 0.), vec2(r + 0.01, 0.20)));
  d = min(d, neck);

  vec3 hexp = (vec4(p + vec3(0, -0.9, 0), 1.0)).xzy;

  float cone = sdCappedCone(rotateX(hexp, PI * 1.5), vec3(0.25, 0.27, 0.20));
  float notch = sdBox(p + vec3(0., -1.09, 0.0), vec3(0.02, 0.04, 0.8));
  float top = max(cone, -notch);
  d = min(d, top);
  return d;
}

vec2 doModel(vec3 p) {
  // p += noise4d(vec4(p * 20., t)) * 0.01;
  p = rotateX(p, t);
  p = rotateZ(p, t);
  float b0 = bolt0(p);
  p = rotateX(p, t);
  float b1 = bolt1(p);
  p = rotateZ(p, t);
  float b2 = bolt2(p);

  float d = 1000.;
  float id = 1.0;

  float f = mod(t * 10., 300.);

  if (f > 140.) {
    d = min(d, b0);
  }

  if (f < 160.) {

    if (d > b1) {
      id = 2.0;
    }
    d = min(d, b1);
  }
  if (f < 40. || f > 260.) {
    if (d > b2) {
      id = 3.0;
    }
    d = min(d, b2);
  }

  return vec2(d, id);
}

vec3 lighting(vec3 pos, vec3 nor, vec3 ro, vec3 rd, float id) {
  float occ = calcAO(pos, nor);

  vec3 dir1 = normalize(vec3(1.));
  vec3 col1 = hsv2rgb(vec3(0.9 * id, 0.5, 1.0));

  // float grain = noise4d(vec4(nor * 80., t)) * 0.2;

  // col1 = hsv2rgb(vec3((fract(dot(nor, rd) + grain) * 0.23), 0.8, 1.0));

  vec3 dif1 = col1 * orenn(dir1, -rd, nor, 0.15, 1.0);
  vec3 spc1 = col1 * gauss(dir1, -rd, nor, 0.15) * 0.1;

  vec3 dir2 = normalize(nor + ro);
  vec3 col2 = hsv2rgb(vec3(0.2 * id, 0.5, 1.0));

  // col2 = hsv2rgb(vec3((fract(dot(nor, dir2) + grain) * 0.1) + id, 0.1,
  // 0.8));

  vec3 dif2 = col2 * orenn(dir2, -rd, nor, 0.15, 1.0) * 1.0;
  vec3 spc2 = col2 * gauss(dir2, -rd, nor, 0.15) * 0.1;

  return vec3(0.01) + (dif1 + spc1 + ((dif2 + spc2) * occ));
  // return vec3(0.01) + (dif1 + spc1 + ((dif2 + spc2)));
}

void main() {

  vec3 color;
  vec2 textCoord = uv * 0.5 + vec2(0.5);
  float colorBand = sin((t - uv.y * 25.) / 9.) + 1.0;
  float weight = 1.0;

  vec3 ro, rd;

  float rotation = t;
  float height = 2.;
  float dist = 2.;

  camera(rotation, height, dist, resolution.xy, ro, rd);

  vec2 tr = raytrace(ro, rd, 100., 0.0001);
  vec3 pos;
  vec3 nor;
  if (tr.x > -0.9) {
    pos = ro + rd * tr.x;
    nor = normal(pos);
    color = lighting(pos, nor, ro, rd, tr.y);

    float l = luma(color);
    float s = 0.1 + (floor(l * 10.) / 10.);
    // color = hsv2rgb(vec3(m4 + tr.y / 5. + ((s - 0.5) * 0.5), s + 0.05, s));

    // if (10. > 0.1) {

    // if (luma(color) < 0.3 + (sin(uv.x * 1000.) + cos(uv.y * 1000.)) * 0.1) {
    if (luma(color) < 0.3 + noise3d(vec3(uv * 250., t)) * 0.1) {
      // color = max(color, color2);
      color = vec3(0.);
    } else {
      // color = vec3(1.0);
      color = hsv2rgb(vec3(tr.y / 5., 0.3, 0.9));
    }
    // }

  } else {

    vec2 outward = normalize(vec2(0.0) - uv) * pixel * 2.;
    outward = vec2(0., 1.0) * pixel;
    vec2 randa = vec2(sin(t * 2.0), cos(t * 2.)) * pixel;
    vec2 sample = textCoord + outward;

    float mix = 0.2;
    vec3 color2 =
        1.000 * (texture2D(backBuffer, sample).rgb * (1.0 - mix * 2.) +
                 texture2D(backBuffer, sample + randa).rgb * mix +
                 texture2D(backBuffer, sample - randa).rgb * mix);
    vec3 backColor = texture2D(backBuffer, sample).rgb;
    // color = texture2D(spectrum, abs(vec2(0.5) - sample)).rgb * 2.;

    // color = color2;
    if (uv.y < 1.0 - pixel.y) {
      color = backColor;
    }
  }

  gl_FragColor.rgb = color;
  gl_FragColor.a = 1.0;
}