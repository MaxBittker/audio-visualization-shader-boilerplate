// clang-format off

mat4 rotateX_Mat(float theta) {
  float c = cos(theta);
  float s = sin(theta);
  return mat4(
    vec4(1, 0, 0, 0),
    vec4(0, c, -s, 0),
    vec4(0, s, c, 0),
    vec4(0, 0, 0, 1));
}

vec3 rotateX(vec3 p, float theta) {
  return (rotateX_Mat(theta) * vec4(p, 1.0)).xyz;
}

#pragma glslify: export(rotateX)
