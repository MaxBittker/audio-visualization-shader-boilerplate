let { setupOverlay } = require("regl-shader-error-overlay");
let _ = require("lodash");
setupOverlay();

const regl = require("regl")({ pixelRatio: 1.2 });
let { audioAnalyzer } = require("./src/audio");
let { getMidiValue } = require("./src/midi");

let shaders = require("./src/pack.shader.js");
const lastFrame = regl.texture();
const pixels = regl.texture();
let audioBuffer = null;

let vert = shaders.vertex;
let frag = shaders.fragment;

shaders.on("change", () => {
  console.log("update");
  vert = shaders.vertex;
  frag = shaders.fragment;
  let overlay = document.getElementById("regl-overlay-error");
  overlay && overlay.parentNode.removeChild(overlay);
});

let audioVisualization = (audio, {}) => {
  let drawTriangle = regl({
    uniforms: {
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
        return bands;
      },
      spectrum: () => {
        return regl.texture({
          width: audioBuffer.length,
          height: 1,
          data: new Uint8Array(_.flatMap(audioBuffer, i => [i, i, i, i]))
        });
      },
      t: ({ tick }) => tick / 100,
      resolution: ({ viewportWidth, viewportHeight }) => [
        viewportWidth,
        viewportHeight
      ],
      backBuffer: lastFrame,

      "m[0]": () => getMidiValue(0),
      "m[1]": () => getMidiValue(1),
      "m[2]": () => getMidiValue(2),
      "m[3]": () => getMidiValue(3),
      "m[4]": () => getMidiValue(4),
      "m[5]": () => getMidiValue(5),
      "m[6]": () => getMidiValue(6),
      "m[7]": () => getMidiValue(7)
    },

    frag: () => shaders.fragment,
    vert: () => shaders.vertex,
    attributes: {
      // Full screen triangle
      position: [[-1, 4], [-1, -1], [4, -1]]
    },
    // Our triangle has 3 vertices
    count: 3
  });

  regl.frame(function(context) {
    window.a = audio;

    if (!audioBuffer) {
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
