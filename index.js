import { setupOverlay } from "regl-shader-error-overlay";
import _ from 'lodash';
setupOverlay();

const regl = require("regl")({ pixelRatio: 2 });
const wc = require("./regl-webcam");
const {audioAnalyzer, timeDomainFeatures, spectralFeatures} = require("./meyda-audio");

let fsh = require("./fragment.glsl");
let vsh = require("./vertex.glsl");

const lastFrame = regl.texture();
const pixels = regl.texture();
let audioVisualization = (audio, {}) => {
  let drawTriangle = regl({
    frag: fsh,
    uniforms: {
      // webcam,
      rms: ()=>audio.get("rms"),
      energy: ()=>audio.get("energy"),
      zcr: ()=>audio.get("zcr"),
      
      spectrum: () =>
        regl.texture({
          width: audio.get("powerSpectrum").length,
          height: 1,
          data: new Uint8Array(
            _.map(
            _.flatten(
              _.zip(
                audio.get("powerSpectrum"),
                audio.get("amplitudeSpectrum"),
                audio.get("powerSpectrum"),
                audio.get("powerSpectrum"),
                
              )),
              i=>i*256,
            )
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
    vert: vsh,
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
