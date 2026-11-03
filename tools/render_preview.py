#!/usr/bin/env python3
"""Render an honest schematic preview from the map coordinates in Config.luau."""
from __future__ import annotations

import html
from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[1]


def pairs(block: str) -> list[tuple[float, float]]:
    return [(float(x), float(z)) for x, z in re.findall(r"\{\s*(-?\d+(?:\.\d+)?)\s*,\s*(-?\d+(?:\.\d+)?)\s*\}", block)]


def main() -> None:
    config = (ROOT / "src/shared/Config.luau").read_text(encoding="utf-8")
    scale = float(re.search(r"Scale\s*=\s*([\d.]+)", config).group(1))
    points_block = re.search(r"Points\s*=\s*\{(.*?)\n\t\},", config, re.S).group(1)
    pads_block = re.search(r"Pads\s*=\s*\{(.*?)\n\t\},", config, re.S).group(1)
    route = [(x * scale, z * scale) for x, z in pairs(points_block)]
    pads = [(x * scale, z * scale) for x, z in pairs(pads_block)]

    def project(x: float, z: float) -> tuple[float, float]:
        return 790 + (x + 88) / 176 * 560, 105 + (z + 58) / 116 * 350

    def route_d() -> str:
        return " ".join(("M" if i == 0 else "L") + f"{project(x, z)[0]:.1f} {project(x, z)[1]:.1f}" for i, (x, z) in enumerate(route))

    pad_markup = []
    for index, (x, z) in enumerate(pads, 1):
        px, py = project(x, z)
        pad_markup.append(f'<circle cx="{px:.1f}" cy="{py:.1f}" r="9" fill="#203b43" stroke="#7eefc1" stroke-width="2"/><text x="{px:.1f}" y="{py + 3:.1f}" text-anchor="middle" font-size="8" fill="#cdeee2">{index:02d}</text>')
    trees = []
    for x, z in ((-78, 28), (-64, 38), (-48, -50), (-30, -48), (0, 44), (28, -48), (52, -44), (76, 40), (-78, 4), (48, 2)):
        px, py = project(x, z)
        trees.append(f'<path d="M {px:.1f} {py - 13:.1f} l 11 20 h -22 Z" fill="#39745d"/><path d="M {px:.1f} {py - 5:.1f} l 13 22 h -26 Z" fill="#2d624f"/>')
    start_x, start_y = project(*route[0])
    end_x, end_y = project(*route[-1])
    svg = f'''<svg xmlns="http://www.w3.org/2000/svg" width="1440" height="560" viewBox="0 0 1440 560" role="img" aria-labelledby="title desc">
  <title id="title">РУБЕЖ — кооперативная tower defense для Roblox</title>
  <desc id="desc">Схематичная карта лесного рубежа: маршрут врагов, площадки башен, портал и ядро. Это не скриншот игры.</desc>
  <defs>
    <linearGradient id="bg" x1="0" y1="0" x2="1" y2="1"><stop stop-color="#111d28"/><stop offset="1" stop-color="#1b3440"/></linearGradient>
    <linearGradient id="island" x1="0" y1="0" x2="0" y2="1"><stop stop-color="#426f59"/><stop offset="1" stop-color="#2d5145"/></linearGradient>
  </defs>
  <rect width="1440" height="560" rx="28" fill="url(#bg)"/>
  <path d="M 0 470 C 300 390 470 600 760 480 S 1180 420 1440 500 V 560 H 0 Z" fill="#162a35"/>
  <g font-family="Segoe UI, DejaVu Sans, Arial, sans-serif">
    <text x="70" y="88" font-size="16" font-weight="700" letter-spacing="4" fill="#7eefc1">CHRDK · ROBLOX CO-OP</text>
    <text x="64" y="190" font-size="92" font-weight="800" letter-spacing="2" fill="#e8f3f2">РУБЕЖ</text>
    <text x="70" y="235" font-size="21" font-weight="700" letter-spacing="2" fill="#9eb9c2">КООПЕРАТИВНАЯ TOWER DEFENSE</text>
    <text x="70" y="292" font-size="18" fill="#b7cbd1">Одна база. Общая оборона.</text>
    <text x="70" y="321" font-size="18" fill="#b7cbd1">Стройте, улучшайте и держите рубеж вместе.</text>
    <g font-size="15" font-weight="700" text-anchor="middle">
      <rect x="70" y="365" width="150" height="42" rx="21" fill="#244b43"/><text x="145" y="392" fill="#7eefc1">1–4 ИГРОКА</text>
      <rect x="232" y="365" width="130" height="42" rx="21" fill="#263e50"/><text x="297" y="392" fill="#7ed5ff">20 ВОЛН</text>
      <rect x="374" y="365" width="190" height="42" rx="21" fill="#443e2d"/><text x="469" y="392" fill="#ffd278">4 КЛАССА БАШЕН</text>
    </g>
    <text x="70" y="486" font-size="14" font-weight="700" letter-spacing="2" fill="#7eefc1">СТРОЙТЕ · УЛУЧШАЙТЕ · ПОБЕЖДАЙТЕ</text>
    <rect x="765" y="78" width="610" height="404" rx="28" fill="#10232c" stroke="#416270" stroke-width="2"/>
    <rect x="780" y="93" width="580" height="374" rx="22" fill="url(#island)"/>
    {''.join(trees)}
    <path d="{route_d()}" fill="none" stroke="#263f38" stroke-width="31" stroke-linejoin="round" stroke-linecap="round"/>
    <path d="{route_d()}" fill="none" stroke="#ccb991" stroke-width="23" stroke-linejoin="round" stroke-linecap="round"/>
    <path d="{route_d()}" fill="none" stroke="#eadbb8" stroke-width="2" stroke-dasharray="7 10" stroke-linejoin="round"/>
    {''.join(pad_markup)}
    <circle cx="{start_x:.1f}" cy="{start_y:.1f}" r="17" fill="#402d35" stroke="#ff877c" stroke-width="4"/>
    <path d="M {start_x - 5:.1f} {start_y - 7:.1f} l 10 7 l -10 7" fill="none" stroke="#ffb1a7" stroke-width="3"/>
    <circle cx="{end_x:.1f}" cy="{end_y:.1f}" r="23" fill="#173d40" stroke="#7eefc1" stroke-width="3"/>
    <path d="M {end_x:.1f} {end_y - 15:.1f} l 11 15 l -11 15 l -11 -15 Z" fill="#a5ffe0"/>
    <text x="1070" y="520" text-anchor="middle" font-size="12" letter-spacing="2" fill="#9eb9c2">СХЕМА КАРТЫ · НЕ СКРИНШОТ · v0.1.1</text>
  </g>
</svg>
'''
    output = ROOT / "docs/assets/rubezh-preview.svg"
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(svg, encoding="utf-8")
    print(f"Rendered {output.relative_to(ROOT)} ({len(pads)} pads, {len(route)} route points)")


if __name__ == "__main__":
    main()
