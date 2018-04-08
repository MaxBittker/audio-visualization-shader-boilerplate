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
  // p += bands.xyz * 0.1;
  float r = (bands.x + 4.0) * 0.25;
  r += noise4d(vec4((p * 2.0), t)) * 0.15 * bands.y;
  // r += noise4d(vec4((p * 2.5 * bands.x), t)) * 0.05;
  // r += noise4d(vec4((p * 10.5), t)) * 0.001;
  // r += noise4d(vec4((p * 2.0), t)) * 0.3* 0.5 * 0.5;
  // r += (noise4d(vec4((p * 4.)+  bands.z*0.1, t)) * 0.3* 0.25 * 0.5);
  // r += (noise4d(vec4((p * 8.)+  bands.w*0.1, t)) * 0.3* 0.125 * 0.5);

  // r = noise(vec4(p, t), 2) * 0.4;
  // r -= 1.01 * texture2D(spectrum, vec2(r-1.2)).x;
  float h = 0.;
  h = texture2D(spectrum, vec2((p.y * 0.1) + 0.4, 0.)).x;

  float d = length(p) - r;

  // d = max(-d, length((p + vec3(0.0, 0.1, 0.)).y) - r);
  // float d = sdPlane(p - vec3(.0, r, h * 0.5), vec4(0., 0.6, 0.5, 0.0));

  // p+=vec3(2.1,0.,0.);
  // d = min(udBox(p, vec3(r) ), d);
  // d = max(d, length(p - vec3(0., 0., -0.5)) - 1.5);
  // r = 1.00 - 0.01;
  // r -= abs(worley3D((p * 2.5), 1.0, false).x * 0.2);
  // d = min(d, length(p) - r);
  float id = 0.0;
  return vec2(d, id);
}

vec3 lighting(vec3 pos, vec3 nor, vec3 ro, vec3 rd) {
  float occ = calcAO(pos, nor);

  vec3 dir1 = normalize(vec3(0, 1, 0));
  vec3 col1 = vec3(3.0, 2.0, 1.9);
  float grain = noise4d(vec4(nor * 280., t)) * 0.2;

  col1 =
      hsv2rgb(vec3(fract(dot(nor, rd) + grain) * 0.8, dot(nor, rd) * 0.8, 1.0));

  vec3 dif1 = col1 * orenn(dir1, -rd, nor, 0.15, 1.0);
  vec3 spc1 = col1 * gauss(dir1, -rd, nor, 0.15) * 0.2;

  vec3 dir2 = normalize(vec3(0.9, 3.0, -0.7));
  vec3 col2 = vec3(0.9, 0.9, 2.1);

  // col2 = hsv2rgb(vec3(
  //   (fract(dot(nor, dir2) + grain)*0.8)+0.4,
  //    0.3, 2.8));

  vec3 dif2 = col2 * orenn(dir2, -rd, nor, 0.15, 1.0) * 1.0;
  vec3 spc2 = col2 * gauss(dir2, -rd, nor, 0.15) * 0.1;

  return (dif1 + spc1 + dif2 + spc2) * occ * 0.9;
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

  float rotation = t;
  float height = 4.5;
  float dist = 1.0;

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
  vec2 sample = textCoord + outward * 1.1 +
                (pixel * 50. * bands.z *
                 noise3d(vec3(uv * 2. + bands.y, nor.y * 2. + bands.x)));

  vec2 randa = vec2(sin(t * 0.1), cos(t * 0.1));

  vec3 color2 = 1.0 * (texture2D(backBuffer, textCoord + outward).rgb);
  // +
  //  texture2D(backBuffer, textCoord + outward + randa * pixel).rgb +
  //  texture2D(backBuffer, textCoord + outward - randa * pixel).rgb) /
  // 3.;

  vec3 color3 = texture2D(spectrum, abs(vec2(0.5) - sample)).rgb * 2.;

  if (length(color3) > 1.5) {
    color = color3;
  }
  gl_FragColor.rgb = color;
  gl_FragColor.a = 1.0;
}