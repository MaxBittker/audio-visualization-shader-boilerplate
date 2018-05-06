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

float smin(float a, float b, float k) {
  float res = exp(-k * a) + exp(-k * b);
  return -log(res) / k;
}

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

vec3 opTwist(vec3 p) {
  float c = cos(10.0 * p.y + 10.0);
  float s = sin(10.0 * p.y + 10.0);
  mat2 m = mat2(c, -s, s, c);
  return vec3(m * p.xz, p.y);
}

float bolt0(vec3 p) {
  p = (vec4(p, 1.0) * rotateX(t)).xyz;
  float r = 0.15;
  float d = sdCappedCylinder(p, vec2(r));

  float d2 = sdBox(p, vec3(10., 1.0, 10.));
  d = max(d, d2);

  vec3 threadp = p + vec3(-r, 0.1, -r);
  threadp = (vec4(threadp, 1.0) * rotateY(p.y * 55.)).xyz;

  d = smin(d, sdBox(threadp, vec3(0.1, 0.9, r + 0.01)), 30.);

  vec3 hexp = (vec4(p + vec3(-r, -.9, -r), 1.0)).xzy;
  float top = min(d, sdHexPrism(hexp, vec2(0.3, 0.15)));

  float dome = sdSphere((hexp + vec3(0., 0., -0.1)) * vec3(1., 1., 2.), 0.3);
  top = min(top, dome);

  d = min(top, d);
  float neck = min(d, sdCylinder(p + vec3(0.05), vec3(r + 0.05)));
  float d3 = sdBox(p + vec3(0., -0.6, 0.), vec3(10., 0.15, 10.));

  neck = max(neck, d3);
  d = min(d, neck);
  return d;
}

float bolt1(vec3 p) {
  p = (vec4(p, 1.0) * rotateY(t)).xyz;
  float r = 0.15;
  float d = sdCylinder(p, vec3(r));

  float d2 = sdBox(p, vec3(10., 1.0, 10.));
  d = max(d, d2);

  vec3 threadp = p + vec3(-r, 0.1, -r);
  threadp = (vec4(threadp, 1.0) * rotateY(p.y * 55.)).xyz;

  d = smin(d, sdBox(threadp, vec3(0.1, 0.9, r + 0.01)), 30.);

  vec3 hexp = (vec4(p + vec3(-r, -.9, -r), 1.0)).xzy;
  float top = min(d, sdHexPrism(hexp, vec2(0.3, 0.15)));

  float dome = sdSphere((hexp + vec3(0., 0., -0.1)) * vec3(1., 1., 2.), 0.3);
  top = min(top, dome);

  d = min(top, d);
  float neck = min(d, sdCylinder(p + vec3(0.05), vec3(r + 0.05)));
  float d3 = sdBox(p + vec3(0., -0.6, 0.), vec3(10., 0.15, 10.));

  neck = max(neck, d3);
  d = min(d, neck);
  return d;
}

vec2 doModel(vec3 p) {
  float b0 = bolt0(p);
  float b1 = bolt1(p);

  float d = b0;
  d = min(b0, b1);
  float id = 1.0;
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

  float rotation = t * 1.0 * m6 * 0.1;
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

    float l = luma(color);
    float s = 0.1 + (floor(l * m5) / m5);
    color = hsv2rgb(vec3(m4 + tr.y + ((s - 0.5) * 0.5), s + 0.05, s));

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

    // color = texture2D(spectrum, abs(vec2(0.5) - sample)).rgb * 2.;

    // color += (color - color2 * 0.1) * 2.7;
  }
  if (luma(color) < m1 + noise3d(vec3(uv * 150., t)) * m2) {
    // color = max(color, color2);
    color = vec3(0.);
  } else {
    color = vec3(1.0);
  }
  gl_FragColor.rgb = color;
  gl_FragColor.a = 1.0;
}