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
#pragma glslify: squareFrame = require("glsl-square-frame")
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

float bolt2(vec3 pos) {
  vec3 p = pos.xyz;
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
  float g = 1.;
  float g2 = g * 2.;
  // p *= 2.;
  // p = mod(p, vec3(g2, g2, 0.));
  // p -= vec3(g, g, 0.);

  // p += vec3(sin(t + p.y * 10.) * 0.1, 0., 0.);
  float r = g - 0.1;
  r += noise4d(vec4(p * 2., t)) * 0.1;
  float d = sdSphere(p, r);
  return vec2(d, 1.0);
  // p += noise4d(vec4(p * 20., t)) * 0.01;
  p = rotateX(p, t);
  p = rotateZ(p, t);
  float b0 = bolt0(p);
  p = rotateX(p, t);
  float b1 = bolt1(p);
  p = rotateZ(p, t);
  float b2 = bolt2(p);

  // float d = 1000.;
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

  vec3 dir1 = normalize(vec3(sin(t), cos(t), sin(t)));
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
  vec2 pos = squareFrame(resolution);
  vec3 color;
  float colorBand = sin((t - uv.y * 25.) / 9.) + 1.0;

  color = vec3(.0, 0.1, 0.1);
  float a = PI * 0.25;
  float s = 0.02;
  vec3 weft = vec3(0.1, 0.9, 0.3);

  // pos += vec2(0., noise2d(vec2(0., pos.y * 10.)) * 0.01);

  // vec2 ruv = mod(abs(pos), 0.2);

  // pos += noise3d(vec3(pos * 20., t)) * s * 0.1;
  vec2 ruv = mod(pos, s * 2.);
  pos += vec2(s * 0.75);
  vec2 posr = mod(pos, s * 2.);
  vec2 uv45 = vec2(posr.x * cos(a) - posr.y * sin(a),
                   posr.x * sin(a) + posr.y * cos(a));

  uv45 -= vec2(0., s * 1.40);
  uv45 = abs(uv45);
  // vec2 ruv = abs(pos);
  ruv = abs(ruv - s * 2.);
  // vec2 rotpos =
  vec2 cellloc = pos + vec2(s, s);
  cellloc += uv45;
  cellloc = floor(cellloc / (s * 2.));

  if (ruv.y - ruv.x > 0.) {
    cellloc.y += 0.5;
  }
  // cellloc.y *= 0.5;
  // cellloc += bands.xy;
  // float cellI = cellloc.x + (cellloc.y * 4. * 13.);
  // weft = hsv2rgb(vec3(cellI * 0.25, 0.5, 0.5));
  float d = 10000.;
  for (float i = 0.; i < 7.; i++) {
    // i += bands.x;
    vec2 ball_pos = vec2(noise2d(vec2(t + i * 20.)),
                         noise2d(vec2(t + i * 200. + vec2(100.))));
    ball_pos += vec2(sin(t * 10. + i), cos(t * 10. + i));
    // d = cellloc.x - ;
    float bd = length(cellloc * 0.1 - ball_pos * 1.0);
    d = smin(d, bd, 7.5);
    // d = min(d, bd);
  }
  // float n = noise3d(vec3(cellloc * 0.15 - vec2(0., -t * 0.90), t * 0.9) *
  // 0.95);
  weft = hsv2rgb(vec3(0.4, 0.8, 1.));
  if (d > 0.4) {
    weft *= 0.15;
  } else if (d > 0.2) {
    // weft *= 0.2;
  }
  cellloc += bands.yw;
  cellloc.y += (t + bands.x) * 20.;
  if (mod(cellloc.x + sin(cellloc.y * 0.5) * 4. + t * 2., 10.) < 7.) {

    // weft *= 0.25;
  }
  // if
  if (max(ruv.x, ruv.y) > s * 1.5 && min(uv45.x, uv45.y) > s * 0.1) {
    color = weft;
  }
  gl_FragColor.rgb = color;
  gl_FragColor.a = 1.0;
}