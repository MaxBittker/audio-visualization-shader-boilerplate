precision mediump float;
uniform float t;
uniform vec2 resolution;
uniform sampler2D backBuffer;
uniform float rms;
uniform float energy;
uniform float zcr;
uniform sampler2D spectrum;

// uniform sampler2D webcam;
// uniform vec2 videoResolution;

varying vec2 uv;

// clang-format off
#pragma glslify: hsv2rgb = require('glsl-hsv2rgb')
#pragma glslify: luma = require(glsl-luma)
#pragma glslify: noise = require('glsl-noise/simplex/3d')

// clang-format on
vec2 pixel = vec2(1.0) / resolution;

void main() {
  // vec2 webcamCoord = (uv * 0.5 + vec2(0.5)) * resolution/videoResolution;
  // vec3 webcamColor = texture2D(webcam, vec2(1.) - webcamCoord).rgb * 0.95;

  vec3 color;
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
  if (uv.x < 0.) {

    color = hsv2rgb(vec3(1.0, 0.2, 1.0)) *
            texture2D(spectrum, vec2(0.99) - polar.yx).y;
  } else {
    color = hsv2rgb(vec3(1.0, 0.2, 1.0)) *
            texture2D(spectrum, vec2(0.99) - polar.yx).x;
  }

  // texture2D(spectrum, uv ).y;
  vec2 textCoord = uv * 0.5 + vec2(0.5);
  vec3 color2 =
      texture2D(backBuffer, textCoord + vec2(0, 1.0) * 500. * energy * pixel *
                                            (1.0 +noise(vec3(uv, t))))
          .rgb *
      0.99;
  color = max(color, color2);
  gl_FragColor = vec4(color, 1.0);
}