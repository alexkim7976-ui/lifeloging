#!/usr/bin/env python3
"""Generate the LifeLogger app logo as SVG.

Design language pulled straight from the app:
  - Deep-ocean -> midnight liquid-glass background (LiquidGlassStyle.dashboardGradient)
  - Signature Focus Ring: angular sweep frost -> iceBlue -> aquaGlow -> mintGlow -> frost
  - A bright "live" node at the leading tip = the 1s tracking sample (the heartbeat of logging)
  - Glassy center with a soft pulse mark
"""
import math

CX, CY = 512.0, 512.0
R = 300.0          # ring radius
W = 80.0           # ring stroke width
SWEEP = 0.72       # focus ratio shown by the arc (matches FocusRingView vibe)
START_DEG = -90.0  # start at top
N = 160            # arc segments for a smooth angular gradient

# Focus ring color stops (LiquidGlassStyle.focusRingGradient)
STOPS = [
    (0.86, 0.95, 1.00),  # frost
    (0.74, 0.91, 1.00),  # iceBlue
    (0.38, 0.86, 0.88),  # aquaGlow
    (0.42, 0.92, 0.78),  # mintGlow
    (0.86, 0.95, 1.00),  # frost (loop)
]

def lerp(a, b, t):
    return a + (b - a) * t

def color_at(t):
    """t in [0,1] across the STOPS list."""
    t = max(0.0, min(1.0, t))
    seg = t * (len(STOPS) - 1)
    i = min(int(seg), len(STOPS) - 2)
    f = seg - i
    r = lerp(STOPS[i][0], STOPS[i + 1][0], f)
    g = lerp(STOPS[i][1], STOPS[i + 1][1], f)
    b = lerp(STOPS[i][2], STOPS[i + 1][2], f)
    return f"#{int(round(r*255)):02X}{int(round(g*255)):02X}{int(round(b*255)):02X}"

def pt(theta_deg):
    th = math.radians(theta_deg)
    # SVG y is down; this makes 0deg = top and angle increase => clockwise
    return CX + R * math.sin(th), CY - R * math.cos(th)

def build_arc_segments():
    span = 360.0 * SWEEP
    out = []
    # slight overlap so round caps hide the seams between solid segments
    overlap = (span / N) * 0.55
    for i in range(N):
        a0 = START_DEG + (span * i) / N - overlap
        a1 = START_DEG + (span * (i + 1)) / N + overlap
        x0, y0 = pt(a0)
        x1, y1 = pt(a1)
        large = 0
        col = color_at((i + 0.5) / N)
        out.append(
            f'<path d="M {x0:.2f} {y0:.2f} A {R:.2f} {R:.2f} 0 {large} 1 {x1:.2f} {y1:.2f}" '
            f'stroke="{col}" stroke-width="{W:.2f}" stroke-linecap="round" fill="none"/>'
        )
    return "\n      ".join(out), pt(START_DEG), pt(START_DEG + span)

arc_svg, start_pt, end_pt = build_arc_segments()
sx, sy = start_pt
ex, ey = end_pt

