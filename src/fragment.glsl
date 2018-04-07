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
  float r = (sin(t * 2.) + 3.0) * 0.25;
  r += noise4d(vec4((p * 49.9), t)) * 0.5 * bands.y;
  r += noise4d(vec4((p * 1.5), t)) * 0.05;
  // r += noise4d(vec4((p * 10.5), t)) * 0.001;
  // r += noise4d(vec4((p * 2.0), t)) * 0.3* 0.5 * 0.5;
  // r += (noise4d(vec4((p * 4.)+  bands.z*0.1, t)) * 0.3* 0.25 * 0.5);
  // r += (noise4d(vec4((p * 8.)+  bands.w*0.1, t)) * 0.3* 0.125 * 0.5);

  // r = noise(vec4(p, t), 2) * 0.4;
  // r -= 1.01 * texture2D(spectrum, vec2(r-1.2)).x;
  float h = 0.;
  h = texture2D(spectrum, vec2((p.y * 0.1) + 0.4, 0.)).x;

  float d = udBox(p, vec3(r));

  d = smin(d, udBox(p + vec3(r), vec3(1.0 - r)), 3.9);
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
  col1 = hsv2rgb(vec3(fract(dot(nor, rd) + grain) * 0.8, dot(nor, rd) * 0.8,
                      abs(dot(nor, rd)) * 18. + 0.0));

  vec3 dif1 = col1 * orenn(dir1, -rd, nor, 0.15, 1.0);
  vec3 spc1 = col1 * gauss(dir1, -rd, nor, 0.15) * 3.0;

  vec3 dir2 = normalize(vec3(0.9, 3.0, -0.7));
  vec3 col2 = vec3(0.9, 0.9, 2.1);

  // col2 = hsv2rgb(vec3(
  //   (fract(dot(nor, dir2) + grain)*0.8)+0.4,
  //    0.3, 2.8));

  vec3 dif2 = col2 * orenn(dir2, -rd, nor, 0.15, 1.0) * 2.0;
  vec3 spc2 = col2 * gauss(dir2, -rd, nor, 0.15) * 0.1;

  return (dif1 + spc1 + dif2 + spc2) * occ;
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
  // sin(t * 50.) * 0.1;
  float height = 4.;
  float dist = 5.0;

  camera(rotation, height, dist, resolution.xy, ro, rd);

  vec2 t = raytrace(ro, rd);
  if (t.x > -0.5) {
    vec3 pos = ro + rd * t.x;
    vec3 nor = normal(pos);

    color = lighting(pos, nor, ro, rd);
  }
  if (luma(color) < 1.5 * noise3d(vec3(uv * 20., t))) {
    // color = vec3(0.);
  } else {
    // color
  }
  vec2 outward = normalize(vec2(0.0) - uv) * pixel;
  vec2 sample =
      textCoord + outward * 2.5 +
      (pixel * 5. * bands.z * noise3d(vec3(uv * 2. + bands.y, t + bands.x)));

  vec3 color2 = 0.999 *
                (texture2D(backBuffer, sample).rgb +
                 texture2D(backBuffer, sample + sin(t * 0.01) * pixel).rgb +
                 texture2D(backBuffer, sample - sin(t * 0.01) * pixel).rgb) /
                3.;

  vec3 color3 = texture2D(spectrum, abs(vec2(0.5) - sample)).rgb * 2.;

  if (length(color) < 0.21) {
    // color = color3;
    // color = max(color, color2);
  }

  gl_FragColor.rgb = color;
  gl_FragColor.a = 1.0;
}