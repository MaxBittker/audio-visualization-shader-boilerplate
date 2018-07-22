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
#pragma glslify: worley2D = require(glsl-worley/worley2D.glsl)
#pragma glslify: worley3D = require(glsl-worley/worley3D.glsl)
#pragma glslify: noise4d = require('glsl-noise/simplex/4d')
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
float rand(float n){return fract(sin(n) * 43758.5453123);}
float rand(vec2 n) { 
	return fract(sin(dot(n, vec2(12.9898, 4.1414))) * 43758.5453);
}
// float randb(vec2 n) { 
// 	return fract(sin(dot(n, vec2(19.9898, 3.1414))) * 42518.5453);
// }
 float randb(vec2 co)
{
    highp float a = 12.9898;
    highp float b = 78.233;
    highp float c = 43758.5453;
    highp float dt= dot(co.xy ,vec2(a,b));
    highp float sn= mod(dt,3.14);
    return fract(sin(sn) * c);
}
vec4 hexagon( vec2 p ) 
{
	vec2 q = vec2( p.x*2.0*0.5773503, p.y + p.x*0.5773503 );
	
	vec2 pi = floor(q);
	vec2 pf = fract(q);

	float v = mod(pi.x + pi.y, 3.0);

	float ca = step(1.0,v);
	float cb = step(2.0,v);
	vec2  ma = step(pf.xy,pf.yx);
	
    // distance to borders
	float e = dot( ma, 1.0-pf.yx + ca*(pf.x+pf.y-1.0) + cb*(pf.yx-2.0*pf.xy) );

	// distance to center	
	p = vec2( q.x + floor(0.5+p.y/1.5), 4.0*p.y/3.0 )*0.5 + 0.5;
	float f = length( (fract(p) - 0.5)*vec2(1.0,0.85) );		
	
	return vec4( pi + ca - cb*ma, e, f );
}

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

vec2 doModel(vec3 pos) {
  float g = 0.2;
  float g2 = g * 2.;
  vec4 hexc = hexagon((pos.yx + vec2(g)) / g2 * 6. / 4.);

  if (mod(pos.x * 0.5, g2) < 0.5 * g2) {
    pos.y += g;
  }
  // p *= 2.;
  vec3 p = mod(pos, vec3(g2, g2, 0.));
  p -= vec3(g, g, 0.);
  vec2 ci = floor(pos.xy / g2);
  // ci = hexc.rg;
  float id = floor(rand(ci) * 8.);

  // p += vec3(sin(t + p.y * 10.) * 0.1, 0., 0.);
  float pad = 0.01;
  float d = 1000.;
  p = rotateX(p, t + id * 100.);
  // p = vec3(ci, p.z);
  float box = sdBox(p, vec3(g - pad, g - pad, g - pad * 2.));
  float sphere = length(p) - g + pad;
  float dcylinder = sdCappedCylinder(p.xyz, vec2(g - pad * 3., g - pad));
  float scylinder = sdCappedCylinder(p.yxz, vec2(g - pad * 3., g - pad));
  float fcylinder = sdCappedCylinder(p.xzy, vec2(g - pad * 3., g - pad));
  float bfcylinder =
      sdCappedCylinder(p.xzy - vec3(g, 0., g), vec2(g2 - pad * 3., g - pad));
  float revbfcylinder = max(box, -bfcylinder);
  bfcylinder = max(box, bfcylinder);

  float hexf = sdHexPrism(p, vec2(g - pad, 0.05));
  float hex = sdHexPrism(p.zyx, vec2(g - pad));
  // vec3 dd = abs(vec3(ci, p.z)) - g;
  // hexf = min(max(dd.x, max(dd.y, dd.z)), 0.0) + length(max(dd, 0.0));
  // hexf = length(max(abs(vec3(ci, p.z)) - 0.1, 0.));
  d = box;
  // d = fcylinder;
  d = hexf;
  if (id > 0.01) {
    // d = sphere;
  }
  if (id > 1.01) {
    // d = fcylinder;
  }
  if (id > 2.01) {
    // d = scylinder;
  }
  if (id > 3.01) {
    d = dcylinder;
  }
  if (id > 4.01) {
    // d = max(box, -fcylinder);
  }
  if (id > 5.01) {
    // d = bfcylinder;
  }
  if (id > 6.01) {
    // d = revbfcylinder;
  }
  return vec2(d, randb(ci * 200.));
}

vec3 lighting(vec3 pos, vec3 nor, vec3 ro, vec3 rd, float id) {
  float occ = calcAO(pos, nor);

  vec3 dir1 = normalize(vec3(sin(m7), cos(m7), sin(m7)));
  vec3 col1 = hsv2rgb(vec3(0.4, 0.5, 1.0));

  // float grain = noise4d(vec4(nor * 80., t)) * 0.2;

  // col1 = hsv2rgb(vec3((fract(dot(nor, rd) + grain) * 0.23), 0.8, 1.0));

  vec3 dif1 = col1 * orenn(dir1, -rd, nor, 0.15, 1.0);
  vec3 spc1 = col1 * gauss(dir1, -rd, nor, 0.15) * 0.1;

  vec3 dir2 = normalize(nor + ro);
  vec3 col2 = hsv2rgb(vec3(0.8 * id, 0.5, 1.0));

  // col2 = hsv2rgb(vec3((fract(dot(nor, dir2) + grain) * 0.1) + id, 0.1,
  // 0.8));

  vec3 dif2 = col2 * orenn(dir2, -rd, nor, 0.15, 1.0) * 1.0;
  vec3 spc2 = col2 * gauss(dir2, -rd, nor, 0.15) * 0.1;

  // return vec3(0.01) + (dif1 + spc1 + ((dif2 + spc2) * occ));
  return vec3(0.1) + (dif1 + spc1 + ((dif2 + spc2)));
}

void main() {
  vec3 color;
  float colorBand = sin((t - uv.y * 25.) / 9.) + 1.0;

  color = vec3(.0, 0.1, 0.1);

  vec3 ro, rd;

  float rotation = m6;
  float height = m5;
  float dist = m4;

  camera(rotation, height, dist, resolution.xy, ro, rd);
  ro.y -= t * m1;

  vec2 tr = raytrace(ro, rd, 100., 0.0001);
  vec3 pos;
  vec3 nor;

  if (tr.x > -0.9) {
    pos = ro + rd * tr.x;
    nor = normal(pos);
    color = lighting(pos, nor, ro, rd, tr.y);

    float l = luma(color);
    float ncolors = m3;
    float s = 0.1 + (floor(l * ncolors) / ncolors);
    color = hsv2rgb(
        vec3(0.5 * (tr.y / 0.01) + ((s - 0.5) * 0.5), s + 0.015, s + 0.01));

    // if (10. > 0.1) {

    // if (luma(color) < 0.3 + (sin(uv.x * 1000.) + cos(uv.y * 1000.)) * 0.1) {
    if (luma(color) < 0.4 + noise3d(vec3(pos.xyz) * m2 * 20.) * 0.3) {
      // color = max(color, color2);
      color = vec3(0.);
      // color *= 0.2;
    } else {
      // color *= 1.2;
      color = vec3(1.0);
      // color = hsv2rgb(vec3(t + (tr.y / 5.), 0.3, 0.9));
    }
  }
  gl_FragColor.rgb = color;
  gl_FragColor.a = 1.0;
}