svg = f'''<?xml version="1.0" encoding="UTF-8"?>
<svg width="1024" height="1024" viewBox="0 0 1024 1024" xmlns="http://www.w3.org/2000/svg">
  <defs>
    <!-- macOS squircle clip -->
    <clipPath id="squircle">
      <rect x="0" y="0" width="1024" height="1024" rx="229" ry="229"/>
    </clipPath>

    <linearGradient id="bg" x1="0" y1="0" x2="1024" y2="1024" gradientUnits="userSpaceOnUse">
      <stop offset="0"    stop-color="#3A87E2"/>
      <stop offset="0.34" stop-color="#1F5CB8"/>
      <stop offset="0.68" stop-color="#0F2E6B"/>
      <stop offset="1"    stop-color="#0A152B"/>
    </linearGradient>

    <radialGradient id="glowAqua" cx="0.5" cy="0.5" r="0.5">
      <stop offset="0" stop-color="#61DBE0" stop-opacity="0.55"/>
      <stop offset="1" stop-color="#61DBE0" stop-opacity="0"/>
    </radialGradient>
    <radialGradient id="glowLav" cx="0.5" cy="0.5" r="0.5">
      <stop offset="0" stop-color="#949EEB" stop-opacity="0.42"/>
      <stop offset="1" stop-color="#949EEB" stop-opacity="0"/>
    </radialGradient>
    <radialGradient id="glowMint" cx="0.5" cy="0.5" r="0.5">
      <stop offset="0" stop-color="#6BEBC7" stop-opacity="0.30"/>
      <stop offset="1" stop-color="#6BEBC7" stop-opacity="0"/>
    </radialGradient>

    <!-- top specular sheen across the whole tile -->
    <linearGradient id="sheen" x1="0" y1="0" x2="0" y2="1024" gradientUnits="userSpaceOnUse">
      <stop offset="0"    stop-color="#FFFFFF" stop-opacity="0.20"/>
      <stop offset="0.32" stop-color="#FFFFFF" stop-opacity="0.04"/>
      <stop offset="0.55" stop-color="#FFFFFF" stop-opacity="0"/>
    </linearGradient>

    <!-- glass center disc -->
    <radialGradient id="centerGlass" cx="0.42" cy="0.36" r="0.85">
      <stop offset="0"   stop-color="#EAF6FF" stop-opacity="0.30"/>
      <stop offset="0.45" stop-color="#BFE2FF" stop-opacity="0.10"/>
      <stop offset="1"   stop-color="#0A152B" stop-opacity="0.16"/>
    </radialGradient>
    <radialGradient id="pulseGlow" cx="0.5" cy="0.5" r="0.5">
      <stop offset="0"   stop-color="#DBF2FF" stop-opacity="0.95"/>
      <stop offset="0.5" stop-color="#6BEBC7" stop-opacity="0.45"/>
      <stop offset="1"   stop-color="#6BEBC7" stop-opacity="0"/>
    </radialGradient>

    <filter id="soft" x="-40%" y="-40%" width="180%" height="180%">
      <feGaussianBlur stdDeviation="10"/>
    </filter>
    <filter id="softer" x="-60%" y="-60%" width="220%" height="220%">
      <feGaussianBlur stdDeviation="26"/>
    </filter>
    <filter id="ringShadow" x="-40%" y="-40%" width="180%" height="180%">
      <feDropShadow dx="0" dy="10" stdDeviation="16" flood-color="#06203D" flood-opacity="0.45"/>
    </filter>
  </defs>

  <g clip-path="url(#squircle)">
    <!-- base -->
    <rect x="0" y="0" width="1024" height="1024" fill="url(#bg)"/>

    <!-- ambient glows (mirrors LiquidGlassBackground blobs) -->
    <circle cx="250" cy="240" r="420" fill="url(#glowAqua)" filter="url(#softer)"/>
    <circle cx="830" cy="360" r="340" fill="url(#glowLav)"  filter="url(#softer)"/>
    <circle cx="430" cy="860" r="320" fill="url(#glowMint)" filter="url(#softer)"/>

    <!-- glass center disc behind the ring -->
    <circle cx="{CX}" cy="{CY}" r="{R - W/2 - 14:.1f}" fill="url(#centerGlass)"/>
    <circle cx="{CX}" cy="{CY}" r="{R - W/2 - 14:.1f}" fill="none"
            stroke="#FFFFFF" stroke-opacity="0.14" stroke-width="2"/>

    <!-- pulse mark: the live "logging heartbeat" -->
    <circle cx="{CX}" cy="{CY}" r="148" fill="none" stroke="#DBF2FF" stroke-opacity="0.10" stroke-width="3"/>
    <circle cx="{CX}" cy="{CY}" r="96"  fill="none" stroke="#DBF2FF" stroke-opacity="0.16" stroke-width="3"/>
    <circle cx="{CX}" cy="{CY}" r="120" fill="url(#pulseGlow)" filter="url(#soft)"/>
    <circle cx="{CX}" cy="{CY}" r="34" fill="#EAFBFF"/>
    <circle cx="{CX}" cy="{CY}" r="34" fill="url(#pulseGlow)"/>

    <!-- track ring -->
    <g filter="url(#ringShadow)">
      <circle cx="{CX}" cy="{CY}" r="{R}" fill="none"
              stroke="#FFFFFF" stroke-opacity="0.16" stroke-width="{W}"/>
    </g>

    <!-- focus arc (angular gradient via segments) -->
    <g filter="url(#ringShadow)">
      {arc_svg}
    </g>

    <!-- soft aqua halo around the arc -->
    <circle cx="{CX}" cy="{CY}" r="{R}" fill="none" stroke="#61DBE0" stroke-opacity="0.22"
            stroke-width="{W+22:.0f}" filter="url(#softer)"
            stroke-dasharray="{2*math.pi*R*SWEEP:.1f} {2*math.pi*R:.1f}"
            transform="rotate(-90 {CX} {CY})"/>

    <!-- live node at the leading tip -->
    <circle cx="{ex:.2f}" cy="{ey:.2f}" r="{W*0.85:.1f}" fill="#6BEBC7" opacity="0.55" filter="url(#soft)"/>
    <circle cx="{ex:.2f}" cy="{ey:.2f}" r="{W*0.46:.1f}" fill="#FFFFFF"/>
    <circle cx="{ex:.2f}" cy="{ey:.2f}" r="{W*0.30:.1f}" fill="#6BEBC7"/>

    <!-- whole-tile sheen -->
    <rect x="0" y="0" width="1024" height="1024" fill="url(#sheen)"/>
    <!-- top rim highlight -->
    <rect x="3" y="3" width="1018" height="1018" rx="227" ry="227"
          fill="none" stroke="#FFFFFF" stroke-opacity="0.30" stroke-width="2"/>
  </g>
</svg>
'''

with open("Branding/AppIcon.svg", "w") as f:
    f.write(svg)
print("wrote Branding/AppIcon.svg")
print(f"arc end node at ({ex:.1f},{ey:.1f})")
print("Run: ./Branding/sync_appicon.sh  (SVG → LifeLogger/Assets.xcassets PNGs)")
