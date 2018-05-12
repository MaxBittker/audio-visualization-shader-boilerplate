// clang-format off


mat4 rotateZ_Mat(float theta) {
  float c = cos(theta);
  float s = sin(theta);
  return mat4(
    vec4(c, -s, 0, 0),
    vec4(s, c, 0, 0),
    vec4(0, 0, 1, 0),
    vec4(0, 0, 0, 1));
}


vec3 rotateZ(vec3 p, float theta) {
  return (rotateZ_Mat(theta) * vec4(p, 1.0)).xyz;
}

#pragma glslify: export(rotateZ)
