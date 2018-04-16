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

vec2 doModel(vec3 p) {
  float r = 1.;
  // r += noise4d(vec4((p * 10.5), t)) * 0.0005;
  // r += noise4d(vec4((p * 2.0), t)) * 0.3 * 0.5 * 0.5;
  // r = noise(vec4(p, t), 2) * 0.4;
  float h = 0.;

  // h = texture2D(spectrum, vec2((p.y * 0.1) + 0.4, 0.)).x * -0.1;
  // p;

  float d = length(p) - r;
  r += noise4d(vec4((p * m[0]), t)) * m[1];
  float wall = (r - 1.);
  float d2 = p.z - wall;
  d = max(d, d2);
  float d3 = wall - m3 - p.z;

  d = max(d, d3);
  // d = d2;
  // d = udBox(p, );
  // p += vec3(0., 0., 0.);
  float id = 0.0;
  return vec2(d, id);
}

vec3 lighting(vec3 pos, vec3 nor, vec3 ro, vec3 rd) {
  float occ = calcAO(pos, nor);

  vec3 dir1 = normalize(vec3(1.));
  vec3 col1 = vec3(3.0, 2.0, 1.9);
  float grain = noise4d(vec4(nor * 80., t)) * 0.2;

  col1 = hsv2rgb(vec3(0.5 + fract(dot(nor, rd) + grain) * 0.7, 0.3, 1.0));

  vec3 dif1 = col1 * orenn(dir1, -rd, nor, 0.15, 1.0);
  vec3 spc1 = col1 * gauss(dir1, -rd, nor, 0.15) * 0.3;

  vec3 dir2 = normalize(nor + ro);
  vec3 col2 = vec3(0.9, 0.9, 2.1);

  col2 = hsv2rgb(vec3((fract(dot(nor, dir2) + grain) * 0.1) + 0.4, 0.3, 0.8));

  vec3 dif2 = col2 * orenn(dir2, -rd, nor, 0.15, 1.0) * 1.0;
  vec3 spc2 = col2 * gauss(dir2, -rd, nor, 0.15) * 0.3;

  return vec3(0.1) + (dif1 + spc1 + dif2 + spc2) * occ;
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

  float rotation = m7;
  float height = 0.0;
  float dist = 3.0;

  camera(rotation, height, dist, resolution.xy, ro, rd);

  vec2 tr = raytrace(ro, rd);
  vec3 pos;
  vec3 nor;
  if (tr.x > -0.9) {
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
  if (luma(color) < m[4] + noise3d(vec3(uv * 200., length(bands)))) {
    // color = vec3(0.);
  } else {
    // color = vec3(1.0);
  }
  // color = max(color, color3);
  gl_FragColor.rgb = color;
  gl_FragColor.a = 1.0;
}