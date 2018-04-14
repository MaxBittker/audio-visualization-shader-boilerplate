let midi = require("web-midi-api");

// m = MIDIAccess object for you to make calls on
var m = null;
const midiData = {};
navigator.requestMIDIAccess().then(onSuccessCallback, onErrorCallback);
function handleMidiMessage({ data }) {
  console.log(data);
}
function onSuccessCallback(access) {
  // If the browser supports WebMIDI, access is a native MIDIAccess
  // object. If not, it is an instance of a custom class that mimics
  // the behavior of MIDIAccess using Jazz.
  m = access;
  console.log(access);
  // Things you can do with the MIDIAccess object:

  // inputs = MIDIInputMaps, you can retrieve the inputs with iterators
  var inputs = m.inputs;

  // outputs = MIDIOutputMaps, you can retrieve the outputs with iterators
  var outputs = m.outputs;

  // returns an iterator that loops over all inputs
  var iteratorInputs = inputs.values();

  // get the first input
  var input = iteratorInputs.next().value;
  // onmidimessage(event), event.data & event.receivedTime are populated
  input.onmidimessage = handleMidiMessage;
}

function onErrorCallback(err) {
  console.log("uh-oh! Something went wrong! Error code: " + err.code);
}
function midiController() {}
module.exports = { midiController };
