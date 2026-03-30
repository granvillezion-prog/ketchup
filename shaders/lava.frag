// shaders/lava.frag
// Domain-warped metaballs for Flutter runtime_effect (GLSL)
//
// Uniform layout (set in Dart, in this exact order):
//  0: uTime
//  1: uWidth
//  2: uHeight
//  3: b0x  4: b0y  5: b0r
//  6: b1x  7: b1y  8: b1r
//  ...
//  27: b8x 28: b8y 29: b8r

#include <flutter/runtime_effect.glsl>
precision highp float;

uniform float uTime;
uniform float uWidth;
uniform float uHeight;

uniform float b0x; uniform float b0y; uniform float b0r;
uniform float b1x; uniform float b1y; uniform float b1r;
uniform float b2x; uniform float b2y; uniform float b2r;
uniform float b3x; uniform float b3y; uniform float b3r;
uniform float b4x; uniform float b4y; uniform float b4r;
uniform float b5x; uniform float b5y; uniform float b5r;
uniform float b6x; uniform float b6y; uniform float b6r;
uniform float b7x; uniform float b7y; uniform float b7r;
uniform float b8x; uniform float b8y; uniform float b8r;

out vec4 fragColor;

vec2 res() { return vec2(uWidth, uHeight); }
float sat(float x) { return clamp(x, 0.0, 1.0); }

vec3 mix3(vec3 a, vec3 b, float t) { return a * (1.0 - t) + b * t; }

// -------------------- noise (fast, no textures) --------------------
float hash21(vec2 p) {
  // stable hash: returns 0..1
  p = fract(p * vec2(123.34, 456.21));
  p += dot(p, p + 34.345);
  return fract(p.x * p.y);
}

float noise21(vec2 p) {
  vec2 i = floor(p);
  vec2 f = fract(p);
  // smooth
  f = f * f * (3.0 - 2.0 * f);

  float a = hash21(i + vec2(0.0, 0.0));
  float b = hash21(i + vec2(1.0, 0.0));
  float c = hash21(i + vec2(0.0, 1.0));
  float d = hash21(i + vec2(1.0, 1.0));

  return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

float fbm(vec2 p) {
  float v = 0.0;
  float a = 0.55;
  for (int i = 0; i < 4; i++) {
    v += a * noise21(p);
    p *= 2.02;
    a *= 0.5;
  }
  return v;
}

// Domain warp makes edges “liquid” instead of solid translation
vec2 warp(vec2 p, float t) {
  // Work in normalized space for stable warp amplitude across screens
  vec2 uv = p / res();
  float w = res().x / max(res().y, 1.0);

  // Two scrolling fbm fields
  float n1 = fbm(vec2(uv.x * 2.2 * w, uv.y * 2.2) + vec2(0.10 * t, -0.06 * t));
  float n2 = fbm(vec2(uv.x * 3.1 * w, uv.y * 3.1) + vec2(-0.07 * t, 0.09 * t));

  // Warp in pixels (strong enough to see, not blurry)
  vec2 d = vec2(n1 - 0.5, n2 - 0.5);
  d *= vec2(res().x, res().y);

  // amplitude: bigger = more liquid motion
  float amp = 16.0; // px
  return p + d * (amp / max(res().x, res().y)) * vec2(res().x, res().y);
}

// -------------------- metaballs --------------------
float metaballField(vec2 p, vec2 c, float r) {
  vec2 d = p - c;
  float d2 = dot(d, d) + 12.0; // keep stable, prevents spiky singularities
  float rr = r * r;
  return rr / d2;
}

float totalField(vec2 p) {
  float f = 0.0;
  f += metaballField(p, vec2(b0x, b0y), b0r);
  f += metaballField(p, vec2(b1x, b1y), b1r);
  f += metaballField(p, vec2(b2x, b2y), b2r);
  f += metaballField(p, vec2(b3x, b3y), b3r);
  f += metaballField(p, vec2(b4x, b4y), b4r);
  f += metaballField(p, vec2(b5x, b5y), b5r);
  f += metaballField(p, vec2(b6x, b6y), b6r);
  f += metaballField(p, vec2(b7x, b7y), b7r);
  f += metaballField(p, vec2(b8x, b8y), b8r);
  return f;
}

void main() {
  vec2 p0 = FlutterFragCoord().xy;
  float t = uTime;

  // Warp the domain -> the blobs themselves deform over time
  vec2 p = warp(p0, t);

  vec2 uv = p0 / res();

  // Field value
  float f = totalField(p);

  // Tight edge = crisp boundary (no glow)
  float threshold = 1.05;  // lower => bigger blobs
  float edge = 0.045;      // smaller => sharper

  float m = smoothstep(threshold - edge, threshold + edge, f);

  // Depth inside: use higher field values to push darker “core”
  float core = smoothstep(threshold + 0.10, threshold + 0.95, f);

  // Gradient normal for shading (adds depth without glow)
  float eps = 1.35;
  float fx1 = totalField(warp(p0 + vec2(eps, 0.0), t));
  float fx2 = totalField(warp(p0 - vec2(eps, 0.0), t));
  float fy1 = totalField(warp(p0 + vec2(0.0, eps), t));
  float fy2 = totalField(warp(p0 - vec2(0.0, eps), t));
  vec2 grad = vec2(fx1 - fx2, fy1 - fy2);
  vec2 n = normalize(grad + 1e-5);

  vec2 lightDir = normalize(vec2(-0.65, -0.85));
  float ndl = sat(dot(n, lightDir) * 0.5 + 0.5);

  // Background: brighter + cleaner so purple pops
  vec3 base = vec3(0.992, 0.985, 1.000);
  base = mix3(base, vec3(0.965, 0.945, 1.000), uv.y * 0.75);

  // Punchy purple palette (high contrast)
  vec3 lavaBright = vec3(0.80, 0.34, 1.00); // vivid
  vec3 lavaMid    = vec3(0.55, 0.12, 0.98); // saturated
  vec3 lavaDeep   = vec3(0.22, 0.02, 0.65); // core

  // Interior shading: bright on light side, deep in core
  vec3 inside = mix3(lavaMid, lavaBright, ndl * 0.95);
  inside = mix3(inside, lavaDeep, core * 0.85);

  // NO outer glow. Only tiny internal variation, stays inside due to mask
  float micro = fbm(vec2(uv.x * 8.0, uv.y * 8.0) + vec2(0.20 * t, -0.18 * t));
  inside = mix3(inside, inside + vec3(0.06), (micro - 0.5) * (1.0 - core) * 0.35);

  // Blend
  vec3 color = mix3(base, inside, m);

  fragColor = vec4(color, 1.0);
}
