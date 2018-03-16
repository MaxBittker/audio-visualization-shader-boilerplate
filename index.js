import { setupOverlay } from "regl-shader-error-overlay";
import _ from "lodash";
setupOverlay();

const regl = require("regl")({ pixelRatio: 2 });
const wc = require("./regl-webcam");
import { audioAnalyzer } from "./audio";

let fsh = require("./fragment.glsl");
let vsh = require("./vertex.glsl");

const lastFrame = regl.texture();
const pixels = regl.texture();
let audioBuffer = null;

let audioVisualization = (audio, {}) => {
  let drawTriangle = regl({
    frag: fsh,
    uniforms: {
      // webcam,
      bands: () => {
        let bands = new Array(4);
        var k = 0;
        var f = 0.0;
        var a = 5,
          b = 11,
          c = 24,
          d = 512,
          i = 0;
        for (; i < a; i++) f += audioBuffer[i];
        f *= 0.2; // 1/(a-0)
        f *= 0.003921569; // 1/255
        bands[0] = f;
        f = 0.0;
        for (; i < b; i++) f += audioBuffer[i];
        f *= 0.166666667; // 1/(b-a)
        f *= 0.003921569; // 1/255
        bands[1] = f;
        f = 0.0;
        for (; i < c; i++) f += audioBuffer[i];
        f *= 0.076923077; // 1/(c-b)
        f *= 0.003921569; // 1/255
        bands[2] = f;
        f = 0.0;
        for (; i < d; i++) f += audioBuffer[i];
        f *= 0.00204918; // 1/(d-c)
        f *= 0.003921569; // 1/255
        bands[3] = f;
        return bands
      },
      spectrum: () => {
        return regl.texture({
          width: audioBuffer.length,
          height: 1,
          data: new Uint8Array(_.flatMap(audioBuffer, i => [i, i, i, i]))
        });
      },
      // videoResolution: [videoWidth, videoHeight],
      t: ({ tick }) => tick / 100,
      resolution: ({ viewportWidth, viewportHeight }) => [
        viewportWidth,
        viewportHeight
      ],
      backBuffer: lastFrame
      // Many datatypes are supported here.
      // See: https://github.com/regl-project/regl/blob/gh-pages/API.md#uniforms
    },

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
    if( !audioBuffer){
      audioBuffer = new Uint8Array(audio.frequencyBinCount);
    }
    audio.getByteFrequencyData(audioBuffer);
    
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

