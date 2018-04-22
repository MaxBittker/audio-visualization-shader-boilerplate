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

float smin(float a, float b, float k) {
  float res = exp(-k * a) + exp(-k * b);
  return -log(res) / k;
}

float sdTorus(vec3 p, vec2 t) {
  vec2 q = vec2(length(p.xz) - t.x, p.y);
  return length(q) - t.y;
}

float udBox(vec3 p, vec3 b) { return length(max(abs(p) - b, 0.0)); }

// clang-format off

mat4 rotateX(float theta) {
  float c = cos(theta);
  float s = sin(theta);
  return mat4(
   vec4(1, 0, 0, 0),
   vec4(0, c, -s, 0),
   vec4(0, s, c, 0),
   vec4(0, 0, 0, 1));
}

mat4 rotateY(float theta) {
  float c = cos(theta);
  float s = sin(theta);
  return mat4(
   vec4(c, 0, s, 0),
   vec4(0, 1, 0, 0),
   vec4(-s, 0, c, 0),
   vec4(0, 0, 0, 1));
}


mat4 rotateZ(float theta) {
  float c = cos(theta);
  float s = sin(theta);
  return mat4(
   vec4(c, -s, 0, 0),
   vec4(s, c, 0, 0),
   vec4(0, 0, 1, 0),
   vec4(0, 0, 0, 1));
}
// clang-format on

vec2 doModel(vec3 p) {
  float r = 0.;
  // r += noise3d(p * m0 + t) * m1;
  // r += noise4d(vec4((p * 2.0), t)) * 0.3 * 0.5 * 0.5;
  // r = noise(vec4(p, t), 2) * 0.4;
  float h = 0.;
  // h = texture2D(spectrum, vec2((p.y * 0.1) + 0.4, 0.)).x * -0.1;
  // p;
  float speed = 2.;
  float id = 0.0;
  vec3 torus1p = (vec4(p + vec3(-0.3, 0., 0.), 1.0) * rotateZ(t * speed)).xzy;
  r += noise4d(vec4(torus1p * m0, t * 1.0)) * m1;
  r += noise4d(vec4((torus1p * m2), t * 1.0)) * m3;
  vec2 torSize = vec2(0.6, 0.2 + r);
  float d = sdTorus(torus1p, torSize);

  r = 0.;
  vec3 torus2p =
      (vec4(p.xzy + vec3(0.3, 0., 0.), 1.0) * rotateZ(t * speed)).xzy;

  r += noise4d(vec4(torus2p * m0, t * 1.0)) * m1;
  r += noise4d(vec4((torus2p * m2), t * 1.0)) * m3;
  torSize = vec2(0.6, 0.2 - r);
  float d2 = sdTorus(torus2p, torSize);

  if (d > d2) {
    id = 0.5;
  }

  // d = smin(d, d2, 28.);
  d = min(d, d2);

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
}

void main() {

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

  float rotation = t * 1.0;
  float height = 2.0;
  float dist = 2.0;

  camera(rotation, height, dist, resolution.xy, ro, rd);

  vec2 tr = raytrace(ro, rd);
  vec3 pos;
  vec3 nor;
  if (tr.x > -0.9) {
    pos = ro + rd * tr.x;
    nor = normal(pos);
    color = lighting(pos, nor, ro, rd, tr.y);
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

  // color += (color - color2 * 0.1) * 2.7;
  float l = luma(color);
  float s = 0.1 + (floor(l * m5) / m5);
  color = hsv2rgb(vec3(m4 + tr.y + ((s - 0.5) * 0.5), s + 0.05, s));

  // if (luma(color) < 0.5 + m[4] + noise3d(vec3(uv * 150., length(bands)))) {
  // color = vec3(0.);
  // } else {
  // color = vec3(1.0);
  // }
  // color = max(color, color3);
  gl_FragColor.rgb = color;
  gl_FragColor.a = 1.0;
}