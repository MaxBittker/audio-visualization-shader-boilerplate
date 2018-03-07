import { setupOverlay } from "regl-shader-error-overlay";
setupOverlay();

const regl = require("regl")({ pixelRatio: 1 });
const wc = require("./regl-webcam");
const audioAnalyzer = require("./meyda-audio");

let fsh = require("./fragment.glsl");

const lastFrame = regl.texture();
const pixels = regl.texture();
let audioVisualization = (audio, {}) => {
  let drawTriangle = regl({
    frag: fsh,
    uniforms: {
      // webcam,
      spectrum: () =>
        regl.texture({
          width: 64*4,
          height: 1,
          data: new Uint8Array(
            audio.get("powerSpectrum").map(i=>i*256)
          )
        }),
      // videoResolution: [videoWidth, videoHeight],
      // Becomes `uniform float t`  and `uniform vec2 resolution` in the shader.
      t: ({ tick }) => tick,
      resolution: ({ viewportWidth, viewportHeight }) => [
        viewportWidth,
        viewportHeight
      ],
      backBuffer: lastFrame
      // Many datatypes are supported here.
      // See: https://github.com/regl-project/regl/blob/gh-pages/API.md#uniforms
    },

    /*
Attributes you don't need to modify if you just want to write full bleed fragment shaders:
*/
    vert: `
// boring "pass-through" vertex shader
precision mediump float;
attribute vec2 position;
varying vec2 uv;

void main () {
  uv = position;
  gl_Position = vec4(position, 0, 1);
}`,
    attributes: {
      // Full screen triangle
      position: [[-1, 4], [-1, -1], [4, -1]]
    },
    // Our triangle has 3 vertices
    count: 3
  });

  regl.frame(function(context) {
    window.a = audio;

    regl.clear({
      color: [0, 0, 0, 1]
    });
    drawTriangle();
    lastFrame({
      copy: true
    });
  });
};

let audio = audioAnalyzer({
  regl,
  done: audioVisualization
});

// let cam = wc({
//   regl,
//   done: audio
// });
