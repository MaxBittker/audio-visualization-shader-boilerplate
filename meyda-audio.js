const getUserMedia = require("getusermedia");
const Meyda = require("meyda");

module.exports = function(options) {
  const regl = options.regl;
  getUserMedia({ audio: true }, function(err, stream) {
    if (err) {
      options.error && options.error(err);
      return;
    }

    var context = new AudioContext();
    var source = context.createMediaStreamSource(stream);
    let features = ["rms", "powerSpectrum"];
    var meydaAnalyzer = Meyda.createMeydaAnalyzer({
      audioContext: context, // required
      source: source, // required
      bufferSize: 512, // required
      hopSize: 256, // optional
      windowingFunction: "hamming", // optional
      featureExtractors: features, // optional - A string, or an array of strings containing the names of features you wish to extract.
      callback: null// optional callback in which to receive the features for each buffer
    });
    meydaAnalyzer.start(features);
    // regl.frame(() => webcam.subimage(video));
    options.done(meydaAnalyzer, {});
  });
};
