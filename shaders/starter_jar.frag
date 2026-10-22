#version 460 core

// The starter jar: glass, lid, a living surface, rising bubbles and a glass
// highlight. Drawn by lib/ui/widgets/starter_jar.dart, which keeps the uniform
// order below in step with its setFloat calls.

#include <flutter/runtime_effect.glsl>

precision highp float;

uniform vec2 uSize;     // 0, 1
uniform float uTime;    // 2   seconds; frozen when motion is reduced
uniform float uLevel;   // 3   0..1 of the jar's inside
uniform float uDome;    // 4   0..1, the risen dough doming at its peak
uniform float uFizz;    // 5   0..1, how lively the bubbles are
uniform vec4 uGlass;    // 6..9
uniform vec4 uRim;      // 10..13
uniform vec4 uStarter;  // 14..17
uniform vec4 uDeep;     // 18..21
uniform vec4 uBubble;   // 22..25

out vec4 fragColor;

// Inigo Quilez's rounded box, with y pointing down: r.x is the bottom corners'
// radius and r.y the top corners'.
float roundBox(vec2 p, vec2 b, vec2 r) {
  float radius = p.y > 0.0 ? r.x : r.y;
  vec2 q = abs(p) - b + radius;
  return min(max(q.x, q.y), 0.0) + length(max(q, 0.0)) - radius;
}

float hash(float n) {
  return fract(sin(n * 12.9898) * 43758.5453);
}

// Bubbles rise from the bottom to the surface and fade as they reach it. Each
// has its own lane, size and speed, so the pattern never visibly repeats.
float bubbles(vec2 p, float surface, float bottom) {
  float span = bottom - surface;
  float acc = 0.0;
  for (int i = 0; i < 12; i++) {
    float fi = float(i);
    float lane = hash(fi + 1.0);
    float pace = hash(fi + 17.0);
    float size = hash(fi + 31.0);
    // Fewer, smaller bubbles when the starter is calm.
    float alive = step(fi / 12.0, uFizz);
    float travel = fract(uTime * (0.05 + pace * 0.09) + pace);
    float y = bottom - 6.0 - travel * max(span - 6.0, 0.0);
    float x = uSize.x * (0.2 + 0.6 * lane) + sin(uTime * 1.3 + fi * 2.1) * 2.5;
    // Sized to the jar, so a small jar has small bubbles.
    float scale = clamp(uSize.x / 180.0, 0.35, 1.2);
    float radius = (1.6 + size * 3.6) * (0.55 + 0.45 * travel) * scale;
    float d = length(p - vec2(x, y)) - radius;
    float body = 1.0 - smoothstep(-0.8, 0.8, d);
    float ring = 1.0 - smoothstep(0.3, 1.3, abs(d + 0.6));
    float fade = smoothstep(surface + 1.0, surface + 9.0, y);
    acc = max(acc, (body * 0.45 + ring * 0.55) * fade * alive);
  }
  return acc * step(8.0, span);
}

void main() {
  vec2 p = FlutterFragCoord().xy;
  float w = uSize.x;
  float h = uSize.y;

  // The lid sits across the top, the body below it.
  float lidH = h * 0.085;
  vec2 bodyMin = vec2(1.0, lidH * 0.7);
  vec2 bodyMax = vec2(w - 1.0, h - 1.0);
  vec2 bodyCentre = (bodyMin + bodyMax) * 0.5;
  vec2 bodyHalf = (bodyMax - bodyMin) * 0.5;
  float body = roundBox(p - bodyCentre, bodyHalf, vec2(w * 0.3, w * 0.18));

  vec2 lidCentre = vec2(w * 0.5, lidH * 0.5 + 0.5);
  vec2 lidHalf = vec2(w * 0.38, lidH * 0.5);
  float lid = roundBox(p - lidCentre, lidHalf, vec2(lidH * 0.45));

  // The starter's surface: a slow two-part wave, calmer as it domes.
  float top = bodyMin.y + h * 0.07;
  float bottom = bodyMax.y - 5.0;
  float rest = mix(bottom, top, clamp(uLevel, 0.0, 1.0));
  float x = p.x / w;
  float wave = sin(x * 7.5 + uTime * 1.4) * 1.8 + sin(x * 16.0 - uTime * 2.1) * 0.9;
  float dome = uDome * h * 0.06 * (1.0 - pow(2.0 * x - 1.0, 2.0));
  float surface = rest + wave * (1.0 - 0.7 * uDome) - dome;
  float inStarter = smoothstep(surface - 0.75, surface + 0.75, p.y);

  // Honey at the top, settling deeper towards the bottom, with a bright
  // meniscus line where it meets the glass above.
  float depth = clamp((p.y - surface) / max(bottom - surface, 1.0), 0.0, 1.0);
  vec3 starter = mix(uStarter.rgb, uDeep.rgb, depth * 0.8);
  float meniscus = exp(-pow((p.y - surface) / 2.2, 2.0));
  starter = mix(starter, uBubble.rgb, meniscus * 0.6);

  vec3 colour = mix(uGlass.rgb, starter, inStarter);
  colour = mix(colour, uBubble.rgb, bubbles(p, surface, bottom) * inStarter);

  // A soft vertical highlight down the left of the glass.
  float hx = (p.x - w * 0.2) / (w * 0.045);
  float streak = exp(-hx * hx)
      * smoothstep(top, top + h * 0.08, p.y)
      * (1.0 - smoothstep(bottom - h * 0.22, bottom, p.y));
  colour = mix(colour, uBubble.rgb, streak * 0.4);

  // The glass rim, drawn just inside the body's edge.
  float rim = 1.0 - smoothstep(1.0, 2.4, abs(body + 1.6));
  colour = mix(colour, uRim.rgb, rim);

  float inBody = 1.0 - smoothstep(-0.75, 0.75, body);
  float inLid = 1.0 - smoothstep(-0.75, 0.75, lid);
  colour = mix(colour, uRim.rgb, inLid);
  float alpha = max(inBody, inLid);

  fragColor = vec4(colour * alpha, alpha);
}
