precision mediump float;
uniform float t;
uniform vec2 resolution;
uniform sampler2D backBuffer;
#define FFT_SIZE 256
uniform sampler2D spectrum;

// uniform sampler2D webcam;
// uniform vec2 videoResolution;

varying vec2 uv;

// clang-format off
#pragma glslify: hsv2rgb = require('glsl-hsv2rgb')
#pragma glslify: luma = require(glsl-luma)
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
  if(polar.x < 0.0){
  polar.x += 6.28318530718;
  }
  polar.x /= 6.28318530718;
  polar.x = 1.0 - polar.x;
  
  // if (polar.y < 0. - pixel.y * 3.) {
  
    color = texture2D(spectrum, polar.yx).rgb;
    if(length(color)<0.1){
    vec2 textCoord = uv * 0.5 + vec2(0.5);
    color = texture2D(backBuffer, textCoord + vec2(0, 1.0) * 2.*pixel).rgb * 0.999;
  }
    // color = vec3(1.0) * polar.y;
  gl_FragColor = vec4(color, 1.0);
}